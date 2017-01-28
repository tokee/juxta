#!/bin/bash

# Creates collage of public available images from kb.dk
# API described on https://github.com/Det-Kongelige-Bibliotek/access-digital-objects

: ${MAX_IMAGES:=1000}
: ${BROWSE_URL:="http://www.kb.dk/images/billed/2010/okt/billeder"}
: ${PAGE_SIZE:=40}
: ${KB_LANGUAGE:=da}
: ${SEARCH_URL_PREFIX:="http://www.kb.dk/cop/syndication/images/billed/2010/okt/billeder/${KB_LANGUAGE}/?itemsPerPage=$PAGE_SIZE&orderBy=notBefore&"}

# TODO: Extract the title of the collection and show it on the generated page
# TODO: Better guessing of description text based on md:note fields
# TODO: Extraction of title

usage() {
    echo "Usage:"
    echo "./demo_kb.sh list"
    echo "             Shows available collections"
    echo "./demo_kb.sh create collection"
    echo "             Creates a page for the given collection ID"
    exit $1
}

COMMAND="$1"
if [ "list" != "$COMMAND" -a "create" != "$COMMAND" ]; then
    if [  "." == ".$COMMAND" ]; then
        echo "Please provide a command"
        usage
    fi
    >&2 echo "Error: Unknown command '$COMMAND'"
    usage 1
fi
COLLECTION="$2"
if [ "create" == "$COMMAND" -a "." == ".$COLLECTION" ]; then
    >&2 echo "Error: A collection must be provided"
    usage 2
fi

# https://github.com/Det-Kongelige-Bibliotek/access-digital-objects
# http://www.kb.dk/cop/syndication/images/billed/2010/okt/billeder/subject2109/
list_collections() {
    echo "Not implemented yet. Go to"
    echo "http://www.kb.dk/images/billed/2010/okt/billeder/subject2109/en/"
    echo "And browse to a collection (not an individual image)."
    echo "In the URL the subject can be located, such as 'subject3795'."
}

download_collection() {
    echo "- Downloading a maximum of $MAX_IMAGES images from collection ${COLLECTION}"
    local SUBJECT_ID=`echo $COLLECTION | grep -o "[0-9]*"`
    mkdir -p downloads/$COLLECTION
    local T=`mktemp`
    local PAGE=1
    rm -f downloads/$COLLECTION/sources.dat
    while [ $(( (PAGE-1)*PAGE_SIZE )) -lt $MAX_IMAGES ]; do
        local URL="${SEARCH_URL_PREFIX}page=${PAGE}&subject=${SUBJECT_ID}"
        echo "  - Fetching page ${PAGE}: $URL"
        # TODO: Seems to be limited to 400 total entries
        # http://www.kb.dk/maps/kortsa/2012/jul/kortatlas/subject233/da/?orderBy=notBefore&page=2
        # Seems to allow for paging all the way to the end of the search result
        curl -s -m 60 "$URL" | xmllint --format - > $T
        local HITS=$( cat $T | grep totalResults | sed 's/.\+>\([0-9]\+\)<.*/\1/' )
        IFS=$'\n'
        for ITEM in $( cat $T | tr '\n' ' ' | sed 's/<item /\n<item /g' | grep "<item " ); do
            local LINK=$( echo "$ITEM" | grep -o '<link>[^<]*</link>' | sed ' s/<\/\?link>//g' )
            local DESCRIPTION=$( echo "$ITEM" | grep -o '<description>[^<]*</description>' | sed ' s/<\/\?description>//g' )
            local TITLE=$( echo "$ITEM" | grep -o '<title>[^<]*</title>' | sed ' s/<\/\?title>//g' )
            local IMAGE_URL=$( echo "$ITEM" | grep -o "<[^<]*displayLabel=.image.[^>]>*[^<]*<" | sed 's/.*type=.uri..\(http[^<]*\).*/\1/' )
            local IMAGE_SHORT=`basename "$IMAGE_URL" | sed 's/ /_/g'`
            if [ ! -s downloads/$COLLECTION/$IMAGE_SHORT ]; then
                echo "    - Downloading $IMAGE_SHORT"
                # TODO: Fetch full image with
                # http://kb-images.kb.dk/online_master_arkiv_6/non-archival/Images/BILLED/2008/Billede/dk_eksp_album_191/kbb_alb_2_191_friis_011/full/full/0/native.jpg
                # https://github.com/Det-Kongelige-Bibliotek/access-digital-objects/blob/master/image-delivery.md
                curl -s -m 60 "$IMAGE_URL" > downloads/$COLLECTION/$IMAGE_SHORT
                if [ ! -s downloads/$COLLECTION/$IMAGE_SHORT ]; then
                    >&2 echo "Error: Unable do download $IMAGE_URL"
                    rm -f downloads/$COLLECTION/$IMAGE_SHORT
                    continue
                fi
            fi
            echo "downloads/$COLLECTION/${IMAGE_SHORT}|${LINK}§${TITLE}§${DESCRIPTION}" >> downloads/$COLLECTION/sources.dat
        done
        if [ $(( PAGE*PAGE_SIZE )) -ge $HITS ]; then
            break
        fi
        PAGE=$(( PAGE+1 ))
    done
    rm $T
}

if [ "list" == "$COMMAND" ]; then
    list_collections
    exit
fi

download_collection
BACKGROUND=000000 ROW_W=4 ROW_H=4 TEMPLATE=demo_kb.template.html ./juxta.sh downloads/$COLLECTION/sources.dat $COLLECTION

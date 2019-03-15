#!/bin/bash

# Creates collage of public available images from kb.dk
# API described on https://github.com/Det-Kongelige-Bibliotek/access-digital-objects

: ${MAX_IMAGES:=1000}
: ${BROWSE_URL:="http://www.kb.dk/images/billed/2010/okt/billeder"}
: ${PAGE_SIZE:=40}
: ${KB_LANGUAGE:=da}
# http://www.kb.dk/cop/syndication/images/billed/2010/okt/billeder/subject2109/en/?itemsPerPage=5
: ${SEARCH_URL_PREFIX:="http://www.kb.dk/cop/syndication/images/billed/2010/okt/billeder/"}
: ${SEARCH_URL_INFIX:="/${KB_LANGUAGE}/?itemsPerPage=$PAGE_SIZE&orderBy=notBefore&"}
# Valid values are 'none', 'intensity' and 'rainbow'
: ${IMAGE_SORT:="none"}

: ${ALLOW_UPSCALE:=true}
: ${RAW_MODE:=automax}
: ${BACKGROUND:=000000}
: ${TEMPLATE:=demo_kb.template.html}

: ${SKIP_DOWNLOAD:="false"} # Only used when debugging problematic targets

# TODO: Extract the title of the collection and show it on the generated page
# TODO: Better guessing of description text based on md:note fields
# TODO: Get full images: http://kb-images.kb.dk/online_master_arkiv_6/non-archival/Images/BILLED/2008/Billede/dk_eksp_album_191/kbb_alb_2_191_friis_011/full/full/0/native.jpg
# TODO: Trim titles to max X chars

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
export COLLECTION="$2"
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
    local PAGE=1
    local DOWNLOADED=0
    local HITS="-1"
    local POSSIBLE=0
    rm -f downloads/$COLLECTION/sources.dat
    while [ $(( (PAGE-1)*PAGE_SIZE )) -lt $MAX_IMAGES ]; do
        local URL="${SEARCH_URL_PREFIX}${COLLECTION}${SEARCH_URL_INFIX}page=${PAGE}"
        #&subject=${SUBJECT_ID}"
        # http://www.kb.dk/maps/kortsa/2012/jul/kortatlas/subject233/da/?orderBy=notBefore&page=2
        # Seems to allow for paging all the way to the end of the search result
        T="downloads/$COLLECTION/page_${PAGE}.xml"
        if [ ! -s "$T" ]; then
            echo "  - Fetching page ${PAGE}: $URL"
            curl -s -m 60 "$URL" | xmllint --format - > $T
        else
            echo " - $COLLECTION browse page $PAGE already fetched"
        fi
        if [ "$HITS" -eq "-1" ]; then
            local HITS=$( cat $T | grep totalResults | sed 's/.*>\([0-9]*\)<.*/\1/' )
            echo " - Total hits for ${COLLECTION}: $HITS"
            if [ "$HITS" -lt "$MAX_IMAGES" ]; then
                POSSIBLE=$HITS
            else
                POSSIBLE=$MAX_IMAGES
            fi
        fi
        IFS=$'\n'
        for ITEM in $( cat $T | tr '\n' ' ' | sed $'s/<item /\\\n<item /g' | grep "<item " ); do
            local LINK=$( echo "$ITEM" | grep -o '<link>[^<]*</link>' | sed ' s/<\/\?link>//g' )
            local DESCRIPTION=$( echo "$ITEM" | grep -o '<description>[^<]*</description>' | sed ' s/<\/\?description>//g' )
            local TITLE=$( echo "$ITEM" | grep -o '<title>[^<]*</title>' | sed ' s/<\/\?title>//g' )
            local IMAGE_URL=$( echo "$ITEM" | grep -o "<[^<]*displayLabel=.image.[^>]>*[^<]*<" | sed 's/.*type=.uri..\(http[^<]*\).*/\1/' )
            # The server is not consistent, so we hack. Encountered results are
            # http://kb-images.kb.dk/DAMJP2/online_master_arkiv_3/non-archival/Images/BILLED/DH/DH014583/full/full/0/native.jpg
            # http://www.kb.dk/imageService/online_master_arkiv_6/non-archival/Maps/KORTSA/2009/aug/KBK2_2_15/KBK2_2_15_014.jpg
            # TODO: Sometimes (subject3756) there are multiple image-urls. Investigate what that is about
            local IMAGE_URL=$( echo "$IMAGE_URL" | sed 's/\/full\/full\/0\/native//' | head -n 1 )
            local IMAGE_SHORT=`basename "$IMAGE_URL" | sed 's/ /_/g'`
            # Tweak URL to be against the IIIF so that the full resolution is requested
            # http://www.kb.dk/imageService/online_master_arkiv_6/non-archival/Maps/KORTSA/ATLAS_MAJOR/Kbk2_2_57/Kbk2_2_57_010.jpg
            # http://kb-images.kb.dk/online_master_arkiv_6/non-archival/Maps/KORTSA/ATLAS_MAJOR/Kbk2_2_57/Kbk2_2_57_010/full/full/0/native.jpg
            local IMAGE_URL=$( echo "$IMAGE_URL" | sed -e 's/www.kb.dk\/imageService/kb-images.kb.dk/' -e 's/.jpg$/\/full\/full\/0\/native.jpg/' -e 's/\/full\/full\/0\/native\/full\/full\/0\/native.jpg/\/full\/full\/0\/native.jpg/' )
            DOWNLOADED=$((DOWNLOADED+1))
            if [[ ! -s downloads/$COLLECTION/$IMAGE_SHORT ]]; then
                if [[ "$SKIP_DOWNLOAD" == "true" ]]; then
                    echo "    - Skipping download of image #${DOWNLOADED}/${POSSIBLE}: $IMAGE_SHORT as SKIP_DOWNLOAD=true"
                else
                    echo "    - Downloading image #${DOWNLOADED}/${POSSIBLE}: $IMAGE_SHORT"
                    # TODO: Fetch full image with
                    # http://kb-images.kb.dk/online_master_arkiv_6/non-archival/Images/BILLED/2008/Billede/dk_eksp_album_191/kbb_alb_2_191_friis_011/full/full/0/native.jpg
                    # 
                    # https://github.com/Det-Kongelige-Bibliotek/access-digital-objects/blob/master/image-delivery.md
                    # echo "Downloading $IMAGE_URL to downloads/$COLLECTION/$IMAGE_SHORT"
                    curl -s -m 60 "$IMAGE_URL" > downloads/$COLLECTION/$IMAGE_SHORT
                    if [ ! -s downloads/$COLLECTION/$IMAGE_SHORT ]; then
                        >&2 echo "Error: Unable to download $IMAGE_URL to downloads/$COLLECTION/$IMAGE_SHORT"
                        rm -f downloads/$COLLECTION/$IMAGE_SHORT
                        continue
                    fi
                fi
            fi
            if [ ! -s downloads/$COLLECTION/$IMAGE_SHORT ]; then
                echo "downloads/$COLLECTION/${IMAGE_SHORT}|${LINK}§${TITLE}§${DESCRIPTION}" >> downloads/$COLLECTION/sources.dat
            else
                echo "$IMAGE_URL" >> downloads/$COLLECTION/sources_unavailable.dat
            fi
            if [ "$DOWNLOADED" -ge "$MAX_IMAGES" ]; then
                break
            fi
        done
        if [ $(( PAGE*PAGE_SIZE )) -ge $HITS ]; then
            break
        fi
        PAGE=$(( PAGE+1 ))
    done
}

if [ "list" == "$COMMAND" ]; then
    list_collections
    exit
fi

download_collection
if [ "intensity" == "$IMAGE_SORT" ]; then
    DAT=downloads/$COLLECTION/sources_intensity_${MAX_IMAGES}.dat
    if [ -s "$DAT" ]; then
        echo "- Skipping sort by intensity as $DAT already exists"
    else 
        echo "- Sorting images by intensity"
        ./intensity_sort.sh downloads/$COLLECTION/sources.dat $DAT
    fi
    SORTED_SOURCE="$DAT"
elif [ "rainbow" == "$IMAGE_SORT" ]; then
    DAT=downloads/$COLLECTION/sources_rainbow_${MAX_IMAGES}.dat
    if [ -s $DAT ]; then
        echo "Skipping sort in rainbow order as $DAT already exists"
    else
        echo "- Sorting images in rainbow order"
        ./rainbow_sort.sh downloads/$COLLECTION/sources.dat $DAT
    fi
    SORTED_SOURCE="$DAT"
else
    SORTED_SOURCE="downloads/$COLLECTION/sources.dat"
fi
. ./juxta.sh $SORTED_SOURCE $COLLECTION

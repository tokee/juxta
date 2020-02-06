#!/bin/bash

# Downloads images from kb.dk along with URL, title and description
# Intended for further processing with tools such as juxta or PixPlot
#
# API described on https://github.com/Det-Kongelige-Bibliotek/access-digital-objects
# Collection browsable at http://www.kb.dk/images/billed/2010/okt/billeder/subject2108/en/?

###############################################################################
# CONFIG
###############################################################################

: ${MAX_IMAGES:=100000}
: ${BROWSE_URL:="http://www5.kb.dk/images/billed/2010/okt/billeder"}
: ${PAGE_SIZE:=40}
: ${KB_LANGUAGE:=da}
# http://www.kb.dk/cop/syndication/images/billed/2010/okt/billeder/subject2109/en/?itemsPerPage=5
: ${SEARCH_URL_PREFIX:="http://www5.kb.dk/cop/syndication/images/billed/2010/okt/billeder/"}
: ${SEARCH_URL_INFIX:="/${KB_LANGUAGE}/?itemsPerPage=$PAGE_SIZE&orderBy=notBefore&"}
: ${DOWNLOAD_FOLDER:="downloads"}
# If true and an image is to be downloaded, the full download folder is searched for images with
# the same name. If one is found, it is hard-linked to the current destination folder.
# Note that there is no formal guarantee that image names are unique across collections.
: ${FIND_EQUAL_NAME:="false"} 
: ${SKIP_DOWNLOAD:="false"} # Only used when debugging problematic targets
: ${SKIP_XMLLINT:="false"}
# The maximum number of constituents for each image database entry. For some postcards both the
# front and the back are scanned as separate image bitmaps, but they are stores as a single
# entry. Specifying 2 as MAX_CONSTITUENTS means that both the front and the back is fetched.
: ${MAX_CONSTITUENTS:="1"}

: ${COLLECTION:="$1"}

# TODO: Get full images: http://kb-images.kb.dk/online_master_arkiv_6/non-archival/Images/BILLED/2008/Billede/dk_eksp_album_191/kbb_alb_2_191_friis_011/full/full/0/native.jpg

usage() {
    echo ""
    echo "Usage:"
    echo "./download_kb.sh collection-ID"
    echo ""
    echo "Example: MAX_IMAGES=10 ./demo_kb.sh subject3795"
    exit $1
}

check_parameters() {
    if [[ "." == ".$COLLECTION" ]]; then
        >&2 echo "Error: A collection-ID must be provided"
        usage 2
    fi
    if [[ "$MAX_CONSTITUENTS" -lt "1" ]]; then
        >&2 echo "Error: MAX_CONSTITUENTS must be at least 1. It was $MAX_CONSTITUENTS"
        usage 3
    fi
    if [[ -z "$(which xmllint)" ]]; then
        >&2 echo "Error: 'xmllint' not available. Install with 'sudo apt  install libxml2-utils' or similar"
        exit 4
    fi
}

################################################################################
# FUNCTIONS
################################################################################

streaming_unique() {
    local LAST=""
    while read -r URL; do
        if [[ "$URL" != "$LAST" ]]; then
            echo "$URL"
        fi
        LAST="$URL"
    done
}
download_image() {
    local IMAGE_URL="$1"
    
    local IMAGE_SHORT=`basename "$IMAGE_URL" | sed 's/ /_/g'`
    local IMAGE_DEST="${DOWNLOAD_FOLDER}/$COLLECTION/$IMAGE_SHORT"
    # Tweak URL to be against the IIIF so that the full resolution is requested
    # http://www.kb.dk/imageService/online_master_arkiv_6/non-archival/Maps/KORTSA/ATLAS_MAJOR/Kbk2_2_57/Kbk2_2_57_010.jpg
    # http://kb-images.kb.dk/online_master_arkiv_6/non-archival/Maps/KORTSA/ATLAS_MAJOR/Kbk2_2_57/Kbk2_2_57_010/full/full/0/native.jpg
    local IMAGE_URL=$( echo "$IMAGE_URL" | sed -e 's/www.kb.dk\/imageService/kb-images.kb.dk/' -e 's/.jpg$/\/full\/full\/0\/native.jpg/' -e 's/\/full\/full\/0\/native\/full\/full\/0\/native.jpg/\/full\/full\/0\/native.jpg/' )
    DOWNLOADED=$((DOWNLOADED+1))
    
    local ALREADY_DEBUGGED=false
    # Can the image be located elsewhere in the download folder?
    if [[ ! -s "${IMAGE_DEST}" && "$FIND_EQUAL_NAME" == "true" ]]; then
        local ALTERNATIVE=$(find "${DOWNLOAD_FOLDER}" -name "$IMAGE_SHORT" | head -n 1)
        if [[ "." != "$ALTERNATIVE" ]]; then
            echo "    - Hardlinking image #${DOWNLOADED}/${POSSIBLE}: $IMAGE_DEST from $ALTERNATIVE"
            ln "$ALTERNATIVE" "$IMAGE_DEST"
            ALREADY_DEBUGGED=true
        fi
    fi

    # Download the image if it is not existing
    if [[ ! -s "${IMAGE_DEST}" ]]; then
        if [[ "$SKIP_DOWNLOAD" == "true" ]]; then
            echo "    - Skipping download of image #${DOWNLOADED}/${POSSIBLE}: $IMAGE_DEST as SKIP_DOWNLOAD=true"
        else
            echo "    - Downloading image #${DOWNLOADED}/${POSSIBLE}: $IMAGE_DEST"
            # TODO: Fetch full image with
            # http://kb-images.kb.dk/online_master_arkiv_6/non-archival/Images/BILLED/2008/Billede/dk_eksp_album_191/kbb_alb_2_191_friis_011/full/full/0/native.jpg
            # 
            # https://github.com/Det-Kongelige-Bibliotek/access-digital-objects/blob/master/image-delivery.md
            # echo "Downloading $IMAGE_URL to ${IMAGE_DEST}"
            curl -s -m 60 "$IMAGE_URL" > "${IMAGE_DEST}"
            if [ ! -s "${IMAGE_DEST}" ]; then
                >&2 echo "Error: Unable to download $IMAGE_URL to ${IMAGE_DEST}"
                rm -f "${IMAGE_DEST}"
                continue
            fi
        fi
    else
        if [[ "$ALREADY_DEBUGGED" == "false" ]]; then
            echo "    - Skipping download of image #${DOWNLOADED}/${POSSIBLE}: $IMAGE_DEST as image is already present"
        fi
    fi

    # Update mappings
    if [ -s "${IMAGE_DEST}" ]; then
        echo "${IMAGE_DEST}|${LINK}§${TITLE}§${DESCRIPTION}§${COPYRIGHT}" >> "${DOWNLOAD_FOLDER}/$COLLECTION/sources.dat"
    else
        echo "$IMAGE_URL" >> "${DOWNLOAD_FOLDER}/$COLLECTION/sources_unavailable.dat"
    fi
}

download_collection() {
    echo "- Downloading a maximum of $MAX_IMAGES images from collection ${COLLECTION}"
    local SUBJECT_ID=`echo $COLLECTION | grep -o "[0-9]*"`
    mkdir -p ${DOWNLOAD_FOLDER}/$COLLECTION
    local PAGE=1
    local DOWNLOADED=0
    local HITS="-1"
    local POSSIBLE=0
    rm -f "${DOWNLOAD_FOLDER}/$COLLECTION/sources.dat"
    while [ $(( (PAGE-1)*PAGE_SIZE )) -lt $MAX_IMAGES ]; do
        local URL="${SEARCH_URL_PREFIX}${COLLECTION}${SEARCH_URL_INFIX}page=${PAGE}"
        #&subject=${SUBJECT_ID}"
        # http://www.kb.dk/maps/kortsa/2012/jul/kortatlas/subject233/da/?orderBy=notBefore&page=2
        # Seems to allow for paging all the way to the end of the search result
        T="${DOWNLOAD_FOLDER}/$COLLECTION/page_${PAGE}.xml"
        if [ ! -s "$T" ]; then
            echo "  - Fetching page ${PAGE}: $URL"
            if [[ "true" == "$SKIP_XMLLINT" ]]; then
                curl -s -m 60 "$URL" > $T
            else
                curl -s -m 60 "$URL" | xmllint --format - > $T
            fi
        else
            echo " - $COLLECTION browse page $PAGE already fetched"
        fi
        if [ "$HITS" -eq "-1" ]; then
            local HITS=$( grep totalResults < $T | sed 's/.*>\([0-9]*\)<.*/\1/' )
            if [[ ".$HITS" == .$(grep totalResults < $T) ]]; then
                # <meta name="totalResults" content="2604" />
                local HITS=$( grep totalResults < $T | sed 's/.*content="\([0-9]*\)".*/\1/' )
            fi
            echo " - Total hits for ${COLLECTION}: $HITS"
            if [[ -z "$HITS" ]]; then
                >&2 echo "Warning: Unable to locate totalResults in $URL"
                POSSIBLE=$MAX_IMAGES
            elif [ "$HITS" -lt "$MAX_IMAGES" ]; then
                POSSIBLE=$HITS
            else
                POSSIBLE=$MAX_IMAGES
            fi
        fi
        IFS=$'\n'
        for ITEM in $( cat $T | tr '\n' ' ' | sed $'s/<item /\\\n<item /g' | grep "<item " ); do
            local LINK=$( echo "$ITEM" | grep -o '<link>[^<]*</link>' | sed ' s/<\/\?link>//g' )
            local DESCRIPTION=$( echo "$ITEM" | grep -o '<description>[^<]*</description>' | sed ' s/<\/\?description>//g' )
            local COPYRIGHT=$( echo "$ITEM" | grep -o '<md:accessCondition[^>]*displayLabel="Copyright"[^>]*>[^<]*</md:accessCondition>' | sed ' s/<md:accessCondition[^>]*displayLabel="Copyright"[^>]*>\([^<]*\)<\/md:accessCondition>/\1/' )
            local TITLE=$( echo "$ITEM" | grep -o '<title>[^<]*</title>' | sed ' s/<\/\?title>//g' )
            local IMAGE_URL=$( echo "$ITEM" | grep -o "<[^<]*displayLabel=.image.[^>]>*[^<]*<" | sed 's/.*type=.uri..\(http[^<]*\).*/\1/' )
            # The server is not consistent, so we hack. Encountered results are
            # http://kb-images.kb.dk/DAMJP2/online_master_arkiv_3/non-archival/Images/BILLED/DH/DH014583/full/full/0/native.jpg
            # http://www.kb.dk/imageService/online_master_arkiv_6/non-archival/Maps/KORTSA/2009/aug/KBK2_2_15/KBK2_2_15_014.jpg
            # TODO: Sometimes (subject3756) there are multiple image-urls. Investigate what that is about
            local IMAGE_URLS=$( echo "$IMAGE_URL" | sed 's/\/full\/full\/0\/native//' | streaming_unique | head -n $MAX_CONSTITUENTS )
            while read -r IMAGE_URL; do
                download_image "$IMAGE_URL"
            done <<< "$IMAGE_URLS"
            
            if [ "$DOWNLOADED" -ge "$MAX_IMAGES" ]; then
                break
            fi
        done
        if [ $(( PAGE*PAGE_SIZE )) -ge "$HITS" ]; then
            break
        fi
        PAGE=$(( PAGE+1 ))
    done
    # Why do we get duplicates?
    echo " - Ensuring that "${DOWNLOAD_FOLDER}/$COLLECTION/sources.dat" only contains unique entries"
    local TUNIQ=$(mktemp)
    LC_ALL=C sort "${DOWNLOAD_FOLDER}/$COLLECTION/sources.dat" | LC_ALL=C uniq > "$TUNIQ"
    mv "$TUNIQ" "${DOWNLOAD_FOLDER}/$COLLECTION/sources.dat"

}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
download_collection
echo "Finished downloading $COLLECTION with MAX_IMAGES=$MAX_IMAGES $(date +'%Y-%m-%d %H:%M')"

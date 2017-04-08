#!/bin/bash

# Creates collage of public available images from coverbrowser.com

# http://www.coverbrowser.com/covers/maxx
# TODO: Don't download the images, just extract the URLs
# Move meta-information to footer (amazing-spider-man is fine for testing)

: ${MAX_IMAGES:=5000}
: ${URL_BASE:="http://www.coverbrowser.com/covers"}
: ${IMG_BASE:="http://www.coverbrowser.com"}
: ${OUT:="$2"}
: ${THREADS:=4}
: ${RAW_W:=2}
: ${RAW_H:=3}
: ${BACKGROUND:="000000"}
: ${TEMPLATE:=demo_coverbrowser.template.html}
: ${ALLOW_UPSCALE:=true}

usage() {
    echo "Usage:   ./demo_coverbrowser.sh collection"
    echo "Example: ./demo_coverbrowser.sh cerebus"
    echo "Locate collections at http://www.coverbrowser.com"
    exit $1
}

# Out: API_SEARCH
process_args() {
    COLLECTION="$1"
    if [ "." == ".$COLLECTION" ]; then
        >&2 echo "Error: No collection specified"$'\n'
        usage 2
    fi
}

fetch_pages() {
    echo " - Fetching primary page ${URL_BASE}/${COLLECTION}"
    mkdir -p "${COLLECTION}"
    if [ ! -s "${COLLECTION}/page_1.html" ]; then
        curl -s -m 100 "${URL_BASE}/${COLLECTION}" > "${COLLECTION}/page_1.html"
    fi
    local SUBS=$( cat ${COLLECTION}/page_1.html | grep -o "<a href=\"/covers/$COLLECTION/[0-9]\+\">#" | sort | uniq | sed 's/.*\/\([0-9]\+\)">#/\1/' )
    if [ "." != ".$SUBS" ]; then
        for SUB in $SUBS; do
            echo "   - Fetching next page ${URL_BASE}/${COLLECTION}/${SUB}"
            if [ ! -s "${COLLECTION}/page_${SUB}.html" ]; then
                curl -s -m 100 "${URL_BASE}/${COLLECTION}/${SUB}" > "${COLLECTION}/page_${SUB}.html"
            fi
        done
    fi
    
}

extract_image_data() {
    echo " - Extracting image data"
    pushd ${COLLECTION} > /dev/null
    for PAGE in $( ls page_[0-9]*.html | sort -n -t _ -k 2); do
        cat $PAGE | grep -o "<p class=\"cover\".*$" > "${PAGE}.relevant"
        if [ "$PAGE" == "page_1.html" ]; then
            local PAGE_BASE="${URL_BASE}/${COLLECTION}"
        else
            local PN=$(echo "$PAGE" | grep -o "[0-9]*")
            local PAGE_BASE="${URL_BASE}/${COLLECTION}/${PN}"
        fi
        while read LINE; do
            # Don't confuse the zoom-image with the cover
            LINE=$( echo "$LINE" | sed 's/img src="\/image\/zoom\.png" alt="zoom"//' )
            local ALT=$( echo "$LINE" | sed 's/.*alt="\([^"]*\).*/\1/' )
            local SRC=$( echo "$LINE" | sed 's/.*src="\([^"]*\).*/\1/' )
            local ANCHOR=$( echo "$LINE" | sed 's/.*href="\(#[^"]*\).*/\1/' )
            local LINK="${PAGE_BASE}${ANCHOR}"
            echo "$SRC $LINK $ALT" >> imagedata.dat
        done < "${PAGE}.relevant"
    done
    popd > /dev/null
}

download_image() {
    local SRC="$1"
    local IMG_URL="${IMG_BASE}${SRC}"
    local IBASE=$( basename "$SRC" )
    local IMG_DEST="${COLLECTION}/images/${IBASE}"
    if [ -s "$IMG_DEST" ]; then
        echo "   - Skipping existing image $IMG_DEST"
    else
        echo "   - Downloading $IMG_URL"
        curl -s -m 60 "$IMG_URL" > "$IMG_DEST"
    fi
}
export -f download_image

download_images() {
    echo " - Downloading images"
    export COLLECTION
    export URL_BASE
    export IMG_BASE
    mkdir -p "${COLLECTION}/images"
    cat ${COLLECTION}/imagedata.dat | head -n $MAX_IMAGES | cut -d\  -f1 | tr '\n' '\0' | sed 's/"/\\"/g' | xargs -0 -P $THREADS -n 1 -I {} bash -c 'download_image "{}"'
}

generate_juxta_data() {
    echo " - Generating juxta data"
    rm -f "${COLLECTION}/juxtafeed.dat"
    local COUNT=0
    while read LINE; do
        local IMG=${COLLECTION}/images/$( basename $(echo "$LINE" | cut -d\  -f1) )
        local HREF=$(echo "$LINE" | cut -d\  -f2)
        local TITLE=$(echo "$LINE" | sed 's/^[^ ]* [^ ]* //')
        echo "${IMG}|${HREF}§${TITLE}" >> "${COLLECTION}/juxtafeed.dat"
        COUNT=$(( COUNT+1 ))
        if [ "$COUNT" -eq "$MAX_IMAGES" ]; then
            break
        fi
    done < ${COLLECTION}/imagedata.dat
}

process_args $@
fetch_pages
extract_image_data
download_images
generate_juxta_data

echo " - Calling juxta"
. ./juxta.sh "${COLLECTION}/juxtafeed.dat" "$COLLECTION"

#!/bin/bash

# Fetches Flora Danica images from Statens Naturhistoriske Museum http://www.daim.snm.ku.dk/flora-danica-dk

: ${BACKGROUND:="eeeeee"}
: ${AGGRESSIVE_IMAGE_SKIP:=true}
: ${RAW_MODE:=percentile90}
: ${RAW_GRAVITY:="center"}
: ${ALLOW_UPSCALE:=true}
: ${QUALITY:=90}
: ${CANVAS_ASPECT_W:="2"}

: ${MAX_IMAGES:="3980"}

: ${DEST:="$1"}
: ${DEST:="flora_danica"}
: ${DOWNLOAD:="downloads/flora_danica"}
: ${SORT_ORDER:="name"} # Possible valued: id, name
: ${MAX_ZOOM_PIXEL_RATIO:="4.0"}

MIN_ID=3981
MAX_ID=7960
URL_BASE="http://www.daim.snm.ku.dk/Flora-Danica-details-dk?auto_id="

usage() {
    echo "Usage:"
    echo "./demo_flora.sh [destination]"
    echo ""
    echo "Smaller test run with"
    echo "MAX_IMAGES=20 ./demo_flora.sh flora_test"
    exit $1
}

pushd ${BASH_SOURCE%/*} > /dev/null
JUXTA_HOME=$(pwd)
mkdir -p "$DOWNLOAD"
pushd "$DOWNLOAD" > /dev/null
DOWNLOAD=$(pwd)
popd > /dev/null
popd > /dev/null
: ${TEMPLATE:="$JUXTA_HOME/demo_flora.template.html"}
mkdir -p "$DEST"

download() {
    echo -n "" > "${DEST}/imagelist.dat"
    local COUNT=1
    local ID=$MIN_ID
    while [[ $COUNT -le $MAX_IMAGES && $ID -le $MAX_ID ]]; do
        local URL="${URL_BASE}$ID"
        local H_DEST="${DOWNLOAD}/${ID}.html"
        local I_DEST="${DOWNLOAD}/flora_danica_${ID}.jpg"
        if [[ ! -s "$H_DEST" ]]; then
            curl -s -L "$URL" > "$H_DEST"
        fi

        IMAGE_URL=$(grep '<img id="limage" ' < "$H_DEST" | sed 's/.*id="limage" src="\([^"]*\)".*/\1/')
        if [[ ! -s "$I_DEST" ]]; then
            curl -s -L "$IMAGE_URL" > "$I_DEST"
        fi
        LATIN_NAME=$(grep '<tr><td class="caption ">Oprindeligt navn' < "$H_DEST" | sed 's/.*>\([^<]*\)<\/td><\/tr>/\1/')
        
        
        echo "${I_DEST}|${URL}§${LATIN_NAME}" | tee -a "${DEST}/imagelist.dat"
        
        COUNT=$(( COUNT+1 ))
        ID=$(( ID+1 ))
    done
}    

sort_images() {
    echo " - Sorting by $SORT_ORDER"
    if [[ "name" == "$SORT_ORDER" ]]; then
        sed 's/\(.*\)§\(.*\)/\2§\1/' < ${DEST}/imagelist.dat | sort | sed 's/\(.*\)§\(.*\)/\2§\1/' > ${DEST}/imagelist_sorted.dat
    else
        cp ${DEST}/imagelist.dat ${DEST}/imagelist_sorted.dat
    fi
}

download
sort_images
. ./juxta.sh "${DEST}/imagelist_sorted.dat" $SORTED_SOURCE $DEST

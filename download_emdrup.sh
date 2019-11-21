#!/bin/bash

# Raw image download for open images from Emdrup Library
# TODO: Extend with linkback & metadata
# TODO: Handle different image formats

: ${MAX_IMAGES:="10"}
: ${START_IMAGE:="11000"}
: ${DEST:="downloads/emdrup"}

: ${SIDE:="20000"}
: ${OVERWRITE:="false"}

: ${DOWNLOAD_URL_PREFIX:="http://galleri.au.dk/fsi/server?type=image&source=aul/anskuelsestavler%20-%20fullsize/"}
: ${DOWNLOAD_URL_POSTFIX:=".tif&width=${SIDE}&height=${SIDE}"}

mkdir -p "$DEST"

download() {
    local COUNTER=0
    while [[ "$COUNTER" -lt $MAX_IMAGES ]]; do
        local IMAGE_ID=$(( START_IMAGE + COUNTER ))
        local DI="${DEST}/${IMAGE_ID}.jpg"
        if [[ -s "$DI" && "$OVERWRITE" == "false" ]]; then
            echo " - Skipping $DI as it already exists"
        else
            local IU="${DOWNLOAD_URL_PREFIX}${IMAGE_ID}${DOWNLOAD_URL_POSTFIX}"
            echo " - Downloading $IU"
            curl -s "$IU" > "$DI"
            if [[ ! -s "$DI" ]]; then
                echo "   - Download failed"
                rm -f "$DI"
            fi
        fi
        COUNTER=$(( COUNTER +1 ))
    done
}

download
echo "Finished. Result in $DEST"
        

#!/bin/bash

# Fetches Flora Danica images from Statens Naturhistoriske Museum http://www.daim.snm.ku.dk/flora-danica-dk

: ${BACKGROUND:="000000"}
: ${AGGRESSIVE_IMAGE_SKIP:=true}
: ${RAW_MODE:=percentile90}
: ${ALLOW_UPSCALE:=true}

: ${MAX_IMAGES:="3980"}

: ${DEST:="$1"}
: ${DEST:="flora_danica"}
: ${DOWNLOAD:="downloads/flora_danica"}

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

download() {
    local COUNT=1
    local ID=$MIN_ID
    while [[ $COUNT -le $MAX_IMAGES && $ID -le $MAX_ID ]]; then
        URL="${URL_BASE}$ID"

        local TDEST="${DOWNLOADS}/${ID}.html"
        if [[ ! -s "$TDEST" ]]; then
            curl -s "$URL" > "$TDEST"
        fi
        IMAGE_URL=$(grep '<img id="limage" ' < "$TDEST" | sed 's/.*id="limage" src="\([^"]*\)".*/\1/')
        LATIN_NAME=$(grep '<tr><td class="caption ">Oprindeligt navn' < "$TDEST" | sed 's/.*>\([^<]*\)<\/td><\/tr>/\1/')

        echo "$
        
        COUNT=$(( COUNT+1 ))
        ID=$(( ID+1 ))
    done
}    


# Produces: CONTENT_FOLDERS with a list of sub-folders that has content
process() {
    local PARENT="$1"
    local CURRENT="$2"
    if [ ! -d "$CURRENT" ]; then
        >&2 echo "$CURRENT folder not found"
        return
    fi
    pushd "$CURRENT" > /dev/null
    local DESIGNATION=$(basename $(pwd))

    # Depth-first
    local SUB
    local SUBS=""
    local SUBSUBS=""
    local ALLSUBS=$(ls -d */ 2> /dev/null)
    for SUB in $ALLSUBS; do
        if [[ ".juxta" == "$SUB" ]]; then
            continue
        fi
        process "$DESIGNATION" "$SUB"
        if [[ "." != ".$CONTENT_FOLDERS" ]]; then
            if [[ "." != ".$SUBS" ]]; then
                SUBS="$SUBS"$'\n'
                SUBSUBS="$SUBSUBS"$'\n'
            fi
            SUBS="$SUBS$CONTENT_FOLDERS"
            SUBSUBS="$SUBSUBS$DESIGNATION/$SUB"
        fi
    done

    # Any images in current folder?
    shopt -s nocaseglob 
    local IMAGES=$(ls -d -- $FORMAT_GLOB 2> /dev/null)
    shopt -u nocaseglob 
    if [[ "." == .$(echo "$IMAGES" | tr -d '\n') ]]; then
        IMAGES=""
    fi
    if [[ "." == .$(echo "$SUBS" | tr -d '\n') ]]; then
        SUBS=""
    fi

    if [[ "." == ".$SUBS" && "." == ".$IMAGES" ]]; then
        popd > /dev/null
        CONTENT_FOLDERS=""
        return
    fi
    #log "Images [${IMAGES}] or sub-folders [${SUBS}] with images located in $DESIGNATION"
    mkdir -p .juxta

    #¤¤¤ TODO: Make this a proper js-include structure
    echo "$SUBS" > .juxta/sub_image_folders.js
    
    echo "$IMAGES" > .juxta/glob_images.dat
    if [[ "." != ".$IMAGES" ]]; then
        local DIFF=""
        if [[ "true" == "$MAKE_ZIP" ]]; then
            log "Creating ZIP-file with all images for bulk download"
            ZIPNAME="$(basename $(pwd)).zip"
            zip -u $ZIPNAME -@ < .juxta/glob_images.dat
        else
            ZIPNAME=""
        fi
        
        if [[ ! -s .juxta/active_images.dat  ||  "." != .$(diff .juxta/glob_images.dat .juxta/active_images.dat) ]]; then
            log "Creating collage for $(echo "$IMAGES" | wc -l) images in ${DESIGNATION}"
            # TODO: Delete any existing tile structures
        else
            log "Re-creating index.html for collage $(echo "$IMAGES" | wc -l) images in ${DESIGNATION}"
            #log "Skipping collage-creation for ${DESIGNATION} as images are unchanged"
        fi
        mv .juxta/glob_images.dat .juxta/active_images.dat
        ZIPNAME="$ZIPNAME" DESIGNATION="$DESIGNATION" PARENT="$PARENT" SUBS="$SUBS" . $JUXTA_HOME/juxta.sh .juxta/active_images.dat .juxta/
        mv .juxta/index.html ./index.html

        CONTENT_FOLDERS="$DESIGNATION/"
    else
        log "Skipping collage-creation for ${DESIGNATION} as there are no images only sub folders $SUBSUBS"
        CONTENT_FOLDERS="$SUBSUBS"
    fi
    #¤¤¤ TODO: Move .juxta/index.html to image folder
    
    popd > /dev/null
}
log "Creating/updating galleries from root $1"
process "" $1
log "Finished creating/updating galleries from root $1"

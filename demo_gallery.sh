#!/bin/bash

# Performs a recursive descend of a folder structure, creating a collage for the images in each folder
# as well links to parent- and sub-folders with images.
# The juxta-generated files will be a folder named '_juxta' as well as an index.html-file in each folder.

# Note: If any folders contains more than 10,000 images, RAW_MODE=fixed as well as RAW_W and RAW_H must
# be specified. Sample: RAW_MODE=fixed RAW_W=8 RAW_H=6 ./demo_gallery.sh MyPictures

# TODO: Add switch for index.html or not in links to sub-folders

# Glob for finding images in the folder
: ${FORMAT_GLOB:="*.jpg *.jpeg *.png *.tif *.tiff *.bmp"}
# We move index.html one step up, and data resides in the .juxta-folder
: ${DATA_ROOT:=".juxta/"}

: ${BACKGROUND:="000000"}
: ${AGGRESSIVE_IMAGE_SKIP:=true}
: ${RAW_MODE:=percentile90}
: ${ALLOW_UPSCALE:=true}
: ${MAKE_ZIP:=false} # If true, a ZIP with all the images for a given page is created
: ${SORT:="alpha"} # Possible values: "alpha" (1.jpg, 10.jpg, 2.jpg) and "numeric" (1.jpg, 2.jpg ... 10.jpg)

usage() {
    echo "Usage:"
    echo "./demo_gallery.sh imageroot"
    echo ""
    echo "Smaller test run with"
    echo "MAX_IMAGES=20 ./demo_gallery.sh imageroot"
    exit $1
}
log() {
    #¤¤¤ TODO: Make a proper log
    >&2 echo "Log: $1"
}
IMAGE_ROOT="$1"
if [ "." == ".$IMAGE_ROOT" ]; then
    usage 1
fi
pushd ${BASH_SOURCE%/*} > /dev/null
JUXTA_HOME=$(pwd)
popd > /dev/null
: ${TEMPLATE:="$JUXTA_HOME/demo_gallery.template.html"}

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

    if [[ "$SORT" == "numeric" ]]; then
        echo "Sorting images numerically (best for 1.jpg, 2.jpg ... 10.jpg image collections)"
        echo "$IMAGES" | sort -n > .juxta/glob_images.dat
    else
        echo "$IMAGES" > .juxta/glob_images.dat
    fi
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

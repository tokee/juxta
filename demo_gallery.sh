#!/bin/bash

# Performs a recursive descend of a folder structure, creating a collage for the images in each folder
# as well links to parent- and sub-folders with images.
# The juxta-generated files will be a folder named '_juxta' as well as an index.html-file in each folder.

# STATUS: Under construction


# Glob for finding images in the folder
: ${FORMAT_GLOB:="*.jpg *.jpeg *.png *.tif *.tiff *.bmp"}
# We move index.html one step up, and data resides in the .juxta-folder
: ${DATA_ROOT:=".juxta/"}
: ${BACKGROUND:="000000"}

usage() {
    echo "Usage:"
    echo "./demo_scale.sh imageroot"
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

# Produces: true if images, else false
process() {
    local PARENT="$1"
    local CURRENT="$2"
    if [ ! -d "$CURRENT" ]; then
        >&2 echo "$CURRENT folder not found"
        return
    fi
    pushd "$CURRENT" > /dev/null
    local DESIGNATION=$(basename $(pwd))

    log "#¤¤¤ parent=$PARENT current=$CURRENT"

    # Depth-first
    local SUB
    local SUBS=""
    local ALLSUBS=$(ls -d */ 2> /dev/null)
    log "#¤¤¤ ALLSUBS=$ALLSUBS"
    for SUB in $ALLSUBS; do
        log "#¤¤¤ sub=$SUB"
        if [[ ".juxta" == "$SUB" ]]; then
            continue
        fi
        log "#¤¤¤ Recursive call to process $DESIGNATION $SUB"
        if [[ $(process "$DESIGNATION" "$SUB") ]]; then
            log "#¤¤¤ Finished recursive call to $SUB with true"
            if [[ "." != ".$SUBS" ]]; then
                SUBS="$SUBS"$'\n'
            fi
            SUBS="$SUBS$SUB"
        else
            log "#¤¤¤ process $DESIGNATION $SUB resulted in false"
        fi
    done
    log "#¤¤¤ Image-containing subs=$SUBS"

    # Any images in current folder?
    shopt -s nocaseglob 
    local IMAGES=$(ls -d $FORMAT_GLOB 2> /dev/null)
    shopt -u nocaseglob 
    log "#¤¤¤ Images=$(echo $IMAGES | wc -l)"
    log "#¤¤¤ Images2=$(echo $IMAGES)"

    if [[ "." == ".$SUBS" && "." == ".$IMAGES" ]]; then
        log "No images or sub-folders with images in $DESIGNATION"
        popd > /dev/null
        false
        return
    fi
    log "Images or sub-folders with images located in $DESIGNATION"
    mkdir -p .juxta

    #¤¤¤ TODO: Make this a proper js-include structure
    echo "$SUBS" > .juxta/sub_image_folders.js
    
    echo "$IMAGES" > .juxta/glob_images.dat
    log "Checking for existing image lists"
    local DIFF=""
    if [[ ! -s .juxta/active_images.dat  ||  "." != .$(diff .juxta/glob_images.dat .juxta/active_images.dat) ]]; then
        log "Creating collage for $(echo "$IMAGES" | wc -l) images in ${DESIGNATION}"
        mv .juxta/glob_images.dat .juxta/active_images.dat
        . $JUXTA_HOME/juxta.sh .juxta/active_images.dat .juxta/
        mv .juxta/index.html ./index.html
    else
        log "Skipping collage-creation for ${DESIGNATION} as images are unchanged"
    fi

    #¤¤¤ TODO: Move .juxta/index.html to image folder
    
    popd > /dev/null
    true
}
process "" $1

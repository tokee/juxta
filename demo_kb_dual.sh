#!/bin/bash

# Creates a dual-layer collage for image-pairs from kb.dk
# API described on https://github.com/Det-Kongelige-Bibliotek/access-digital-objects

pushd ${BASH_SOURCE%/*} > /dev/null
: ${DOWNLOAD_SCRIPT:="$(pwd)/download_kb.sh"}
popd > /dev/null

# Valid values are 'none', 'intensity' and 'rainbow'
: ${IMAGE_SORT:="none"}

: ${ALLOW_UPSCALE:=true}
: ${RAW_MODE:=automax}
: ${BACKGROUND:=000000}
: ${TEMPLATE:=demo_kb.template.html}

: ${MAX_IMAGES:="1000000000"} # 1b
: ${MAX_IMAGES_PER_COLLECTION:="$MAX_IMAGES"}

# What to do is an etry only holds a single image. Possible values are
# discard:   Discard the image completely
# duplicate: Use the same image as primary and secondary
# blank:     Use a bland (empty area) as secondary image
: ${SINGLE_IMAGE_ACTION:="discard"}

# TODO: Extract the title of the collection and show it on the generated page
# TODO: Better guessing of description text based on md:note fields
# TODO: Get full images: http://kb-images.kb.dk/online_master_arkiv_6/non-archival/Images/BILLED/2008/Billede/dk_eksp_album_191/kbb_alb_2_191_friis_011/full/full/0/native.jpg
# TODO: Trim titles to max X chars

usage() {
    echo "Usage:"
    echo "./demo_kb_multi.sh list"
    echo "             Shows available collections"
    echo "./demo_kb_multi.sh create collection*"
    echo "             Creates a page for the given collection IDs"
    echo "Sample:"
    echo "./demo_kb_multi.sh create subject3795"

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
shift
export COLLECTIONS="$@"
if [ "create" == "$COMMAND" -a "." == ".$COLLECTIONS" ]; then
    >&2 echo "Error: A collection must be provided"
    usage 2
fi
# Multi-collection handling
ALLC=$(tr ' ' '_' <<< "$COLLECTIONS" | sed 's/_$//')
: ${ROOTDEST:="$ALLC"}

# https://github.com/Det-Kongelige-Bibliotek/access-digital-objects
# http://www.kb.dk/cop/syndication/images/billed/2010/okt/billeder/subject2109/
list_collections() {
    echo "Not implemented yet. Go to"
    echo "http://www.kb.dk/images/billed/2010/okt/billeder/subject2109/en/"
    echo "And browse to a collection (not an individual image)."
    echo "In the URL the subject can be located, such as 'subject3795'."
}

download_images() {
    mkdir -p downloads/$ROOTDEST
    rm -r downloads/$ROOTDEST/dual_sources.dat
    if [[ "$MAX_IMAGES" -lt "$MAX_IMAGES_PER_COLLECTION" ]]; then
        MAX_IMAGES_PER_COLLECTION=$MAX_IMAGES
    fi
    OLD_MI=$MAX_IMAGES
    MAX_IMAGES=$MAX_IMAGES_PER_COLLECTION
    for COLLECTION in $COLLECTIONS; do
        echo "Downloading collection $COLLECTION"
        # We force this to 2 as handling image pairs is the sole purpose of this script
        MAX_CONSTITUENTS=2
        . $DOWNLOAD_SCRIPT "$COLLECTION"
        cat downloads/$COLLECTION/sources.dat >> downloads/$ROOTDEST/dual_sources.dat
    done
    MAX_IMAGES=$OLD_MI
}

handle_single_image() {
    local IMAGE="$1"
    local URL="$2"
    local EXTRA="$3"

    echo " - Single $URL"

    local LINE="${IMAGE}|${URL}§$EXTRA"
    echo "$LINE" >> "downloads/$ROOTDEST/duplicate_primary_sources.dat"
    echo "$LINE" >> "downloads/$ROOTDEST/duplicate_secondary_sources.dat"

    echo "$LINE" >> "downloads/$ROOTDEST/blank_primary_sources.dat"
    echo "missing|${URL}§$EXTRA" >> "downloads/$ROOTDEST/blank_secondary_sources.dat"
}

create_sources() {
    # Clean up
    for HANDLING in discard duplicate blank; do
        for PRIORITY in primary secondary; do
            S="downloads/$ROOTDEST/${HANDLING}_${PRIORITY}_sources.dat"
            if [[ -s "$S" ]]; then
                rm "$S"
            fi
        done
    done
    
    local LAST_IMAGE=""
    local LAST_URL=""
    local LAST_EXTRA=""
    while read -r LINE; do
        local BASE=$( sed 's/§.*//' <<< "$LINE" )

        local IMAGE=$(cut -d\| -f1 <<< "$BASE")
        local URL=$(cut -d\| -f2 <<< "$BASE")
        local EXTRA=$( sed 's/^[^§]*§//' <<< "$LINE" )

        if [[ "$URL" == "$LAST_URL" ]]; then # Dual-image
            local PRIMARY="${LAST_IMAGE}|${LAST_URL}§${LAST_EXTRA}"
            local SECONDARY="${IMAGE}|${URL}§${EXTRA}"
            for HANDLING in discard duplicate blank; do
                echo "$PRIMARY" >> "downloads/$ROOTDEST/${HANDLING}_primary_sources.dat"
                echo "$SECONDARY" >> "downloads/$ROOTDEST/${HANDLING}_secondary_sources.dat"
                echo " - Dual   $URL"
            done
            
            LAST_IMAGE=""
            LAST_URL=""
            LAST_LINE=""
            continue
        fi
        if [[ ".$LAST_IMAGE" != "." ]]; then # Single image
            handle_single_image "$LAST_IMAGE" "$LAST_URL" "$LAST_EXTRA"
        fi          
        
        LAST_IMAGE="$IMAGE"
        LAST_URL="$URL"
        LAST_EXTRA="$EXTRA"
    done < downloads/$ROOTDEST/dual_sources.dat

    if [[ ".$LAST_IMAGE" != "." ]]; then # Single image
        handle_single_image "$LAST_IMAGE" "$LAST_URL" "$LAST_EXTRA"
    fi          
}

if [ "list" == "$COMMAND" ]; then
    list_collections
    exit
fi

#download_images
create_sources

mkdir -p "dual_$ROOTDEST"
for PRIORITY in primary secondary; do
    . ./juxta.sh downloads/$ROOTDEST/${SINGLE_IMAGE_ACTION}_${PRIORITY}_sources.dat "dual_${ROOTDEST}/${PRIORITY}"
done

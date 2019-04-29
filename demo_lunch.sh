#!/bin/bash

# An interesting project at University Of North Texas (https://digital.library.unt.edu) documents
# lunch trays before eating and after: https://digital.library.unt.edu/ark:/67531/metadc36227/#top
# This script creates _two_ collages: One of the images before eating and one after.
# These are presented on top of each other and panning & zooming is synchronized.
# A circular area around the mouse shows the after-eating trays, simulating a magnifying
# glass, while the rest of the page shows the before-eating trays.

#
# API can be found at https://digital.library.unt.edu/api/ 
#


###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null

: ${MAX_IMAGES:="1000000000"}
: ${SET:="collection:DPWMSC"}
: ${DEST:="lunch"}

: ${RAW_W:="6"}
: ${RAW_H:="5"}

: ${REPOSITORY:="https://digital.library.unt.edu/oai/"}
: ${USE_RESUMPTION:="true"}
: ${SKIP_OAI:="false"}
: ${SKIP_RENDER:="false"}
popd > /dev/null

usage() {
    echo "Usage:"
    echo "./demo_lunch.sh"
    exit $1
}

check_parameters() {
    true
}

################################################################################
# FUNCTIONS
################################################################################

fetch_metadata() {
    if [[ "true" == "$SKIP_OAI" ]]; then
        echo "- Skipping OAI-PMH harvest of $SET from $REPOSITORY as SKIP_OAI == true"
        return
    fi
    REPOSITORY="$REPOSITORY" SET="$SET" USE_RESUMPTION="true" DEST="$DEST" ./harvest_oai_pmh.sh 
}

total_images() {
    if [[ ! -s "$DEST/images_double.dat" ]]; then
        >&2 echo "Error: No images in $DEST/images_double.dat"
        usage 3
    fi

    local ICOUNT=$(wc -l < $DEST/images_double.dat)
    if [[ $ICOUNT -lt $MAX_IMAGES ]]; then
        echo $ICOUNT
    else
        echo $MAX_IMAGES
    fi
}

# TODO: Seems to fetch the wrong image for after
fetch_images() {
    cat $DEST/oai-pmh.page_*.xml | tr '\n' ' ' | sed 's/<\/record>/<\/record>\n/g' | grep '<record>' | sed 's/.*<dc:title>\([^<]*\)<.*<dc:title.*<dc:identifier>\(https\?:\/\/digital.library.unt.edu\/\)\([^<]*\)<.*/\2\3|\2\/iiif\/\3m1\/1\/full\/max\/0\/default.jpg|\2iiif\/\3m1\/2\/full\/max\/0\/default.jpg|\1/' > $DEST/images_double.dat

    local MAXI=$(total_images)
    echo "- Downloading $MAXI images"
    mkdir -p $DEST/images
    local CURRENT=1
    while read -r ILINE; do
        # https://digital.library.unt.edu/ark:/67531/metadc36125/|https://digital.library.unt.edu//iiif/ark:/67531/metadc36125/m1/1/full/max/0/default.jpg|https://digital.library.unt.edu/iiif/ark:/67531/metadc36125/m1/1/full/max/1/default.jpg|Student Lunch Tray: 01_20110413_01C5954
        local ID=$(sed 's%.*/\([^/]*\)/m1/1/full/max/0.*%\1%' <<< "$ILINE")
        local LINK==$(cut -d\| -f1 <<< "$ILINE")
        local IMAGE0=$(cut -d\| -f2 <<< "$ILINE")
        local IMAGE1=$(cut -d\| -f3 <<< "$ILINE")
        local DESIGNATION=$(cut -d\| -f4 <<< "$ILINE")
        
        local DIMAGE="$DEST/images/${ID}"
        if [[ -s "${DIMAGE}_0.jpg" && -s "${DIMAGE}_1.jpg" ]]; then
            echo "   - ${CURRENT}/${MAXI}: Skipping images for $ID as they already exists"
        CURRENT=$(( CURRENT+1 ))
            continue
        else
            echo "   - ${CURRENT}/${MAXI}: Downloading images for $ID"
        fi
        curl -s "$IMAGE0" > "${DIMAGE}_0.jpg"
        curl -s "$IMAGE1" > "${DIMAGE}_1.jpg"
        CURRENT=$(( CURRENT+1 ))
    done <<< $(head -n $MAXI "$DEST/images_double.dat")
}

create_juxta_input() {
    echo "  - Generating juxta data files"
    rm -f "$DEST/images_set_0.dat" "$DEST/images_set_1.dat"
    local MAXI=$(total_images)
    while read -r ILINE; do
        # https://digital.library.unt.edu/ark:/67531/metadc36125/|https://digital.library.unt.edu//iiif/ark:/67531/metadc36125/m1/1/full/max/0/default.jpg|https://digital.library.unt.edu/iiif/ark:/67531/metadc36125/m1/1/full/max/1/default.jpg|Student Lunch Tray: 01_20110413_01C5954
        local ID=$(sed 's%.*/\([^/]*\)/m1/1/full/max/0.*%\1%' <<< "$ILINE")
        local LINK=$(cut -d\| -f1 <<< "$ILINE")
        local DESIGNATION=$(cut -d\| -f4 <<< "$ILINE")
        local DIMAGE="images/${ID}"
        echo "${DIMAGE}_0.jpg|${LINK}|${DESIGNATION}" >> "$DEST/images_set_0.dat"
        echo "${DIMAGE}_1.jpg|${LINK}|${DESIGNATION}" >> "$DEST/images_set_1.dat"
    done <<< $(head -n $MAXI "$DEST/images_double.dat")
}

render_collages() {
    if [[ "true" == "$SKIP_RENDER" ]]; then
        echo "- Skipping rendering of the two collages as SKIP_RENDER == true"
        return
    fi
    echo " - Rendering two collages"
    create_juxta_input
    pushd $DEST > /dev/null
    for C in 0 1; do
        echo " - Calling juxta for collage $C"
        MAX_IMAGES="$MAX_IMAGES" BACKGROUND="000000" RAW_W="$RAW_W" RAW_H="$RAW_H" ALLOW_UPSCALE="true" ../juxta.sh images_set_${C}.dat collage_${C}
    done
    popd > /dev/null
}

merge_collages() {
    echo " - Not implemented yet"
    # cp collage_0/index.html .
    # cp -r collage_0/resources/ .
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
fetch_metadata
fetch_images
render_collages
merge_collages

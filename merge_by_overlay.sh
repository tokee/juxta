#!/bin/bash

#
# Takes 2 juxta collages and creates a presentation with one collage as base and
# the other collage shown as a loupe-effect (magnifying glass).
#
# The collages needs to be exact same size and with the same number of images.
#
# Used by demo_lunch.sh to visualise before & after images of lunch trays.
#

# TODO: Add merge_by_overlay.template.html based on working files from demo_lunch.sh

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
: ${COLLAGE1:="$1"}
: ${COLLAGE2:="$2"}
: ${DEST_FILE:="loupe.html"}
: ${TEMPLATE:="$(pwd)/merge_by_overlay.template.html"}
popd > /dev/null

usage() {
    echo "Usage: ./merge_by_overlay.sh collage1 collage2"
    exit $1
}

get_json_value() {
    local INPUT="$1"
    local KEY="$2"
    local VALUE=$(grep -o "\"$KEY\" *: *\"[^\"]\+\"" | cut -d: -f2 | sed -e 's/^ *"//' -e 's/" *$//')
    if [[ -z "$VALUE" ]]; then
        >&2 echo "Error: Unable to extract value for '$KEY' from '$INPUT'"
        exit 4
    fi
    echo "$VALUE"
}

check_parameters() {
    if [[ ! -s "${COLLAGE1}/collage.dzi" ]]; then
        >&2 echo "Unable to read '${COLLAGE1}/collage.dzi'"
        usage 2
    fi
    if [[ ! -s "${COLLAGE2}/collage.dzi" ]]; then
        >&2 echo "Unable to read '${COLLAGE2}/collage.dzi'"
        usage 3
    fi
    WIDTH=$(get_json_value "${COLLAGE1}/collage.dzi" "Width")
    WIDTH2=$(get_json_value "${COLLAGE2}/collage.dzi" "Width")
    if  [[ "$WIDTH" -ne "$WIDTH1" ]]; then
        >&2 echo "Error: The widths for the 2 collages must be equal, but were $WIDTH and $WIDTH2"
        exit 5
    fi
    HEIGHT=$(get_json_value "${COLLAGE1}/collage.dzi" "HEIGHT")
    HEIGHT2=$(get_json_value "${COLLAGE2}/collage.dzi" "HEIGHT")
    if  [[ "$HEIGHT" -ne "$HEIGHT1" ]]; then
        >&2 echo "Error: The heights for the 2 collages must be equal, but were $HEIGHT and $HEIGHT2"
        exit 6
    fi
}

################################################################################
# FUNCTIONS
################################################################################

# http://stackoverflow.com/questions/14434549/how-to-expand-shell-variables-in-a-text-file
# Input: template-file
function ctemplate() {
    if [[ ! -s "$1" ]]; then
        >&2 echo "Error: Template '$1' could not be found"
        exit 8
    fi
    local TMP=$(mktemp /tmp/juxta_XXXXXXXX)
    echo 'cat <<END_OF_TEXT' >  "$TMP"
    cat  "$1"                >> "$TMP"
    echo 'END_OF_TEXT'       >> "$TMP"
    . "$TMP"
    rm "$TMP"
}

merge() {
    ctemplate > "$DEST_FILE"
}


###############################################################################
# CODE
###############################################################################

check_parameters "$@"
merge
echo "Created $DEST_FILE"

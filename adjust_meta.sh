#!/bin/bash

#
# Regenerates meta-files used for providing contextual metadata when an image is selected.
# This is primarily used for enabling metadata search on an existing non-search-capable
# collage.
#
# Released under Apache 2.0
# Primary developer: Toke Eskildsen - @TokeEskildsen - toes@kb.dk / te@ekot.dk
#

###############################################################################
# CONFIG
###############################################################################

: ${COLLAGE:="$1"}
: ${ASYNC_META_SIDE:=100000000} # Effectively infinite

# Will (hopefully) be filled later on by data from the existing collage
: ${INCLUDE_ORIGIN:=""}
: ${RAW_IMAGE_COLS:=""}

function usage() {
    cat <<EOF
Usage: ./adjust_meta.js <collage>

When executed, the script will force all image metadata to be loaded when the
webpage with the collage is opened. This will result in 2 things:

1) It will be possible to enable search functionality (see the default template
   on how to do so)
2) It will be possible to see all meta data on image selection if the webpage
   is opened from the local file system (it is always possible when a webserver
   is used)

Warning: Do not run this script on collages with 100.000+ images: It will
likely make the collage unusable as the browser will require too much memory
to hold the meta data.

Advanced: It is possible to use this script to generate chunked metadata files
instead, thereby reverting a previous concatenation. If that is derired, run as
ASYNC_META_SIDE:=50 ./adjust_meta.js <collage>
EOF
    exit $1
}

check_parameters() {
    if [[ -z "$COLLAGE" ]]; then
        >&2 echo "Error: No collage specified"
        usage 2
    fi
    if [[ ! -s "$COLLAGE/collage_setup.js" ]]; then
        >&2 echo "Error: The file $COLLAGE/collage_setup.js is not available."
        >&2 echo "Unable to adjust meta data layout"
        usage 3
    fi
    if [[ ! -s "$COLLAGE/imagelist.dat" ]]; then
        >&2 echo "Error: The file $COLLAGE/imagelist.dat is not available."
        >&2 echo "Unable to adjust meta data layout"
        usage 4
    fi
    if [[ -s "$COLLAGE/previous_options.conf" ]]; then
        echo "  - Sourcing previous options from $COLLAGE/previous_options.conf"
        source "$COLLAGE/previous_options.conf"
    fi
    if [[ ".$INCLUDE_ORIGIN" == "." ]]; then
        echo "Warning: Unable to determine if INCLUDE_ORIGIN was originally true or false. Going with the default 'true', but if that yields unexpected results, try re-running with INCLUDE_ORIGIN=false instead"
        INCLUDE_ORIGIN="true"
    fi
    if [[ ".$RAW_IMAGE_COLS" == "." ]]; then
        if [[ "$(wc -l < "$COLLAGE/imagelist.dat")" -le "$ASYNC_META_SIDE" ]]; then
            # Does not matter what RAW_IMAGE_COLS was as everything will be a single file
            RAW_IMAGE_COLS="$ASYNC_META_SIDE"
        else
            RAW_IMAGE_COLS=$(grep colCount "$COLLAGE/collage_setup.js" | grep -o "[0-9]*")
            if [[ -z "$RAW_IMAGE_COLS" ]]; then
                >&2 echo "Error: Unable to determine RAW_IMAGE_COLS. Using RAW_IMAGE_COLS=10000000 and hoping for the best"
                RAW_IMAGE_COLS=10000000
            fi
        fi            
    fi
    
    DEST="$COLLAGE" # Compatibility with unmodified create_meta_files
}

################################################################################
# FUNCTIONS
################################################################################


#
# Creates callback-files with filenames and/or meta-data for the source images,
# used for the graphical overlays.
#
# This must be kept in sync with the same method in juxta.sh
# TODO: Copy it from juxta.sh upon program run to ensure it is in sync.
#
create_meta_files() {
    echo "  - Creating meta files"
    rm -f "$DEST/meta/"*.json
    mkdir -p "$DEST/meta"
    local ROW=0
    local COL=0
    local TOKENS
    while read IMAGE; do
        if [[ "true" == "$INCLUDE_ORIGIN" ]]; then
            if [[ "$PRE" -gt 0 || "$POST" -gt 0 ]]; then
                IFS=$'|' TOKENS=($IMAGE)
                local IPATH=${TOKENS[0]}
                local IMETA=${TOKENS[1]}
                unset IFS
                local ILENGTH=${#IPATH}
#                if [[ $PRE -eq $POST ]]; then # Happens with single image
#                    local IMETA=""
#                else 
                local CUT_LENGTH=$(( ILENGTH-POST-PRE ))
                if [[ "$CUT_LENGTH" -lt "0" ]]; then
                    local IMETA="|$IMETA"
                else
                    local IMETA="${IPATH:$PRE:$CUT_LENGTH}|$IMETA"
                fi
#                fi
            else
                local IMETA="$IMAGE"
            fi
        else
            IFS=$'|' TOKENS=($IMAGE)
            local IMETA=${TOKENS[1]}
            # Use bash replace instead
            unset IFS
        fi
        local IMETA="$(echo "$IMETA" | sed -e 's/&/&amp;/g' -e 's/\"/\\&quot;/g')"
        local DM="$DEST/meta/$((COL/ASYNC_META_SIDE))_$((ROW/ASYNC_META_SIDE)).json"
        if [[ ! -s "$DM" ]]; then
            echo "{ \"prefix\": \"${IMAGE_PATH_PREFIX}\"," >> "$DM"
#            if [[ $PRE -eq $POST ]]; then # Probably single image
#                echo "  \"postfix\": \"\"," >> $DM
#            else
                echo "  \"postfix\": \"${IMAGE_PATH_POSTFIX}\"," >> "$DM"
#            fi
            echo -n "  \"meta\": ["$'\n'"\"$IMETA\"" >> "$DM"
        else
            echo -n ","$'\n'"\"$IMETA\"" >> "$DM"
        fi
        COL=$(( COL+1 ))
        if [[ "$COL" -ge "$RAW_IMAGE_COLS" ]]; then
            ROW=$(( ROW+1 ))
            COL=0
        fi
    done < "$DEST/imagelist.dat"
    # Close all structures in the metadata files
    find "$DEST/meta/" -name "*.json" -exec bash -c "echo ']}' >> \"{}\"" \;
    # Create a preload file for the upper left block of image metadata
    # This is primarily to get around CORS-issued with Chrome on the local file system
    mkdir -p "$DEST/resources/"
    echo -n "var preloaded = " > "$DEST/resources/overlays_preload.js"
    cat "$DEST/meta/0_0.json" >> "$DEST/resources/overlays_preload.js"
}

adjust_previous_options() {
    if [[ ! -s "$COLLAGE/previous_options.conf" ]]; then
        echo "Warning: Cannot update non-existing $COLLAGE/previous_options.conf (not critical)"
        return
    fi
    echo "  - Setting INCLUDE_ORIGIN=$INCLUDE_ORIGIN and RAW_IMAGE_COLS=$RAW_IMAGE_COLS in $COLLAGE/previous_options.conf"
    sed -i "s/INCLUDE_ORIGIN:=\"[a-z]*\"/INCLUDE_ORIGIN:=\"$INCLUDE_ORIGIN\"/" "$COLLAGE/previous_options.conf"
    sed -i "s/ASYNC_META_SIDE:=\"[0-9]*\"/ASYNC_META_SIDE:=\"$ASYNC_META_SIDE\"/" "$COLLAGE/previous_options.conf"
}

adjust_collage_setup() {
    if [[ ! -s "$COLLAGE/collage_setup.js" ]]; then
        >&2 echo "Warning: Cannot update non-existing $COLLAGE/collage_setup.js"
        usage 5
    fi
    echo "  - Setting asyncMetaSide: $ASYNC_META_SIDE in $COLLAGE/collage_setup.js and $COLLAGE/index.html"
    sed -i "s/asyncMetaSide: *[0-9]*/asyncMetaSide: $ASYNC_META_SIDE/" "$COLLAGE/collage_setup.js"
    sed -i "s/asyncMetaSide: *[0-9]*/asyncMetaSide: $ASYNC_META_SIDE/" "$COLLAGE/index.html"
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"

create_meta_files
adjust_previous_options
adjust_collage_setup
echo "Finished adjusting metadata file layout for $COLLAGE"

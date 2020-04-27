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
: ${CREATE_BACKUP:="true"}

# Holds a list of imagepath/imagenames with metadata. The list will be merged
# with the existing image list for the collage, replacing the metadata for
# matching images in that list.
# This will not change the number of images or the order of the images in the
# imagelist for the collage.
# The format for imagepath/imagename and metadata is
#
# myimages/someimage123.jpg|Metadata for image 123
# myimages/someimage127.jpg
# myimages/someimage134.jpg|Only metadata for some images
#
# IMPORTANT: Not implemented yet!
: ${ENRICHED:=""}
# If enriched is defined, the path is ignored when matching the images with
# metadata.
: ${ENRICHED_IGNORE_PATH:="true"}

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
    echo "  - Located imagelist with $(wc -l < "$COLLAGE/imagelist.dat") images at $COLLAGE/imagelist.dat"
    if [[ -s "$COLLAGE/previous_options.conf" ]]; then
        echo "  - Sourcing previous options from $COLLAGE/previous_options.conf"
        source "$COLLAGE/previous_options.conf"
    fi
    if [[ ".$INCLUDE_ORIGIN" == "." ]]; then
        echo "Warning: Unable to determine if INCLUDE_ORIGIN was originally true or false. Going with the default 'true'. If that yields unexpected results, try re-running with INCLUDE_ORIGIN=false instead"
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

create_backup() {
    if [[ ".true" != ".$CREATE_BACKUP" ]]; then
        echo "  - Skipping backup as CREATE_BACKUP==$CREATE_BACKUP"
        return
    fi
    local ZIP="meta_backup_$(date +%Y%m%d-%H%M).zip"
    echo "  - Creating backup $COLLAGE/$ZIP"
    pushd "$COLLAGE" > /dev/null
    zip -qr "$ZIP" collage_setup.js index.html meta/* previous_options.conf resources/overlays_preload.sh resources/search_support.sh imagelist.dat
    popd > /dev/null
}


#
# Splits the given imagelist infor tabulated format:
# sequence_number path image path/image metadata
#
# Synchronized from juxta.sh
tabify_imagelist() {
    local IN="$1"
    COUNTER=0
    while read -r LINE; do
        if [[ "." == ".$LINE" ]]; then
            continue
        fi
        
        if [[ "$LINE" =~ ^([^|]*)[|](.*)$ ]]; then
            local PATHFILE="${BASH_REMATCH[1]}"
            local META="${BASH_REMATCH[2]}"
        else
            local PATHFILE="$LINE"
            local META=""
        fi
        
        if [[ "$PATHFILE" =~ ^(.*/)([^/]*)$ ]]; then
            local FPATH="${BASH_REMATCH[1]}"
            local FNAME="${BASH_REMATCH[2]}"
        else
            local FPATH=""
            local FNAME="$PATHFILE"
        fi
        
        echo "$COUNTER"$'\t'"$FPATH"$'\t'"$FNAME"$'\t'"$PATHFILE"$'\t'"$META"

        COUNTER=$(( COUNTER+1 ))
    done < "$IN"
}

#
# Merges the given ENRICHED list with the existing image list for the collage,
# replacing the metadata for matching images in that list.
enrich_metadata() {
    if [[ -z "$ENRICHED" ]]; then
        echo "  - Skipping enrichment of metadata as no ENRICHED is defined"
        return
    fi
    echo "  - Enriching $COLLAGE/imagelist.dat ($(wc -l < "$COLLAGE/imagelist.dat") entries) with $ENRICHED"

    local S=$(mktemp)
    local D=$(mktemp)
    local DS=$(mktemp)
    
    if [[ "true" == "$ENRICHED_IGNORE_PATH" ]]; then
        local SORT_KEY=3,3
        tabify_imagelist "$ENRICHED" | LC_ALL=c sort -t $'\t' -k3,3 > "$S"
        tabify_imagelist "$COLLAGE/imagelist.dat" | LC_ALL=c sort -t $'\t' -k3,3 > "$D"
        LC_ALL=c join -t $'\t' -j 3 -a 2 -o 2.1,2.2,2.3,2.5,1.5 "$S" "$D" > "$DS"
    else
        local SORT_KEY=4,4
        tabify_imagelist "$ENRICHED" | LC_ALL=c sort -t $'\t' -k4,4 > "$S"
        tabify_imagelist "$COLLAGE/imagelist.dat" | LC_ALL=c sort -t $'\t' -k4,4 > "$D"
        LC_ALL=c join -t $'\t' -j 4 -a 2 -o 2.1,2.2,2.3,2.5,1.5 "$S" "$D" > "$DS"
    fi

    echo -n "" > "$COLLAGE/imagelist_enriched.dat"
    while IFS=  read -r LINE; do
        local META=$(cut -d$'\t' -f5 <<< "$LINE")  # Primary
        local FALLBACK=$(cut -d$'\t' -f4 <<< "$LINE") # Fallbac
        : ${META:="$FALLBACK"}
        echo -n "$(cut -d$'\t' -f2,3 <<< "$LINE" | tr -d $'\t')" >> "$COLLAGE/imagelist_enriched.dat"
        if [[ ! -z "$META" ]]; then
            echo "|$META" >> "$COLLAGE/imagelist_enriched.dat"
        else
            echo "" >> "$COLLAGE/imagelist_enriched.dat"
        fi
    done < <(sort -n < "$DS")

    local OL=$(wc -l < "$COLLAGE/imagelist.dat")
    local EL=$(wc -l < "$COLLAGE/imagelist_enriched.dat")
    if [[ "$OL" -ne "$EL" ]]; then
        >&2 echo "Error: Enriching $COLLAGE/imagelist.dat ($OL entries) with $ENRICHED produced $COLLAGE/imagelist_enriched.dat ($EL entries). The mismatch between the number of entries means that imagelist_enriched.dat will not be used"
    else
        echo "  - Replacing $COLLAGE/imagelist.dat $COLLAGE/imagelist_enriched.dat (storing old imagelist.dat as $COLLAGE/imagelist.dat.old)"
        mv "$COLLAGE/imagelist.dat" "$COLLAGE/imagelist.dat.old"
        cp "$COLLAGE/imagelist_enriched.dat" "$COLLAGE/imagelist.dat"
    fi
    
    rm "$S" "$D" "$DS"
}

#
# Calculates prefix & postfix used for packing by create_meta_files
#
# This must be kept in sync with store_collage_setup in juxta.sh
#
calculate_pre_and_post() {
    # Derive shared pre- and post-fix for all images for light image compression
    local BASELINE="$(head -n 1 "$DEST/imagelist.dat" | cut -d'|' -f1)"
    local LENGTH=${#BASELINE}
    PRE=$LENGTH
    POST=$LENGTH
    local POST_STR=$BASELINE
    local ANY_META=false
    while read IMAGE; do
        IFS=$'|' TOKENS=($IMAGE)
        local IPATH=${TOKENS[0]}
        local IMETA=${TOKENS[1]}
        unset IFS
        if [[ "." != ".$IMETA" ]]; then
            ANY_META=true
        fi
        #echo "**** ${BASELINE:0:$PRE} $BASELINE $LENGTH $PRE"
        #echo "$IMAGE"
        while [[ "$PRE" -gt 0 && ".${IPATH:0:$PRE}" != ".${BASELINE:0:$PRE}" ]]; do
            PRE=$((PRE-1))
        done

        local CLENGTH=${#IPATH}
        local CSTART=$(( CLENGTH-POST ))
        while [[ "$POST" -gt 0 && ".${POST_STR}" != ".${IPATH:$CSTART}" ]]; do
            #echo "*p* $POST  ${POST_STR} != ${IPATH:$CSTART:$CLENGTH}"
            POST=$(( POST-1 ))

            local PSTART=$(( LENGTH-POST ))
            POST_STR=${BASELINE:$PSTART}
            local CSTART=$(( CLENGTH-POST ))
        done

        #echo "pre=$PRE post=$POST post_str=$POST_STR $IMAGE"
        if [[ "$PRE" -eq "0" && "$POST" -eq "$LENGTH" ]]; then
            #echo "break"
            break
        fi
    done < "$DEST/imagelist.dat"
    IMAGE_PATH_PREFIX=${BASELINE:0:$PRE}
    IMAGE_PATH_POSTFIX=${POST_STR}
#    echo "Pre $PRE '$IMAGE_PATH_PREFIX', post $POST '$IMAGE_PATH_POSTFIX'"
}



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
    echo "  - Setting prefix: '$IMAGE_PATH_PREFIX' and postfix: '$IMAGE_PATH_POSTFIX' in $COLLAGE/collage_setup.js and $COLLAGE/index.html"
    local SAFE_PREFIX="$(sed 's%/%\\/%g' <<< "$IMAGE_PATH_PREFIX")"
    sed -i "s/prefix: *\"[^\"]*\"/prefix: \"${SAFE_PREFIX}\"/" "$COLLAGE/index.html"
    sed -i "s/prefix: *\"[^\"]*\"/prefix: \"${SAFE_PREFIX}\"/" "$COLLAGE/collage_setup.js"
    local SAFE_POSTFIX="$(sed 's%/%\\/%g' <<< "$IMAGE_PATH_POSTFIX")"
    sed -i "s/postfix: *\"[^\"]*\"/postfix: \"${SAFE_POSTFIX}\"/" "$COLLAGE/index.html"
    sed -i "s/postfix: *\"[^\"]*\"/postfix: \"${SAFE_POSTFIX}\"/" "$COLLAGE/collage_setup.js"

}

copy_support_files() {
    local DF="$COLLAGE/resources/search_support.js"
    if [[ ! -s "$DF" ]]; then
        echo "  - Copying search_support.js to $COLLAGE/resources/"
        cp "${BASH_SOURCE%/*}/web/search_support.js" "$DF"
    elif [[ "." != ".$(diff "${BASH_SOURCE%/*}/web/search_support.js" "$COLLAGE/resources/search_support.js")" ]]; then
        echo "  - Copying search_support.js to $COLLAGE/resources/ as it was outdated"
        cp "${BASH_SOURCE%/*}/web/search_support.js" "$DF"
    else
        echo "  - Skipping copying of search_support.js as it is already present at $COLLAGE/resources/"
    fi
}

print_finish_message() {
    cat<<EOF

Finished adjusting metadata file layout for ${COLLAGE}.
If this was done to enable search, add the following HTML-snippet somewhere
in $COLLAGE/index.html:

  <input type="text" placeholder="Search query" id="free_search" title="Search query" />
  <span id="search_matches">? hits</span>

and add the follow snippet at the bottom, just before just before </body>:

  <!-- Must be included after creation of OpenSeadragon viewer -->
  <script src="resources/search_support.js"></script>
  <script>
    // See resources/search_support.js for all options
    searchConfig.minQueryLength = 2;
  </script>


This script changed the following files:

$COLLAGE/collage_setup.js
$COLLAGE/index.html
$COLLAGE/meta/*
$COLLAGE/previous_options.conf
$COLLAGE/resources/overlays_preload.sh
$COLLAGE/resources/search_support.sh
$( if [[ ! -z "$ENRICHED" ]]; then echo "$COLLAGE/imagelist.dat"; fi)
EOF
    
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"

create_backup

enrich_metadata

calculate_pre_and_post
create_meta_files

adjust_previous_options
adjust_collage_setup
copy_support_files

print_finish_message

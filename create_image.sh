#!/bin/bash

#
# Creates a single image from a juxta mosaic
#
# Requirements: vips for all processing, python for 100MPixel+ images
#
# Note: Regular TIFF and JPEG are not usable for large files.
# - Regular TIFF cannot exceed 4GB (2GB for some readers) and
# - JPEG cannot exceed 65Kx65K in dimensions ( ~4 Gigapixel ).
#
# Some formats suitable for large images are BigTIFF, JPEG2000 and PNG.
# BigTIFF has limited support: https://en.wikipedia.org/wiki/TIFF#BigTIFF
# JPEG2000 has so-so support: https://en.wikipedia.org/wiki/JPEG_2000#Application_support
# PNG has excellent support but does not support lossless compression
# so images will be large, relative to JPEG2000.
#

###############################################################################
# CONFIG
###############################################################################

: ${COLLAGE_FOLDER:="$1"}
: ${ZOOM_LEVEL:="$2"}

: ${IMAGE_TYPE:="png"}
: ${OUT:="$(basename $COLLAGE_FOLDER).$IMAGE_TYPE"}

################################################################################
# FUNCTIONS
################################################################################

usage() {
    echo "Usage: ./create_image.sh collage_folder [zoom_level]"
    echo ""
    echo "If no zoom_level is provided, the deepest one will be used"
    exit $1
}

parse_parameters() {
    if [[ ! -f "$COLLAGE_FOLDER" ]]; then
        >&2 echo "Error: Unable to access collage folder '$COLLAGE_FOLDER'"
        usage 2
    fi
    if [[ "." != ".$ZOOM_LEVEL" ]]; then
        if [[ ! -f "$COLLAGE_FOLDER/$ZOOM_LEVEL" ]]; then
            >&2 echo "Error: Unable to access collage folder at given zoom level '$COLLAGE_FOLDER/$ZOOM_LEVEL'"
            usage 3
        fi
    else
        for Z in $(seq 1 40); do
            if [[ -f "$COLLAGE_FOLDER/$Z" ]]; then
                ZOOM_LEVEL="$Z"
            else
                break
            fi
        done
        if [[ "." == ".$ZOOM_LEVEL" ]]; then
            >&2 echo "Error: Expected sub-folders for OpenSeadragon zoom levels in '$COLLAGE_FOLDER'"
            exit 4
        fi
    fi
    echo " - Merging tiles from $COLLAGE_FOLDER/$ZOOM_LEVEL into $OUT"
}

resolve_file_layout() {
    # If limit, resolve LIMIT_FOLDER_SIZE & col/row from dumped setup. Fail if no setup
    # If dzi, use find+sort and find+sed+sort to derive col/row
    # Use find+wc to determine the number of tiles (which is probably lower than col*row)
}



###############################################################################
# CODE
###############################################################################

parse_parameters "$@"
resolve_file_layout

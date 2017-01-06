#!/bin/bash

if [ -s ${BASH_SOURCE%/*}/juxta.conf ]; then
    source ${BASH_SOURCE%/*}/juxta.conf
fi

# Maximum number of threads to use for processing
: ${THREADS:=1}

# Don't change this unless you know what you are doing
: ${TILE_SIDE:=256}
# Hex RGB for background, when the aspect ration for an image does not fit
: ${BACKGROUND:=cccccc}
: ${TILE_FORMAT:=jpg}
# Quality only applicable to JPG
: ${TILE_QUALITY:=80}

# The size of the raw (fully zoomed) images, measured in 256x256 pixel tiles.
# RAW_W=4 and RAW_H=3 means (4*256)x(3*256) = 1024x768 pixels.
: ${RAW_W:=4}
: ${RAW_H:=3}

# The preferable aspect ratio of the virtual canvas.
# Note that this is not guaranteed to be exact.
: ${CANVAS_ASPECT_W:=1}
: ${CANVAS_ASPECT_H:=1}

: ${DEST:=tiles}

set_converter() {
    if [ -z "`which convert`" ]; then
        >&2 echo "Error: ImageMagick could be located"
        exit 3
    fi
    export CONVERTER="convert"
}
set_converter

# https://bobcopeland.com/blog/2010/09/log2-in-bash/
log2() {
    local x=0
    for (( y=$1-1 ; $y > 0; y >>= 1 )) ; do
        let x=$x+1
    done
    echo $x
}

# Problem: Debug output gets jumbled with threads>1. Synchronize or just don't output?
process_base() {
    local ROW=`echo "$1" | cut -d\  -f1`
    local COL=`echo "$1" | cut -d\  -f2`
    local IMAGE=`echo "$1" | sed 's/[0-9]* [0-9]* \(.*\)/\1/'`
    local TILE_START_ROW=$((ROW*RAW_W))
    local TILE_START_COL=$((COL*RAW_H))
    local RAW_PIXEL_W=$((RAW_W*TILE_SIDE))
    local RAW_PIXEL_H=$((RAW_H*TILE_SIDE))
    if [ -s $DEST/$MAX_ZOOM/${TILE_START_ROW}_${TILE_START_COL}.${TILE_FORMAT} ]; then
        echo "    - Skipping tiles at grid ${ROW}x${COL} / tile ${TILE_START_ROW}x${TILE_START_COL} as they already exist for $IMAGE "
        return
    fi
        
    echo "    - Creating tiles at grid ${ROW}x${COL} / tile ${TILE_START_ROW}x${TILE_START_COL} from $IMAGE "
    mkdir -p $DEST/$MAX_ZOOM
    
    # Resize and pad to RAW_PIXEL*, crop tiles
    # convert image.jpg -gravity center -geometry 100x200 -background blue -extent 100x200 out.png
    # http://www.imagemagick.org/Usage/crop/#crop_tile

    convert "$IMAGE" -gravity center -quality $TILE_QUALITY -geometry ${RAW_PIXEL_W}x${RAW_PIXEL_H} -background "#$BACKGROUND" -extent ${RAW_PIXEL_W}x${RAW_PIXEL_H} +gravity -crop ${TILE_SIDE}x${TILE_SIDE} -set filename:tile "%[fx:page.x/${TILE_SIDE}+${TILE_START_ROW}]_%[fx:page.y/${TILE_SIDE}+${TILE_START_COL}]" "${DEST}/${MAX_ZOOM}/%[filename:tile].${TILE_FORMAT}"
}
export -f process_base

# Input SOURCE_LEVEL
create_zoom_levels() {
    local SOURCE_ZOOM=$1
    if [ $SOURCE_ZOOM -eq 1 ]; then
        return
    fi
    local DEST_ZOOM=$(( SOURCE_ZOOM-1 ))
    echo "  - Creating zoom level $DEST_ZOOM"
    local HALF_TILE_SIDE=$((TILE_SIDE/2))
    mkdir -p $DEST/$DEST_ZOOM
    local COL=0
    local ROW=0
    while [ true ]; do
        local TILE=$DEST/$DEST_ZOOM/${COL}_${ROW}.${TILE_FORMAT}
        if [ -s $TILE ]; then
            echo "    - Skipping tile ${COL}x${ROW} as it already exists"
        else
            local SCOL=$(($COL*2))
            local SROW=$(($ROW*2))

            local S00=$DEST/$SOURCE_ZOOM/${SCOL}_${SROW}.${TILE_FORMAT}
            local S10=$DEST/$SOURCE_ZOOM/$((SCOL+1))_${SROW}.${TILE_FORMAT}
            local S01=$DEST/$SOURCE_ZOOM/${SCOL}_$((SROW+1)).${TILE_FORMAT}
            local S11=$DEST/$SOURCE_ZOOM/$((SCOL+1))_$((SROW+1)).${TILE_FORMAT}

            if [ ! -s $S00 ]; then
                if [ $COL -eq 0 ]; then
                    break
                fi
                COL=0
                ROW=$((ROW+1))
                continue
            fi
            if [ -s $S11 ]; then # 2x2
                montage $S00 $S10 $S01 $S11 -tile 2x2 -quality ${TILE_QUALITY} -geometry ${HALF_TILE_SIDE}x${HALF_TILE_SIDE}+0+0 -background "#${BACKGROUND}" $TILE
            elif [ -s $S10 ]; then # 2x1
                montage $S00 $S10 -tile 2x1 -quality ${TILE_QUALITY} -geometry ${HALF_TILE_SIDE}x${HALF_TILE_SIDE}+0+0 -background "#${BACKGROUND}" $TILE
            elif [ -s $S01 ]; then # 1x2
                montage $S00 $S01 -tile 1x2 -quality ${TILE_QUALITY} -geometry ${HALF_TILE_SIDE}x${HALF_TILE_SIDE}+0+0 -background "#${BACKGROUND}" $TILE
            else # 1x1
                montage $S00 -tile 1x1 -quality ${TILE_QUALITY} -geometry ${HALF_TILE_SIDE}x${HALF_TILE_SIDE}+0+0 -background "#${BACKGROUND}" $TILE
            fi
            # TODO: Nearly there, but the edges and the upper levels should not be forced out to 256x256
        fi
        COL=$((COL+1))
    done
    create_zoom_levels $DEST_ZOOM
}

if [ -z "$1" ]; then
    echo "Usage: ./juxta.sh imagelist"
    echo "Where imagelist is a file with images represented as file paths"
    exit
fi
IMAGE_LIST="$1"
if [ ! -s $IMAGE_LIST ]; then
    >&2 echo "Error: Unable to access imagelist '$IMAGE_LIST'"
    exit 1
fi

IMAGE_COUNT=`cat "$IMAGE_LIST" | grep -v "^#.*" | grep -v "^$" | wc -l`
RAW_PIXEL_W=$((RAW_W*TILE_SIDE))
RAW_PIXEL_H=$((RAW_H*TILE_SIDE))

RAW_TILES_PER_CANVAS_ELEMENT=$(( IMAGE_COUNT*RAW_W*RAW_H/(CANVAS_ASPECT_W*CANVAS_ASPECT_H) ))
CANVAS_ELEMENT_SIDE=`echo "sqrt($RAW_TILES_PER_CANVAS_ELEMENT)" | bc`
if [ $CANVAS_ELEMENT_SIDE -eq 0 ]; then
    CANVAS_ELEMENT_SIDE=1
fi
RAW_IMAGE_ROWS=$((CANVAS_ELEMENT_SIDE*CANVAS_ASPECT_W/RAW_W))
if [ $RAW_IMAGE_ROWS -eq 0 ]; then
    RAW_IMAGE_ROWS=1
fi
RAW_IMAGE_COLS=$((IMAGE_COUNT/RAW_IMAGE_ROWS))
if [ $(( RAW_IMAGE_ROWS*WAR_IMAGE_COLS )) -le $IMAGE_COUNT ]; then
    RAW_IMAGE_COLS=$(( RAW_IMAGE_COLS+1 ))
fi
CANVAS_PIXEL_W=$((RAW_IMAGE_ROWS*RAW_W*TILE_SIDE))
CANVAS_PIXEL_H=$((RAW_IMAGE_ROWS*RAW_H*TILE_SIDE))
if [ $CANVAS_PIXEL_W -lt $CANVAS_PIXEL_H ]; then
    MAX_ZOOM=`log2 $CANVAS_PIXEL_H`
else
    MAX_ZOOM=`log2 $CANVAS_PIXEL_W`
fi

echo "- Montaging ${IMAGE_COUNT} images in a ${RAW_IMAGE_ROWS}x${RAW_IMAGE_COLS} grid for a virtual canvas of ${CANVAS_PIXEL_W}x${CANVAS_PIXEL_H} pixels with max zoom $MAX_ZOOM"
BATCH=`mktemp`
echo "  - Creating job list for batch processing $BATCH"

ROW=0
COL=0
while read IMAGE; do
    if [ ! -s $IMAGE ]; then
        >&2 echo "Error: The image '$IMAGE' from imagelist '$IMAGE_LIST' does not exist"
        exit 2
    fi
    echo "$ROW $COL $IMAGE" >> $BATCH
    ROW=$(( ROW+1 ))
    if [ $ROW -eq $RAW_IMAGE_ROWS ]; then
        ROW=0
        COL=$(( COL+1 ))
    fi
done < $IMAGE_LIST

echo "  - Creating base zoom level $MAX_ZOOM using $THREADS threads"
export RAW_W
export RAW_H
export DEST
export MAX_ZOOM
export BACKGROUND
export TILE_SIDE
export TILE_FORMAT
export TILE_QUALITY
# ###
cat $BATCH | head -n 6 | xargs -P $THREADS -n 1 -I {} -d'\n'  bash -c 'process_base "{}"'
create_zoom_levels $MAX_ZOOM


rm $BATCH

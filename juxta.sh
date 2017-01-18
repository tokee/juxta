#!/bin/bash

pushd ${BASH_SOURCE%/*} > /dev/null
if [ -s juxta.conf ]; then
    source juxta.conf
fi
JUXTA_HOME=`pwd`
popd > /dev/null
if [ -s juxta.conf ]; then # Also look for configuration in calling folder
    source juxta.conf
fi
if [ -s "$JUXTA_CONF" ]; then # And see if the caller specified the configuration
    source "$JUXTA_CONF"
fi

# Maximum number of threads to use for processing
: ${THREADS:=1}

# Don't change this unless you know what you are doing
: ${TILE_SIDE:=256}
# Hex RGB for background, when the aspect ration for an image does not fit
: ${BACKGROUND:=cccccc}
: ${TEMPLATE:="$JUXTA_HOME/web/presentation.template.html"}
# Free space (in pixels) around each raw image
: ${MARGIN:=5}
: ${FORMAT:=jpg}
: ${TILE_FORMAT:=$FORMAT}
# Quality only applicable to JPG
: ${QUALITY:=80}
: ${TILE_QUALITY:=$QUALITY}

# The size of the raw (fully zoomed) images, measured in 256x256 pixel tiles.
# RAW_W=4 and RAW_H=3 means (4*256)x(3*256) = 1024x768 pixels.
: ${RAW_W:=4}
: ${RAW_H:=3}
# Where to position the images if their aspect does not match the ideal
# Possible values are NorthWest, North, NorthEast, West, Center, East, SouthWest, South, SouthEast
: ${RAW_GRAVITY:=center}

# The preferable aspect ratio of the virtual canvas.
# Note that this is not guaranteed to be exact.
: ${CANVAS_ASPECT_W:=1}
: ${CANVAS_ASPECT_H:=1}

# Controls log level
: ${VERBOSE:=true}

# Ignore missing source images
: ${IGNORE_MISSING:=false}

# If true, any pre-existing HTML file for the collage will be overwritten
: ${OVERWRITE_HTML:=true}

: ${DEST:=tiles}
if [ ! "." == ".$2" ]; then
    DEST="$2"
fi

# Where to get OpenSeadragon
: ${OSD_VERSION:=2.2.1}
: ${OSD_ZIP:="openseadragon-bin-${OSD_VERSION}.zip"}
: ${OSD_URL:="http://github.com/openseadragon/openseadragon/releases/download/v${OSD_VERSION}/$OSD_ZIP"}

fetch_dragon() {
    if [ -s $JUXTA_HOME/osd/$OSD_ZIP ]; then
        return
    fi
    mkdir -p $JUXTA_HOME/osd/
    echo "  - Fetching $OSD_ZIP from $OSD_URL"
    curl -m 3600 "$OSD_URL" > $JUXTA_HOME/osd/$OSD_ZIP
    if [ ! -s $JUXTA_HOME/osd/$OSD_ZIP ]; then
        >&2 echo "Error: Unable to fetch OpenSeadragon from $OSD_URL"
        >&2 echo "Please download is manually and store it in $JUXTA_HOME/osd/"
        exit 3
    fi
}
fetch_dragon

set_converter() {
    if [ -z "`which convert`" ]; then
        >&2 echo "Error: ImageMagick could be located"
        exit 3
    fi
    export CONVERT="convert"
    export MONTAGE="montage"
    if [ ! -z "`which gm`" ]; then
        # TODO: Test if GM reallu is the better choise for these tasks
        export CONVERT="gm convert"
        export MONTAGE="gm montage"
    fi
}

# https://bobcopeland.com/blog/2010/09/log2-in-bash/
log2() {
    local x=0
    for (( y=$1-1 ; $y > 0; y >>= 1 )) ; do
        let x=$x+1
    done
    echo $x
}

# http://stackoverflow.com/questions/14434549/how-to-expand-shell-variables-in-a-text-file
# Input: template-file
function ctemplate() {
    local TMP=`mktemp --suffix .sh`
    echo 'cat <<END_OF_TEXT' >  $TMP
    cat  "$1"                >> $TMP
    echo 'END_OF_TEXT'       >> $TMP
    . $TMP
    rm $TMP
}

# Problem: Debug output gets jumbled with threads>1. Synchronize or just don't output?
process_base() {
    local IMAGE_NUMBER=`echo "$1" | cut -d\  -f1`
    local COL=`echo "$1" | cut -d\  -f2`
    local ROW=`echo "$1" | cut -d\  -f3`
    local IMAGE=`echo "$1" | sed 's/[0-9]* [0-9]* [0-9]* \(.*\)/\1/'`
    local TILE_START_COL=$((COL*RAW_W))
    local TILE_START_ROW=$((ROW*RAW_H))
    local RAW_PIXEL_W=$((RAW_W*TILE_SIDE))
    local RAW_PIXEL_H=$((RAW_H*TILE_SIDE))
    local GEOM_W=$((RAW_PIXEL_W-2*$MARGIN))
    local GEOM_H=$((RAW_PIXEL_H-2*$MARGIN))
    mkdir -p $DEST/$MAX_ZOOM
    if [ ! -s "$DEST/blank.${TILE_FORMAT}" ]; then
        $CONVERT -size ${TILE_SIDE}x${TILE_SIDE} xc:#${BACKGROUND} -quality ${TILE_QUALITY} "$DEST/blank.${TILE_FORMAT}"
    fi
    if [ -s $DEST/$MAX_ZOOM/${TILE_START_COL}_${TILE_START_ROW}.${TILE_FORMAT} ]; then
        if [ "$VERBOSE" == "true" ]; then
            echo "    - Skipping #${IMAGE_NUMBER}/${IMAGE_COUNT} grid ${ROW}x${COL} as tiles already exist for `basename \"$IMAGE\"`"
        fi
        return
    fi
        
    
    # Resize and pad to RAW_PIXEL*, crop tiles
    # convert image.jpg -gravity center -geometry 100x200 -background blue -extent 100x200 out.png
    # http://www.imagemagick.org/Usage/crop/#crop_tile

    # Cannot use GraphicsMagic here as output naming does not work like ImageMagic's
    if [ "missing" != "$IMAGE" ]; then
        echo "    - Creating tiles for #${IMAGE_NUMBER}/${IMAGE_COUNT} at grid ${COL}x${ROW} from `basename \"$IMAGE\"`"
        convert "$IMAGE" -size ${RAW_PIXEL_W}x${RAW_PIXEL_H} -strip -geometry "${GEOM_W}x${GEOM_H}>" -background "#$BACKGROUND" -gravity ${RAW_GRAVITY} -extent ${GEOM_W}x${GEOM_H} -gravity center -extent ${RAW_PIXEL_W}x${RAW_PIXEL_H} +gravity -crop ${TILE_SIDE}x${TILE_SIDE} -quality $TILE_QUALITY -set filename:tile "%[fx:page.x/${TILE_SIDE}+${TILE_START_COL}]_%[fx:page.y/${TILE_SIDE}+${TILE_START_ROW}]" "${DEST}/${MAX_ZOOM}/%[filename:tile].${TILE_FORMAT}" 2> /dev/null
    fi
    if [ ! -s "$DEST/${MAX_ZOOM}/${TILE_START_COL}_${TILE_START_ROW}.${TILE_FORMAT}" ]; then
        if [ "missing" == "$IMAGE" ]; then
            echo "    - Creating blank tiles for #${IMAGE_NUMBER}/${IMAGE_COUNT} at grid ${ROW}x${COL} as there are no more source images"
        else
            echo "    - Error: Could not create tiles from source image #${IMAGE_NUMBER}/${IMAGE_COUNT}. Using blank tiles instead. $IMAGE"
        fi
       
        for BLC in `seq 1 $RAW_W`; do
            for BLR in `seq 1 $RAW_H`; do
                cp "$DEST/blank.${TILE_FORMAT}" "${DEST}/${MAX_ZOOM}/$((TILE_START_COL+BLC-1))_$((TILE_START_ROW+BLR-1)).${TILE_FORMAT}"
            done
        done
    fi
}
export -f process_base

process_zoom() {
    local BLANK="$DEST/blank.${TILE_FORMAT}"
    local ROW="$1"
    local COL=0

    while [ $COL -le $MAX_COL ]; do
        local TILE=$DEST/$DEST_ZOOM/${COL}_${ROW}.${TILE_FORMAT}
        local S00=$DEST/$SOURCE_ZOOM/$((COL*2))_$((ROW*2)).${TILE_FORMAT}
        local S10=$DEST/$SOURCE_ZOOM/$((COL*2+1))_$((ROW*2)).${TILE_FORMAT}
        local S01=$DEST/$SOURCE_ZOOM/$((COL*2))_$((ROW*2+1)).${TILE_FORMAT}
        local S11=$DEST/$SOURCE_ZOOM/$((COL*2+1))_$((ROW*2+1)).${TILE_FORMAT}
        COL=$((COL+1))
        if [ -s $TILE ]; then
            continue
        fi
        
        if [ -s $S00 -a -s $S10 -a -s $S01 -a -s $S11 ]; then # 2x2
            montage $S00 $S10 $S01 $S11 -mode concatenate -tile 2x miff:- | convert - -geometry 50%x50% -quality ${TILE_QUALITY} $TILE
        elif [ -s $S00 -a -s $S10 ]; then # 2x1
            montage $S00 $S10 -mode concatenate -tile 2x miff:- | convert - -geometry 50%x50% -quality ${TILE_QUALITY} $TILE
        elif [ -s $S00 -a -s $S01 ]; then # 1x2
            montage $S00 $S01 -mode concatenate -tile 1x miff:- | convert - -geometry 50%x50% -quality ${TILE_QUALITY} $TILE
        elif [ -s $S00 ]; then # 1x1
            $CONVERT $S00 -geometry 50%x50% -quality ${TILE_QUALITY} $TILE
        else # No more source images for the lower right corner
            cp "$BLANK" $TILE
        fi
    done
    echo -n "$ROW "
    
}
export -f process_zoom

# Input SOURCE_LEVEL
create_zoom_levels() {
    local SOURCE_ZOOM=$1
    if [ $SOURCE_ZOOM -eq 1 ]; then
        return
    fi
    local DEST_ZOOM=$(( SOURCE_ZOOM-1 ))
    local HALF_TILE_SIDE=$((TILE_SIDE/2))
    mkdir -p $DEST/$DEST_ZOOM

    MAX_ROW=`find $DEST/$SOURCE_ZOOM/ -name 0_*.${TILE_FORMAT} | wc -l`
    MAX_ROW=$(( ( MAX_ROW - 1) / 2 ))
    if [ $MAX_ROW -lt 0 ]; then
        MAX_ROW=0
    fi

    MAX_COL=`find $DEST/$SOURCE_ZOOM/ -name *_0.${TILE_FORMAT} | wc -l`
    MAX_COL=$(( ( MAX_COL - 1 ) / 2 ))
    if [ $MAX_COL -lt 0 ]; then
        MAX_COL=0
    fi
    
    echo "  - Creating zoom level $DEST_ZOOM with $(( MAX_COL + 1 )) columns and $(( MAX_ROW + 1 )) rows of tiles"
    echo -n "    Rows: "
    export MAX_COL
    export DEST
    export SOURCE_ZOOM
    export TILE_FORMAT
    export TILE_QUALITY
    export DEST_ZOOM
    export HALF_TILE_SIDE
    export TILE_SIDE
    export BACKGROUND
    export VERBOSE
    seq 0 $MAX_ROW | xargs -P $THREADS -n 1 -I {} -d'\n'  bash -c 'process_zoom "{}"'

    echo ""
    create_zoom_levels $DEST_ZOOM
}

create_html() {
    pushd $DEST > /dev/null
    TILE_SOURCE=$(basename `pwd`)
    popd > /dev/null
    HTML=$DEST/../${TILE_SOURCE}.html
    
    mkdir -p $TILE_SOURCE/resources/images
    cp $JUXTA_HOME/web/*.css $TILE_SOURCE/resources/
    cp $JUXTA_HOME/web/*.js $TILE_SOURCE/resources/
    unzip -q -o -j -d $TILE_SOURCE/resources/ $JUXTA_HOME/osd/openseadragon-bin-${OSD_VERSION}.zip ${OSD_ZIP%.*}/openseadragon.min.js
    
    unzip -q -o -j -d $TILE_SOURCE/resources/images/ $JUXTA_HOME/osd/openseadragon-bin-${OSD_VERSION}.zip `unzip -l $JUXTA_HOME/osd/openseadragon-bin-*.zip | grep -o "opensea.*.png" | tr '\n' ' '`
    
    if [ -s $HTML ]; then
        if [ "true" == "$OVERWRITE_HTML" ]; then
            if [ "$VERBOSE" == "true" ]; then
                echo "  - Overwriting existing $HTML"
            fi
            rm $HTML
        else
            if [ "$VERBOSE" == "true" ]; then
                echo "  - Skipping generation of $HTML as it already exists"
            fi
            return
        fi
    fi
    echo "  - Generation sample page $HTML"
    ctemplate "$TEMPLATE" > $HTML
}

create_image_map() {
    echo "  - Creating image map"
    echo "var juxtaColCount=$RAW_IMAGE_COLS;" > $DEST/imagemap.js
    echo "var juxtaRowCount=$(( ROW + 1 ));" >> $DEST/imagemap.js
    echo "var juxtaImageCount=`cat $DEST/imagelist.dat | wc -l`;" >> $DEST/imagemap.js
    echo "var juxtaTileSize=$TILE_SIDE;" >> $DEST/imagemap.js
    echo "var juxtaRawW=$RAW_W;" >> $DEST/imagemap.js
    echo "var juxtaRawH=$RAW_H;" >> $DEST/imagemap.js

    local BASELINE="`cat $DEST/imagelist.dat | head -n 1 | cut -d'|' -f1`"
    local LENGTH=${#BASELINE} 
    local PRE=$LENGTH
    local POST=$LENGTH
    local POST_STR=$BASELINE
    local ANY_META=false
    while read IMAGE; do
        local IPATH="`echo \"$IMAGE\" | cut -d'|' -f1`"
        local IMETA="`echo \"$IMAGE\" | cut -s -d'|' -f2`"
        if [ "." != ".$IMETA" ]; then
            ANY_META=true
        fi
#        echo "**** ${BASELINE:0:$PRE} $BASELINE $LENGTH $PRE"
#        echo "$IMAGE"
        while [ $PRE -gt 0 -a ${IPATH:0:$PRE} != ${BASELINE:0:$PRE} ]; do
            PRE=$((PRE-1))
        done

        local CLENGTH=${#IPATH}
        local CSTART=$(( CLENGTH-$POST ))
        while [ $POST -gt 0 -a ${POST_STR} != ${IPATH:$CSTART} ]; do
            #echo "*p* $POST  ${POST_STR} != ${IPATH:$CSTART:$CLENGTH}"
            local POST=$(( POST-1 ))

            local PSTART=$(( LENGTH-POST ))
            local POST_STR=${BASELINE:$PSTART}
            local CSTART=$(( CLENGTH-POST ))
        done

#        echo "pre=$PRE post=$POST"
        if [ $PRE -eq 0 -a $POST -eq $LENGTH ]; then
            #echo "break"
            break
        fi
    done < $DEST/imagelist.dat
    echo "var juxtaPrefix=\"${BASELINE:0:$PRE}\";" >> $DEST/imagemap.js
    echo "var juxtaPostfix=\"${POST_STR}\";" >> $DEST/imagemap.js

    # All the images
    echo "var juxtaImages=[" >> $DEST/imagemap.js
    local FIRST=false
    while read IMAGE; do
        local IPATH="`echo \"$IMAGE\" | cut -d'|' -f1`"
        local IMETA="`echo \"$IMAGE\" | cut -s -d'|' -f2`"
        if [ "false" == "$FIRST" ]; then
            local FIRST=true
        else
            echo ","  >> $DEST/imagemap.js
        fi
        local ILENGTH=${#IPATH}
        local CUT_LENGTH=$(( ILENGTH-POST-PRE ))
        echo -n "\"${IPATH:$PRE:$CUT_LENGTH}\"" >> $DEST/imagemap.js
    done < $DEST/imagelist.dat
    echo "];" >> $DEST/imagemap.js

    # And their meta data (if available)
    if [ "true" == "$ANY_META" ]; then
        echo "var juxtaMeta=[" >> $DEST/imagemap.js
        local FIRST=false
        while read IMAGE; do
            local IMETA="`echo \"$IMAGE\" | cut -s -d'|' -f2`"
            echo "** $IMETA --- $IMAGE"
            if [ "false" == "$FIRST" ]; then
                local FIRST=true
            else
                echo ","  >> $DEST/imagemap.js
            fi
        echo -n "\"${IMETA}\"" >> $DEST/imagemap.js
        done < $DEST/imagelist.dat
        echo "];" >> $DEST/imagemap.js
    fi

    # functions to use the data
    cat  >> $DEST/imagemap.js <<EOF
// Override juxtaCallback to perform custom action
var juxtaCallback = function(x, y, boxX, boxY, boxWidth, boxHeight, validPos, image) { }

function juxtaExpand(x, y, boxX, boxY, boxWidth, boxHeight) {
  var image = "";
  var meta = "";
  var validPos = false;
  imageIndex = y*juxtaColCount+x;
  if (x >= 0 && x < juxtaColCount && y >= 0 && y < juxtaRowCount && imageIndex < juxtaImageCount) {
    image = juxtaPrefix + juxtaImages[imageIndex] + juxtaPostfix;
    validPos = true;
    if (typeof(juxtaMeta) != 'undefined') {
      meta = juxtaMeta[imageIndex];
    }
  }
  juxtaCallback(x, y, boxX, boxY, boxWidth, boxHeight, validPos, image, meta);
}
EOF
}

if [ -z "$1" ]; then
    echo "Usage: ./juxta.sh imagelist [destination]"
    echo "imagelist: A file with images represented as file paths"
    echo "destination: Where to store the generated tiles"
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
if [ $(( CANVAS_ELEMENT_SIDE / RAW_W * RAW_W )) -lt $CANVAS_ELEMENT_SIDE ]; then
    CANVAS_ELEMENT_SIDE=$(( CANVAS_ELEMENT_SIDE / RAW_W * RAW_W + RAW_W ))
fi
RAW_IMAGE_COLS=$((CANVAS_ELEMENT_SIDE*CANVAS_ASPECT_W/RAW_W))
if [ $RAW_IMAGE_COLS -eq 0 ]; then
    RAW_IMAGE_COLS=1
fi
RAW_IMAGE_ROWS=$((IMAGE_COUNT/RAW_IMAGE_COLS))
if [ $(( RAW_IMAGE_COLS*RAW_IMAGE_ROWS )) -lt $IMAGE_COUNT ]; then
    RAW_IMAGE_ROWS=$(( RAW_IMAGE_ROWS+1 ))
fi
CANVAS_PIXEL_W=$((RAW_IMAGE_COLS*RAW_W*TILE_SIDE))
CANVAS_PIXEL_H=$((RAW_IMAGE_ROWS*RAW_H*TILE_SIDE))
if [ $CANVAS_PIXEL_W -lt $CANVAS_PIXEL_H ]; then
    MAX_ZOOM=`log2 $CANVAS_PIXEL_H`
else
    MAX_ZOOM=`log2 $CANVAS_PIXEL_W`
fi

START_TIME=`date +%Y%m%d-%H%M`
echo "- Montaging ${IMAGE_COUNT} images in a ${RAW_IMAGE_COLS}x${RAW_IMAGE_ROWS} grid for a virtual canvas of ${CANVAS_PIXEL_W}x${CANVAS_PIXEL_H} pixels with max zoom $MAX_ZOOM to folder '$DEST' using $THREADS threads"
set_converter
BATCH=`mktemp`

echo "  - Preparing image list"
mkdir -p $DEST
COL=0
ROW=0
ICOUNTER=1
echo -n "" > $DEST/imagelist.dat
while read IMAGE; do
    if [ "." == ".$IMAGE" -o "#" == "${IMAGE:0:1}" ]; then
        continue
    fi
    # Slow due to system call
    IPATH="`echo \"$IMAGE\" | cut -d'|' -f1`"
    IMETA="`echo \"$IMAGE\" | cut -s -d'|' -f2`"
    if [ ! -s "$IPATH" ]; then
        if [ "true" == "$IGNORE_MISSING" ]; then
            echo "  - Skipping unavailable image '$IPATH'"
            continue
        else
            >&2 echo "Error: The image '$IPATH' from imagelist '$IMAGE_LIST' does not exist"
            exit 2
        fi
    fi
    echo "$ICOUNTER $COL $ROW $IPATH" >> $BATCH
    echo "$IMAGE" >> $DEST/imagelist.dat
    ICOUNTER=$(( ICOUNTER+1 ))
    COL=$(( COL+1 ))
    if [ $COL -eq $RAW_IMAGE_COLS ]; then
        COL=0
        ROW=$(( ROW+1 ))
    fi
done < $IMAGE_LIST

if [ ! $COL -eq 0 ]; then
    RAW_IMAGE_MAX_COL=$((RAW_IMAGE_COLS-1))
    for MISSING_COL in `seq $COL $RAW_IMAGE_MAX_COL`; do
        echo "$MISSING_COL $ROW missing" >> $BATCH
    done
fi
create_image_map

echo "  - Creating base zoom level $MAX_ZOOM"
export RAW_W
export RAW_H
export RAW_GRAVITY
export DEST
export MAX_ZOOM
export BACKGROUND
export MARGIN
export TILE_SIDE
export TILE_FORMAT
export TILE_QUALITY
export VERBOSE
export IMAGE_COUNT
# ###
cat $BATCH | xargs -P $THREADS -n 1 -I {} -d'\n'  bash -c 'process_base "{}"'
create_zoom_levels $MAX_ZOOM
create_html

rm $BATCH
echo "Finished montaging ${IMAGE_COUNT} images `date +%Y%m%d-%H%M` (process began ${START_TIME})"

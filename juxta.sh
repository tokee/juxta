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
: ${THREADS:=3}

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

# If either of these are defines, a fixed width or height layout is used
# If none are defined, the canvas aspect is used
# If both are defined, the ROWS is ignored
: ${RAW_IMAGE_COLS:=$COLS}
: ${RAW_IMAGE_ROWS:=$ROWS}
# If true, the special case ROWS=1 or COLS=1 are handled so no empty tiles are created
: ${AUTO_CROP:=true}
# The preferable aspect ratio of the virtual canvas.
# Note that this is not guaranteed to be exact.
: ${CANVAS_ASPECT_W:=1}
: ${CANVAS_ASPECT_H:=1}
# If true, structures are provided for resolving the source image belonging to the
# tiles that are hovered
: ${INCLUDE_ORIGIN:=true}
# Meta-data are resolved using async calls for arrays. To avoid flooding the server,
# they are stored in chunks, where each chunk contains ASYNC_META_SIDE^2 entries.
: ${ASYNC_META_SIDE:=50}
# The number of meta-data-chunks to keep cached in the browser.
: ${ASYNC_META_CACHE:=10}

# If 'dzi', image tiles are stored in folders fully compatible with DZI, directly usable
# OpenSeadragon and similar. This is highly recommended as long as the number of tiles
# making up the collage is "low" (think 10K and below). When the number of tiles gets
# "high", some file systems experience performance problems.
# If 'limit', a custom layout is used where the number of tiles in a single folder is
# kept at a level that ensures fine performance by common file systems. This layout is
# not dzi-compatible and requires a custom tile-provider for OpenSeadragon (automatically
# generated for the demo page). Using 'limit' with 10K tiles or less has no performance
# benefits.
# If 'auto', juxta uses 'dzi', unless the tile-count exceeds $AUTO_FOLDER_LIMIT, in which
# case it uses 'high'. The AUTO_FOLDER_LIMIT is intentionally high (1M) to promote
# standard layout. A more performance-oriented choice would be 100K.
: ${FOLDER_LAYOUT:=auto}
: ${AUTO_FOLDER_LIMIT:=20000}
# The edge length of the raw grid blocks for creating sub-folders when FOLDER_LAYOUT=limit.
# The number of tiles in each folder will be AUTO_FOLDER_SIDE^2*RAW_W*RAW_H.
# With the default values that is 40^2 * 4 * 3 = 19,200.
# Note that ext2 has a limit of 32,768 files/folder, an fat32's limit is 65,536.
: ${LIMIT_FOLDER_SIDE:=40}

# Controls log level
: ${VERBOSE:=true}

# Ignore missing source images
: ${IGNORE_MISSING:=false}

# If true, any pre-existing HTML file for the collage will be overwritten
: ${OVERWRITE_HTML:=true}

# If true, no images are processed if any destination-images exist
: ${AGGRESSIVE_IMAGE_SKIP:=false}

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
    wget "$OSD_URL" -O  $JUXTA_HOME/osd/$OSD_ZIP
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

# Input: raw_x, raw_y
get_tile_subfolder() {
    local RAW_X=$1
    local RAW_Y=$2
    local RAW_COLS=$3
    if [ "dzi" == "$FOLDER_LAYOUT" ]; then
        echo ""
        return
    fi
    echo $((RAW_X/LIMIT_FOLDER_SIDE*LIMIT_FOLDER_SIDE))_$((RAW_Y/LIMIT_FOLDER_SIDE*LIMIT_FOLDER_SIDE))/
}
export -f get_tile_subfolder

process_base() {
    local TOKENS
    IFS=$' ' TOKENS=($1)
    local IMAGE_NUMBER=${TOKENS[0]}
    local COL=${TOKENS[1]}
    local ROW=${TOKENS[2]}
    unset IFS
    # TODO: Use a bash-regexp instead
    local IMAGE=`echo "$1" | sed 's/[0-9]* [0-9]* [0-9]* \(.*\)/\1/'`
    local TILE_START_COL=$((COL*RAW_W))
    local TILE_START_ROW=$((ROW*RAW_H))
    local RAW_PIXEL_W=$((RAW_W*TILE_SIDE))
    local RAW_PIXEL_H=$((RAW_H*TILE_SIDE))
    local GEOM_W=$((RAW_PIXEL_W-2*$MARGIN))
    local GEOM_H=$((RAW_PIXEL_H-2*$MARGIN))

    local TILE_SUB=`get_tile_subfolder $COL $ROW`
    mkdir -p $DEST/$MAX_ZOOM/$TILE_SUB
    if [ ! -s "$DEST/blank.${TILE_FORMAT}" ]; then
        $CONVERT -size ${TILE_SIDE}x${TILE_SIDE} xc:#${BACKGROUND} -quality ${TILE_QUALITY} "$DEST/blank.${TILE_FORMAT}"
    fi
    if [ -s $DEST/$MAX_ZOOM/${TILE_SUB}${TILE_START_COL}_${TILE_START_ROW}.${TILE_FORMAT} ]; then
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
        convert "$IMAGE" -size ${RAW_PIXEL_W}x${RAW_PIXEL_H} -strip -geometry "${GEOM_W}x${GEOM_H}>" -background "#$BACKGROUND" -gravity ${RAW_GRAVITY} -extent ${GEOM_W}x${GEOM_H} -gravity center -extent ${RAW_PIXEL_W}x${RAW_PIXEL_H} +gravity -crop ${TILE_SIDE}x${TILE_SIDE} -quality $TILE_QUALITY -set filename:tile "%[fx:page.x/${TILE_SIDE}+${TILE_START_COL}]_%[fx:page.y/${TILE_SIDE}+${TILE_START_ROW}]" "${DEST}/${MAX_ZOOM}/${TILE_SUB}%[filename:tile].${TILE_FORMAT}" 2> /dev/null
    fi
    if [ ! -s "$DEST/${MAX_ZOOM}/${TILE_SUB}${TILE_START_COL}_${TILE_START_ROW}.${TILE_FORMAT}" ]; then
        if [ "missing" == "$IMAGE" ]; then
            echo "    - Creating blank tiles for #${IMAGE_NUMBER}/${IMAGE_COUNT} at grid ${ROW}x${COL} as there are no more source images"
        else
            echo "    - Error: Could not create tiles from source image #${IMAGE_NUMBER}/${IMAGE_COUNT}. Using blank tiles instead. $IMAGE"
        fi
        for BLC in `seq 1 $RAW_W`; do
            for BLR in `seq 1 $RAW_H`; do
                cp "$DEST/blank.${TILE_FORMAT}" "${DEST}/${MAX_ZOOM}/${TILE_SUB}$((TILE_START_COL+BLC-1))_$((TILE_START_ROW+BLR-1)).${TILE_FORMAT}"
            done
        done
    fi
}
export -f process_base

process_zoom() {
    local BLANK="$DEST/blank.${TILE_FORMAT}"
    local ROW="$1"
    local RAW_ROW=$((ROW/RAW_H))
    local COL=0
    local COL_COUNT=$((MAX_COL+1))

    while [ $COL -le $MAX_COL ]; do
        local RAW_COL=$((COL/RAW_W))
        local TILE_SOURCE_SUB=`get_tile_subfolder $((RAW_COL*2)) $((RAW_ROW*2))`
        local TILE_DEST_SUB=`get_tile_subfolder $RAW_COL $RAW_ROW`
        mkdir -p $DEST/$DEST_ZOOM/$TILE_DEST_SUB
        
        local TILE=$DEST/$DEST_ZOOM/${TILE_DEST_SUB}${COL}_${ROW}.${TILE_FORMAT}
        local S00=$DEST/$SOURCE_ZOOM/${TILE_SOURCE_SUB}$((COL*2))_$((ROW*2)).${TILE_FORMAT}
        local S10=$DEST/$SOURCE_ZOOM/${TILE_SOURCE_SUB}$((COL*2+1))_$((ROW*2)).${TILE_FORMAT}
        local S01=$DEST/$SOURCE_ZOOM/${TILE_SOURCE_SUB}$((COL*2))_$((ROW*2+1)).${TILE_FORMAT}
        local S11=$DEST/$SOURCE_ZOOM/${TILE_SOURCE_SUB}$((COL*2+1))_$((ROW*2+1)).${TILE_FORMAT}
        COL=$((COL+1))
        if [ -s $TILE ]; then
            continue
        fi

        # We use box + scale as we are binning: http://www.imagemagick.org/Usage/filter/#box
        # Or is the box-filter not used? http://stackoverflow.com/questions/8517304/what-is-the-difference-for-sample-resample-scale-resize-adaptive-resize-thumbnai



        if [ -s $S00 -a -s $S01 -a -s $S10 -a -s $S11 ]; then # 2x2 
            # If we are not at the edge, montage is easy. Still need the source existence check above.
            if [ $COL -lt $MAX_COL -a $ROW -lt $MAX_ROW ]; then
                montage $S00 $S10 $S01 $S11 -background "#$BACKGROUND" -geometry 128x128 -tile 2x2 -quality ${TILE_QUALITY} $TILE
            else
                montage $S00 $S10 $S01 $S11 -mode concatenate -tile 2x miff:- | convert - -filter box -scale 50%x50% -quality ${TILE_QUALITY} $TILE
            fi
        elif [ -s $S00 -a -s $S10 ]; then # 2x1
            montage $S00 $S10 -mode concatenate -tile 2x miff:- | convert - -filter box -scale 50%x50% -quality ${TILE_QUALITY} $TILE
        elif [ -s $S00 -a -s $S01 ]; then # 1x2
            montage $S00 $S01 -mode concatenate -tile 1x miff:- | convert - -filter box -scale 50%x50% -quality ${TILE_QUALITY} $TILE
        elif [ -s $S00 ]; then # 1x1
            $CONVERT $S00 -filter box -scale 50%x50% -quality ${TILE_QUALITY} $TILE
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
    if [ "true" == "$AGGRESSIVE_IMAGE_SKIP" -a -d $DEST/$DEST_ZOOM ]; then
        echo "  - Skipping creation of zoom level $DEST_ZOOM as it already exists"
        return
    fi
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
    export MAX_ROW
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
    HTML=$DEST/index.html
    TOTAL_IMAGES=`cat $DEST/imagelist.dat | wc -l`
    
    mkdir -p $TILE_SOURCE/resources/images
    cp $JUXTA_HOME/web/*.css $TILE_SOURCE/resources/
    cp $JUXTA_HOME/web/*.js $TILE_SOURCE/resources/
    unzip -q -o -j -d $TILE_SOURCE/resources/ $JUXTA_HOME/osd/openseadragon-bin-${OSD_VERSION}.zip ${OSD_ZIP%.*}/openseadragon.min.js
    unzip -q -o -j -d $TILE_SOURCE/resources/images/ $JUXTA_HOME/osd/openseadragon-bin-${OSD_VERSION}.zip `unzip -l $JUXTA_HOME/osd/openseadragon-bin-*.zip | grep -o "opensea.*.png" | tr '\n' ' '`

    ###

    if [ "limit" == "$FOLDER_LAYOUT" ]; then
        TILE_SOURCES="    tileSources:   {
        height: $CANVAS_PIXEL_H,
        width: $CANVAS_PIXEL_W,
        tileSize: 256,
        getTileUrl: function( level, x, y ){
            return level + \"/\" + (Math.floor(Math.floor(x/juxtaRawW)/juxtaLimitFolderSide)*juxtaLimitFolderSide) +
                    \"_\" + (Math.floor(Math.floor(y/juxtaRawH)/juxtaLimitFolderSide)*juxtaLimitFolderSide) + \"/\" +
                    x + \"_\" + y + \".jpg\";
        }
    }"
    else
        TILE_SOURCES="tileSources:   {
    Image: {
        xmlns:    \"http://schemas.microsoft.com/deepzoom/2008\",
        Url:      \"\",
        Format:   \"$TILE_FORMAT\", 
        Overlap:  \"0\", 
        TileSize: \"$TILE_SIDE\",
        Size: {
            Width: \"$CANVAS_PIXEL_W\",
            Height:  \"$CANVAS_PIXEL_H\"
        }
    }
}"
    fi

    export TILE_SOURCE
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
    echo "  - Generating sample page $HTML"
    ctemplate "$TEMPLATE" > $HTML
}

create_meta_files() {
    echo "  - Creating meta files"
    rm -f $DEST/meta/*.json
    mkdir -p $DEST/meta
    local ROW=0
    local COL=0
    local TOKENS
    while read IMAGE; do
        if [ "true" == "$INCLUDE_ORIGIN" ]; then
            if [ $PRE -gt 0 -o $POST -gt 0 ]; then
                IFS=$'|' TOKENS=($IMAGE)
                local IPATH=${TOKENS[0]}
                local IMETA=${TOKENS[1]}
                unset IFS
                local ILENGTH=${#IPATH}
                local CUT_LENGTH=$(( ILENGTH-POST-PRE ))
                local IMETA="${IPATH:$PRE:$CUT_LENGTH}|$IMETA"
            else
                local IMETA="$IMAGE"
            fi
        else
            IFS=$'|' TOKENS=($IMAGE)
            local IMETA=${TOKENS[1]}
            # Use bash replace instead
            unset IFS
        fi
        local IMETA="`echo \"$IMETA\" | sed -e 's/&/&amp;/g' -e 's/\"/\\&quot;/g'`"
        local DM=$DEST/meta/$((COL/ASYNC_META_SIDE))_$((ROW/ASYNC_META_SIDE)).json
        if [ ! -s $DM ]; then
            echo -n "{\"meta\": ["$'\n'"\"$IMETA\"" >> $DM
        else
            echo -n ","$'\n'"\"$IMETA\"" >> $DM
        fi
        COL=$(( COL+1 ))
        if [ $COL -ge $RAW_IMAGE_COLS ]; then
            ROW=$(( ROW+1 ))
            COL=0
        fi
    done < $DEST/imagelist.dat
    find $DEST/meta/ -name "*.json" -exec bash -c "echo ']}' >> {}" \;
}

create_image_map() {
    echo "  - Analyzing collection meta data"
    echo "var juxtaColCount=$RAW_IMAGE_COLS;" > $DEST/imagemap.js
    echo "var juxtaRowCount=$(( ROW + 1 ));" >> $DEST/imagemap.js
    echo "var juxtaImageCount=`cat $DEST/imagelist.dat | wc -l`;" >> $DEST/imagemap.js
    echo "var juxtaTileSize=$TILE_SIDE;" >> $DEST/imagemap.js
    echo "var juxtaRawW=$RAW_W;" >> $DEST/imagemap.js
    echo "var juxtaRawH=$RAW_H;" >> $DEST/imagemap.js
    echo "var juxtaAsyncMetaSide=$ASYNC_META_SIDE;" >> $DEST/imagemap.js
    echo "var juxtaMetaIncludesOrigin=$INCLUDE_ORIGIN;" >> $DEST/imagemap.js
    echo "var juxtaFolderLayout=\"$FOLDER_LAYOUT\";" >> $DEST/imagemap.js
    echo "var juxtaLimitFolderSide=$LIMIT_FOLDER_SIDE;" >> $DEST/imagemap.js

    # Derive shared pre- and post-fix for all images for light image compression
    local BASELINE="`cat $DEST/imagelist.dat | head -n 1 | cut -d'|' -f1`"
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
            POST_STR=${BASELINE:$PSTART}
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

    # DEPRECATED: Images are now (optionally) stored with the async meta-data
    # Use the shared pre- and post-fixes to build a lightly compressed image list
    if [ "true" == "false" ]; then
    #if [ "true" == "$INCLUDE_ORIGIN" ]; then
        echo "var juxtaImages=[" >> $DEST/imagemap.js
        local FIRST=false
        while read IMAGE; do
            IFS=$'|' TOKENS=($IMAGE)
            local IPATH=${TOKENS[0]}
            local IMETA=${TOKENS[1]}
            unset IFS
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
    fi
    
    # Meta-data are added directly (if available & enabled)
    if [ "true" == "$INCLUDE_ORIGIN" -o "true" == "$ANY_META" ]; then
        create_meta_files
    fi
}

resolve_dimensions() {
    IMAGE_COUNT=`cat "$DEST/imagelist_onlyimages.dat" | grep -v "^#.*" | grep -v "^$" | wc -l`
    if [ "." != ".$RAW_IMAGE_COLS" ]; then # Fixed width
        if [ "true" == "$AUTO_CROP" -a $RAW_IMAGE_COLS -gt $IMAGE_COUNT ]; then
            RAW_IMAGE_COLS=$IMAGE_COUNT
        fi
        RAW_IMAGE_ROWS=$((IMAGE_COUNT/RAW_IMAGE_COLS))
        if [ $(( RAW_IMAGE_COLS*RAW_IMAGE_ROWS )) -lt $IMAGE_COUNT ]; then
            RAW_IMAGE_ROWS=$(( RAW_IMAGE_ROWS+1 ))
        fi
    elif [ "." != ".$RAW_IMAGE_ROWS" ]; then # Fixed height
        if [ "true" == "$AUTO_CROP" -a $RAW_IMAGE_ROWS -gt $IMAGE_COUNT ]; then
            RAW_IMAGE_ROWS=$IMAGE_COUNT
        fi
        RAW_IMAGE_COLS=$((IMAGE_COUNT/RAW_IMAGE_ROWS))
        if [ $(( RAW_IMAGE_COLS*RAW_IMAGE_ROWS )) -lt $IMAGE_COUNT ]; then
            RAW_IMAGE_COLS=$(( RAW_IMAGE_COLS+1 ))
        fi
    else
        local RAW_PIXEL_W=$((RAW_W*TILE_SIDE))
        local RAW_PIXEL_H=$((RAW_H*TILE_SIDE))
        
        local RAW_TILES_PER_CANVAS_ELEMENT=$(( IMAGE_COUNT*RAW_W*RAW_H/(CANVAS_ASPECT_W*CANVAS_ASPECT_H) ))
        local CANVAS_ELEMENT_SIDE=`echo "sqrt($RAW_TILES_PER_CANVAS_ELEMENT)" | bc`
        if [ $CANVAS_ELEMENT_SIDE -eq 0 ]; then
            local CANVAS_ELEMENT_SIDE=1
        fi
        if [ $(( CANVAS_ELEMENT_SIDE / RAW_W * RAW_W )) -lt $CANVAS_ELEMENT_SIDE ]; then
            local CANVAS_ELEMENT_SIDE=$(( CANVAS_ELEMENT_SIDE / RAW_W * RAW_W + RAW_W ))
        fi
        RAW_IMAGE_COLS=$((CANVAS_ELEMENT_SIDE*CANVAS_ASPECT_W/RAW_W))
        if [ $RAW_IMAGE_COLS -eq 0 ]; then
            RAW_IMAGE_COLS=1
        fi
        RAW_IMAGE_ROWS=$((IMAGE_COUNT/RAW_IMAGE_COLS))
        if [ $(( RAW_IMAGE_COLS*RAW_IMAGE_ROWS )) -lt $IMAGE_COUNT ]; then
            RAW_IMAGE_ROWS=$(( RAW_IMAGE_ROWS+1 ))
        fi
    fi

    CANVAS_PIXEL_W=$((RAW_IMAGE_COLS*RAW_W*TILE_SIDE))
    CANVAS_PIXEL_H=$((RAW_IMAGE_ROWS*RAW_H*TILE_SIDE))
    if [ $CANVAS_PIXEL_W -lt $CANVAS_PIXEL_H ]; then
        MAX_ZOOM=`log2 $CANVAS_PIXEL_H`
    else
        MAX_ZOOM=`log2 $CANVAS_PIXEL_W`
    fi
    export RAW_IMAGE_COLS;
    export RAW_IMAGE_ROWS;
}

usage() {
    echo "Usage: ./juxta.sh imagelist [destination]"
    echo "imagelist: A file with images represented as file paths"
    echo "destination: Where to store the generated tiles"
    exit $1
}

sanitize_input() {
    if [ -z "$1" ]; then
        usage
    fi
    IMAGE_LIST="$1"
    if [ ! -s $IMAGE_LIST ]; then
        >&2 echo "Error: Unable to access imagelist '$IMAGE_LIST'"
        usage 1
    fi

    echo "  - Verifying images availability"
    mkdir -p $DEST
    local ICOUNTER=1
    rm -rf $DEST/imagelist.dat $DEST/imagelist_onlyimages.dat
    while read IMAGE; do
        if [ "." == ".$IMAGE" -o "#" == "${IMAGE:0:1}" ]; then
            continue
        fi
        IFS=$'|' TOKENS=($IMAGE)
        local IPATH=${TOKENS[0]}
        local IMETA=${TOKENS[1]}
        unset IFS
        if [ "http://" != ${IPATH:0:7} -a "https://" != ${IPATH:0:8} ]; then
            if [ ! -s "$IPATH" ]; then
                if [ "true" == "$IGNORE_MISSING" ]; then
                    echo "  - Skipping unavailable image '$IPATH'"
                    continue
                else
                    >&2 echo "Error: The image '$IPATH' from imagelist '$IMAGE_LIST' does not exist"
                    exit 2
                fi
            fi
        fi
        echo "$IMAGE" >> $DEST/imagelist.dat
        echo "$IPATH" >> $DEST/imagelist_onlyimages.dat
        local ICOUNTER=$(( ICOUNTER+1 ))
    done < $IMAGE_LIST

    # Determine folder layout
    local TILE_COUNT=$((ICOUNTER*RAW_W*RAW_H))
    if [ "auto" == "$FOLDER_LAYOUT" ]; then
        if [ $TILE_COUNT -le $AUTO_FOLDER_LIMIT ]; then
            echo "  - Auto-selecting FOLDER_LAYOUT=dzi with expected ${TILE_COUNT} base tiles from $ICOUNTER images"
            FOLDER_LAYOUT="dzi"
        else
            echo "  - Auto-selecting FOLDER_LAYOUT=limit with expected ${TILE_COUNT} base tiles from $ICOUNTER images"
            FOLDER_LAYOUT="limit"
        fi
    elif [ "dzi" == "$FOLDER_LAYOUT" ]; then
        echo "  - Using folder layout 'dzi' with expected ${TILE_COUNT} base tiles from $ICOUNTER images"
        if [ $TILE_COUNT -gt $AUTO_FOLDER_LIMIT ]; then
            echo "    - Warning: This is a high tile count. Consider using the custom layout 'limit' with FOLDER_LAYOUT=limit for performance reasons"
        fi
    elif [ "limit" == "$FOLDER_LAYOUT" ]; then
        echo "  - Using folder layout 'limit' with expected ${TILE_COUNT} base tiles from $ICOUNTER images"
        if [ $TILE_COUNT -le $AUTO_FOLDER_LIMIT ]; then
            echo "    - Warning: This is not an excessively high tile count. Consider using the DZI-compatible layout with FOLDER_LAYOUT=dzi for compatibility reasons"
        fi
    fi
    export FOLDER_LAYOUT
    export LIMIT_FOLDER_SIDE
}

prepare_batch() {
    BATCH=`mktemp`
    echo "  - Preparing batch job"
    COL=0
    ROW=0
    ICOUNTER=1
    while read IMAGE; do
        echo "$ICOUNTER $COL $ROW $IMAGE" >> $BATCH
        ICOUNTER=$(( ICOUNTER+1 ))
        COL=$(( COL+1 ))
        if [ $COL -eq $RAW_IMAGE_COLS ]; then
            COL=0
            ROW=$(( ROW+1 ))
        fi
    done < $DEST/imagelist_onlyimages.dat

    if [ ! $COL -eq 0 ]; then
        RAW_IMAGE_MAX_COL=$((RAW_IMAGE_COLS-1))
        for MISSING_COL in `seq $COL $RAW_IMAGE_MAX_COL`; do
            echo "$ICOUNTER $MISSING_COL $ROW missing" >> $BATCH
            ICOUNTER=$(( ICOUNTER+1 ))
        done
    fi
}

START_S=`date +%s`
START_TIME=`date +%Y%m%d-%H%M`
sanitize_input $@
resolve_dimensions
echo "- Montaging ${IMAGE_COUNT} images in a ${RAW_IMAGE_COLS}x${RAW_IMAGE_ROWS} grid for a virtual canvas of ${CANVAS_PIXEL_W}x${CANVAS_PIXEL_H} pixels with max zoom $MAX_ZOOM to folder '$DEST' using $THREADS threads"
set_converter
prepare_batch
create_image_map
create_html

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

if [ "true" == "$AGGRESSIVE_IMAGE_SKIP" -a -d $DEST/$MAX_ZOOM ]; then
    echo "  - Skipping creation of full zoom level $MAX_ZOOM as it already exists"
else
    echo "  - Creating base zoom level $MAX_ZOOM"
    cat $BATCH | xargs -P $THREADS -n 1 -I {} -d'\n'  bash -c 'process_base "{}"'
fi
create_zoom_levels $MAX_ZOOM
END_S=`date +%s`
SPEND_S=$((END_S-START_S))
rm $BATCH
ICOUNT=`cat $DEST/imagelist_onlyimages.dat | wc -l`

echo "Process started $START_TIME and ended `date +%Y%m%d-%H%M`"
echo "juxta used $SPEND_S seconds to generate a $ICOUNT image collage of $((RAW_W*TILE_SIDE))x$((RAW_H*TILE_SIDE)) pixel images"
echo "Average speed was $((SPEND_S/ICOUNT)) seconds/image or $((ICOUNT/SPEND_S)) images/second"
echo "HTML-page available at $HTML"


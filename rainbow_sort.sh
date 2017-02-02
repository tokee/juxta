#!/bin/bash

#
# Sorts images in rainbow-order. Supports meta-data in the image-list
# Meta-data are separated from the images themselved by a bar |
# Sample-line:
# clothes/black_feathers.png|My beautiful rocks
#
# Requires ImageMagick
#
#

# curl -s "http://colrd.com/palette/22198/?download=css" | grep -o "RGB(.*)" | sed -e 's/RGB(//' -e 's/[ )]//g' | tr '\n' ' '
: ${RAINBOW:="248,12,18 238,17,0 255,51,17 255,68,34 255,102,68 255,153,51 254,174,45 204,187,51 208,195,16 170,204,34 105,208,37 34,204,170 18,189,185 17,170,187 68,68,221 51,17,187 59,12,189 68,34,153"}

usage() {
    echo "Usage: ./rainbow_sort.sh in_imagelist.dat out_imagelist.dat"
    exit $1
}

IN="$1"
OUT="$2"
if [ ! -s "$IN" ]; then
    >&2 echo "Unable to open image list '$IN'"
    usage 1
fi
if [ "." == ".$OUT" ]; then
    >&2 echo "An output file must be provided"
    usage 2
fi


rainbow_bucket() {
    local RGB="$1"
    local RGB_A
    IFS=$',' RGB_A=($RGB)
    local RGB_A=($RGB)
    unset IFS
    local T=`mktemp`

    # https://en.wikipedia.org/wiki/Color_difference#Euclidean
    local BEST=0
    # Higher than 2*256^2 + 4*256^2 + 3*256^2
    local MIN_DIST=9999999
    local RAIN_RGB
    local RAIN_RGB_A
    local INDEX=0
    for RAIN_RGB in $RAINBOW; do
        IFS=',' RAIN_RGB_A=($RAIN_RGB)
        unset IFS
        local DIST=$(( 2*(RGB_A[0]-RAIN_RGB_A[0])*(RGB_A[0]-RAIN_RGB_A[0]) + 4*(RGB_A[1]-RAIN_RGB_A[1])*(RGB_A[1]-RAIN_RGB_A[1]) + 3*(RGB_A[1]-RAIN_RGB_A[1])*(RGB_A[1]-RAIN_RGB_A[1]) ))
        if [ "$DIST" -lt "$MIN_DIST" ]; then
            BEST=$INDEX
            MIN_DIST=$DIST
        fi
        INDEX=$((INDEX+1))
    done
    echo $BEST
}

echo "- Determining average RGB and assigning rainbow-index for images in $IN"

TOTAL=`cat "$IN" | wc -l`
UNSORTED=`mktemp`
COUNTER=1
while read IMAGE; do
    IFS=$'|' TOKENS=($IMAGE)
    IPATH=${TOKENS[0]}
    IMETA=${TOKENS[1]}
    unset IFS
    echo " - Analyzing $COUNTER/$TOTAL: $IPATH"
    RGB=`convert "$IPATH" -resize '1x1!' -format "%[fx:int(255*r+.5)],%[fx:int(255*g+.5)],%[fx:int(255*b+.5)]" info:-`
    RAINBOW_INDEX=`rainbow_bucket $RGB`

    echo -n "$RAINBOW_INDEX $IPATH" >> $UNSORTED
    if [ "." == ".$IMETA" ]; then
        echo "" >> $UNSORTED
    else
        echo "|$IMETA" >> $UNSORTED
    fi
    COUNTER=$((COUNTER+1))
done < "$IN"
cat $UNSORTED | sort -n | sed 's/^[0-9.]* //' > "$OUT"
rm $UNSORTED

echo "- Sorting finished, result in $OUT"

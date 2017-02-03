#1/bin/bash

#
# Image sorter by intensity that supports meta-data in the image-list
# Meta-data are separated from the images themselved by a bar |
# Sample-line:
# clothes/rainbow_feathers.png|My beautiful socks
#
# Requires ImageMagick
#
# Note: This does not work especially well. A more interesting sorter
# would sort by rainbow order or something like that.
# See http://imagemagick.org/Usage/quantize/#extract for further ideas of
# extracting image statistics that are sortable.
#
usage() {
    echo "Usage: ./intensity_sort.sh in_imagelist.dat out_imagelist.dat"
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

echo "- Image intensity sorting $IN"

TOTAL=`cat "$IN" | wc -l`
UNSORTED=`mktemp /tmp/juxta_intensity_sort.XXXXXXXX`
COUNTER=1
while read IMAGE; do
    IFS=$'|' TOKENS=($IMAGE)
    IPATH=${TOKENS[0]}
    IMETA=${TOKENS[1]}
    unset IFS
    echo " - Analyzing $COUNTER/$TOTAL: $IPATH"
    INTENSITY=`convert "$IPATH" -type Grayscale -format "%[mean]" info:`
    echo -n "$INTENSITY $IPATH" >> $UNSORTED
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

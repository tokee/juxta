#!/bin/bash

# Displays multiple collections as one large gallery with each collection being show below
# the previous one. The effect is achieved by inserting blank images.

: ${BACKGROUND:="000000"}
: ${AGGRESSIVE_IMAGE_SKIP:=true}
: ${ALLOW_UPSCALE:=true}
# If true, the generated index.html will be put one level above the destination folder
: ${MOVE_INDEX_UP:=false}

pushd ${BASH_SOURCE%/*} > /dev/null
JUXTA_HOME=$(pwd)
popd > /dev/null
: ${TEMPLATE:="$JUXTA_HOME/demo_multi.template.html"}

usage() {
    echo "Usage:"
    echo "./demo_multi.sh imagefile* destination"
    echo "It is highly recommended to specify RAW_IMAGE_COLS."
    exit $1
}

# Resolve sources and destination
if [ "$#" -lt "2" ]; then
    >&2 echo "Error: Need at least 1 source and a destination"
    usage 2
fi

# Check source & destination
SOURCES=""
SCOUNT=0
for ARG in "$@"; do
    SCOUNT=$((SCOUNT+1))
    if [[ "$SCOUNT" -eq "$#" ]]; then
        DEST="$ARG"
        break
    fi
    if [[ ! -f "$ARG" ]]; then
        >&2 echo "Error: Source file '$ARG' cannot be read"
        usage 3
    fi
    if [[ "." != ".$SOURCES" ]]; then
        SOURCES="$SOURCES"$'\n'
    fi
    SOURCES="$SOURCES$ARG"
done

# Check dimensions
TOTAL_IMAGES=$(cat $SOURCES | wc -l)
if [[ ".$RAW_IMAGE_COLS" == "." ]]; then
    RAW_IMAGE_COLS=$(echo "sqrt($TOTAL_IMAGES)" | bc)
    echo "Warning: RAW_IMAGE_COLS not specified. Setting RAW_IMAGE_COLS to sqrt($TOTAL_IMAGES images)=$RAW_IMAGE_COLS "
fi

# Create merged source file with blanks inserted to get visual grouping
mkdir -p "$DEST"
rm -f "$DEST/multi_source.dat"
while read -r SOURCE; do
    COL=0
    while read -r IMG; do
        COL=$((COL+1))
        echo "$IMG" >> "$DEST/multi_source.dat"
        if [[ "$COL" -eq "$RAW_IMAGE_COLS" ]]; then
            COL=0
        fi
    done < $SOURCE
    while [[ "$COL" -ne 0 && "$COL" -lt "$RAW_IMAGE_COLS" ]]; do
        echo "missing" >> "$DEST/multi_source.dat"
        COL=$((COL+1))
    done
done <<< "$SOURCES"

# Ensure that index can be moves if needed
if [[ "$MOVE_INDEX_UP" == "true" ]]; then
    DATA_ROOT="${DEST%/}/"
fi
. $JUXTA_HOME/juxta.sh "$DEST/multi_source.dat" "$DEST"
if [[ "$MOVE_INDEX_UP" == "true" ]]; then
    mv "$DEST/index.html" $(dirname "$DEST")
fi

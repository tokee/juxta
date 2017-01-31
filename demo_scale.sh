#!/bin/bash

# Creates arbitrarily large collages from ImageMagic sample images
#
# Intended for scale testing

: ${MAX_IMAGES:=1000}
: ${BACKGROUND:=000000}
: ${RAW_W:=4}
: ${RAW_H:=3}

usage() {
    echo "Usage:"
    echo "MAX_IMAGES=100 ./demo_scale.sh"
    exit $1
}

DEST=downloads/scale_${RAW_W}x${RAW_H}
JDEST=scale_${RAW_W}x${RAW_H}_${MAX_IMAGES}
if [ -d $JDEST ]; then
    >&2 echo "Error: Destination $JDEST already exists"
    exit 1
fi

# Create a few sample images
mkdir -p $DEST
echo "- Creating sample images"
SAMPLES=0
for C in green red blue yellow magenta black white orange; do
    if [ ! -s $DEST/sample_${C}.png ]; then
        convert logo: -geometry $((RAW_W*256))x$((RAW_H*256)) -fill $C -colorize 50% $DEST/sample_${SAMPLES}.png
    fi
    SAMPLES=$((SAMPLES+1))
done

# Create image list of arbitrary size with fake meta-data
echo "- Creating image list with $MAX_IMAGES entries"
COUNTER=0
SAMPLE=0
rm -f demo_scale.images.dat
while [ $COUNTER -lt $MAX_IMAGES ]; do
    echo "$DEST/sample_${SAMPLE}.png|Meta-data place holder #$COUNTER" >> demo_scale.images.dat
    COUNTER=$((COUNTER+1))
    SAMPLE=$((SAMPLE+1))
    if [ $SAMPLE -eq $SAMPLES ]; then
        SAMPLE=0
    fi
done

echo "- Activating juxta"
./juxta.sh demo_scale.images.dat $JDEST

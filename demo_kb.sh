#!/bin/bash

# Creates collage of public available images from kb.dk
# API described on https://github.com/Det-Kongelige-Bibliotek/access-digital-objects

pushd ${BASH_SOURCE%/*} > /dev/null
: ${DOWNLOAD_SCRIPT:="$(pwd)/download_kb.sh"}
popd > /dev/null

# Valid values are 'none', 'intensity' and 'rainbow'
: ${IMAGE_SORT:="none"}

: ${ALLOW_UPSCALE:=true}
: ${RAW_MODE:=automax}
: ${BACKGROUND:=000000}
: ${TEMPLATE:=demo_kb.template.html}

: ${MAX_IMAGES:="1000000000"} # 1b
: ${MAX_IMAGES_PER_COLLECTION:="$MAX_IMAGES"}

# TODO: Extract the title of the collection and show it on the generated page
# TODO: Better guessing of description text based on md:note fields
# TODO: Get full images: http://kb-images.kb.dk/online_master_arkiv_6/non-archival/Images/BILLED/2008/Billede/dk_eksp_album_191/kbb_alb_2_191_friis_011/full/full/0/native.jpg
# TODO: Trim titles to max X chars

usage() {
    echo "Usage:"
    echo "./demo_kb.sh list"
    echo "             Shows available collections"
    echo "./demo_kb.sh create collection*"
    echo "             Creates a page for the given collection IDs"
    exit $1
}

COMMAND="$1"
if [ "list" != "$COMMAND" -a "create" != "$COMMAND" ]; then
    if [  "." == ".$COMMAND" ]; then
        echo "Please provide a command"
        usage
    fi
    >&2 echo "Error: Unknown command '$COMMAND'"
    usage 1
fi
shift
export COLLECTIONS="$@"
if [ "create" == "$COMMAND" -a "." == ".$COLLECTIONS" ]; then
    >&2 echo "Error: A collection must be provided"
    usage 2
fi
# Multi-collection handling
ALLC=$(tr ' ' '_' <<< "$COLLECTIONS" | sed 's/_$//')
: ${DEST:="$ALLC"}

# https://github.com/Det-Kongelige-Bibliotek/access-digital-objects
# http://www.kb.dk/cop/syndication/images/billed/2010/okt/billeder/subject2109/
list_collections() {
    echo "Not implemented yet. Go to"
    echo "http://www.kb.dk/images/billed/2010/okt/billeder/subject2109/en/"
    echo "And browse to a collection (not an individual image)."
    echo "In the URL the subject can be located, such as 'subject3795'."
}

if [ "list" == "$COMMAND" ]; then
    list_collections
    exit
fi

mkdir -p downloads/$DEST
rm -r downloads/$DEST/sources.dat
if [[ "$MAX_IMAGES" -lt "$MAX_IMAGES_PER_COLLECTION" ]]; then
    MAX_IMAGES_PER_COLLECTION=$MAX_IMAGES
fi
OLD_MI=$MAX_IMAGES
MAX_IMAGES=$MAX_IMAGES_PER_COLLECTION
for COLLECTION in $COLLECTIONS; do
    echo "Downloading collection $COLLECTION"
    . $DOWNLOAD_SCRIPT "$COLLECTION"
    cat downloads/$COLLECTION/sources.dat >> downloads/$DEST/sources.dat
done
MAX_IMAGES=$OLD_MI

COLLECTION="$DEST"
if [ "intensity" == "$IMAGE_SORT" ]; then
    DAT=downloads/$DEST/sources_intensity_${MAX_IMAGES}.dat
    if [ -s "$DAT" ]; then
        echo "- Skipping sort by intensity as $DAT already exists"
    else 
        echo "- Sorting images by intensity"
        ./intensity_sort.sh downloads/$COLLECTION/sources.dat $DAT
    fi
    SORTED_SOURCE="$DAT"
elif [ "rainbow" == "$IMAGE_SORT" ]; then
    DAT=downloads/$COLLECTION/sources_rainbow_${MAX_IMAGES}.dat
    if [ -s $DAT ]; then
        echo "Skipping sort in rainbow order as $DAT already exists"
    else
        echo "- Sorting images in rainbow order"
        ./rainbow_sort.sh downloads/$COLLECTION/sources.dat $DAT
    fi
    SORTED_SOURCE="$DAT"
else
    SORTED_SOURCE="downloads/$COLLECTION/sources.dat"
fi

. ./juxta.sh $SORTED_SOURCE $DEST

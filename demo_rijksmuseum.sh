#!/bin/bash

# Creates collage of public available images from rijksmuseum.nl
# API described on http://rijksmuseum.github.io/
# Terms & Conditions: https://www.rijksmuseum.nl/en/api/terms-and-conditions-of-use

# Single image: https://www.rijksmuseum.nl/api/en/collection/sk-c-5?key=fakekey&format=json
# Manual search: https://www.rijksmuseum.nl/en/search?f.principalMakers.name.sort=Rembrandt+Harmensz.+van+Rijn&st=OBJECTS
# API: https://www.rijksmuseum.nl/api/en/collection?key=fakekey&format=json&f.principalMakers.name.sort=Rembrandt+Harmensz.+van+Rijn

# For easier use define KEY in the file demo_rijksmuseum.properties
if [ -s demo_rijksmuseum.properties ]; then
    source demo_rijksmuseum.properties
fi

: ${MAX_IMAGES:=10}
: ${BASE_API_SEARCH:="https://www.rijksmuseum.nl/api/en/collection"}
: ${ARGS:="&imgonly=True&ps=100"}
: ${KEY:="NA"}
: ${OUT:="$2"}
: ${THREADS:=4}
: ${RAW_W:=10}
: ${RAW_H:=10}
: ${BACKGROUND:="000000"}
: ${TEMPLATE:=demo_rijksmuseum.template.html}

usage() {
    echo "Usage: KEY=yourkey ./demo_rijksmuseum.sh \"search-URL\" \"outfolder\""
    echo "Example: KEY=yourkey ./demo_rijksmuseum.sh \"https://www.rijksmuseum.nl/en/search?s=chronologic&f.principalMakers.name.sort=Rembrandt+Harmensz.+van+Rijn&st=OBJECTS\" \"rembrandt\""
    exit $1
}

# Out: API_SEARCH
process_args() {
    if [ ".NA" == ".$KEY" ]; then
        >&2 echo "Error: No KEY defined. Read http://rijksmuseum.github.io/ for details on obtaining a (free) key"
        exit 2
    fi
    if [ "." == ".$SEARCH" ]; then
        local SEARCH=$( echo "$1" | cut -d'?' -f2 )
    fi
    if [ "." == ".$SEARCH" ]; then
        >&2 echo "Error: No search provided"
        usage 3
    fi
    if [ "." == ".$OUT" ]; then
        >&2 echo "Error: No output folder"
        usage 4
    fi
    if [ -d "$OUT" ]; then
        echo "Output folder '$OUT' already exist. It will be updated"
    fi
    API_SEARCH="${BASE_API_SEARCH}?${ARGS}&key=${KEY}&${SEARCH}"
}

perform_search() {
    if [ -s metadata.dat ]; then
        local CURRENT_COUNT=$( cat metadata.dat | wc -l )
        if [ "$CURRENT_COUNT" -ge "$MAX_IMAGES" ]; then
            echo " - Already resolved metadata, no searches performed"
            return
        else
            echo " - Not enough metadata resolved, deleting and re-searching"
            rm metadata.dat
        fi
    fi
    local LAST_COUNT=0
    local PAGE=0
    rm -rf metadata.dat
    while [ "$LAST_COUNT" -lt "$MAX_IMAGES" ]; do
        curl -m 100 -s "$API_SEARCH&p=${PAGE}" | jq --indent 0 '.artObjects[] | {url: .webImage .url, objectNumber: .objectNumber, title: .title, maker: .principalOrFirstMaker}' >> metadata.dat
        # Not the most efficient, but the collections should be small-ish (< 100K)
        local CURRENT_COUNT=$( cat metadata.dat | wc -l )
        echo " - Result sum: $CURRENT_COUNT"
        if [ "$CURRENT_COUNT" -eq "$LAST_COUNT" ]; then
            break
        fi
        LAST_COUNT=$CURRENT_COUNT
        PAGE=$((PAGE+1))
    done
}

download_image() {
    # TODO: Escape <, >, " and &
    local URL=$( echo "$1" | jq -r '.url' )
    local ID=$( echo "$1" | jq -r '.objectNumber' )
    local MAKER=$( echo "$1" | jq -r '.maker' )
    local TITLE=$( echo "$1" | jq -r '.title' )
    local IMAGE=$(basename "$URL").jpg
    if [ ! -s "images/$IMAGE" ]; then
        echo " - Downloading $URL"
        wget -q "$URL" -O "images/$IMAGE"
    fi
}
export -f download_image

make_image_list() {
    # TODO: Escape <, >, " and &
    local URL=$( echo "$1" | jq -r '.url' )
    local ID=$( echo "$1" | jq -r '.objectNumber' )
    local MAKER=$( echo "$1" | jq -r '.maker' )
    local TITLE=$( echo "$1" | jq -r '.title' )
    local IMAGE=$(basename "$URL").jpg
    echo "$OUT/images/$IMAGE|$ID§$MAKER§$TITLE" | sed -e 's/&/&amp;/g' -e 's/"/&nbsp;/g' -e 's/</&lt;/g'  -e 's/>/&gt;/g' 
}
export -f make_image_list

download_images() {
    #    cat metadata.dat | head -n $MAX_IMAGES | tr '\n' '\0' | xargs -0 -P $THREADS -n 1 -I {} bash -c 'wget -q $( echo "{}" | jq --indent 0 -r '.url' )'
    export THREADS
    export MAX_IMAGES
    export OUT
    mkdir -p images
    echo " - Downloading images"
    cat metadata.dat | head -n $MAX_IMAGES | tr '\n' '\0' | sed 's/"/\\"/g' | xargs -0 -P $THREADS -n 1 -I {} bash -c 'download_image "{}"'
    echo " - Generating image list"
    cat metadata.dat | head -n $MAX_IMAGES | tr '\n' '\0' | sed 's/"/\\"/g' | xargs -0 -P 1 -n 1 -I {} bash -c 'make_image_list "{}"' > images.dat
}

process_args $@
mkdir -p "$OUT"
pushd "$OUT" > /dev/null
perform_search
download_images
popd > /dev/null
echo " - Calling juxta"
. ./juxta.sh "$OUT/images.dat" "$OUT"

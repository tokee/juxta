#!/bin/bash

#
# Takes a list of tweet-IDs
# - Extracts the tweets using  https://github.com/docnow/twarc
# - Extract image-URLs from the tweets
# - Downloads the images
# - Generates a collage using the images with links back to the tweets
#
# The format of the tweet-ID-file is a list of tweetIDs (numbers), one per line
#
# Requirements: An installed twarc and a Twitter API key (see the twarc GitHub readme)
#

: ${TWARC:="../twarc"}
: ${IMAGE_BUCKET_SIZE:=20000}
: ${MAX_IMAGES:=99999999999}

: ${RAW_W:=1}
: ${RAW_H:=1}

usage() {
    echo "./demo_twitter.sh tweet-ID-list collage_name"
    exit $1
}

parse_arguments() {
    TWEETIDS="$1"
    if [ ! -s "$TWEETIDS" ]; then
        >&2 echo "No tweet-ID-list at '$TWEETIDS'"
        usage 1
    fi
    DEST="$2"
    if [ ! -s "$TWEETIDS" ]; then
        >&2 echo "No collage name specified"
        exit 2
    fi
    if [ ! -d "$TWARC" }; then
        >&2 echo "Unable to locate twarc folder (tried $TWARC)"
        >&2 echo "Please state the folder using environment variables, such as"
        >&2 echo "TWARC=/home/myself/bin/twarc ./demo_twitter.sh mytweetIDs.dat mytweets"
        exit 3
    fi
}

hydrate() {
    if [ -s "$DOWNLOAD/hydrated.json" ]; then
        echo " - Skipping hydration of '$TWEETIDS' as $DOWNLOAD/hydrated.json already exists"
        return
    fi
    echo " - Hydration of '$TWEETIDS' to $DOWNLOAD/hydrated.json"
    # TODO: $TWEETIDS -> $DOWNLOAD/hydrated.json
}

extract_image_data() {
    if [ -s "$DOWNLOAD/date-id-imageURL.dat" ]; then
        echo " - Skipping extraction of date, ID and imageURL as $DOWNLOAD/date-id-imageURL.dat already exists"
        return
    fi
    echo " - Extracting date, ID and imageURL to $DOWNLOAD/date-id-imageURL.dat"
    # TODO: $DOWNLOAD/hydrated.json -> $DOWNLOAD/date-id-imageURL.dat
}

download_images() {
    local MAX=`cat "$DOWNLOAD/date-id-imageURL.dat" | wc -l`
    if [ "$MAX_IMAGES" -lt "$MAX" ]; then
        MAX=$MAX_IMAGES
    fi
    echo " - Downloading a maximum of $MAX images"
    rm "$DOWNLOAD/date-id-imagePath.dat"
    local COUNTER=0
    IFS=$'\n'
    while read LINE do;
          # TODO: Status, check existence, curl-with-timeout, update "$DOWNLOAD/date-id-imagePath.dat"
          COUNTER=$(( COUNTER + 1 ))
          if [ $COUNTER -ge $MAX ]; then
              break
          fi
    done < "$DOWNLOAD/date-id-imageURL.dat"
}

prepare_juxta_input() {
    # TODO: cat "$DOWNLOAD/date-id-imagePath.dat" | sort | sed 's/' > "$DOWNLOAD/imagelist.dat"
}

parse_arguments $@
DOWNLOAD="${DEST}_downloads"
mkdir -p "$DOWNLOAD"
hydrate
extract_image_data
download_images
prepare_juxta_input
# don't include imagePath in metadata
. TEMPLATE=demo_twitter.template.html INCLUDE_ORIGIN=false ./juxta.sh "$DOWNLOAD/imagelist.dat" "$DEST"

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
# Requirements:
# - An installed twarc and a Twitter API key (see the twarc GitHub readme)
# - jq (sudo apt install jq)
#
# TODO: Consider adding user.screen_name as metadata
# TODO: Pipe the hydrate output through gzip to save disk space
# TODO: Better guessing as to where twarc is installed

: ${TWARC:="$HOME/.local/bin/twarc"}
: ${IMAGE_BUCKET_SIZE:=20000}
: ${MAX_IMAGES:=99999999999}
: ${THREADS:=3}
: ${TIMEOUT:=60}
: ${TEMPLATE:="demo_twitter.template.html"}
: ${ALREADY_HYDRATED:=false}

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
    if [ ! -x "$TWARC" ]; then
        >&2 echo "Unable to locate twarc executable (tried $TWARC)"
        >&2 echo "Please state the folder using environment variables, such as"
        >&2 echo "TWARC=/home/myself/bin/twarc ./demo_twitter.sh mytweetIDs.dat mytweets"
        exit 3
    fi
    # TODO: Verify that jq is installed
}

hydrate() {
    if [ -s "$DOWNLOAD/hydrated.json" ]; then
        echo " - Skipping hydration of '$TWEETIDS' as $DOWNLOAD/hydrated.json already exists"
        return
    fi
    if [ "." != ".$(grep '{' $TWEETIDS)" ]; then
        echo "Input file $TWEETIDS contains a '{', so it is probably already hydrated"
        ALREADY_HYDRATED=true
    fi
    if [ "true" == "$ALREADY_HYDRATED" ]; then
        echo "Input file $TWEETIDS is already hydrated"
        cp $TWEETIDS $DOWNLOAD/hydrated.json
        return
    fi
    echo " - Hydration of '$TWEETIDS' to $DOWNLOAD/hydrated.json"
    $TWARC hydrate "$TWEETIDS" > "$DOWNLOAD/hydrated.json"
}

extract_image_data() {
    if [ -s "$DOWNLOAD/date-id-imageURL.dat" ]; then
        echo " - Skipping extraction of date, ID and imageURL as $DOWNLOAD/date-id-imageURL.dat already exists"
        return
    fi
    echo " - Extracting date, ID and imageURL to $DOWNLOAD/date-id-imageURL.dat"
    # TODO: Better handling of errors than throwing them away
    cat "$DOWNLOAD/hydrated.json" | jq --indent 0 -r 'if (.entities .media[] .type) == "photo" then [.id_str,.created_at,.entities .media[] .media_url_https // .entities .media[] .media_url] else empty end' > "$DOWNLOAD/date-id-imageURL.dat" 2>/dev/null
    
    # TODO: $DOWNLOAD/hydrated.json -> $DOWNLOAD/date-id-imageURL.dat
}

# 1 [786532479343599600,"Thu Oct 13 11:42:10 +0000 2016","https://pbs.twimg.com/media/CupTGBlWcAA-yzz.jpg"]
download_image() {
    local LINE="$@"
    local IFS=$' '
    local TOKENS=($LINE)
    local COUNT=${TOKENS[0]}
    unset IFS
    LINE=${LINE#*\[}

    # 786532479343599600,"Thu Oct 13 11:42:10 +0000 2016","https://pbs.twimg.com/media/CupTGBlWcAA-yzz.jpg"]
    IFS=,
    local TOKENS=($LINE)
    local ID=${TOKENS[0]}
    local ID=$( echo $ID | tr -d '"' )
    local DATE_STR=${TOKENS[1]}
    local TDATE=$( date -d $DATE_STR +"%Y-%m-%dT%H:%M:%S" )
    unset IFS
    local LINE=${LINE#*,}
    local LINE=${LINE#*,}
    local IMAGE_URL=${LINE%?}
    local IMAGE_NAME=$(echo "$IMAGE_URL" | sed -e 's/^[a-zA-Z]*:\/\///' -e 's/[^-A-Za-z0-9_.]/_/g' )
    local BUCKET=$((COUNT / IMAGE_BUCKET_SIZE * IMAGE_BUCKET_SIZE ))
    mkdir -p "$DOWNLOAD/images/$BUCKET"
    local IDEST="$DOWNLOAD/images/$BUCKET/$IMAGE_NAME"
    if [ ! -s "$IDEST" ]; then
        curl -s -m $TIMEOUT "$IMAGE_URL" > "$IDEST"
    fi
    if [ -s "$IDEST" ]; then
        echo "$COUNT/$MAX $TDATE $ID $IDEST"
    else
        >&2 echo "Unable to download $IMAGE_URL"
    fi    
}
export -f download_image

download_images() {
    if [ -s "$DOWNLOAD/counter-max-date-id-imagePath.dat" ]; then
        echo " - $DOWNLOAD/counter-max-date-id-imagePath.dat already exists, but all images might not be there"
    fi
    echo " - Downloading images defined in $DOWNLOAD/date-id-imageURL.dat"

    # Create job list
    local MAX=`cat "$DOWNLOAD/date-id-imageURL.dat" | wc -l`
    if [ "$MAX_IMAGES" -lt "$MAX" ]; then
        MAX=$MAX_IMAGES
    fi
    local ITMP=`mktemp /tmp/juxta_demo_twitter_XXXXXXXX`
    local COUNTER=1
    IFS=$'\n'
    while read LINE; do
        if [ $COUNTER -gt $MAX ]; then
            break
        fi
        echo "$COUNTER $LINE" >> $ITMP
        COUNTER=$(( COUNTER + 1 ))
    done < "$DOWNLOAD/date-id-imageURL.dat"

    # Run download jobs threaded
    export MAX
    export IMAGE_BUCKET_SIZE
    export DOWNLOAD
    export TIMEOUT
    #cat $ITMP | tr '\n' '\0' | xargs -0 -P $THREADS -n 1 -I {} bash -c 'echo "{}"'
    cat $ITMP | tr '\n' '\0' | xargs -0 -P $THREADS -n 1 -I {} bash -c 'download_image "{}"' | tee "$DOWNLOAD/counter-max-date-id-imagePath.dat"
    rm $ITMP
}

prepare_juxta_input() {
    echo " - Sorting and preparing juxta image list $DOWNLOAD/twitter_images.dat"
    cat "$DOWNLOAD/counter-max-date-id-imagePath.dat" | sed -e 's/^[0-9\/]* //' -e 's/^\([^ ][^ ]*\) \([0-9][0-9]*\) \([^ ][^ ]*\)$/\3|\2 \1/' > "$DOWNLOAD/twitter_images.dat"
}

parse_arguments $@
DOWNLOAD="${DEST}_downloads"
mkdir -p "$DOWNLOAD"
hydrate
extract_image_data
download_images
prepare_juxta_input

export TEMPLATE
export RAW_W
export RAW_H
export THREADS
INCLUDE_ORIGIN=false ./juxta.sh "$DOWNLOAD/twitter_images.dat" "$DEST"

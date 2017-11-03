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

###############################################################################
# CONFIG
###############################################################################

: ${TWARC:="/usr/local/bin/twarc"} # Also tries default path
: ${IMAGE_BUCKET_SIZE:=20000}
: ${MAX_IMAGES:=99999999999}
: ${THREADS:=3}
: ${TIMEOUT:=60}
: ${TEMPLATE:="demo_twitter.template.html"}
: ${ALREADY_HYDRATED:=false}
: ${AGGRESSIVE_TWITTER_SKIP:=false} # true = skip when there are existing structures
: ${BACKGROUND:="000000"}
: ${FORCE_HYDRATE_GZ:=

: ${RAW_W:=2}
: ${RAW_H:=2}
: ${ALLOW_UPSCALE:=true}

pushd ${BASH_SOURCE%/*} > /dev/null
: ${JUXTA_HOME:="$(pwd)"}
popd > /dev/null
export JUXTA_HOME

################################################################################
# FUNCTIONS
################################################################################

usage() {
    echo "./demo_twitter.sh tweet-ID-list [collage_name]"
    exit $1
}

parse_arguments() {
    TWEETIDS="$1"
    if [[ ! -s "$TWEETIDS" ]]; then
        >&2 echo "Error: No tweet-ID-list at '$TWEETIDS'"
        usage 1
    fi
    DEST="$2"
    if [[ "." == ".$DEST" ]]; then
        DEST=$(basename "$TWEETIDS") # foo.json.gz
        DEST="${DEST%.*}" # foo.json
        DEST="twitter_${DEST%.*}" # foo
        echo "No collage name specified, using $DEST"
    fi
    if [[ "." == .$(which jq) ]]; then
        >&2 echo "Error: jq not available. Install with 'sudo apt-get install jq'"
        exit 9
    fi
}

# Output: HYDRATED
hydrate() {
    export HYDRATED="$DOWNLOAD/hydrated.json.gz"
    
    if [[ "." != .$( grep '{' "$TWEETIDS" | head -n 1 ) ]]; then
        echo "Input file $TWEETIDS contains a '{', so it is probably already hydrated"
        ALREADY_HYDRATED=true
    fi
    if [[ -s "$DOWNLOAD/hydrated.json" ]]; then
        echo " - Skipping hydration of '$TWEETIDS' as $DOWNLOAD/hydrated.json already exists"
        export HYDRATED="$DOWNLOAD/hydrated.json"
        return
    elif [[ -s "$DOWNLOAD/hydrated.json.gz" ]]; then
        echo " - Skipping hydration of '$TWEETIDS' as $DOWNLOAD/hydrated.json.gz already exists"
        return
    fi
    
    if [ "true" == "$ALREADY_HYDRATED" ]; then
        if [[ "$TWEETIDS" == *.gz ]]; then
            echo "Input file $TWEETIDS is already hydrated. Copying to $DOWNLOAD/hydrated.json.gz"
            cp $TWEETIDS $DOWNLOAD/hydrated.json.gz
        else
            echo "Input file $TWEETIDS is already hydrated. GZIPping to $DOWNLOAD/hydrated.json.gz"
            gzip -c $TWEETIDS > $DOWNLOAD/hydrated.json.gz
        fi
        return
    fi
    if [ ! -x "$TWARC" ]; then
        TWARC=$(which twarc)
        if [ ! -x "$TWARC" ]; then
            >&2 echo "Unable to locate twarc executable (tried $TWARC)"
            >&2 echo "Please state the folder using environment variables, such as"
            >&2 echo "TWARC=/home/myself/bin/twarc ./demo_twitter.sh mytweetIDs.dat mytweets"
            exit 3
        fi
    fi
    echo " - Hydration of '$TWEETIDS' to $DOWNLOAD/hydrated.json.gz"
    $TWARC hydrate "$TWEETIDS" | gzip > "$DOWNLOAD/hydrated.json"
}

extract_image_data() {
    if [ -s "$DOWNLOAD/date-id-imageURL.dat" ]; then
        echo " - Skipping extraction of date, ID and imageURL as $DOWNLOAD/date-id-imageURL.dat already exists"
        return
    fi
    echo " - Extracting date, ID and imageURL to $DOWNLOAD/date-id-imageURL.dat"
    # TODO: Better handling of errors than throwing them away
    zcat "$HYDRATED" | jq --indent 0 -r 'if (.entities .media[] .type) == "photo" then [.id_str,.created_at,.entities .media[] .media_url_https // .entities .media[] .media_url] else empty end' > "$DOWNLOAD/date-id-imageURL.dat" 2>/dev/null
    
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
        if [[ "true" == "$AGGRESSIVE_TWITTER_SKIP" ]]; then
            echo " - $DOWNLOAD/counter-max-date-id-imagePath.dat already exists and AGGRESSIVE_TWITTER_SKIP==treu. Skipping image download"
            return
        else 
            echo " - $DOWNLOAD/counter-max-date-id-imagePath.dat already exists, but all images might not be there"
        fi
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
    if [[ "true" == "$AGGRESSIVE_TWITTER_SKIP" && -s "$DOWNLOAD/twitter_images.dat" ]]; then
        echo " - Skipping sorting and preparing juxta image list $DOWNLOAD/twitter_images.dat as it already exists AGGRESSIVE_TWITTER_SKIP=true"
        return
    fi
    echo " - Sorting and preparing juxta image list $DOWNLOAD/twitter_images.dat"
    cat "$DOWNLOAD/counter-max-date-id-imagePath.dat" | sed -e 's/^[0-9\/]* //' -e 's/^\([^ ][^ ]*\) \([0-9][0-9]*\) \([^ ][^ ]*\)$/\3|\2 \1/' > "$DOWNLOAD/twitter_images.dat"
}

###############################################################################
# CODE
###############################################################################

parse_arguments "$@"
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
INCLUDE_ORIGIN=false . ${JUXTA_HOME}/juxta.sh "$DOWNLOAD/twitter_images.dat" "$DEST"

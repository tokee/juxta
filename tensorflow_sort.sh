#!/bin/bash

#
# Fairly convoluted setup of tensorflow + tSNE + rasterfairy for sorting
# images to a 2D grid (aka juxta collage) by visual similarity.
#
# This requires Python 3 and performs a GitHub checkout. Dirty dirty.
#

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
: ${SCRIPT_HOME:=$(pwd)}
: ${TENSOR_FOLDER:="$SCRIPT_HOME/tensorflow"}
: ${VIRTUAL_FOLDER:="$TENSOR_FOLDER/virtualenv"}
: ${ML_FOLDER:="$TENSOR_FOLDER/ml4a-ofx"}
: ${CACHE_HOME:="$TENSOR_FOLDER/cache"}

: ${ML_GIT:="https://github.com/ml4a/ml4a-ofx.git"}
: ${PYTHON_REQUIREMENTS:="pillow sklearn tensorflow keras numpy prime rasterfairy"}
: ${PYTHON:=$(which python3)}
: ${PYTHON:=$(which python)}
: ${PIP:=$(which pip3)}
: ${USE_VIRTUALENV:="true"}

: ${IN:="$1"}
: ${OUT:="$2"}
: ${CACHE_FOLDER:="$CACHE_HOME/$(basename "$OUT")"}

: ${MIN_IMAGES:="300"}
popd > /dev/null

usage() {
    echo "Usage: ./tensorflow_sort.sh in_imagelist.dat out_imagelist.dat"
    exit $1
}

check_parameters() {
    if [[ -z "$IN" ]]; then
        >&2 echo "Error: No in_imagelist.dat specified"
        usage 10
    fi
    if [[ ! -s "$IN" ]]; then
        >&2 echo "Error: The input image list $IN did not hold any content"
        usage 11
    fi
    local IN_COUNT=$(wc -l < "$IN")
    if [[ "$IN_COUNT" -lt "$MIN_IMAGES" ]]; then
        >&2 echo "Error: tensorflow_sort.sh requires at least $MIN_IMAGES images. There were only $IN_COUNT"
        exit 12
    fi
    if [[ -z "$OUT" ]]; then
        >&2 echo "Error: No out_imagelist.dat specified"
        usage 12
    fi
            
    if [[ -z "$PYTHON" ]]; then
        >&2 echo "Error: Unable to locate python3 or python"
        exit 2
    fi
    local PYTHON_VERSION=$(2>&1 $PYTHON --version  | cut -d\  -f2 | cut -d. -f1)
    if [[ "$PYTHON_VERSION" -le "2" ]]; then
        >&2 echo "Error: Python 3 required but could only locate $PYTHON which is version $PYTHON_VERSION"
        exit 3
    fi
    
    if [[ -z "$PIP" ]]; then
        PIP=$(which pip)
        if [[ -z "$PIP" ]]; then
            >&2 echo "Error: Unable to locate either pip3 or pip"
            exit 4
        fi
    fi
    local PIP_PYTHON_VERSION=$($PIP --version | grep -o "(python.*" | cut -d\  -f2 | cut -d. -f1)
    if [[ "$PIP_PYTHON_VERSION" -le "2" ]]; then
        >&2 echo "Error: pip for Python 3 required but could only locate $PIP which is for Python version $PIP_PYTHON_VERSION"
        exit 5
    fi

}

################################################################################
# FUNCTIONS
################################################################################

setup_environment() {
    if [[ -d "$VIRTUAL_FOLDER" ]]; then
        echo "- Skipping setup of virtualenv as $VIRTUAL_FOLDER already exist"
        return
    fi
    echo "- Setting up Python virtualenv in $VIRTUAL_FOLDER"
    $PYTHON -m venv "$VIRTUAL_FOLDER"
    source "$VIRTUAL_FOLDER/bin/activate"
    for REQ in $PYTHON_REQUIREMENTS; do
        pip3 install $REQ
    done
    VIRTUAL_ENV_ACTIVATED=true
}

activate_environment() {
    if [[ "true" == "$VIRTUAL_ENV_ACTIVATED" ]]; then
        return
    fi

    echo "- Activating Python virtualenv in $VIRTUAL_FOLDER"
    source "$VIRTUAL_FOLDER/bin/activate"
}

ensure_environment() {
    if [[ "true" != "$USE_VIRTUALENV" ]]; then
        echo "- Using Python directly as USE_VIRTUALENV==$USE_VIRTUALENV"
        return
    fi
    setup_environment
    activate_environment
}

ensure_ml4a() {
    if [[ -d "$ML_FOLDER" ]]; then
        echo "- Skipping git clone of ml4a-ofx as $ML_FOLDER already exists"
        return
    fi
    echo "- git cloning ml4a-ofx from $ML_GIT"
    git clone "$ML_GIT" "$ML_FOLDER"
    
}

link_images() {
    echo "- Symlinking to images in cache folder $CACHE_FOLDER"
    if [[ -d "$CACHE_FOLDER" ]]; then
        echo "Cache folder $CACHE_FOLDER already exists. Skipping symlinking"
        return

        rm -r "$CACHE_FOLDER"
    fi
    mkdir -p "$CACHE_FOLDER"
    while read -r IMG; do
        ln -s $(realpath "$IMG") "$CACHE_FOLDER/$(basename "$IMG")"
        #cp $(realpath "$IMG") "$CACHE_FOLDER/$(basename "$IMG")"
    done < "$IN"
}

tensorflow_and_tsne() {
    echo "- Running tensorflow and tSNE on images from $IN"
    rm points.json
    $PYTHON $ML_FOLDER/scripts/tSNE-images.py --images_path "$CACHE_FOLDER" --output_path points.json
    if [[ ! -s points.json ]]; then
        >&2 echo "Error: RunningtSNE-imaes.py did not produce the expected file 'points.json'"
        exit 5
    fi
}

gridify() {
    echo "- Creating preview image and gridifying"
    $PYTHON plotpoints.py
    mv gridified.dat "$OUT"
    echo "- Stored grid sorted images to $OUT"
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
ensure_environment
ensure_ml4a
link_images
tensorflow_and_tsne
gridify

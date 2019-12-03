#!/bin/bash

#
# Fairly convoluted setup of tensorflow + tSNE + rasterfairy for sorting
# images to a 2D grid (aka juxta collage) by visual similarity.
#
# This requires Python 3 and performs a GitHub checkout. Dirty dirty.
#
# Note: Only works when all images have unique file names across folders
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

    # Note: Resolving PYTHON & PIP is only for verifying that the system has them.
    # When the virtual environment is activated, it provides "new" python & pip commands.
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
    echo "- Using Python '$PYTHON' and pip '$PIP'"

    OUT_FN="${OUT%.*}"
    OUT_EXT="${OUT##*.}"
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
    if [[ "." == ".$(grep "$(pwd)" <<< "$(pip -V)" )" ]]; then
        >&2 echo "Error: Virtual envionment not activated: 'pip -V' does not include current folder: $(pip -V)"
        exit 12
    fi
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
        echo "  Cache folder $CACHE_FOLDER already exists. Skipping symlinking"
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
    if [[ -s points.jso ]]; then
            rm points.json
    fi
    python3 $ML_FOLDER/scripts/tSNE-images.py --images_path "$CACHE_FOLDER" --output_path points.json
    if [[ ! -s points.json ]]; then
        >&2 echo "Error: RunningtSNE-imaes.py did not produce the expected file 'points.json'"
        exit 5
    fi
}

# Output: GX GY OUT_FINAL
gridify() {
    echo "- Creating preview image and gridifying"
    GRID=$(python3 plotpoints.py | grep "Data in .* with a render-grid.*" | grep -o " [0-9]*x[0-9]*" | tr -d \  )
    GX=$(cut -dx -f1 <<< "$GRID")
    GY=$(cut -dx -f2 <<< "$GRID")
    OUT_FINAL="${OUT_FN}_${GX}x${GY}.${OUT_EXT}"
    mv gridified.dat "$OUT_FINAL"
    echo "- Stored grid sorted images to $OUT_FINAL"
}

fix_paths() {
    pushd $CACHE_FOLDER > /dev/null
    # https://stackoverflow.com/questions/407523/escape-a-string-for-a-sed-replace-pattern#2705678
    local CFULL=$(sed 's/[]\/$*.^[]/\\&/g' <<< "$(pwd)/" )
    popd > /dev/null
    sed -i "s/$CFULL//" "$OUT_FINAL"
    # OUT_FINAL now holds filenames only in wanted order

    T1=$(mktemp)
    local COUNTER=0
    while read -r IMG; do
        echo "$IMG"$'\t'"$COUNTER" >> "$T1"
        COUNTER=$(( COUNTER + 1 ))
    done <"$OUT_FINAL"

    T1B=$(mktemp)
    LC_ALL=c sort < "$T1" > "$T1B"
    
    T2=$(mktemp)
    sed 's%^\(.*\)/\([^/]*\)$%\2\t\1%' < "$IN" | LC_ALL=c sort > "$T2"

    paste /tmp/tmp.4SXKuzVe6A /tmp/tmp.TKbzqzbzDP | sed 's/\(.*\)\t\(.*\)\t\(.*\)\t\(.*\)/\2\t\4\/\3/' | sort -n | sed 's/^[^\t]*\t//' > "$T1"
    mv "$T1" "$OUT_FINAL"
    rm "$T1B" "$T2"
    echo "- Fixed paths for $OUT_FINAL"
    echo "- Sample juxta call:"

    local RENDER=$(basename "${OUT_FINAL%.*}")

    echo "RAW_IMAGE_COLS=$GX RAW_IMAGE_ROWS=$GY ./juxta.sh \"$OUT_FINAL\" \"$RENDER\""
}


###############################################################################
# CODE
###############################################################################

check_parameters "$@"
ensure_environment
ensure_ml4a
#link_images
#tensorflow_and_tsne
gridify
fix_paths

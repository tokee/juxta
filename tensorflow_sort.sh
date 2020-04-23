#!/bin/bash

#
# Fairly convoluted setup of tensorflow + tSNE + rasterfairy for sorting
# images to a 2D grid (aka juxta collage) by visual similarity.
#
# This requires Python 3
#

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null

: ${IN:="$1"}
: ${OUT:="$2"}
: ${OUT_FULL:="${OUT}.full.json"}
: ${RAW_IMAGE_COLS:="0"}
: ${RAW_IMAGE_ROWS:="0"}

: ${SCRIPT_HOME:=$(pwd)}
: ${TENSOR_FOLDER:="$SCRIPT_HOME/tensorflow"}
: ${VIRTUAL_FOLDER:="$TENSOR_FOLDER/virtualenv"}
: ${CACHE_HOME:="$TENSOR_FOLDER/cache"}

# If true, full processing is always done. If false, processing is skipped if the output file already exists
: ${FORCE_PROCESSING:="false"} #true false
# If true, a mini collage of the image positioned by normalised t-SNE coordinates is created. Mostly used
# to check how well RasterFairy positioned the images on the main collage.
: ${GENERATE_TSNE_PREVIEW_IMAGE:="false"}
# The dimensionality reduction it two-phase: A cheap PCA phase and a heavy t-SNE phase.
# The PCA_COMPONENTS states the first reduction. Decreasing this speeds things up, at
# the cost of poorer result and vice versa.
: ${PCA_COMPONENTS:="300"}

: ${PYTHON:=$(which python3)}
: ${PYTHON:=$(which python)}
: ${PIP:=$(which pip3)}
: ${USE_VIRTUALENV:="true"}

: ${MIN_IMAGES:="2"}

REQUIREMENTS="jq"

popd > /dev/null

usage() {
    echo "Usage: ./tensorflow_sort.sh in_imagelist.dat out_imagelist.dat"
    exit $1
}

check_requirements() {
    for REQ in $REQUIREMENTS; do
        if [[ -z $(which $REQ) ]]; then
            >&2 echo "Error: '$REQ' not available, please install it"
            exit 11
        fi
    done
}

check_parameters() {
    check_requirements
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

    # downloads/subject3795/516937.jpg|http://www.kb.dk/images/billed/2010/okt/billeder/object171949/da/§Holbæk. Parti fra Havnen§§CC BY-NC-ND

    # Uniqueness is not a requirement after switch to new Python script
#    local UNIQUE_COUNT=$(sed -e 's%|.*%%' -e 's%.*/%%' < "$IN" | LC_ALL=C sort | LC_ALL=c uniq | wc -l)
#    if [[ "$IN_COUNT" -ne "$UNIQUE_COUNT" ]]; then
#        >&2 echo "Error: The input $IN ($IN_COUNT images) contained duplicate (de-duplicate $UNIQUE_COUNT images) file names: [$(sed -e 's%|.*%%' -e 's%.*/%%' < "$IN" | LC_ALL=C sort | LC_ALL=c uniq -c | grep -v " 1 " | sed 's/ *[0-9]\+ //' | tr '\n' ' ')]"
#        exit 13

#    fi
    if [[ -z "$OUT" ]]; then
        >&2 echo "Error: No out_imagelist.dat specified"
        usage 14
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
    pip install --prefer-binary -r ${SCRIPT_HOME}/Requirements.txt
    VIRTUAL_ENV_ACTIVATED=true
}

activate_environment() {
    if [[ "true" == "$VIRTUAL_ENV_ACTIVATED" ]]; then
        return
    fi

    echo "- Activating Python virtualenv in $VIRTUAL_FOLDER"
    source "$VIRTUAL_FOLDER/bin/activate"

#    $PIP show tensorflow
#    if [[ "." == ".$(grep "$(pwd)" <<< "$(pip -V)" )" ]]; then
#        >&2 echo "Error: Virtual envionment not activated: 'pip -V' does not include current folder: $(pip -V)"
#        exit 12
#    fi
}

ensure_environment() {
    if [[ "true" != "$USE_VIRTUALENV" ]]; then
        echo "- Using Python directly as USE_VIRTUALENV==$USE_VIRTUALENV"
        return
    fi
    setup_environment
    activate_environment
}

perform_analysis() {
    if [[ -s ${OUT} ]]; then
        if [[ $(wc -l < "$IN") -ne $( wc -l < "$OUT") ]]; then
            echo "- Deleting existing output '$OUT' as it has a different number of lines than input '$IN'"
            rm "$OUT"
        else
            if [[ "false" == "$FORCE_PROCESSING" ]]; then
                echo "- Reusing existing similarity sort '$OUT'"
                return
            else
                echo "- Deleting existing output '$OUT' as FORCE_PROCESSING==${FORCE_PROCESSING}"
                rm "${OUT}"
            fi
        fi
    fi

    echo "- Similarity sorting and gridifying ${IN} with --grid_width=${RAW_IMAGE_COLS} --grid_height=${RAW_IMAGE_ROWS}"
    echo "- NOTE: RasterFairy hangs on some grid layouts (the cause is not known). If nothing happens after this line, try re-running with RAW_IMAGE_COLS=$((RAW_IMAGE_COLS-1)) or $((RAW_IMAGE_COLS+1))"

    # Strip metadata
    T_ONLY_PATHS=$(mktemp)
    cut -d'|' -f1 < "$IN" > "$T_ONLY_PATHS"
    T_GRID=$(mktemp)
    if [[ "true" == "$GENERATE_TSNE_PREVIEW_IMAGE" ]]; then
        local PREVIEW="$(dirname $OUT)/tsne_collage.png"
    else
        local PREVIEW=""
    fi
    python3 ${SCRIPT_HOME}/imagenet_tsne_rasterfairy.py --render_tsne="$PREVIEW" --images ${T_ONLY_PATHS} --grid_width=${RAW_IMAGE_COLS} --grid_height=${RAW_IMAGE_ROWS} --output=${OUT_FULL} --components=${PCA_COMPONENTS} | tee "$T_GRID"
    GRID=$(grep "Stored result" "$T_GRID" | grep -o " [0-9]*x[0-9]*" | tr -d \  )
    rm "$T_GRID" "$T_ONLY_PATHS"

    if [[ "." == ".$GRID" ]]; then
        >&2 echo "Error: Cannot proceed as no GRID was returned from call"
        >&2 echo "python3 ${SCRIPT_HOME}/imagenet_tsne_rasterfairy.py --render_tsne=\"$PREVIEW\" --images ${T_ONLY_PATHS} --grid_width=${RAW_IMAGE_COLS} --grid_height=${RAW_IMAGE_ROWS} --output=${OUT_FULL}"
        exit 21
    fi
    GX=$(cut -dx -f1 <<< "$GRID")
    GY=$(cut -dx -f2 <<< "$GRID")
}

convert_to_list() {
    jq -r .path < "$OUT_FULL" > "$OUT"
    echo "RAW_IMAGE_COLS=$GX RAW_IMAGE_ROWS=$GY ./juxta.sh \"$OUT\" \"$RENDER\""
}

# The OUT contains the images in the correct order, but without metadata
# This methods assigns the metadata from IN to OUT, preserving the order
add_metadata() {
    local T1=$(mktemp)
    local COUNTER=0
    while read -r IMG; do
        echo "$IMG"$'\t'"$COUNTER" >> "$T1"
        COUNTER=$(( COUNTER + 1 ))
    done <"$OUT"
    # T1 now holds [path counter] in tsne order
    
    T1B=$(mktemp)
    LC_ALL=c sort < "$T1" > "$T1B"
    # T1 now holds [path counter] in path order

    T2=$(mktemp)
    sed 's%^\([^|]*\)\([|].*\)\?$%\1\t\2%' < "$IN" | LC_ALL=c sort > "$T2"
    # T2 now holds [path meta] in path order
    
    paste "$T1B" "$T2" | sed 's/\(.*\)\t\(.*\)\t\(.*\)\t\(.*\)/\2\t\3\4/' | sort -n | sed 's/^[^\t]*\t//' > "$T1"
    
    mv "$T1" "$OUT"
    rm "$T1B" "$T2"
}


###############################################################################
# CODE
###############################################################################

check_parameters "$@"
ensure_environment
perform_analysis
convert_to_list
add_metadata
#fix_paths

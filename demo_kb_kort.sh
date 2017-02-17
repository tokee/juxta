#!/bin/bash

#
# Calls demo_kb.sh with parameters use the "Kort & Atlas" (Maps and atlases) collection at kb.dk
# instead of the broad collection.
#

#
# http://kb-images.kb.dk/online_master_arkiv_6/non-archival/Maps/KORTSA/ATLAS_MAJOR/Kbk2_2_63/Kbk2_2_63_009/full/full/0/native.jpg
#

: ${BROWSE_URL:="http://www.kb.dk/maps/kortsa/2012/jul/kortatlas"}
: ${SEARCH_URL_PREFIX:="http://www.kb.dk/cop/syndication/maps/kortsa/2012/jul/kortatlas/"}

# Maps & Atlases are quite high-resolution, so we try to make room for a lot of pixels without
# getting too much padding for the smaller ones.
# Note that the image server at kb.dk only accept sizes up to 8000x8000
: ${RAW_W:=16}
: ${RAW_H:=12}

. demo_kb.sh $@

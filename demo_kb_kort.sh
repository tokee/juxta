#!/bin/bash

#
# Calls demo_kb.sh with parameters use the "Kort & Atlas" (Maps and atlases) collection at kb.dk
# instead of the broad collection.
#
# Sample: MAX_IMAGES=5 ./demo_kb_kort.sh create subject208

#
# http://kb-images.kb.dk/online_master_arkiv_6/non-archival/Maps/KORTSA/ATLAS_MAJOR/Kbk2_2_63/Kbk2_2_63_009/full/full/0/native.jpg
#

: ${BROWSE_URL:="http://www.kb.dk/maps/kortsa/2012/jul/kortatlas"}
: ${SEARCH_URL_PREFIX:="http://www.kb.dk/cop/syndication/maps/kortsa/2012/jul/kortatlas/"}

# Maps & Atlases are quite high-resolution, so we try to make room for a lot of pixels without
# getting too much upscaling for the smaller ones.
# Note that the image server at kb.dk caps the size at 8000x8000
: ${RAW_W:=24}
: ${RAW_H:=18}
: ${MARGIN:=20}

# Although many of the maps are 50MP+, some are smaller. To avoid ugly size differences
# we upscale. The proze is pixelation when zooming the (relatively) smaller maps.
: ${ALLOW_UPSCALE:=true}


. demo_kb.sh $@

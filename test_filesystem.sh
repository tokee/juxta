#!/bin/bash

# Tests performance deterioration while creating many tiny files in a single folder

: ${DEBUG_EVERY:=1000}
: ${CHECK_FIRST:=true}

usage() {
    echo "./test_filesystem.sh numfiles"
    exit $1
}
NUMFILES="$1"
if [ "." == ".$NUMFILES" ]; then
    usage 1
fi

echo "Writing $NUMFILES files with CHECK_FIRST=$CHECK_FIRST"

rm -rf test_filesystem.tmp
mkdir -p test_filesystem.tmp
pushd test_filesystem.tmp > /dev/null
COUNT=0
START=`date +%s.%N | sed 's/[.]\([0-9][0-9][0-9][0-9]\).*/\1/'`
LAST=$START
while [ $COUNT -lt $NUMFILES ]; do
    if [ "true" == "$CHECK_FIRST" ]; then
        if [ ! -f ${COUNT}.tmp ]; then
            (cat ../${BASH_SOURCE} ; echo "Tiny file #$COUNT" ) > ${COUNT}.tmp
        fi
    else
        (cat ../${BASH_SOURCE} ; echo "Tiny file #$COUNT" ) > ${COUNT}.tmp
    fi
    COUNT=$((COUNT+1))
    if [ $((COUNT%DEBUG_EVERY)) -eq 0 -o $COUNT -eq $NUMFILES ]; then
        NOW=`date +%s.%N | sed 's/[.]\([0-9][0-9][0-9][0-9]\).*/\1/'`
        SPEND=$((NOW-LAST))
        if [ $SPEND -eq 0 ]; then
            SPEND=1
        fi
        SPEND_TOTAL=$((NOW-START))
        if [ $SPEND_TOTAL -eq 0 ]; then
            SPEND_TOTAL=1
        fi
        if [ $COUNT -lt $DEBUG_EVERY ]; then
            OVERALL=$COUNT
        else
            OVERALL=$DEBUG_EVERY
        fi
        echo " - Wrote $COUNT/$NUMFILES files. Overall $SPEND ms, average $((COUNT*1000/SPEND_TOTAL)) files/s. Current $SPEND ms, average $((OVERALL*1000/SPEND)) files/s"
        LAST=$NOW
    fi
done
echo " - Cleaning up test_filesystem.tmp"
rm -rf test_filesystem.tmp

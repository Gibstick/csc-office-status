#! /bin/sh

outputfile=$(mktemp -p .)
frame=$(mktemp -p .)

cleanup () {
    rm $outputfile
    rm $frame
}
trap cleanup exit

main () {
    timeout 2.5s wget -N -q http://bit-shifter:8081/ -O $outputfile
    set -e

    # guard against empty file
    if [ ! -s $outputfile ]; then
        echo "Could not fetch webcam stream." 1>&2
        exit 5
    fi

    boundary=$(awk '/--BoundaryString/{ print NR; }' ${outputfile} | sed -n 2p)
    sed -n 5,${boundary}p ${outputfile} | head -n -1 > $frame

    brightness=$(convert ${frame} -colorspace gray -format  "%[fx:floor(100*mean)]" info:)

    if [ "$brightness" -lt 30 ]; then
        retval=1
    else
        retval=0
    fi

    # echo $retval >&2
    exit $retval
}

main

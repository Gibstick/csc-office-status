#! /bin/sh

frame=$HOME/bit-shifter-webcam/frame.jpg

main () {
    # guard against empty file
    if [ ! -s $frame ]; then
        echo "Could not fetch webcam stream." 1>&2
        exit 5
    fi

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

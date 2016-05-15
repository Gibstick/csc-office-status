#! /bin/sh

./openoffice.sh
if [ $? -eq 0 ]; then
    echo "Open!"
else
    echo "Not open!"
fi

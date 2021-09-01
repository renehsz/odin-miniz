#!/bin/sh
VERSION="2.2.0"

if [ -z "$CC" ]; then
    export CC=gcc
fi
if [ -z "$AR" ]; then
    export AR=ar
fi

curl -LO "https://github.com/richgel999/miniz/releases/download/$VERSION/miniz-$VERSION.zip" \
    && unzip "miniz-$VERSION.zip" -d ./miniz/
$CC -c -o miniz/miniz.o miniz/miniz.c

$AR rc miniz/libminiz.a miniz/miniz.o


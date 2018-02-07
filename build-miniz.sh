#!/bin/sh

git submodule init
git submodule update

cd miniz && sh amalgamate.sh && cd ..

cc -c -std=c99 miniz/miniz.c -o miniz/miniz.o

ar rcu miniz/libminiz.a miniz/miniz.o

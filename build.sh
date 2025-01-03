#!/bin/bash
set -xe

OPTIONS="$( [[ $1 = 'release' ]] && echo '-o:speed' || echo '-debug' )"
OPTIONS="$OPTIONS -vet -vet-style -vet-semicolon"

COLLECTIONS="-collection:src=src"
# COLLECTIONS="-collection:libs=/home/ngoylufo/libs/odin $COLLECTIONS"

mkdir -p build
odin build src -out:build/json $COLLECTIONS $OPTIONS


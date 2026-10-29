#!/bin/sh
# Build script: data generation -> 64tass -> exomizer -> d64
set -e
cd "$(dirname "$0")"
nice python3 tools/gen.py >/dev/null
nice python3 tools/gensong.py
nice 64tass -C -a -B --cbm-prg -o build/raw.prg -L build/listing.txt --labels=build/labels.txt src/main.s
nice exomizer sfx sys -q -o ascension_vector.prg build/raw.prg
c1541 -format "ascension vector,av" d64 ascension_vector.d64 -write ascension_vector.prg "ascension vector" >/dev/null
ls -l ascension_vector.prg ascension_vector.d64

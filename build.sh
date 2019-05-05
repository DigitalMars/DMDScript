#!/bin/sh
BUILD=release # debug
for t in dmdscript:engine dmdscript:ds dmdscript:ds-ext
do
    dub build --build=$BUILD $t || exit 1
done
# rename both sample binaries
mv ./dmdscript_ds ./dmdscript
mv ./dmdscript_ds-ext ./dmdscript-ext

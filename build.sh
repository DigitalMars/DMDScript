#!/bin/sh
BUILD=release # debug
for t in dmdscript:engine dmdscript:ds dmdscript:ds-ext
do
    dub build --build=$BUILD $t || exit 1
done
# copy 2 sample binaries to the root folder
cp ds/dmdscript_ds ./dmdscript
cp ds-ext/dmdscript_ds-ext ./dmdscript-ext

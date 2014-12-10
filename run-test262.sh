#!/bin/sh
if ! [ -d test262 ] ; then
    git clone https://github.com/tc39/test262
fi
cd test262
tools/packaging/test262.py --summary --non_strict_only --command ../timed-dmdscript.sh > ../dmdscript-test262.log

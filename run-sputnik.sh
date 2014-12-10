#!/bin/sh
# runs older v3 test suite, this requires svn to checkout
if ! [ -d sputnik ] ; then
    svn checkout http://sputniktests.googlecode.com/svn/trunk/ sputnik
fi
cd sputnik
tools/sputnik.py --summary --command ../dmdscript > ../dmdscript-sputnik.log
# Find and display summary with percentage of failed/passed
grep -A 4 Summary ../dmdscript-sputnik.log 
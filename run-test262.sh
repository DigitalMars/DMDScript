#!/bin/sh
set -e

if ! [ -d test262 ] ; then
    echo "Cloning test262 test suite..."
    git clone https://github.com/tc39/test262.git
    echo "Applying patch to make the harness ES3/5 compatible..."
    sed 's/  let /  var /g' -i test262/harness/assert.js
fi
if ! [ -d test262-harness-py ] ; then
    echo "Cloning the console test runner..."
    git clone https://github.com/test262-utils/test262-harness-py.git
    echo "Applying patch to adjust the runner for the latest version of the test suite..."
    sed '/self\.suite\.GetInclude("cth\.js")/d' -i test262-harness-py/src/test262.py
fi

echo "Running the test suite..."
cd test262-harness-py
src/test262.py --summary --non_strict_only --command ../timed-dmdscript.sh --tests=../test262 > ../dmdscript-test262.log
cd ..

echo "Done."

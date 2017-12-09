#!/bin/bash
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
src/test262.py --summary --non_strict_only --command ../timed-dmdscript.sh --tests=../test262 | tee ../dmdscript-test262.log | grep '=== .* failed in .* ==='
cd ..

EXPECTED_TO_PASS=5238
PASSED=$(grep ' - Passed [0-9]* tests' dmdscript-test262.log | sed -n 's/.*Passed \([0-9]*\) tests.*/\1/;P')

if [ "$PASSED" -gt "$EXPECTED_TO_PASS" ]; then
	echo "The number of passed tests has increased ($PASSED vs. $EXPECTED_TO_PASS)."
	echo "EXPECTED_TO_PASS in run-test262.sh needs to be adjusted accordingly."
	exit 1
fi

if [ "$PASSED" -lt "$EXPECTED_TO_PASS" ]; then
	echo "The number of passed tests has decreased: $PASSED vs. $EXPECTED_TO_PASS"
	exit 2
fi

echo "Done."

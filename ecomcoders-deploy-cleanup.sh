#!/usr/bin/env bash
set -euo pipefail

NUMBER_OF_BUILDS_TO_KEEP=4


cd ..
BUILD_COUNT=$(ls -1 | sed -n '/build-/p' | wc -l | tr -d ' ')

if (( $BUILD_COUNT > $NUMBER_OF_BUILDS_TO_KEEP )); then
    echo "----------------------------------------------------"
    echo "Delete old builds..."
    OLD_BUILDS=$(ls -t | sed -n '/build-/p' | awk -v max=$NUMBER_OF_BUILDS_TO_KEEP 'NR > max' )
    rm -rf $OLD_BUILDS
    echo "----------------------------------------------------"
    echo "DONE: Delete old builds: $OLD_BUILDS"
else
    echo "----------------------------------------------------"
    echo "Delete old builds: nothing to delete"
fi
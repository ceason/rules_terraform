#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

echo "Listing '*.bzl' files:"
for f in $(find $BUILD_WORKSPACE_DIRECTORY -type f -name \*.bzl|sort -u); do
	package="/$(dirname "${f#$BUILD_WORKSPACE_DIRECTORY}")"
	echo "    \"$package:$(basename $f)\","
done
#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

source ${BUILD_WORKING_DIRECTORY:="."}/.rules_terraform/test_vars.sh

until response=$(curl -sSL "$SERVICE_URL"); do
	>&2 echo "Could not connect to server, waiting a bit.."
	sleep 2
done
if [ "$response" != "$EXPECTED_OUTPUT" ]; then
	>&2 echo "Response did not match expected output. Got '$response', expected '$EXPECTED_OUTPUT'"
	exit 1
else
	echo "Successfully received expected output '$EXPECTED_OUTPUT'"
fi
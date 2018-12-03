#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

: ${TMPDIR:=/tmp}
# find runfiles dir
if [[ -n "${TEST_SRCDIR-""}" && -d "$TEST_SRCDIR" ]]; then
  # use $TEST_SRCDIR if set.
  export RUNFILES="$TEST_SRCDIR"
elif [[ -z "${RUNFILES-""}" ]]; then
  # canonicalize the entrypoint.
  pushd "$(dirname "$0")" > /dev/null
  abs_entrypoint="$(pwd -P)/$(basename "$0")"
  popd > /dev/null
  if [[ -e "${abs_entrypoint}.runfiles" ]]; then
    # runfiles dir found alongside entrypoint.
    export RUNFILES="${abs_entrypoint}.runfiles"
  elif [[ "$abs_entrypoint" == *".runfiles/"* ]]; then
    # runfiles dir found in entrypoint path.
    export RUNFILES="${abs_entrypoint%%.runfiles/*}.runfiles"
  else
    >&2 echo "ERROR: Could not find runfiles directory."
    exit 1
  fi
fi
if [ -z "${PYTHON_RUNFILES-""}" ]; then
  export PYTHON_RUNFILES="$RUNFILES"
fi
tf_workspace_dir="%{tf_workspace_dir}"
terraform=$("%{render_workspace}" --symlink_plugins "$tf_workspace_dir")

_terraform_quiet(){
	local output=$(mktemp)
	chmod 600 $output
	if "$terraform" "$@" > "$output" 2>&1; then
		rm -rf $output
		return 0
	else
		>&2 cat $output
		rm -rf $output
		exit 1
	fi
}

_terraform_quiet init -input=false
exec "$terraform" "$@"
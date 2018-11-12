#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

: ${TMPDIR:=/tmp}
export RUNFILES=${RUNFILES-$(cd "$0.runfiles" && pwd)}
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
#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

# 'rules_k8s' needs to have PYTHON_RUNFILES set
export PYTHON_RUNFILES=${PYTHON_RUNFILES:=$(cd $0.runfiles && pwd)}
: ${TMPDIR:=/tmp}
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:=$TMPDIR/rules_terraform/plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

tf_workspace_dir="$BUILD_WORKSPACE_DIRECTORY/%{package}/%{tf_workspace_files_prefix}"
tfroot="$tf_workspace_dir/.terraform/tfroot"
plugin_dir="$tf_workspace_dir/.terraform/plugins"
render_tf="%{render_tf}"

_terraform_quiet(){
	local output=$(mktemp)
	chmod 600 $output
	if terraform "$@" > "$output" 2>&1; then
		rm -rf $output
		return 0
	else
		>&2 cat $output
		rm -rf $output
		exit 1
	fi
}

# figure out which command we are running (default to 'apply')
if [ $# -gt 0 ]; then
  command=$1; shift
else
  command="apply"
fi

case "$command" in
# these commands
# - don't rerender the tfroot/plugins dirs
destroy)
  cd "$tf_workspace_dir"
  exec terraform "$command" "$@" "$tfroot"
  ;;

# these commands
# - operate on an already existing state
# - don't take 'tfroot' as an arg
# - thus don't require rendering tfroot/plugin dirs
workspace|import|output|taint|untaint|state|debug)
  cd "$tf_workspace_dir"
  exec terraform "$command" "$@"
  ;;

# all other commands
# - render the tfroot/plugins dirs
# - initialize tf
*)
  rm -rf "$tfroot"
  "$render_tf" --output_dir "$tfroot" --plugin_dir "$plugin_dir" --symlink
  cd "$tf_workspace_dir"
  _terraform_quiet init -input=false "$tfroot"
  exec terraform "$command" "$@" "$tfroot"
  ;;

esac
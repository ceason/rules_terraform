#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

# register cleanup traps here, then execute them on EXIT!
ITS_A_TRAP=()
cleanup(){
	set +e # we want to keep executing cleanup hooks even if one fails
	local JOBS="$(jobs -rp)"
    if [ -n "${JOBS}" ]; then
       kill $JOBS
       wait $JOBS 2>/dev/null
    fi
    # walk the hooks in reverse order (run most recently registered first)
    for (( idx=${#ITS_A_TRAP[@]}-1 ; idx>=0 ; idx-- )) ; do
		local cmd="${ITS_A_TRAP[idx]}"
		(eval "$cmd")
	done
}
trap cleanup EXIT

render_tf="%{render_tf}"
stern="%{stern}"
SRCTEST="%{srctest}"
tf_workspace_files_prefix="%{tf_workspace_files_prefix}"
mkdir -p "$tf_workspace_files_prefix"

: ${TMPDIR:=/tmp}
: ${TF_PLUGIN_CACHE_DIR:=$TMPDIR/rules_terraform/plugin-cache}
export TF_PLUGIN_CACHE_DIR
mkdir -p "$TF_PLUGIN_CACHE_DIR"

# guess the kubeconfig location if it isn't already set
: ${KUBECONFIG:="/Users/$USER/.kube/config:/home/$USER/.kube/config"}
export KUBECONFIG

# render the tf to a tempdir
tfroot=$TEST_TMPDIR/tf/tfroot
tfplan=$TEST_TMPDIR/tf/tfplan
tfstate=$TEST_TMPDIR/tf/tfstate.json
rm -rf "$TEST_TMPDIR/tf"
mkdir -p "$TEST_TMPDIR/tf"
chmod 700 $(dirname "$tfstate")
"$render_tf" --output_dir "$tfroot" --plugin_dir "$tf_workspace_files_prefix/.terraform/plugins" --symlink_plugins

# init and validate terraform
pushd "$tf_workspace_files_prefix" > /dev/null
timeout 20 terraform init -input=false "$tfroot"
timeout 20 terraform validate "$tfroot"
timeout 20 terraform plan -out="$tfplan" -input=false "$tfroot"
popd > /dev/null

# tail stuff with stern in the background
$stern '.*' --tail 1 --color always &

# apply the terraform
ITS_A_TRAP+=("cd '$tf_workspace_files_prefix' && terraform destroy -state='$tfstate' -auto-approve -refresh=false")
pushd "$tf_workspace_files_prefix" > /dev/null
terraform apply -state-out="$tfstate" -auto-approve "$tfplan"
popd > /dev/null

# run the test & await its completion
#echo "pwd:$PWD"
# cat "$SRCTEST"
#JAVA_STUB_DEBUG='set -x' "$SRCTEST" "$@"
"$SRCTEST" "$@"

#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

export RUNFILES=${RUNFILES_DIR}
# guess the kubeconfig location if it isn't already set
: ${KUBECONFIG:="/Users/$USER/.kube/config:/home/$USER/.kube/config"}
export KUBECONFIG

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

render_workspace="%{render_workspace}"
stern="$PWD/%{stern}"
SRCTEST="%{srctest}"

# render the tf
terraform=$("$render_workspace" --symlink_plugins "$PWD/.rules_terraform")

# init and validate terraform
timeout 20 "$terraform" init -input=false
timeout 20 "$terraform" validate

# if the kubectl provider is used then create a namespace for the test
if [ "$(find .rules_terraform/.terraform/plugins/ -type f \( -name 'terraform-provider-kubernetes_*' -o -name 'terraform-provider-kubectl_*' \)|wc -l)" -gt 0 ]; then
	kubectl config view --merge --raw --flatten > "$TEST_TMPDIR/kubeconfig.yaml"
	ITS_A_TRAP+=("rm -rf '$TEST_TMPDIR/kubeconfig.yaml'")
	kube_context=$(kubectl config current-context)
	export KUBECONFIG="$TEST_TMPDIR/kubeconfig.yaml"
	test_namespace=$(mktemp --dry-run test-XXXXXXXXX|tr '[:upper:]' '[:lower:]')
	kubectl create namespace "$test_namespace"
	ITS_A_TRAP+=("kubectl delete namespace $test_namespace --wait=false")
	kubectl config set-context $kube_context --namespace=$test_namespace
	# tail stuff with stern in the background
	"$stern" '.*' --tail 1 --color always &
fi

# apply the terraform
ITS_A_TRAP+=("$terraform destroy -auto-approve -refresh=false")
"$terraform" apply -input=false -auto-approve

# run the test & await its completion
"$SRCTEST" "$@"

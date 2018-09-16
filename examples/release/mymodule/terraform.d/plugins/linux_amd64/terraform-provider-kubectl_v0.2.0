#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

scriptpath=$(cd "$(dirname "$0")" && pwd)
os_arch=$(basename $scriptpath)
version=$(basename $0|cut -d'_' -f2)
output_file=${TF_PLUGIN_CACHE_DIR:="$HOME/.terraform.d/plugin-cache"}/$os_arch/$(basename $0)
src_url=https://github.com/ceason/terraform-provider-kubectl/releases/download/${version}/terraform-provider-kubectl-${version}-${os_arch}

if [ ! -e "$output_file" ]; then
	tmpfile=$(mktemp)
	curl -sSLo "$tmpfile" "$src_url"
	chmod +x "$tmpfile"
	mkdir -p $(dirname "$output_file")
	mv "$tmpfile" "$output_file"
fi

exec "$output_file" <&0
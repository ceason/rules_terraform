#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

: ${TMPDIR:=/tmp}
: ${TF_PLUGIN_CACHE_DIR:=$TMPDIR/terraform-plugin-cache}
scriptpath=$(cd "$(dirname "$0")" && pwd)
os_arch=$(basename $scriptpath)
os=$(  cut -d'_' -f1 <<<"$os_arch")
arch=$(cut -d'_' -f2 <<<"$os_arch")
if [ "$os" == "windows" ]; then
	arch="$arch.exe"
fi
version=$(basename $0|cut -d'_' -f2)
output_file=${TF_PLUGIN_CACHE_DIR}/$os_arch/$(basename $0)
src_url=https://github.com/ceason/terraform-provider-kubectl/releases/download/${version}/terraform-provider-kubectl-${os}-${arch}

if [ ! -e "$output_file" ]; then
	tmpfile=$(mktemp)
	curl -sSLfo "$tmpfile" "$src_url"
	chmod +x "$tmpfile"
	mkdir -p $(dirname "$output_file")
	mv "$tmpfile" "$output_file"
fi

exec "$output_file" <&0
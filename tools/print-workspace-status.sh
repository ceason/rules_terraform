#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

: ${IMAGE_CHROOT:="registry.kube-system.svc.cluster.local:80"}

cat <<EOF
STABLE_IMAGE_CHROOT $IMAGE_CHROOT
EOF
#!/usr/bin/env bash
[ "$DEBUG" = "1" ] && set -x
set -euo pipefail
err_report() { echo "errexit on line $(caller)" >&2; }
trap err_report ERR

IMAGE_TAG=$(git describe --tags --always --dirty)

echo "
STABLE_IMAGE_CHROOT ${IMAGE_CHROOT-registry.kube-system.svc.cluster.local:80}
IMAGE_TAG $IMAGE_TAG
"
#!/usr/bin/env sh
set -eu

. ./scripts/load-env.sh

cluster_name="${CLUSTER_NAME:-kube-starter}"

kind delete cluster --name "$cluster_name"

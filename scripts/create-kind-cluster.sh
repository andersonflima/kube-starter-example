#!/usr/bin/env sh
set -eu

. ./scripts/load-env.sh

cluster_name="${CLUSTER_NAME:-kube-starter}"
kind_config="${KIND_CONFIG:-clusters/local/kind-config.yaml}"

if kind get clusters | grep -qx "$cluster_name"; then
  kubectl config use-context "kind-${cluster_name}"
else
  kind create cluster --name "$cluster_name" --config "$kind_config"
fi

kubectl wait --for=condition=Ready nodes --all --timeout=300s

#!/usr/bin/env sh
set -eu

. ./scripts/load-env.sh

cluster_name="${CLUSTER_NAME:-kube-starter}"
backend_image="${BACKEND_IMAGE:-kube-backend}"
frontend_image="${FRONTEND_IMAGE:-kube-frontend}"
image_tag="${IMAGE_TAG:-latest}"

kind load docker-image "${backend_image}:${image_tag}" --name "$cluster_name"
kind load docker-image "${frontend_image}:${image_tag}" --name "$cluster_name"

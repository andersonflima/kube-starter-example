#!/usr/bin/env sh
set -eu

. ./scripts/load-env.sh

backend_image="${BACKEND_IMAGE:-kube-backend}"
frontend_image="${FRONTEND_IMAGE:-kube-frontend}"
image_tag="${IMAGE_TAG:-latest}"

docker build -t "${backend_image}:${image_tag}" ./backend
docker build -t "${frontend_image}:${image_tag}" ./frontend

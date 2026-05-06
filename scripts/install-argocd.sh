#!/usr/bin/env sh
set -eu

. ./scripts/load-env.sh

argocd_version="${ARGOCD_VERSION:-stable}"
install_url="https://raw.githubusercontent.com/argoproj/argo-cd/${argocd_version}/manifests/install.yaml"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts -f "$install_url"
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=180s

kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-redis -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s

#!/usr/bin/env sh
set -eu

. ./scripts/load-env.sh

kubectl apply -f argocd/projects/kube-starter-project.yaml
kubectl apply -f argocd/root-application.yaml

kubectl get applications.argoproj.io -n argocd

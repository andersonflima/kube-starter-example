$ErrorActionPreference = "Stop"

& "$PSScriptRoot/load-env.ps1"

kubectl apply -f argocd/projects/kube-starter-project.yaml
kubectl apply -f argocd/root-application.yaml

kubectl get applications.argoproj.io -n argocd

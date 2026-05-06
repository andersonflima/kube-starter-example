$ErrorActionPreference = "Stop"

& "$PSScriptRoot/load-env.ps1"

kubectl get applications.argoproj.io -n argocd
kubectl get pods -n ingress-nginx
kubectl get pods -n monitoring
kubectl get pods,svc,hpa,ingress -n kube-starter

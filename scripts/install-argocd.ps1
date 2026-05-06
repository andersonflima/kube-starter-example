$ErrorActionPreference = "Stop"

& "$PSScriptRoot/load-env.ps1"

$argocdVersion = if ($env:ARGOCD_VERSION) { $env:ARGOCD_VERSION } else { "stable" }
$installUrl = "https://raw.githubusercontent.com/argoproj/argo-cd/$argocdVersion/manifests/install.yaml"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts -f $installUrl
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=180s

kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-redis -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s

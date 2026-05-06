$ErrorActionPreference = "Stop"

& "$PSScriptRoot/load-env.ps1"

& "$PSScriptRoot/check-tools.ps1"
& "$PSScriptRoot/build-images.ps1"
& "$PSScriptRoot/create-kind-cluster.ps1"
& "$PSScriptRoot/load-kind-images.ps1"
& "$PSScriptRoot/install-argocd.ps1"
& "$PSScriptRoot/bootstrap-platform.ps1"

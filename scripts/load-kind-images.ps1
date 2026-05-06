$ErrorActionPreference = "Stop"

& "$PSScriptRoot/load-env.ps1"

$clusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "kube-starter" }
$backendImage = if ($env:BACKEND_IMAGE) { $env:BACKEND_IMAGE } else { "kube-backend" }
$frontendImage = if ($env:FRONTEND_IMAGE) { $env:FRONTEND_IMAGE } else { "kube-frontend" }
$imageTag = if ($env:IMAGE_TAG) { $env:IMAGE_TAG } else { "latest" }

kind load docker-image "${backendImage}:${imageTag}" --name $clusterName
kind load docker-image "${frontendImage}:${imageTag}" --name $clusterName

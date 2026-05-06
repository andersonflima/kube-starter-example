$ErrorActionPreference = "Stop"

& "$PSScriptRoot/load-env.ps1"

$backendImage = if ($env:BACKEND_IMAGE) { $env:BACKEND_IMAGE } else { "kube-backend" }
$frontendImage = if ($env:FRONTEND_IMAGE) { $env:FRONTEND_IMAGE } else { "kube-frontend" }
$imageTag = if ($env:IMAGE_TAG) { $env:IMAGE_TAG } else { "latest" }

docker build -t "${backendImage}:${imageTag}" ./backend
docker build -t "${frontendImage}:${imageTag}" ./frontend

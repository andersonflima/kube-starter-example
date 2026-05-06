$ErrorActionPreference = "Stop"

& "$PSScriptRoot/load-env.ps1"

$clusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "kube-starter" }

kind delete cluster --name $clusterName

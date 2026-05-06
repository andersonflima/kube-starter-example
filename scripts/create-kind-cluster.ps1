$ErrorActionPreference = "Stop"

& "$PSScriptRoot/load-env.ps1"

$clusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "kube-starter" }
$kindConfig = if ($env:KIND_CONFIG) { $env:KIND_CONFIG } else { "clusters/local/kind-config.yaml" }
$clusters = kind get clusters

if ($clusters -contains $clusterName) {
  kubectl config use-context "kind-$clusterName"
} else {
  kind create cluster --name $clusterName --config $kindConfig
}

kubectl wait --for=condition=Ready nodes --all --timeout=300s

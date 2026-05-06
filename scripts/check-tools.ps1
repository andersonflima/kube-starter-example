$ErrorActionPreference = "Stop"

& "$PSScriptRoot/load-env.ps1"

$requiredTools = @("docker", "kind", "kubectl", "helm", "npm", "curl")
$missingTools = @()

foreach ($tool in $requiredTools) {
  if (Get-Command $tool -ErrorAction SilentlyContinue) {
    Write-Host "ok: $tool"
  } else {
    Write-Host "missing: $tool"
    $missingTools += $tool
  }
}

if ($missingTools.Count -gt 0) {
  throw "Instale as ferramentas ausentes antes de continuar: $($missingTools -join ', ')"
}

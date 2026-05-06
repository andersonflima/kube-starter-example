$ErrorActionPreference = "Stop"

& "$PSScriptRoot/load-env.ps1"

$attempts = if ($env:SMOKE_ATTEMPTS) { [int]$env:SMOKE_ATTEMPTS } else { 24 }
$sleepSeconds = if ($env:SMOKE_SLEEP_SECONDS) { [int]$env:SMOKE_SLEEP_SECONDS } else { 5 }

function Invoke-RequestWithRetry {
  param([string]$Url)

  foreach ($attempt in 1..$attempts) {
    try {
      Invoke-WebRequest -UseBasicParsing -Uri $Url | Out-Null
      Write-Host "ok: $Url"
      return
    } catch {
      Write-Host "waiting: $Url ($attempt/$attempts)"
      Start-Sleep -Seconds $sleepSeconds
    }
  }

  throw "failed: $Url"
}

Invoke-RequestWithRetry "http://kube-starter.localhost:8080/api/health"
Invoke-RequestWithRetry "http://kube-starter.localhost:8080/api/stats"
Invoke-RequestWithRetry "http://grafana.localhost:8080/login"
Invoke-RequestWithRetry "http://prometheus.localhost:8080/-/ready"

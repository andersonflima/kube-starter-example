$envFile = Join-Path (Split-Path -Parent $PSScriptRoot) ".env"

if (Test-Path $envFile) {
  foreach ($rawLine in Get-Content $envFile) {
    $line = $rawLine.Trim()

    if ($line.Length -eq 0 -or $line.StartsWith("#")) {
      continue
    }

    $parts = $line.Split("=", 2)

    if ($parts.Count -ne 2) {
      continue
    }

    $name = $parts[0].Trim()
    $value = $parts[1].Trim()

    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      $value = $value.Substring(1, $value.Length - 2)
    }

    if (-not [Environment]::GetEnvironmentVariable($name, "Process")) {
      [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
  }
}

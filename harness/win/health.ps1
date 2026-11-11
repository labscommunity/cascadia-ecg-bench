# Poll an OpenAI-compatible endpoint until /v1/models answers (or timeout). usage: -Base http://127.0.0.1:8130 -TimeoutSec 900
param([string]$Base = "http://127.0.0.1:8130", [int]$TimeoutSec = 900, [string]$Token = "dev-token")
$t0 = Get-Date
while (((Get-Date) - $t0).TotalSeconds -lt $TimeoutSec) {
  try { $r = Invoke-RestMethod -Uri "$Base/v1/models" -Headers @{ Authorization = "Bearer $Token" } -TimeoutSec 10; "HEALTHY after " + [int]((Get-Date) - $t0).TotalSeconds + "s model=" + $r.data[0].id; exit 0 } catch { Start-Sleep -Seconds 5 }
}
"TIMEOUT after $TimeoutSec s"; exit 1

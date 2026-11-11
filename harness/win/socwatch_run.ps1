# Run Intel SoC Watch for N seconds and reduce the CSV summary to JSON.
# usage: powershell -File socwatch_run.ps1 -Seconds 60 -Prefix C:\ecgbench\results\x.sw [-Features "power,ddr-bw,gfx-cstate,cpu-pstate"]
param([int]$Seconds = 60, [string]$Prefix, [string]$Features = "power,ddr-bw,gfx-cstate,cpu-pstate", [string]$Exe = "C:\ecgbench\socwatch\64\socwatch.exe")
$ErrorActionPreference = 'Continue'
$fargs = @(); foreach ($f in $Features.Split(',')) { $fargs += @('-f', $f.Trim()) }
$t0 = Get-Date
& $Exe @fargs -t $Seconds -n 100 -o $Prefix 2>&1 | Select-String -Pattern "Started|written|rror" | ForEach-Object { "SW: " + $_ }
$csv = "$Prefix.csv"
if (-not (Test-Path $csv)) { Write-Output ('{"error":"no csv","prefix":"' + $Prefix + '"}'); exit 1 }
$lines = Get-Content $csv
$res = [ordered]@{ seconds = $Seconds; started = $t0.ToString('o'); host = $env:COMPUTERNAME; features = $Features }
$section = ''
foreach ($l in $lines) {
  if ($l -match '^Collection duration \(sec\): ([\d.]+)') { $res.duration_s = [double]$matches[1] }
  if ($l -match '^Package Power Summary: Average Rate') { $section = 'pkgpwr'; continue }
  if ($l -match '^NPU Power Summary' ) { $section = 'npupwr'; continue }
  if ($l -match '^DDR Bandwidth Requests by Component Summary: Average Rate') { $section = 'ddr'; continue }
  if ($l -match '^GFX C-State Summary|^Graphics C-State Summary|^iGFX C-State') { $section = 'gfxc'; continue }
  if ($l -match '^Core P-State|^CPU P-State') { $section = 'pstate'; continue }
  if ($l -match '^=+$' -or $l -match '^\s*$') { continue }
  if ($section -eq 'pkgpwr' -and $l -match '^CPU/Package_0\s*,\s*Power\s*,\s*([\d.]+)\s*,\s*([\d.]+)') { $res.pkg_power_mw_avg = [double]$matches[1]; $res.pkg_energy_mj = [double]$matches[2]; $section = '' }
  if ($section -eq 'npupwr' -and $l -match '^\s*NPU[^,]*,\s*Power\s*,\s*([\d.]+)') { $res.npu_power_mw_avg = [double]$matches[1]; $section = '' }
  if ($section -eq 'ddr' -and $l -match '^DDR\s*,\s*(MC\d-CH\d-SUBCH\d)-(READS|WRITES)\s*,\s*([\d.]+)\s*,\s*([\d.]+)') {
    $k = 'ddr_' + $matches[2].ToLower() + '_mb_s'; if (-not $res.Contains($k)) { $res[$k] = 0.0 }; $res[$k] += [double]$matches[3]
  }
  if ($section -eq 'gfxc' -and $l -match '^(RC0|RC6|RC0\s*\(Active\))\s*,\s*([\d.]+)') { $res['gfx_' + ($matches[1] -replace '[^A-Za-z0-9]','') + '_pct'] = [double]$matches[2] }
}
if ($res.Contains('ddr_reads_mb_s') -and $res.Contains('ddr_writes_mb_s')) { $res.ddr_total_gb_s = [math]::Round(($res.ddr_reads_mb_s + $res.ddr_writes_mb_s) / 1024, 2) }
$res | ConvertTo-Json -Compress
($res | ConvertTo-Json -Compress) | Out-File -Encoding utf8 "$Prefix.json"

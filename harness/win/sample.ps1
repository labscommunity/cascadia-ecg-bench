# Windows utilization sampler -> JSONL (1 line per interval).
# CPU %, memory (available/committed), GPU engine utilization by engine type (3d/compute/copy/neural=NPU),
# GPU adapter shared/dedicated memory, working set + private bytes of cascadia*/ovms* processes.
# usage: powershell -File sample.ps1 -Out C:\ecgbench\results\x.util.jsonl -Seconds 120 [-Interval 1]
param([string]$Out, [int]$Seconds = 120, [double]$Interval = 1.0, [string]$ProcMatch = "cascadia|ovms|python")
$ErrorActionPreference = 'SilentlyContinue'
$paths = @('\Processor Information(_Total)\% Processor Utility', '\Processor Information(_Total)\% Processor Time',
           '\Memory\Available MBytes', '\Memory\Committed Bytes',
           '\GPU Engine(*)\Utilization Percentage',
           '\GPU Adapter Memory(*)\Shared Usage', '\GPU Adapter Memory(*)\Dedicated Usage')
$tEnd = (Get-Date).AddSeconds($Seconds)
$hostname = $env:COMPUTERNAME
while ((Get-Date) -lt $tEnd) {
  $t0 = Get-Date
  $s = Get-Counter -Counter $paths -SampleInterval 1 -MaxSamples 1
  $rec = [ordered]@{ ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0; host = $hostname }
  $eng = @{}
  $gpuShared = 0.0; $gpuDed = 0.0
  foreach ($c in $s.CounterSamples) {
    $p = $c.Path
    if ($p -like '*% Processor Utility*') { $rec.cpu_util_pct = [math]::Round($c.CookedValue, 1) }
    elseif ($p -like '*% Processor Time*') { $rec.cpu_time_pct = [math]::Round($c.CookedValue, 1) }
    elseif ($p -like '*Available MBytes*') { $rec.mem_avail_mb = [math]::Round($c.CookedValue) }
    elseif ($p -like '*Committed Bytes*') { $rec.mem_committed_mb = [math]::Round($c.CookedValue / 1MB) }
    elseif ($p -like '*GPU Engine*') {
      $et = ($c.InstanceName -split '_engtype_')[1]; if (-not $et) { $et = 'other' }
      if (-not $eng.ContainsKey($et)) { $eng[$et] = 0.0 }
      $eng[$et] += $c.CookedValue
    }
    elseif ($p -like '*GPU Adapter Memory*Shared Usage*') { $gpuShared += $c.CookedValue }
    elseif ($p -like '*GPU Adapter Memory*Dedicated Usage*') { $gpuDed += $c.CookedValue }
  }
  foreach ($k in $eng.Keys) { $rec["gpu_$k`_pct"] = [math]::Round($eng[$k], 1) }
  $rec.gpu_shared_mb = [math]::Round($gpuShared / 1MB); $rec.gpu_dedicated_mb = [math]::Round($gpuDed / 1MB)
  $procs = Get-Process | Where-Object { $_.ProcessName -match $ProcMatch }
  $rec.proc_ws_mb = [math]::Round((($procs | Measure-Object WorkingSet64 -Sum).Sum) / 1MB)
  $rec.proc_private_mb = [math]::Round((($procs | Measure-Object PrivateMemorySize64 -Sum).Sum) / 1MB)
  $rec.procs = ($procs | ForEach-Object { $_.ProcessName + ':' + [math]::Round($_.WorkingSet64 / 1MB) }) -join ','
  ($rec | ConvertTo-Json -Compress) | Out-File -Append -Encoding utf8 $Out
  $dt = ((Get-Date) - $t0).TotalSeconds
  if ($dt -lt $Interval) { Start-Sleep -Milliseconds ([int](($Interval - $dt) * 1000)) }
}

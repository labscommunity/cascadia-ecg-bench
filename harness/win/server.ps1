# Launch a cascadia runtime server (whole-model or one pipeline rank) detached, High priority, with a log.
# usage: server.ps1 -Mode run   -Model C:\m -Engine ov-genai -Device GPU -Api :8130 -Log C:\ecgbench\logs\x.log [-Extra "--cb"]
#        server.ps1 -Mode worker -Model C:\tree -Engine qwen35 -Device GPU -Rank 1 -Total 3 -Listen :9100 [-Next host:9100] [-Api :8130] -Log ...
param([string]$Mode = "run", [string]$Model, [string]$Engine = "ov-genai", [string]$Device = "GPU", [string]$Api = "",
      [int]$Rank = -1, [int]$Total = 0, [string]$Listen = "", [string]$Next = "", [string]$Extra = "", [string]$Log,
      [string]$CacheDir = "C:\ecgbench\ovcache", [string]$Priority = "High", [string]$Exe = "", [string]$Env = "")
$exe = if ($Exe) { $Exe } elseif ($env:CASCADIA_EXE) { $env:CASCADIA_EXE } else { (Get-ChildItem C:\ecgbench\rt -Recurse -Filter cascadia.exe | Select-Object -First 1).FullName }
"EXE=" + $exe
New-Item -ItemType Directory -Force -Path (Split-Path $Log) | Out-Null
if ($CacheDir -and $CacheDir -ne 'none') { New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null }
if ($Mode -eq "run") {
  $cmd = '"' + $exe + '" run "' + $Model + '" --engine ' + $Engine + ' --device "' + $Device + '" --api ' + $Api + ' ' + $Extra
} else {
  $cmd = '"' + $exe + '" worker --rank ' + $Rank + ' --total ' + $Total + ' --model "' + $Model + '" --engine ' + $Engine + ' --device "' + $Device + '"'
  if ($CacheDir -and $CacheDir -ne 'none') { $cmd += ' --ov-cache-dir "' + $CacheDir + '" ' } else { $cmd += ' --ov-cache-dir "" ' }
  if ($Listen) { $cmd += ' --listen ' + $Listen }
  if ($Next) { $cmd += ' --next ' + $Next }
  if ($Api) { $cmd += ' --api ' + $Api }
  $cmd += ' ' + $Extra
}
"CMD=" + $cmd
$envPrefix = ''; if ($Env) { foreach ($kv in $Env.Split(';')) { if ($kv) { $envPrefix += 'set ' + $kv + '&& ' } } }
$cl = 'cmd /c "' + $envPrefix + $cmd + ' > ' + $Log + ' 2>&1"'
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cl; CurrentDirectory = "C:\ecgbench" }
Start-Sleep -Seconds 3
$child = Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $r.ProcessId -and $_.Name -eq "cascadia.exe" } | Select-Object -First 1
if ($child) { try { (Get-Process -Id $child.ProcessId).PriorityClass = $Priority } catch {} }
"LAUNCH rc=" + $r.ReturnValue + " cmdpid=" + $r.ProcessId + " childpid=" + $(if ($child) { $child.ProcessId } else { 0 })

# Terminate processes by name match (WMI Terminate works on SSH/Task-Scheduler spawned children).
# usage: powershell -File stop.ps1 -Match "cascadia.exe" [-CmdLike "*--rank 0*"]
param([string]$Match = "cascadia", [string]$CmdLike = "*")
$n = 0
Get-CimInstance Win32_Process | Where-Object { $_.Name -match $Match -and $_.CommandLine -like $CmdLike } | ForEach-Object {
  $r = Invoke-CimMethod -InputObject $_ -MethodName Terminate; $n++; "terminated " + $_.Name + " pid=" + $_.ProcessId + " rc=" + $r.ReturnValue }
"STOPPED n=$n"

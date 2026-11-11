# Launch a detached command (survives SSH logout) with stdout/stderr to a log; prints the pid.
# usage: powershell -File launch.ps1 -Cmd '"C:\ecgbench\rt\cascadia.exe" run C:\m --engine ov-genai --api :8130' -Log C:\ecgbench\logs\x.log [-Cwd C:\ecgbench] [-Priority High]
param([string]$Cmd, [string]$Log, [string]$Cwd = "C:\ecgbench", [string]$Priority = "High")
$cl = 'cmd /c "' + $Cmd + ' > ' + $Log + ' 2>&1"'
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cl; CurrentDirectory = $Cwd }
Start-Sleep -Seconds 2
# find the real child (cascadia.exe) under the cmd and raise priority
$child = Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $r.ProcessId } | Select-Object -First 1
if ($child -and $Priority) { try { (Get-Process -Id $child.ProcessId).PriorityClass = $Priority } catch {} }
"LAUNCH rc=" + $r.ReturnValue + " cmdpid=" + $r.ProcessId + " childpid=" + $(if ($child) { $child.ProcessId } else { 0 })

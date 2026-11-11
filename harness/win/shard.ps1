# Cut a Qwen3.5-family int4 IR into an N-stage surgery tree with `cascadia shard` (runs the bundled exporter on the venv python).
# usage: shard.ps1 -Model C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov -Out C:\ecgbench\shards\q36-2stage -Stages 2 [-LayerSplit "20"] -Log C:\ecgbench\logs\shard2.log
param([string]$Model, [string]$Out, [int]$Stages, [string]$LayerSplit = "", [string]$Log, [string]$Py = "C:\ecgbench\venv\Scripts\python.exe")
$exe = (Get-ChildItem C:\ecgbench\rt -Recurse -Filter cascadia.exe | Select-Object -First 1).FullName
$cmd = '"' + $exe + '" shard --model "' + $Model + '" -o "' + $Out + '" --num-stages ' + $Stages + ' --python "' + $Py + '" --skip-check'
if ($LayerSplit) { $cmd += ' --layer-split ' + $LayerSplit }
"CMD=" + $cmd
$cl = 'cmd /c "' + $cmd + ' > ' + $Log + ' 2>&1"'
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cl; CurrentDirectory = "C:\ecgbench" }
"LAUNCH rc=" + $r.ReturnValue + " pid=" + $r.ProcessId

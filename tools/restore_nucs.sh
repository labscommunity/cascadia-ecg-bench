#!/bin/bash
# Restore the NUCs after the 35B runs: honyaku ranks (beta first, then alpha), watchdog tasks, Acrow on charlie.
cd "$(dirname "$0")"
[ -f /tmp/restore_nucs.done ] && { echo "restore already done"; exit 0; }
while pgrep -f "run_chain.sh|run_eval.sh alpha|run_config.sh alpha|run_config.sh charlie" >/dev/null; do sleep 30; done
cat > /tmp/restore_beta.ps1 <<'PS'
& 'C:\ecgbench\harness\win\stop.ps1' -Match 'cascadia.exe' | Select -Last 1
Enable-ScheduledTask -TaskName honyaku-watchdog | Out-Null; Enable-ScheduledTask -TaskName cascadia-watchdog | Out-Null
"TASKS honyaku-watchdog=" + (Get-ScheduledTask honyaku-watchdog).State + " cascadia-watchdog=" + (Get-ScheduledTask cascadia-watchdog).State
& powershell -NoProfile -ExecutionPolicy Bypass -File C:\cascadia-honyaku\ranks.ps1 start
PS
cat > /tmp/restore_alpha.ps1 <<'PS'
& 'C:\ecgbench\harness\win\stop.ps1' -Match 'cascadia.exe' | Select -Last 1
Enable-ScheduledTask -TaskName honyaku-watchdog | Out-Null; Enable-ScheduledTask -TaskName cascadia-watchdog | Out-Null
"TASKS honyaku-watchdog=" + (Get-ScheduledTask honyaku-watchdog).State + " cascadia-watchdog=" + (Get-ScheduledTask cascadia-watchdog).State
& powershell -NoProfile -ExecutionPolicy Bypass -File C:\cascadia-honyaku\ranks.ps1 start
PS
cat > /tmp/restore_charlie.ps1 <<'PS'
& 'C:\ecgbench\harness\win\stop.ps1' -Match 'cascadia.exe' | Select -Last 1
Start-ScheduledTask -TaskName cascadia-acrow-node
Start-Sleep -Seconds 20
"ACROW task=" + (Get-ScheduledTask cascadia-acrow-node).State
Get-CimInstance Win32_Process | ? { $_.Name -match "cascadia-node-acrow|ovms" } | % { "PROC=" + $_.Name + " pid=" + $_.ProcessId }
PS
echo "[$(date +%H:%M:%S)] restoring beta (r2, r1)"; ./wps.sh beta /tmp/restore_beta.ps1
echo "[$(date +%H:%M:%S)] restoring alpha (r0)"; ./wps.sh alpha /tmp/restore_alpha.ps1
echo "[$(date +%H:%M:%S)] restoring charlie (acrow)"; ./wps.sh charlie /tmp/restore_charlie.ps1
sleep 90
printf 'Get-CimInstance Win32_Process | ? { $_.Name -match "cascadia-node|ovms" } | %% { "PROC=" + $_.Name + " ws=" + [math]::Round($_.WorkingSetSize/1MB) + "MB" }\n' > /tmp/chk.ps1
for h in alpha beta charlie; do echo "== $h"; ./wps.sh $h /tmp/chk.ps1; done
# honyaku chain health probe (alpha gateway :19410) — same request the watchdog uses
printf '$token=(Get-Content C:\\cascadia-honyaku\\partner-linku.token -Raw).Trim(); try { $r = Invoke-RestMethod -Method Post -Uri http://127.0.0.1:19410/v1/chat/completions -Headers @{Authorization="Bearer $token"} -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes(%s)) -TimeoutSec 300; "HONYAKU_OK: " + $r.choices[0].message.content } catch { "HONYAKU_PROBE_FAIL: " + $_.Exception.Message }\n' "'{\"model\":\"gemma-4-31b-honyaku\",\"max_tokens\":4,\"temperature\":0,\"messages\":[{\"role\":\"user\",\"content\":\"[b1] (speech) hai\"}]}'" > /tmp/hprobe.ps1
sleep 120; echo "[$(date +%H:%M:%S)] honyaku probe:"; ./wps.sh alpha /tmp/hprobe.ps1
echo "[$(date +%H:%M:%S)] NUC restore done"; touch /tmp/restore_nucs.done

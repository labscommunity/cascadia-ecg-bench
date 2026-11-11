#!/bin/bash
# usage: wbg.sh <host> <logfile-win-path> <cmdline...>  -- launch detached via WMI (survives ssh exit); prints pid
source "$(dirname "$0")/hosts.sh"
h=$1; log=$2; shift 2; cmd="$*"
tmp=$(mktemp)
cat > "$tmp" <<PS
\$cl = 'cmd /c "' + '$cmd' + ' > $log 2>&1"'
\$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine=\$cl}
"LAUNCH rc=" + \$r.ReturnValue + " pid=" + \$r.ProcessId
PS
"$(dirname "$0")/wps.sh" "$h" "$tmp"; rm -f "$tmp"

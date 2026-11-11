#!/bin/bash
# usage: wps.sh <host> <script.ps1>  -- run a PowerShell script file remotely (encoded), strip CLIXML noise
source "$(dirname "$0")/hosts.sh"
h=$1; f=$2
ENC=$(iconv -f UTF-8 -t UTF-16LE "$f" | base64 | tr -d '\n')
ssh "${SSHOPTS[@]}" $(target "$h") "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $ENC" 2>&1 | grep -v -e '^#< CLIXML' -e '^<Objs'

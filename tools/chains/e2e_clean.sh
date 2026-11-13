#!/bin/bash
# e2e for the clean branch build (C:\ecgbench\rt\clean on tate-07): deploy to the NUCs, doctor, 122B 3-NUC chain with
# --gpu-keepalive-ms 2 (full protocol + GSM8K-20), then without keep-alive (quick), then restore honyaku/acrow.
cd "$(dirname "$0")"; source ./hosts.sh
log(){ echo "[$(date +%H:%M:%S)] [e2e] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
R=/Users/tatef/Workspaces/cascadia-ecg-bench/results; P=../probe
SO=(-o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null)
log "fetch the clean exe from tate-07"
scp -q "${SO[@]}" cascadia-tate-07-ts:C:/ecgbench/rt/clean/cascadia.exe $P/cascadia-clean.exe || { log "FETCH FAILED"; exit 1; }
want=$(shasum -a 256 $P/cascadia-clean.exe | cut -c1-16); log "clean exe sha=$want size=$(stat -f %z $P/cascadia-clean.exe)"
for h in alpha beta charlie; do
  ps $h "New-Item -ItemType Directory -Force -Path C:\ecgbench\rt\clean | Out-Null; robocopy C:\ecgbench\rt\spec C:\ecgbench\rt\clean *.dll /NJH /NJS /NDL /NFL | Out-Null; 'dlls=' + (Get-ChildItem C:\ecgbench\rt\clean -Filter *.dll).Count" | tail -1 | sed "s/^/$h: /"
  scp -q "${SO[@]}" $P/cascadia-clean.exe "$(target $h | awk '{print $NF}'):C:/ecgbench/rt/clean/cascadia.exe"
  ps $h "'exe sha=' + (Get-FileHash C:\ecgbench\rt\clean\cascadia.exe).Hash.Substring(0,16).ToLower() + ' version=' + (& C:\ecgbench\rt\clean\cascadia.exe --version 2>&1 | Select -First 1)" | tail -1 | sed "s/^/$h: /"
done
log "doctor on alpha (new exe)"
ps alpha "& C:\ecgbench\rt\clean\cascadia.exe doctor 2>&1 | Out-String -Width 200" | grep -iE "gpu|budget|wddm|segment|memory|device" | head -12 | tee $P/e2e_doctor_alpha.txt
log "pause honyaku + acrow"; ./pause_nucs.sh
export EXE='C:\ecgbench\rt\clean\cascadia.exe' HEALTH_TIMEOUT=1500 TREE='C:\ecgbench\shards\q122-sym-3' HOSTS="alpha beta charlie" IPS="192.168.0.101 192.168.0.103 192.168.0.188" MODEL_TAG=q35-122b
log "== D4k: keep-alive 2 ms (flag), full protocol + GSM8K-20"
REPEATS=3 EXTRA="--gpu-keepalive-ms 2" ENVS="CASCADIA_QWEN36_PROFILE=1;RUST_LOG=info" EVAL_TOKENS=400 EVAL_N=20 EVAL_WAIT_MIN=60 TAGS="config=D4k-122b-3stage-3nuc-clean-keepalive2 model=q35-122b stages=3 build=clean" ./run_chain.sh D4k-122b-3stage-3nuc-clean-keepalive2 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench|rror|eval|correct|done" | cut -c1-220
sleep 20
log "== K9: no keep-alive (quick)"
QUICK=1 REPEATS=2 ENVS="CASCADIA_QWEN36_PROFILE=1;RUST_LOG=info" TAGS="config=K9-122b-3nuc-clean-nokeepalive model=q35-122b stages=3 build=clean" ./run_chain.sh K9-122b-3nuc-clean-nokeepalive 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench|rror|done" | cut -c1-220
log "restore honyaku + acrow"; rm -f /tmp/restore_nucs.done; ./restore_nucs.sh > $P/restore_e2e.out 2>&1; grep -E "HONYAKU|ACROW|PROC=" $P/restore_e2e.out | tail -6
python3 - <<'PY'
import json,statistics as st,os
R='/Users/tatef/Workspaces/cascadia-ecg-bench/results'
def med(lab):
    try: r=[json.loads(l) for l in open(f'{R}/{lab}/bench.jsonl')]
    except Exception as e: return f'n/a ({e})'
    out={}
    for pid in ('short','medium','long'):
        v=[x['decode_tok_s'] for x in r if x.get('kind')=='bench' and x.get('prompt_id')==pid and x.get('decode_tok_s')]
        t=[x['ttft_s'] for x in r if x.get('kind')=='bench' and x.get('prompt_id')==pid and x.get('ttft_s')]
        out[pid]=(round(st.median(v),2) if v else None, round(st.median(t),2) if t else None)
    return out
def parity(lab):
    try: return {j['prompt_id']:j.get('text','') for j in map(json.loads,open(f'{R}/{lab}/parity.jsonl'))}
    except Exception: return {}
for lab in ('D4k-122b-3stage-3nuc-clean-keepalive2','K9-122b-3nuc-clean-nokeepalive','D3k-122b-3stage-3nuc-keepalive','D3b-122b-3stage-3nuc-commit85'):
    print(lab, med(lab))
a=parity('D4k-122b-3stage-3nuc-clean-keepalive2'); b=parity('D3k-122b-3stage-3nuc-keepalive'); c=parity('D3b-122b-3stage-3nuc-commit85'); d=parity('K9-122b-3nuc-clean-nokeepalive')
print('parity D4k vs D3k:', sum(a.get(k)==b.get(k) for k in a), '/', len(a), '| vs D3b:', sum(a.get(k)==c.get(k) for k in a), '/', len(a), '| K9 vs D4k:', sum(d.get(k)==a.get(k) for k in d), '/', len(d))
ev=f'{R}/D4k-122b-3stage-3nuc-clean-keepalive2-eval'
if os.path.isdir(ev):
    for f in os.listdir(ev):
        if f.endswith('summary.json') or f=='STATUS': print(f, open(f'{ev}/{f}').read()[:300])
PY
echo "E2E_CLEAN_DONE" | tee $P/e2e_clean.done

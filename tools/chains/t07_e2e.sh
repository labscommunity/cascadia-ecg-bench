#!/bin/bash
# tate-07 functional e2e for the clean build: whole-model prompt lookup (repeated prompts must not trip the GenAI prefix-cache
# assertion), single-box staged 35B (qwen35 engine, --total 1), doctor. The enterprise service stays up (64 GB box).
cd "$(dirname "$0")"; source ./hosts.sh
log(){ echo "[$(date +%H:%M:%S)] [t07e2e] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
HZ='C:\ecgbench\harness'; EXE='C:\ecgbench\rt\clean\cascadia.exe'; P=../probe
log "doctor (new exe)"; ps tate07 "& $EXE doctor 2>&1 | Out-String -Width 200" | grep -iE "gpu|budget|wddm|segment|memory|device" | head -12 | tee $P/e2e_doctor_tate07.txt
run(){ local label=$1 model=$2 extra=$3 eng=${4:-ov-genai}; local RW="C:\\ecgbench\\results\\$label"
  log "== $label model=$model engine=$eng extra='$extra'"
  ps tate07 "& '$HZ\\win\\stop.ps1' -Match 'cascadia.exe' | Select -Last 1" >/dev/null
  ps tate07 "New-Item -ItemType Directory -Force -Path '$RW' | Out-Null; & '$HZ\\win\\server.ps1' -Exe '$EXE' -Env 'RUST_LOG=info' -Mode worker -Model '$model' -Engine $eng -Device GPU -Rank 0 -Total 1 -Api ':8130' -CacheDir none -Extra '$extra' -Log '$RW\\server.log'" | tail -1
  NOLAUNCH=1 QUICK=1 REPEATS=2 HEALTH_TIMEOUT=900 TAGS="config=$label host=tate07 model=q36-35b build=clean" ./run_config.sh tate07 "$label" 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench|rror" | cut -c1-200
}
OFF='C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov'
run S1q-tate07-35b-clean-prompt-lookup3-k5 "$OFF" "--prompt-lookup 3 --spec-k 5"
run S0q-tate07-35b-clean-worker-base "$OFF" ""
run S7q-tate07-35b-clean-staged3-base 'C:\ecgbench\shards\q36-3stage' "--prefix-cache-gb 0" qwen35
ps tate07 "& '$HZ\\win\\stop.ps1' -Match 'cascadia.exe' | Select -Last 1; 'svc=' + (Get-Service cascadia-node).Status" | tail -2
python3 - <<'PY'
import json,statistics as st
R='/Users/tatef/Workspaces/cascadia-ecg-bench/results'
def rows(lab):
    try: return [json.loads(l) for l in open(f'{R}/{lab}/bench.jsonl')]
    except Exception as e: return []
def parity(lab):
    try: return {j['prompt_id']:j.get('text','') for j in map(json.loads,open(f'{R}/{lab}/parity.jsonl'))}
    except Exception: return {}
for lab in ('S1q-tate07-35b-clean-prompt-lookup3-k5','S0q-tate07-35b-clean-worker-base','S7q-tate07-35b-clean-staged3-base'):
    r=rows(lab); b=[x for x in r if x.get('kind')=='bench']
    ok=sum(1 for x in b if x.get('status')==200); med=[x['decode_tok_s'] for x in b if x.get('prompt_id')=='medium' and x.get('decode_tok_s')]
    print(lab, 'bench requests ok', ok, '/', len(b), 'medium decode', round(st.median(med),1) if med else None, 'errors:', [x.get('error') for x in b if x.get('status')!=200][:2])
a=parity('S1q-tate07-35b-clean-prompt-lookup3-k5'); base=parity('S0q-tate07-35b-clean-worker-base'); ref=parity('A1b-tate07-whole-gpu'); st3=parity('S7q-tate07-35b-clean-staged3-base'); c2=parity('C2-3nuc-3shard')
print('parity S1q(prompt-lookup) vs S0q(base):', sum(a.get(k)==base.get(k) for k in a), '/', len(a), '| S0q vs A1b(release):', sum(base.get(k)==ref.get(k) for k in base), '/', len(base), '| S7q(staged single-box) vs C2(3-NUC release):', sum(st3.get(k)==c2.get(k) for k in st3), '/', len(st3))
PY
echo "T07_E2E_DONE" | tee $P/t07_e2e.done

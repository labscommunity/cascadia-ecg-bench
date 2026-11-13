#!/usr/bin/env python3
"""Write the intelinside result file for the 122B 3-NUC keep-alive run from the D4k bench/eval outputs."""
import json, statistics as st, sys, os, glob
R='/Users/tatef/Workspaces/cascadia-ecg-bench/results'
lab, rev, bench_sha = sys.argv[1], sys.argv[2], sys.argv[3]
rows=[json.loads(l) for l in open(f'{R}/{lab}/bench.jsonl')]
def med(pid, key): 
    v=[x[key] for x in rows if x.get('kind')=='bench' and x.get('prompt_id')==pid and x.get(key)]
    return st.median(v) if v else None
dec=med('medium','decode_tok_s'); ttft=med('medium','ttft_s'); n=len([x for x in rows if x.get('kind')=='bench' and x.get('prompt_id')=='medium'])
short=med('short','decode_tok_s'); long_=med('long','decode_tok_s'); tl=med('long','ttft_s')
steady=None
try:
    sr=[json.loads(l) for l in open(f'{R}/{lab}/steady.jsonl')]; v=[x['decode_tok_s'] for x in sr if x.get('decode_tok_s')]; steady=st.median(v) if v else None
except Exception: pass
ev=None
try:
    g={}
    summ=None
    for l in open(f'{R}/{lab}-eval/gsm8k.jsonl'):
        j=json.loads(l)
        if j.get('kind')=='summary': summ=j
        elif 'id' in j: g[j['id']]=j
    ev={'correct':summ['correct'],'total':summ['n']} if summ else {'correct':sum(1 for j in g.values() if j.get('correct')),'total':len(g)}
except Exception: pass
par=None
try:
    a={j['prompt_id']:j.get('text','') for j in map(json.loads,open(f'{R}/{lab}/parity.jsonl'))}
    b={j['prompt_id']:j.get('text','') for j in map(json.loads,open(f'{R}/D3b-122b-3stage-3nuc-commit85/parity.jsonl'))}
    par=(sum(a.get(k)==b.get(k) for k in a), len(a))
except Exception: pass
out={
 "$schema":"https://raw.githubusercontent.com/labscommunity/intelinside/main/results/schema.json",
 "rig":"Panther Lake NUC trio 32 GB","model":"qwen3-5-122b-a10b","quant":"gptq-4bit","runtime":"cascadia",
 "runtimeVersion":"0.2.7 + qwen35 GPU keep-alive branch (OpenVINO GenAI 2026.4.1)",
 "runtimeFlags":"3-stage layer pipeline (qwen35 staged engine), one stage per NUC on its Arc B390 iGPU (19/23/23 GB), activations over 2.5 GbE, --gpu-keepalive-ms 2, greedy, batch 1; Windows GPU shared-memory window SystemPartitionCommitLimitPercentage=85 on every node",
 "customRuntimeFile":"custom-runtimes/t8/cascadia-qwen35-gpu-keepalive.json","revision":rev,
 "decodeTps":round(dec,1),"ttftMs":round(ttft*1000),
 "inputTokens":975,"outputTokens":256,"concurrency":1,"decodeMethod":"streamed","repeats":n,"promptCache":False,"thinking":False,"speculative":"none",
 "runDate":"2026-11-13",
 "evidenceUrl":f"https://github.com/labscommunity/cascadia-ecg-bench/blob/{bench_sha}/report/report.md",
}
notes=(f"Three ASUS NUCs (Core Ultra X7 358H, Arc B390 iGPU, 32 GB each, Windows 11) on one 2.5 GbE switch. OpenVINO IR built from Qwen/Qwen3.5-122B-A10B-GPTQ-Int4 with the builder's signed-INT4 expert layout (64 GB total), split 16/16/16 layers across the three iGPUs. "
 f"decodeTps is the medium prompt (975 tokens after the chat template, 256 generated, temperature 0, thinking off) averaged over {n} timed repeats after 1 warm-up: (completion tokens - 1) / (request wall time - time to first token), with TTFT from a separate max_tokens=1 request; ttftMs is that prompt's median. "
 f"Short (31-token) prompt {short:.1f} tok/s; 7.7k-token prompt {long_:.1f} tok/s with {tl:.1f} s to first token" + (f"; 90 s steady loop {steady:.1f} tok/s" if steady else "") + ". "
 "The keep-alive only changes per-token latency: with it off the same chain decodes at about 3 tok/s because the idle iGPU is charged ~0.5 s on 40-50% of steps" + (f"; outputs identical to the stock 0.2.7 build on {par[0]}/{par[1]} parity prompts" if par else "") + (f". GSM8K 20-question subset: {ev.get('correct')}/{ev.get('total', ev.get('n', 20))}" if ev else "") + ".")
out["notes"]=notes
path='/Users/tatef/Workspaces/intelinside/results/t8/2026-11-13-qwen3-5-122b-a10b-gptq-4bit-cascadia-ptl-nuc-trio-3stage-keepalive.json'
json.dump(out, open(path,'w'), indent=2, ensure_ascii=False); open(path,'a').write('\n')
print(json.dumps({k:out[k] for k in ('decodeTps','ttftMs','repeats')}), 'short',short,'long',long_,'steady',steady,'parity',par,'eval',ev and {k:ev[k] for k in ev if k in ('correct','total','n','accuracy')})
print('wrote', path)

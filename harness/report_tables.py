#!/usr/bin/env python3
"""Build report tables from results/. usage: report_tables.py results/ summary.json > report/tables.md
(run `summarize.py results/ --json summary.json` first)"""
import json, os, glob, sys, subprocess
root, sj = sys.argv[1], sys.argv[2]
allrows = {r['run']: r for r in json.load(open(sj))}
rows = {k: v for k, v in allrows.items() if k not in ('A1-tate07-whole-gpu','B1-charlie-whole-gpu')}  # one-chunk-client runs superseded by A1b/B1b
# B1b was a quick re-measure (no power window); its power/utilization come from the full B1 run of the same server state (marked with a dagger)
if 'B1b-charlie-whole-gpu' in rows and 'B1-charlie-whole-gpu' in allrows:
    for k in ('idle_W','steady_W','steady_ddr_GBs','idle_ddr_GBs','cpu_pct','gpu_busy_pct','gpu_neural_pct','gpu_copy_pct','npu_busy_pct','gpu_shared_GB','proc_ws_GB','committed_GB','steady_dec','steady_e2e'):
        if rows['B1b-charlie-whole-gpu'].get(k) is None and allrows['B1-charlie-whole-gpu'].get(k) is not None: rows['B1b-charlie-whole-gpu'][k] = allrows['B1-charlie-whole-gpu'][k]
    rows['B1b-charlie-whole-gpu']['note'] = 'power/utilization from the B1 window (same server state); steady decode there was measured end-to-end'
def g(run, k, fmt='{}'):
    v = rows.get(run, {}).get(k); return '' if v is None else fmt.format(v)
def jl(p):
    try: return [json.loads(l) for l in open(p, encoding='utf-8-sig') if l.strip()]
    except Exception: return []
order = [r for r in ['A1b-tate07-whole-gpu','A3-tate07-2shard-colocated','A4-tate07-3shard-colocated','A2-tate07-whole-cpu','B1b-charlie-whole-gpu','B1-charlie-whole-gpu','B2-charlie-whole-cpu','C1-2nuc-2shard','C2-3nuc-3shard','D1-122b-2x64gb'] if r in rows] + [r for r in rows if r not in ['A1b-tate07-whole-gpu','A3-tate07-2shard-colocated','A4-tate07-3shard-colocated','A2-tate07-whole-cpu','B1b-charlie-whole-gpu','B1-charlie-whole-gpu','B2-charlie-whole-cpu','C1-2nuc-2shard','C2-3nuc-3shard','D1-122b-2x64gb']]
print('## Performance (medians of 3 repeats; greedy, thinking off)\n')
print('| config | TTFT short (31 tok) | TTFT medium (975 tok) | TTFT long (7.7k tok) | decode tok/s (medium) | decode tok/s (steady loop) | e2e tok/s (steady, incl. prefill) |')
print('|---|---|---|---|---|---|---|')
for r in order: print(f"| {r} | {g(r,'short_ttft_s','{:.2f} s')} | {g(r,'medium_ttft_s','{:.2f} s')} | {g(r,'long_ttft_s','{:.2f} s')} | {g(r,'medium_dec','{:.1f}')} | {g(r,'steady_dec','{:.1f}')} | {g(r,'steady_e2e','{:.1f}')} |")
print('\n## Power and utilization (60 s SoC Watch window during sustained decode; 30 s idle with model loaded)\n')
print('| config | idle W | decode W | tok/J | DDR GB/s (decode) | CPU % | GPU busy % | GPU copy % | NPU % | GPU shared mem GB | process WS GB | committed GB |')
print('|---|---|---|---|---|---|---|---|---|---|---|---|')
for r in order: print(f"| {r} | {g(r,'idle_W')} | {g(r,'steady_W')} | {g(r,'tok_per_J')} | {g(r,'steady_ddr_GBs')} | {g(r,'cpu_pct')} | {g(r,'gpu_busy_pct')} | {g(r,'gpu_copy_pct')} | {g(r,'npu_busy_pct')} | {g(r,'gpu_shared_GB')} | {g(r,'proc_ws_GB')} | {g(r,'committed_GB')} |")
# per-rank power for chains
chain = [r for r in order if any(k.startswith('rank') and k.endswith('_W') for k in rows[r])]
if chain:
    print('\n## Per-rank package power during chain decode (W)\n')
    for r in chain: print(f"- {r}: " + ', '.join(f"{k[:-2]} {rows[r][k]} W" for k in sorted(rows[r]) if k.startswith('rank') and k.endswith('_W')) + f" -> total {round(sum(rows[r][k] for k in rows[r] if k.startswith('rank') and k.endswith('_W')),1)} W")
# multipliers vs whole-model baseline on the same box / model
def mult(base, run, k, inv=False):
    a, b = rows.get(base, {}).get(k), rows.get(run, {}).get(k)
    if not a or not b: return ''
    return f"{(a/b if inv else b/a):.2f}x"
print('\n## Sharding multipliers (relative to the whole model on the 64 GB box, A1b)\n')
print('| config | shards | decode tok/s | TTFT medium | TTFT long | decode power | tok/J | GPU shared mem |')
print('|---|---|---|---|---|---|---|---|')
for r in order:
    if r == 'A1b-tate07-whole-gpu': continue
    print(f"| {r} | {rows[r].get('stages','')} | {mult('A1b-tate07-whole-gpu', r, 'steady_dec')} | {mult('A1b-tate07-whole-gpu', r, 'medium_ttft_s')} | {mult('A1b-tate07-whole-gpu', r, 'long_ttft_s')} | {mult('A1b-tate07-whole-gpu', r, 'steady_W')} | {mult('A1b-tate07-whole-gpu', r, 'tok_per_J')} | {mult('A1b-tate07-whole-gpu', r, 'gpu_shared_GB')} |")
# parity vs A1b
print('\n## Output parity vs. the whole model (same greedy prompts, 160 tokens)\n')
ref = os.path.join(root, 'A1b-tate07-whole-gpu', 'parity.jsonl')
if os.path.exists(ref):
    print('| config | prompts | exact match | mean common-prefix fraction |'); print('|---|---|---|---|')
    for r in ['A1-tate07-whole-gpu (same model, same box, earlier run = noise floor)', 'A1c-tate07-whole-gpu-rerun (same model, same box, later run = noise floor)'] + order:
        rr = r.split(' ')[0]
        if rr in ('A1-tate07-whole-gpu','A1c-tate07-whole-gpu-rerun'):
            p = os.path.join(root, rr, 'parity.jsonl')
            if not os.path.exists(p): continue
            out = subprocess.check_output([sys.executable, os.path.join(os.path.dirname(__file__), 'compare_outputs.py'), ref, p]).decode()
            s_ = json.loads(out[:out.index('}')+1]); print(f"| {r} | {s_.get('prompts','')} | {s_.get('exact_match','')}/{s_.get('prompts','')} | {s_.get('mean_prefix_frac','')} |"); continue
        d = os.path.join(root, r); p = os.path.join(d, 'parity.jsonl')
        r0 = glob.glob(os.path.join(d, 'rank0-*'))
        if r0: p = os.path.join(r0[0], 'parity.jsonl')
        if not os.path.exists(p) or r == 'A1b-tate07-whole-gpu': continue
        try:
            out = subprocess.check_output([sys.executable, os.path.join(os.path.dirname(__file__), 'compare_outputs.py'), ref, p]).decode()
            s = json.loads(out.split('\n{', 1)[0] if out.startswith('{') and '\n{' in out else out[:out.index('}\n')+1] if '}\n' in out else out)
        except Exception as e:
            # fall back: first JSON object in output
            try: s = json.loads(out[:out.index('}')+1])
            except Exception: s = {}
        print(f"| {r} | {s.get('prompts','')} | {s.get('exact_match','')}/{s.get('prompts','')} | {s.get('mean_prefix_frac','')} |")
# evals
print('\n## GSM8K-40 (exact match, greedy, thinking off, max 512 tokens)\n')
print('| run | correct | accuracy | completion tokens | wall s |'); print('|---|---|---|---|---|')
for p in sorted(glob.glob(os.path.join(root, '*eval*', '**', 'gsm8k.jsonl'), recursive=True)):
    ss = [json.loads(l) for l in open(p, encoding='utf-8-sig') if l.strip() and 'summary' in l]
    ss = [x for x in ss if x.get('kind') == 'summary']
    if ss: x = ss[-1]; print(f"| {os.path.relpath(os.path.dirname(p), root)} | {x['correct']}/{x['n']} | {x['accuracy']*100:.1f}% | {x['total_completion_tokens']} | {x['wall_s']} |")
notes = [(r, rows[r]['note']) for r in order if rows[r].get('note')]
if notes: print('\nNotes: ' + '; '.join(f'{r}: {n}' for r, n in notes))

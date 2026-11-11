#!/usr/bin/env python3
"""Aggregate results/<run>/ into a markdown table: median TTFT / decode tok/s per prompt, steady power, utilization, memory.
usage: summarize.py results/ [--json out.json]"""
import json, os, sys, statistics as st, glob, argparse
ap = argparse.ArgumentParser(); ap.add_argument('root'); ap.add_argument('--json', default=''); a = ap.parse_args()
def jl(p):
    out = []
    if not os.path.exists(p): return out
    for l in open(p, encoding='utf-8-sig'):
        l = l.strip()
        if not l: continue
        try: out.append(json.loads(l))
        except Exception: pass
    return out
def med(xs):
    xs = [x for x in xs if isinstance(x, (int, float))]
    return round(st.median(xs), 3) if xs else None
rows = []
for d in sorted(glob.glob(os.path.join(a.root, '*'))):
    if not os.path.isdir(d): continue
    run = os.path.basename(d)
    # chain runs keep head results under rank0-*/ ; flat runs at top level
    base = d
    r0 = glob.glob(os.path.join(d, 'rank0-*'))
    if r0: base = r0[0]
    bench = [r for r in jl(os.path.join(base, 'bench.jsonl')) if r.get('kind') == 'bench' and r.get('status') == 200]
    if not bench and not os.path.exists(os.path.join(base, 'idle.sw.json')): continue
    row = {'run': run}
    for pid in ('short', 'medium', 'long'):
        b = [r for r in bench if r['prompt_id'] == pid]
        row[f'{pid}_ttft_s'] = med([r['ttft_s'] for r in b]); row[f'{pid}_dec_tok_s'] = med([r['decode_tok_s'] for r in b])
        if b and b[0].get('prompt_tokens'): row[f'{pid}_prompt_tok'] = b[0]['prompt_tokens']
    cal = {r['prompt_id']: r.get('prompt_tokens') for r in jl(os.path.join(base, 'calib.jsonl'))}
    for pid in ('short', 'medium', 'long'):
        if cal.get(pid): row[f'{pid}_prompt_tok'] = cal[pid]
    steady = [r for r in jl(os.path.join(base, 'steady.jsonl')) if r.get('status') == 200]
    row['steady_dec_tok_s'] = med([r['decode_tok_s'] for r in steady]); row['steady_requests'] = len(steady)
    for k in ('idle', 'steady'):
        p = os.path.join(base, f'{k}.sw.json')
        if os.path.exists(p):
            try:
                sw = json.load(open(p, encoding='utf-8-sig'))
                row[f'{k}_pkg_w'] = round(sw.get('pkg_power_mw_avg', 0) / 1000, 2); row[f'{k}_ddr_gb_s'] = sw.get('ddr_total_gb_s')
                if 'npu_power_mw_avg' in sw: row[f'{k}_npu_w'] = round(sw['npu_power_mw_avg'] / 1000, 2)
            except Exception: pass
        u = jl(os.path.join(base, f'{k}.util.jsonl'))
        if u:
            row[f'{k}_cpu_pct'] = med([x.get('cpu_util_pct') for x in u]); row[f'{k}_gpu3d_pct'] = med([x.get('gpu_3d_pct') for x in u])
            row[f'{k}_gpucompute_pct'] = med([x.get('gpu_compute_pct') for x in u]); row[f'{k}_npu_pct'] = med([x.get('gpu_neural_pct') for x in u])
            row[f'{k}_gpu_shared_gb'] = round((med([x.get('gpu_shared_mb') for x in u]) or 0) / 1024, 2)
            row[f'{k}_proc_ws_gb'] = round((med([x.get('proc_ws_mb') for x in u]) or 0) / 1024, 2)
            row[f'{k}_committed_gb'] = round((med([x.get('mem_committed_mb') for x in u]) or 0) / 1024, 2)
    if row.get('steady_dec_tok_s') and row.get('steady_pkg_w'):
        row['tok_per_joule'] = round(row['steady_dec_tok_s'] / row['steady_pkg_w'], 3)
    # chain: per-rank steady power
    for rk in sorted(glob.glob(os.path.join(d, 'rank*-*'))):
        rname = os.path.basename(rk).split('-')[0]
        for p in glob.glob(os.path.join(rk, f'steady-{rname}.sw.json')):
            try: row[f'{rname}_pkg_w'] = round(json.load(open(p, encoding='utf-8-sig')).get('pkg_power_mw_avg', 0) / 1000, 2)
            except Exception: pass
    rows.append(row)
cols = ['run', 'short_prompt_tok', 'short_ttft_s', 'short_dec_tok_s', 'medium_prompt_tok', 'medium_ttft_s', 'medium_dec_tok_s', 'long_prompt_tok', 'long_ttft_s', 'long_dec_tok_s',
        'steady_dec_tok_s', 'idle_pkg_w', 'steady_pkg_w', 'tok_per_joule', 'steady_ddr_gb_s', 'steady_cpu_pct', 'steady_gpu3d_pct', 'steady_gpucompute_pct', 'steady_npu_pct', 'steady_gpu_shared_gb', 'steady_proc_ws_gb', 'steady_committed_gb']
extra = sorted({k for r in rows for k in r} - set(cols))
cols += extra
print('| ' + ' | '.join(cols) + ' |'); print('|' + '---|' * len(cols))
for r in rows: print('| ' + ' | '.join('' if r.get(c) is None else str(r.get(c)) for c in cols) + ' |')
if a.json: json.dump(rows, open(a.json, 'w'), indent=1)

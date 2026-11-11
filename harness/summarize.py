#!/usr/bin/env python3
"""Aggregate results/<run>/ into a markdown table (medians). usage: summarize.py results/ [--json out.json]"""
import json, os, glob, argparse, statistics as st
ap = argparse.ArgumentParser(); ap.add_argument('root'); ap.add_argument('--json', default=''); a = ap.parse_args()
def jl(p):
    out = []
    if not os.path.exists(p): return out
    for l in open(p, encoding='utf-8-sig'):
        l = l.strip()
        if l:
            try: out.append(json.loads(l))
            except Exception: pass
    return out
def med(xs):
    xs = [x for x in xs if isinstance(x, (int, float))]
    return round(st.median(xs), 2) if xs else None
def sw(p):
    try: return json.load(open(p, encoding='utf-8-sig'))
    except Exception: return {}
rows = []
for d in sorted(glob.glob(os.path.join(a.root, '*'))):
    if not os.path.isdir(d): continue
    run = os.path.basename(d); base = d
    r0 = [x for x in glob.glob(os.path.join(d, 'rank0-*')) if os.path.isdir(x)]
    if r0: base = r0[0]
    bench = [r for r in jl(os.path.join(base, 'bench.jsonl')) if r.get('kind') == 'bench' and r.get('status') == 200]
    steady = [r for r in jl(os.path.join(base, 'steady.jsonl')) if r.get('status') == 200]
    if not bench and not steady: continue
    row = {'run': run, 'status': open(os.path.join(d, 'STATUS')).read().strip() if os.path.exists(os.path.join(d, 'STATUS')) else ''}
    tag_src = (bench or steady)
    if tag_src: row['stages'] = tag_src[0].get('stages') or ('1')
    for pid in ('short', 'medium', 'long'):
        b = [r for r in bench if r['prompt_id'] == pid]
        row[f'{pid}_ptok'] = b[0].get('prompt_tokens') if b else None
        row[f'{pid}_ttft_s'] = med([r.get('ttft_s') for r in b]); row[f'{pid}_dec'] = med([r.get('decode_tok_s') for r in b]); row[f'{pid}_e2e'] = med([r.get('e2e_tok_s') for r in b])
        row[f'{pid}_wall_s'] = med([r.get('wall_s') for r in b])
    row['steady_dec'] = med([r.get('decode_tok_s') for r in steady]); row['steady_e2e'] = med([r.get('e2e_tok_s') for r in steady]); row['steady_n'] = len(steady)
    i, s = sw(os.path.join(base, 'idle.sw.json')), sw(os.path.join(base, 'steady.sw.json'))
    row['idle_W'] = round(i.get('pkg_power_mw_avg', 0) / 1000, 1) if i else None; row['steady_W'] = round(s.get('pkg_power_mw_avg', 0) / 1000, 1) if s else None
    row['steady_ddr_GBs'] = s.get('ddr_total_gb_s'); row['idle_ddr_GBs'] = i.get('ddr_total_gb_s')
    if row['steady_dec'] and row['steady_W']: row['tok_per_J'] = round(row['steady_dec'] / row['steady_W'], 2)
    u = jl(os.path.join(base, 'steady.util.jsonl')); ui = jl(os.path.join(base, 'idle.util.jsonl'))
    if u:
        def adapt(x):
            m = x.get('shared_mb_by_adapter') or {}; e = x.get('eng_by_adapter') or {}
            if not m or not e: return (None, None)
            g = max(m, key=lambda k: m[k])
            gpu = max((v for v in (e.get(g) or {}).values()), default=0.0)
            npu = sum(v for l, d in e.items() if l != g for v in d.values())
            return (gpu, npu)
        ab = [adapt(x) for x in u]
        if any(a[0] is not None for a in ab):
            row['gpu_busy_pct'] = med([a[0] for a in ab]); row['npu_busy_pct'] = med([a[1] for a in ab])
        else:  # pre-patch sampler: GPU compute shows up as the 'neural' engine class on this driver; NPU unknown
            row['gpu_busy_pct'] = med([max(x.get('gpu_neural_pct') or 0, x.get('gpu_compute_pct') or 0, x.get('gpu_3d_pct') or 0) for x in u])
        row['cpu_pct'] = med([x.get('cpu_util_pct') for x in u]); row['gpu_3d_pct'] = med([x.get('gpu_3d_pct') for x in u]); row['gpu_compute_pct'] = med([x.get('gpu_compute_pct') for x in u])
        row['gpu_neural_pct'] = med([x.get('gpu_neural_pct') for x in u]); row['gpu_copy_pct'] = med([x.get('gpu_copy_pct') for x in u]); row['gpu_shared_GB'] = round((med([x.get('gpu_shared_mb') for x in u]) or 0) / 1024, 1)
        row['proc_ws_GB'] = round((med([x.get('proc_ws_mb') for x in u]) or 0) / 1024, 1); row['committed_GB'] = round((med([x.get('mem_committed_mb') for x in u]) or 0) / 1024, 1)
    if ui: row['idle_committed_GB'] = round((med([x.get('mem_committed_mb') for x in ui]) or 0) / 1024, 1)
    for rk in sorted(glob.glob(os.path.join(d, 'rank*-*'))):
        rn = os.path.basename(rk).split('-')[0]; p = os.path.join(rk, f'steady-{rn}.sw.json')
        if os.path.exists(p): row[f'{rn}_W'] = round(sw(p).get('pkg_power_mw_avg', 0) / 1000, 1)
        uu = jl(os.path.join(rk, f'steady-{rn}.util.jsonl'))
        if uu: row[f'{rn}_gpu_shared_GB'] = round((med([x.get('gpu_shared_mb') for x in uu]) or 0) / 1024, 1); row[f'{rn}_ws_GB'] = round((med([x.get('proc_ws_mb') for x in uu]) or 0) / 1024, 1)
    rk = [row[k] for k in row if k.startswith('rank') and k.endswith('_W')]
    if rk:
        row['chain_total_W'] = round(sum(rk), 1); row['steady_W_single_box'] = row.get('steady_W'); row['steady_W'] = row['chain_total_W']
        if row.get('steady_dec'): row['tok_per_J'] = round(row['steady_dec'] / row['chain_total_W'], 2)
        row['gpu_shared_GB_total'] = round(sum(row[k] for k in row if k.startswith('rank') and k.endswith('_gpu_shared_GB')), 1)
    rows.append(row)
cols = ['run', 'short_ptok', 'short_ttft_s', 'medium_ptok', 'medium_ttft_s', 'long_ptok', 'long_ttft_s', 'medium_dec', 'steady_dec', 'steady_e2e', 'idle_W', 'steady_W', 'tok_per_J', 'steady_ddr_GBs', 'cpu_pct', 'gpu_busy_pct', 'gpu_neural_pct', 'gpu_copy_pct', 'npu_busy_pct', 'gpu_shared_GB', 'proc_ws_GB', 'committed_GB']
extra = sorted({k for r in rows for k in r} - set(cols) - {'status'})
print('| ' + ' | '.join(cols) + ' |'); print('|' + '---|' * len(cols))
for r in rows: print('| ' + ' | '.join('' if r.get(c) is None else str(r.get(c)) for c in cols) + ' |')
print('\nextra columns: ' + ', '.join(f"{r['run']}: " + ', '.join(f'{k}={r[k]}' for k in extra if r.get(k) is not None) for r in rows))
if a.json: json.dump(rows, open(a.json, 'w'), indent=1)

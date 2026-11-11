#!/usr/bin/env python3
"""Side-by-side output comparison between two result JSONL files (greedy runs on the same prompts).
Reports exact-match rate, common-prefix fraction (characters), and first divergence per prompt.
usage: compare_outputs.py ref.jsonl other.jsonl [--kind bench] """
import json, sys, argparse
ap = argparse.ArgumentParser(); ap.add_argument('ref'); ap.add_argument('other'); ap.add_argument('--kind', default='bench'); ap.add_argument('--rep', type=int, default=0)
a = ap.parse_args()
def load(p):
    out = {}
    for l in open(p, encoding='utf-8'):
        r = json.loads(l)
        if r.get('kind') == a.kind and r.get('rep', 0) == a.rep and r.get('status') == 200:
            out[r['prompt_id']] = r
    return out
A, B = load(a.ref), load(a.other)
rows = []
for pid in A:
    if pid not in B: continue
    ta, tb = A[pid]['text'], B[pid]['text']
    n = 0
    for x, y in zip(ta, tb):
        if x != y: break
        n += 1
    rows.append({'prompt_id': pid, 'exact': ta == tb, 'common_prefix_chars': n, 'len_ref': len(ta), 'len_other': len(tb),
                 'prefix_frac': round(n / max(1, min(len(ta), len(tb))), 3), 'ref_tail': ta[n:n+60], 'other_tail': tb[n:n+60]})
ex = sum(r['exact'] for r in rows)
print(json.dumps({'prompts': len(rows), 'exact_match': ex, 'exact_rate': round(ex / max(1, len(rows)), 3),
                  'mean_prefix_frac': round(sum(r['prefix_frac'] for r in rows) / max(1, len(rows)), 3)}, indent=1))
for r in rows: print(json.dumps(r, ensure_ascii=False))

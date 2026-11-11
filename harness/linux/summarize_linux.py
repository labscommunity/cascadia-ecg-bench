#!/usr/bin/env python3
"""Reduce sample.sh JSONL (+ optional intel_gpu_top JSON) to medians. usage: summarize_linux.py sample.jsonl [gputop.json]"""
import json, sys, statistics as st
rows=[json.loads(l) for l in open(sys.argv[1]) if l.strip()]
def med(k): 
    xs=[r[k] for r in rows if isinstance(r.get(k),(int,float))]; return round(st.median(xs),2) if xs else None
out={'n':len(rows),'pkg_w_med':med('pkg_w'),'pkg_w_max':max((r['pkg_w'] for r in rows if isinstance(r.get('pkg_w'),(int,float))),default=None),'cpu_util_pct_med':med('cpu_util_pct'),'mem_avail_mb_med':med('mem_avail_mb'),'proc_rss_mb_med':med('proc_rss_mb'),'mem_used_mb_med': (rows[0]['mem_total_mb']-med('mem_avail_mb')) if rows else None}
if len(sys.argv)>2:
    try:
        txt=open(sys.argv[2]).read().strip()
        # intel_gpu_top -J emits a JSON array (possibly unterminated)
        if not txt.endswith(']'): txt=txt.rstrip(',\n ')+']'
        if not txt.startswith('['): txt='['+txt
        g=json.loads(txt); eng={}
        for s in g:
            for name,v in (s.get('engines') or {}).items(): eng.setdefault(name,[]).append(v.get('busy',0))
        out['gpu_engines_busy_med']={k:round(st.median(v),1) for k,v in eng.items()}
        pw=[s.get('power',{}).get('GPU') for s in g if s.get('power',{}).get('GPU') is not None]
        if pw: out['gpu_power_w_med']=round(st.median(pw),2)
    except Exception as e: out['gputop_error']=repr(e)[:120]
print(json.dumps(out))

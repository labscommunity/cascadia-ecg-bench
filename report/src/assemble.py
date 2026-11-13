#!/usr/bin/env python3
"""Build cascadia-panther-lake-benchmark.html from body.html + style.css + fills.json (placeholders __NAME__)."""
import json, re, sys, os, html
here=os.path.dirname(os.path.abspath(__file__))
body=open(os.path.join(here,'body.html')).read(); css=open(os.path.join(here,'style.css')).read()
fills=json.load(open(os.path.join(here,'fills.json'))) if os.path.exists(os.path.join(here,'fills.json')) else {}
def bars(rows, vmax=None):
    vmax=vmax or max(v for _,v,_ in rows)
    out=[]
    for name,val,cls in rows:
        pct=max(1.2, 100*val/vmax); out.append(f'<div class="bar {cls}"><div class="n" title="{html.escape(name)}">{html.escape(name)}</div><div class="t"><i style="width:{pct:.1f}%"></i></div><div class="v">{val:g}</div></div>')
    return '\n'.join(out)
bars35=[("Whole · 64 GB GPU · GPTQ-sym",53.4,""),("Whole · 64 GB GPU",47.5,""),("Whole · 32 GB NUC · window raised",33.2,"alt"),("2 shards co-located · 64 GB",31,""),("3 shards co-located · 64 GB",31,""),("2 NUCs",20.1,""),("3 NUCs",17.8,""),("Whole · 64 GB CPU (e2e)",13.5,"warn"),("Whole · 32 GB NUC CPU (e2e)",12,"warn"),("2 NUCs · CPU tail",11.4,"warn"),("Whole · 32 GB NUC · as shipped",1.7,"warn"),("Whole · 32 GB NUC · HETERO",1.4,"warn")]
for extra in fills.get('BARS35_EXTRA',[]): bars35.append(tuple(extra))
bars35.sort(key=lambda r:-r[1])
page=body.replace('__CSS__',css).replace('__BARS35__',bars(bars35))
for k,v in fills.items():
    if k.startswith('BARS'): continue
    page=page.replace('__'+k+'__', v)
left=sorted(set(re.findall(r'__[A-Z0-9_]+__', page)))
out=os.path.join(here,'cascadia-panther-lake-benchmark.html'); open(out,'w').write(page)
print('wrote', out, len(page), 'bytes; placeholders left:', left)

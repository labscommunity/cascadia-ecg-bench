#!/usr/bin/env python3
"""GSM8K subset eval through an OpenAI-compatible endpoint (greedy). Scores numeric exact match on 'Answer: N'.
usage: eval_gsm8k.py --base http://127.0.0.1:8130 --n 40 --out eval.jsonl --tag model=35b [--thinking off] [--max-tokens 512]"""
import argparse, json, re, time, os, urllib.request
ap = argparse.ArgumentParser()
ap.add_argument('--base', default='http://127.0.0.1:8130'); ap.add_argument('--token', default='dev-token')
ap.add_argument('--data', default=os.path.join(os.path.dirname(__file__), 'gsm8k_test_60.json'))
ap.add_argument('--n', type=int, default=40); ap.add_argument('--max-tokens', type=int, default=512)
ap.add_argument('--thinking', default='off'); ap.add_argument('--out', default=''); ap.add_argument('--tag', action='append', default=[])
ap.add_argument('--timeout', type=float, default=3600)
a = ap.parse_args(); TAGS = dict(t.split('=', 1) for t in a.tag)
SYS = "Solve the math word problem. Reason step by step briefly, then finish with a final line of the form 'Answer: <number>'."
def post(body):
    req = urllib.request.Request(a.base + '/v1/chat/completions', data=json.dumps(body).encode(), headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + a.token})
    return json.loads(urllib.request.urlopen(req, timeout=a.timeout).read())
def extract(t):
    m = re.findall(r'Answer:\s*\$?\s*(-?[\d,]*\.?\d+)', t)
    if m: return m[-1].replace(',', '')
    m = re.findall(r'(-?[\d,]*\.?\d+)', t)
    return m[-1].replace(',', '') if m else None
def norm(x):
    try: return float(x)
    except Exception: return None
rows = json.load(open(a.data))[:a.n]; correct = 0; t_all = time.time(); toks = 0
for r in rows:
    t0 = time.time()
    try:
        d = post({'model': 'default', 'messages': [{'role': 'system', 'content': SYS}, {'role': 'user', 'content': r['question']}], 'max_tokens': a.max_tokens, 'temperature': 0,
                  'enable_thinking': a.thinking == 'on', 'chat_template_kwargs': {'enable_thinking': a.thinking == 'on'}})
        text = d['choices'][0]['message'].get('content', '') or ''; u = d.get('usage') or {}
        pred = extract(text); ok = (norm(pred) is not None and norm(pred) == norm(r['gold'])); correct += ok
        ct = u.get('completion_tokens') or 0; toks += ct
        rec = {'id': r['id'], 'gold': r['gold'], 'pred': pred, 'correct': ok, 'completion_tokens': ct, 'wall_s': round(time.time() - t0, 2), 'finish': d['choices'][0].get('finish_reason'), 'text': text[-300:], **TAGS}
    except Exception as e:
        rec = {'id': r['id'], 'gold': r['gold'], 'error': repr(e)[:200], 'correct': False, **TAGS}
    print(json.dumps(rec, ensure_ascii=False), flush=True)
    if a.out:
        open(a.out, 'a', encoding='utf-8').write(json.dumps(rec, ensure_ascii=False) + '\n')
summ = {'kind': 'summary', 'n': len(rows), 'correct': correct, 'accuracy': round(correct / len(rows), 3), 'total_completion_tokens': toks, 'wall_s': round(time.time() - t_all, 1), **TAGS}
print(json.dumps(summ)); 
if a.out: open(a.out, 'a', encoding='utf-8').write(json.dumps(summ) + '\n')

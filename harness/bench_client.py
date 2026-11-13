#!/usr/bin/env python3
"""Benchmark client for an OpenAI-compatible endpoint (Cascadia runtime), engine-agnostic.

Per prompt and repeat (two-call method, robust to engines that emit one SSE chunk per completion):
  call 1: non-stream, max_tokens=1  -> ttft_s (prefill + first token, incl. HTTP), prompt_tokens (usage)
  call 2: non-stream, max_tokens=N  -> wall_s, completion_tokens (usage), text
  decode_tok_s = (completion_tokens - 1) / (wall_s - ttft_s);  e2e_tok_s = completion_tokens / wall_s
Optionally (--stream-diag) one streaming call per prompt records first-chunk latency and chunk count.
Greedy (temperature 0), thinking off by default (chat_template_kwargs.enable_thinking + legacy field).

Modes: bench (default) | steady (continuous N-token requests for --seconds; for power sampling) | calib (usage only)
"""
import argparse, json, sys, time, threading, urllib.request, urllib.error, os, platform
for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding='utf-8', errors='replace')
    except Exception: pass

ap = argparse.ArgumentParser()
ap.add_argument('--base', default='http://127.0.0.1:8130'); ap.add_argument('--token', default='dev-token'); ap.add_argument('--model', default='')
ap.add_argument('--prompts', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'prompts.json'))
ap.add_argument('--set', default='perf', help='perf | parity | all'); ap.add_argument('--max-tokens', type=int, default=256)
ap.add_argument('--repeats', type=int, default=3); ap.add_argument('--warmup', type=int, default=1); ap.add_argument('--concurrency', type=int, default=1)
ap.add_argument('--thinking', default='off', choices=['off', 'on']); ap.add_argument('--mode', default='bench', choices=['bench', 'steady', 'calib'])
ap.add_argument('--seconds', type=float, default=90); ap.add_argument('--steady-prompt', default='medium'); ap.add_argument('--stream-diag', action='store_true')
ap.add_argument('--timeout', type=float, default=3600); ap.add_argument('--out', default=''); ap.add_argument('--tag', action='append', default=[])
ap.add_argument('--nonce', action='store_true', help='prepend a unique tag to each request so prefix caches never hit (needed for GenAI speculative pipelines)')
ap.add_argument('--path', default='/v1/chat/completions', help='chat completions path (OVMS: /v3/chat/completions)')
ap.add_argument('--api-style', default='cascadia', choices=['cascadia', 'ovms'], help='ovms: no legacy enable_thinking field, no bearer token')
args = ap.parse_args()
TAGS = dict(t.split('=', 1) for t in args.tag); TAGS.setdefault('host', platform.node())

def _req(path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    hdr = {'Content-Type': 'application/json'}
    if args.api_style != 'ovms': hdr['Authorization'] = 'Bearer ' + args.token
    req = urllib.request.Request(args.base + path, data=data, headers=hdr)
    return urllib.request.urlopen(req, timeout=args.timeout)

def model_id():
    if args.model: return args.model
    try: return json.loads(_req('/v1/models').read())['data'][0]['id']
    except Exception: return 'default'
MODEL = model_id()

_nonce_n = [0]
def _with_nonce(messages):
    """--nonce: make every request's prompt unique (prepend a short tag to the last user turn) so a server-side prefix
    cache never serves it; OpenVINO GenAI's prompt-lookup / draft-model pipelines refuse prefix-cached requests."""
    if not getattr(args, 'nonce', False): return messages
    _nonce_n[0] += 1; tag = f"[req {os.getpid() % 10000}-{_nonce_n[0]}] "
    out = [dict(m) for m in messages]
    # put the tag at the very start of the conversation (first message, system if present) so not even the
    # first KV block is shared between requests (block-granular prefix caches hash whole blocks)
    for m in out:
        if isinstance(m.get('content'), str): m['content'] = tag + m['content']; break
    return out
def body(messages, max_tokens, stream=False):
    messages = _with_nonce(messages)
    b = {'model': MODEL, 'messages': messages, 'max_tokens': max_tokens, 'temperature': 0, 'stream': stream,
         'chat_template_kwargs': {'enable_thinking': args.thinking == 'on'}}
    if args.api_style != 'ovms': b['enable_thinking'] = args.thinking == 'on'
    return b

def call(messages, max_tokens):
    """Non-stream request -> (wall_s, usage, text, finish, status, error)."""
    t0 = time.perf_counter()
    try:
        d = json.loads(_req(args.path, body(messages, max_tokens)).read()); wall = time.perf_counter() - t0
        ch = d['choices'][0]; u = d.get('usage') or {}
        text = (ch.get('message') or {}).get('content') or ''
        rc = (ch.get('message') or {}).get('reasoning_content')
        if rc and not text: text = rc
        return wall, u, text, ch.get('finish_reason'), 200, None
    except urllib.error.HTTPError as e:
        return time.perf_counter() - t0, {}, '', None, e.code, e.read().decode(errors='replace')[:300]
    except Exception as e:
        return time.perf_counter() - t0, {}, '', None, -1, repr(e)[:300]

def stream_diag(messages, max_tokens):
    t0 = time.perf_counter(); first = None; n = 0; last = None
    try:
        r = _req(args.path, body(messages, max_tokens, True))
        while True:
            line = r.readline()
            if not line: break
            s = line.decode('utf-8', 'replace').strip()
            if not s.startswith('data:') or s[5:].strip() == '[DONE]': continue
            try: d = json.loads(s[5:])
            except Exception: continue
            for ch in d.get('choices', []):
                dl = ch.get('delta') or {}
                if dl.get('content') or dl.get('reasoning_content'):
                    now = time.perf_counter(); first = first or now; last = now; n += 1
    except Exception as e:
        return {'stream_error': repr(e)[:120]}
    return {'stream_first_chunk_s': round(first - t0, 4) if first else None, 'stream_chunks': n,
            'stream_chunk_rate_s': round((n - 1) / (last - first), 3) if (n > 1 and last > first) else None}

def measure(pid, prompt, max_tokens, diag=False):
    msgs = [{'role': 'user', 'content': prompt}]
    w1, u1, _, _, s1, e1 = call(msgs, 1)
    w2, u2, text, finish, s2, e2 = call(msgs, max_tokens)
    ct = u2.get('completion_tokens'); pt = u2.get('prompt_tokens') or u1.get('prompt_tokens')
    rec = {'prompt_id': pid, 'max_tokens': max_tokens, 'model': MODEL, 'thinking': args.thinking, 'status': 200 if (s1 == 200 and s2 == 200) else (s2 if s2 != 200 else s1),
           'error': e2 or e1, 'ttft_s': round(w1, 4), 'wall_s': round(w2, 4), 'prompt_tokens': pt, 'completion_tokens': ct, 'finish': finish, 'text': text, 'ts': time.time()}
    if ct and ct > 1 and w2 > w1: rec['decode_tok_s'] = round((ct - 1) / (w2 - w1), 3)
    if ct: rec['e2e_tok_s'] = round(ct / w2, 3)
    if diag: rec.update(stream_diag(msgs, min(48, max_tokens)))
    rec.update(TAGS); return rec

def emit(rec):
    line = json.dumps(rec, ensure_ascii=False); print(line, flush=True)
    if args.out:
        with open(args.out, 'a', encoding='utf-8') as f: f.write(line + '\n')

P = json.load(open(args.prompts, encoding='utf-8'))
prompts = [p for s in P.values() for p in s] if args.set == 'all' else P[args.set]

if args.mode == 'calib':
    for p in prompts:
        w, u, text, fin, st, err = call([{'role': 'user', 'content': p['text']}], 16)
        emit({'prompt_id': p['id'], 'kind': 'calib', 'prompt_tokens': u.get('prompt_tokens'), 'completion_tokens': u.get('completion_tokens'), 'wall_s': round(w, 3), 'status': st, 'error': err, 'text': text[:200], **TAGS})
    sys.exit(0)

if args.mode == 'steady':
    p = next(p for s in P.values() for p in s if p['id'] == args.steady_prompt)
    msgs = [{'role': 'user', 'content': p['text']}]
    w1, u1, _, _, _, _ = call(msgs, 1); ttft_ref = w1
    t_end = time.time() + args.seconds; lock = threading.Lock()
    def loop(tid):
        while time.time() < t_end:
            w, u, text, fin, st, err = call(msgs, args.max_tokens); ct = u.get('completion_tokens')
            rec = {'kind': 'steady', 'thread': tid, 'prompt_id': p['id'], 'wall_s': round(w, 4), 'completion_tokens': ct, 'prompt_tokens': u.get('prompt_tokens'), 'status': st, 'error': err,
                   'ttft_ref_s': round(ttft_ref, 4), 'e2e_tok_s': round(ct / w, 3) if ct else None, 'decode_tok_s': round((ct - 1) / (w - ttft_ref), 3) if (ct and ct > 1 and w > ttft_ref) else None, 'model': MODEL, **TAGS}
            with lock: emit(rec)
    ths = [threading.Thread(target=loop, args=(t,)) for t in range(args.concurrency)]; [t.start() for t in ths]; [t.join() for t in ths]
    sys.exit(0)

for _ in range(args.warmup):
    r = measure(prompts[0]['id'], prompts[0]['text'], min(32, args.max_tokens)); r['kind'] = 'warmup'; emit(r)
if args.concurrency == 1:
    for rep in range(args.repeats):
        for p in prompts:
            r = measure(p['id'], p['text'], p.get('max_tokens', args.max_tokens), diag=(args.stream_diag and rep == 0)); r.update({'kind': 'bench', 'rep': rep}); emit(r)
else:
    for rep in range(args.repeats):
        results = []; lock = threading.Lock()
        def worker(tid):
            for p in prompts:
                w, u, text, fin, st, err = call([{'role': 'user', 'content': p['text']}], p.get('max_tokens', args.max_tokens))
                with lock: results.append({'kind': 'bench-conc', 'rep': rep, 'thread': tid, 'prompt_id': p['id'], 'wall_s': round(w, 4), 'completion_tokens': u.get('completion_tokens'), 'status': st, 'error': err, 'model': MODEL, **TAGS})
        t0 = time.perf_counter(); ths = [threading.Thread(target=worker, args=(t,)) for t in range(args.concurrency)]; [t.start() for t in ths]; [t.join() for t in ths]; wall = time.perf_counter() - t0
        for r in results: emit(r)
        tot = sum((r.get('completion_tokens') or 0) for r in results)
        emit({'kind': 'aggregate', 'rep': rep, 'concurrency': args.concurrency, 'requests': len(results), 'total_completion_tokens': tot, 'wall_s': round(wall, 3), 'aggregate_tok_s': round(tot / wall, 3), 'errors': sum(1 for r in results if r.get('status') != 200), 'model': MODEL, **TAGS})

#!/usr/bin/env python3
"""Streaming benchmark client for an OpenAI-compatible endpoint (Cascadia runtime).

Measures, per request: TTFT (first content delta), decode tok/s ((n_tokens-1)/(t_last-t_first)),
end-to-end wall, completion tokens (usage when present, else SSE content chunks), output text.
Greedy (temperature 0), thinking off by default (chat_template_kwargs + legacy field).

Usage:
  python bench_client.py --base http://127.0.0.1:8130 --prompts prompts.json --set perf \
      --max-tokens 256 --repeats 3 --warmup 1 --out results.jsonl --tag host=alpha --tag config=whole-gpu
  python bench_client.py ... --mode steady --seconds 90     # continuous decode loop for power sampling
  python bench_client.py ... --concurrency 4                # concurrent streams (aggregate tok/s)
"""
import argparse, json, sys, time, threading, urllib.request, urllib.error, socket, os, platform

ap = argparse.ArgumentParser()
ap.add_argument('--base', default='http://127.0.0.1:8130')
ap.add_argument('--token', default='dev-token')
ap.add_argument('--model', default='')
ap.add_argument('--prompts', default=os.path.join(os.path.dirname(__file__), 'prompts.json'))
ap.add_argument('--set', default='perf', help='prompt set name inside prompts.json (perf|parity|all)')
ap.add_argument('--max-tokens', type=int, default=256)
ap.add_argument('--repeats', type=int, default=3)
ap.add_argument('--warmup', type=int, default=1)
ap.add_argument('--concurrency', type=int, default=1)
ap.add_argument('--thinking', default='off', choices=['off', 'on'])
ap.add_argument('--mode', default='bench', choices=['bench', 'steady', 'calib'])
ap.add_argument('--seconds', type=float, default=90, help='steady mode duration')
ap.add_argument('--steady-prompt', default='medium')
ap.add_argument('--timeout', type=float, default=1800)
ap.add_argument('--out', default='')
ap.add_argument('--tag', action='append', default=[], help='key=value tags copied into every record')
args = ap.parse_args()
TAGS = dict(t.split('=', 1) for t in args.tag)
TAGS.setdefault('host', platform.node())

def _req(path, body=None, stream=False):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(args.base + path, data=data, headers={
        'Content-Type': 'application/json', 'Authorization': 'Bearer ' + args.token})
    return urllib.request.urlopen(req, timeout=args.timeout)

def model_id():
    if args.model:
        return args.model
    try:
        d = json.loads(_req('/v1/models').read())
        return d['data'][0]['id']
    except Exception as e:  # noqa
        return 'default'

MODEL = model_id()

def body(messages, max_tokens, stream):
    b = {'model': MODEL, 'messages': messages, 'max_tokens': max_tokens, 'temperature': 0,
         'stream': stream, 'enable_thinking': args.thinking == 'on',
         'chat_template_kwargs': {'enable_thinking': args.thinking == 'on'}}
    return b

def one_stream(pid, prompt, max_tokens):
    """Run one streaming request; return a record dict."""
    msgs = [{'role': 'user', 'content': prompt}]
    rec = {'prompt_id': pid, 'max_tokens': max_tokens, 'model': MODEL, 'thinking': args.thinking}
    t0 = time.perf_counter(); t_first = None; t_last = None; n_chunks = 0; text = []; usage = None; finish = None
    try:
        r = _req('/v1/chat/completions', body(msgs, max_tokens, True), stream=True)
        buf = b''
        while True:
            chunk = r.readline()
            if not chunk:
                break
            line = chunk.decode('utf-8', 'replace').strip()
            if not line.startswith('data:'):
                continue
            payload = line[5:].strip()
            if payload == '[DONE]':
                break
            try:
                d = json.loads(payload)
            except Exception:
                continue
            if d.get('usage'):
                usage = d['usage']
            for ch in d.get('choices', []):
                delta = ch.get('delta', {}) or {}
                c = delta.get('content') or delta.get('reasoning_content') or ''
                if c:
                    now = time.perf_counter()
                    if t_first is None:
                        t_first = now
                    t_last = now; n_chunks += 1; text.append(c)
                if ch.get('finish_reason'):
                    finish = ch['finish_reason']
        rec['status'] = 200
    except urllib.error.HTTPError as e:
        rec['status'] = e.code; rec['error'] = e.read().decode(errors='replace')[:300]
    except Exception as e:  # noqa
        rec['status'] = -1; rec['error'] = repr(e)[:300]
    t_end = time.perf_counter()
    n_tok = (usage or {}).get('completion_tokens') or n_chunks
    rec.update({
        'ttft_s': round(t_first - t0, 4) if t_first else None,
        'wall_s': round(t_end - t0, 4),
        'completion_tokens': n_tok, 'sse_chunks': n_chunks,
        'prompt_tokens': (usage or {}).get('prompt_tokens'),
        'decode_tok_s': round((n_tok - 1) / (t_last - t_first), 3) if (t_first and t_last and t_last > t_first and n_tok > 1) else None,
        'e2e_tok_s': round(n_tok / (t_end - t0), 3) if n_tok else None,
        'finish': finish, 'text': ''.join(text), 'ts': time.time(),
    })
    rec.update(TAGS)
    return rec

def calib(pid, prompt):
    """Non-streaming call to get usage (prompt_tokens / completion_tokens) for a prompt."""
    msgs = [{'role': 'user', 'content': prompt}]
    t0 = time.perf_counter()
    try:
        d = json.loads(_req('/v1/chat/completions', body(msgs, 16, False)).read())
        u = d.get('usage') or {}
        return {'prompt_id': pid, 'kind': 'calib', 'prompt_tokens': u.get('prompt_tokens'),
                'completion_tokens': u.get('completion_tokens'), 'wall_s': round(time.perf_counter() - t0, 3),
                'text': d['choices'][0]['message'].get('content', '')[:200], **TAGS}
    except Exception as e:  # noqa
        return {'prompt_id': pid, 'kind': 'calib', 'error': repr(e)[:300], **TAGS}

def emit(rec):
    line = json.dumps(rec, ensure_ascii=False)
    print(line, flush=True)
    if args.out:
        with open(args.out, 'a', encoding='utf-8') as f:
            f.write(line + '\n')

prompts_all = json.load(open(args.prompts, encoding='utf-8'))
if args.set == 'all':
    prompts = [p for s in prompts_all.values() for p in s]
else:
    prompts = prompts_all[args.set]

if args.mode == 'calib':
    for p in prompts:
        emit(calib(p['id'], p['text']))
    sys.exit(0)

if args.mode == 'steady':
    p = next(p for s in prompts_all.values() for p in s if p['id'] == args.steady_prompt)
    t_end = time.time() + args.seconds
    i = 0
    def loop(tid):
        global i
        while time.time() < t_end:
            rec = one_stream(p['id'], p['text'], args.max_tokens)
            rec.update({'kind': 'steady', 'thread': tid}); emit(rec)
    ths = [threading.Thread(target=loop, args=(t,)) for t in range(args.concurrency)]
    [t.start() for t in ths]; [t.join() for t in ths]
    sys.exit(0)

# bench mode
for w in range(args.warmup):
    rec = one_stream(prompts[0]['id'], prompts[0]['text'], min(32, args.max_tokens)); rec['kind'] = 'warmup'; emit(rec)

if args.concurrency == 1:
    for rep in range(args.repeats):
        for p in prompts:
            rec = one_stream(p['id'], p['text'], p.get('max_tokens', args.max_tokens)); rec.update({'kind': 'bench', 'rep': rep}); emit(rec)
else:
    # concurrency sweep: all threads run the same prompt list; report aggregate tokens/wall
    for rep in range(args.repeats):
        results = []; lock = threading.Lock()
        def worker(tid):
            for p in prompts:
                rec = one_stream(p['id'], p['text'], p.get('max_tokens', args.max_tokens)); rec.update({'kind': 'bench-conc', 'rep': rep, 'thread': tid})
                with lock:
                    results.append(rec)
        t0 = time.perf_counter()
        ths = [threading.Thread(target=worker, args=(t,)) for t in range(args.concurrency)]
        [t.start() for t in ths]; [t.join() for t in ths]
        wall = time.perf_counter() - t0
        for r in results:
            emit(r)
        tot = sum((r.get('completion_tokens') or 0) for r in results)
        emit({'kind': 'aggregate', 'rep': rep, 'concurrency': args.concurrency, 'requests': len(results),
              'total_completion_tokens': tot, 'wall_s': round(wall, 3), 'aggregate_tok_s': round(tot / wall, 3),
              'errors': sum(1 for r in results if r.get('status') != 200), 'model': MODEL, **TAGS})

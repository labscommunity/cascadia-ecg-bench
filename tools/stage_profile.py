# Direct OpenVINO profile of one pipeline stage: prefill n tokens, then decode steps at T=1; report wall per step vs summed GPU op time.
import openvino as ov, numpy as np, time, json, sys, os, collections
stage_dir=sys.argv[1]; hidden=int(sys.argv[2]);
_mf=os.path.join(os.path.dirname(stage_dir.rstrip('\\/')),'manifest.json')
if os.path.exists(_mf):
    _h=json.load(open(_mf)).get('hidden_size');  hidden=_h or hidden
device=sys.argv[3] if len(sys.argv)>3 else 'GPU'; extra=dict(kv.split('=') for kv in sys.argv[4:])
core=ov.Core(); cfg={'PERF_COUNT':'YES','PERFORMANCE_HINT':'LATENCY'}; cfg.update(extra)
t0=time.time(); model=core.read_model(os.path.join(stage_dir,'stage.xml')); cm=core.compile_model(model, device, cfg); req=cm.create_infer_request(); print(f"compiled in {time.time()-t0:.1f}s cfg={cfg}")
names=[i.get_any_name() for i in cm.inputs]; print('inputs', names, 'outputs', [o.get_any_name() for o in cm.outputs])
rng=np.random.default_rng(0); pos=0
def run(n):
    global pos
    feeds={}
    for nm in names:
        if 'stage_hidden' in nm: feeds[nm]=(rng.standard_normal((1,n,hidden))*0.5).astype(np.float32)
        elif 'embed' in nm: feeds[nm]=np.zeros((1,n,hidden),np.float32) if 'stage_hidden' in ' '.join(names) else (rng.standard_normal((1,n,hidden))*0.02).astype(np.float32)
        elif 'attention_mask' in nm: feeds[nm]=np.ones((1,pos+n),np.int64)
        elif 'position' in nm: feeds[nm]=np.tile(np.arange(pos,pos+n,dtype=np.int64),(4,1))[:,None,:]
        elif 'beam' in nm: feeds[nm]=np.zeros((1,),np.int32)
        else: raise SystemExit('unknown input '+nm)
    t=time.perf_counter(); req.infer(feeds); dt=time.perf_counter()-t; pos+=n; return dt
req.reset_state(); pos=0
pf=run(64); print(f"prefill 64 tok: {pf*1000:.0f} ms")
NSTEP=int(os.environ.get('NSTEP','24')); SLEEP=float(os.environ.get('SLEEP_MS','0'))/1000.0
steps=[]
for _ in range(NSTEP):
    if SLEEP>0: time.sleep(SLEEP)
    steps.append(run(1))
if NSTEP>=100:
    import numpy as _np; a=_np.array(steps)*1000; idx=_np.argsort(-a)[:12]
    print('slowest steps (index:ms):', ', '.join(f'{i}:{a[i]:.0f}' for i in sorted(idx)))
    print('step ms percentiles p50/p90/p99/max:', ' '.join(f'{_np.percentile(a,q):.0f}' for q in (50,90,99,100)), 'mean', f'{a.mean():.1f}', 'sum', f'{a.sum()/1000:.1f}s')
    print('steps >2x median:', int((a>2*_np.median(a)).sum()), 'of', NSTEP)
print(f"decode T=1: first {steps[0]*1000:.1f} ms, median {np.median(steps[4:])*1000:.1f} ms, min {min(steps)*1000:.1f} ms over {len(steps)} steps")
prof=req.profiling_info
by=collections.defaultdict(lambda:[0.0,0.0,0]); tot_real=tot_cpu=0.0
for p in prof:
    r=p.real_time.total_seconds()*1e3; c=p.cpu_time.total_seconds()*1e3; by[p.node_type][0]+=r; by[p.node_type][1]+=c; by[p.node_type][2]+=1; tot_real+=r; tot_cpu+=c
print(f"last decode step: wall {steps[-1]*1000:.1f} ms, sum op real_time {tot_real:.1f} ms, sum cpu_time {tot_cpu:.1f} ms, ops {len(prof)}, executed {sum(1 for p in prof if p.status==ov.ProfilingInfo.Status.EXECUTED)}")
for k,(r,c,n) in sorted(by.items(), key=lambda x:-x[1][0])[:14]: print(f"   {k:28s} n={n:5d} real={r:8.2f} ms cpu={c:7.2f} ms")

# Sample the iGPU's actual frequency via Level Zero Sysman. usage: zefreq.py [seconds] [interval_s]
import ctypes, os, sys, time, statistics as st
os.environ['ZES_ENABLE_SYSMAN']='1'
ze=ctypes.WinDLL('ze_loader.dll')
r=ze.zeInit(0); assert r==0, hex(r)
try: ze.zesInit(0)
except Exception: pass
class FreqProps(ctypes.Structure): _fields_=[('stype',ctypes.c_int),('pNext',ctypes.c_void_p),('type',ctypes.c_int),('onSubdevice',ctypes.c_bool),('subdeviceId',ctypes.c_uint32),('canControl',ctypes.c_bool),('isThrottleEventSupported',ctypes.c_bool),('min',ctypes.c_double),('max',ctypes.c_double)]
class FreqState(ctypes.Structure): _fields_=[('stype',ctypes.c_int),('pNext',ctypes.c_void_p),('currentVoltage',ctypes.c_double),('request',ctypes.c_double),('tdp',ctypes.c_double),('efficient',ctypes.c_double),('actual',ctypes.c_double),('throttleReasons',ctypes.c_uint32)]
n=ctypes.c_uint32(0); ze.zesDriverGet(ctypes.byref(n),None); drv=(ctypes.c_void_p*max(n.value,1))(); ze.zesDriverGet(ctypes.byref(n),drv)
doms=[]
for d in [ctypes.c_void_p(x) for x in drv[:n.value]]:
    m=ctypes.c_uint32(0); ze.zesDeviceGet(d,ctypes.byref(m),None); devs=(ctypes.c_void_p*max(m.value,1))(); ze.zesDeviceGet(d,ctypes.byref(m),devs)
    for dev in [ctypes.c_void_p(x) for x in devs[:m.value]]:
        k=ctypes.c_uint32(0); ze.zesDeviceEnumFrequencyDomains(dev,ctypes.byref(k),None); fd=(ctypes.c_void_p*max(k.value,1))(); ze.zesDeviceEnumFrequencyDomains(dev,ctypes.byref(k),fd)
        for h in [ctypes.c_void_p(x) for x in fd[:k.value]]:
            p=FreqProps(); p.stype=0x9; r=ze.zesFrequencyGetProperties(h,ctypes.byref(p)); doms.append((h,p.type,p.min,p.max,p.canControl,r))
print('freq domains:',[(t,mn,mx,bool(cc),hex(r&0xffffffff)) for _,t,mn,mx,cc,r in doms])
secs=float(sys.argv[1]) if len(sys.argv)>1 else 5; iv=float(sys.argv[2]) if len(sys.argv)>2 else 0.1
samples={i:[] for i in range(len(doms))}; reasons=set(); t0=time.time()
while time.time()-t0<secs:
    for i,(h,*_ ) in enumerate(doms):
        s=FreqState(); s.stype=0x1b; r=ze.zesFrequencyGetState(h,ctypes.byref(s))
        if r==0: samples[i].append((s.actual,s.request,s.efficient)); reasons.add(s.throttleReasons)
    time.sleep(iv)
for i,(h,t,mn,mx,cc,_) in enumerate(doms):
    a=[x[0] for x in samples[i] if x[0]>0]; q=[x[1] for x in samples[i] if x[1]>0]
    if a: print(f"domain{i} type={'GPU' if t==0 else 'MEM' if t==1 else t} range={mn:.0f}-{mx:.0f}MHz n={len(a)} actual min/med/mean/max={min(a):.0f}/{st.median(a):.0f}/{st.mean(a):.0f}/{max(a):.0f} request med={st.median(q) if q else 0:.0f} throttleReasons={sorted(reasons)}")
    else: print(f"domain{i} no samples")

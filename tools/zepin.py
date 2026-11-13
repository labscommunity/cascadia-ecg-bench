# Pin / unpin the iGPU frequency range via Level Zero Sysman. usage: zepin.py <minMHz> <maxMHz>   (zepin.py 100 2500 restores)
import ctypes, os, sys
os.environ['ZES_ENABLE_SYSMAN']='1'
ze=ctypes.WinDLL('ze_loader.dll'); assert ze.zeInit(0)==0
try: ze.zesInit(0)
except Exception: pass
class FreqProps(ctypes.Structure): _fields_=[('stype',ctypes.c_int),('pNext',ctypes.c_void_p),('type',ctypes.c_int),('onSubdevice',ctypes.c_bool),('subdeviceId',ctypes.c_uint32),('canControl',ctypes.c_bool),('isThrottleEventSupported',ctypes.c_bool),('min',ctypes.c_double),('max',ctypes.c_double)]
class FreqRange(ctypes.Structure): _fields_=[('min',ctypes.c_double),('max',ctypes.c_double)]
lo,hi=float(sys.argv[1]),float(sys.argv[2])
n=ctypes.c_uint32(0); ze.zesDriverGet(ctypes.byref(n),None); drv=(ctypes.c_void_p*max(n.value,1))(); ze.zesDriverGet(ctypes.byref(n),drv)
for d in [ctypes.c_void_p(x) for x in drv[:n.value]]:
    m=ctypes.c_uint32(0); ze.zesDeviceGet(d,ctypes.byref(m),None); devs=(ctypes.c_void_p*max(m.value,1))(); ze.zesDeviceGet(d,ctypes.byref(m),devs)
    for dev in [ctypes.c_void_p(x) for x in devs[:m.value]]:
        k=ctypes.c_uint32(0); ze.zesDeviceEnumFrequencyDomains(dev,ctypes.byref(k),None); fd=(ctypes.c_void_p*max(k.value,1))(); ze.zesDeviceEnumFrequencyDomains(dev,ctypes.byref(k),fd)
        for h in [ctypes.c_void_p(x) for x in fd[:k.value]]:
            p=FreqProps(); p.stype=0x9; ze.zesFrequencyGetProperties(h,ctypes.byref(p))
            if p.type!=0: continue
            cur=FreqRange(); ze.zesFrequencyGetRange(h,ctypes.byref(cur)); print(f"GPU domain before: {cur.min:.0f}-{cur.max:.0f} MHz canControl={bool(p.canControl)}")
            r=FreqRange(lo,hi); rc=ze.zesFrequencySetRange(h,ctypes.byref(r)); print('setRange rc=',hex(rc&0xffffffff))
            cur=FreqRange(); ze.zesFrequencyGetRange(h,ctypes.byref(cur)); print(f"GPU domain after : {cur.min:.0f}-{cur.max:.0f} MHz")

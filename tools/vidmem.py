# Query what WDDM/VidMm actually enforces: segment sizes (dxdiag's numbers) and the per-process video-memory budget.
import ctypes, ctypes.wintypes as wt, sys, os
gdi = ctypes.WinDLL('gdi32'); k32 = ctypes.WinDLL('kernel32')
class LUID(ctypes.Structure): _fields_=[('Low',wt.ULONG),('High',wt.LONG)]
class ADAPTERINFO(ctypes.Structure): _fields_=[('hAdapter',wt.UINT),('Luid',LUID),('NumOfSources',wt.ULONG),('bPrecise',wt.BOOL)]
class ENUMADAPTERS2(ctypes.Structure): _fields_=[('NumAdapters',wt.ULONG),('pAdapters',ctypes.POINTER(ADAPTERINFO))]
class SEGMENTSIZEINFO(ctypes.Structure): _fields_=[('DedicatedVideo',ctypes.c_ulonglong),('DedicatedSystem',ctypes.c_ulonglong),('SharedSystem',ctypes.c_ulonglong)]
class QUERYADAPTERINFO(ctypes.Structure): _fields_=[('hAdapter',wt.UINT),('Type',wt.UINT),('pData',ctypes.c_void_p),('Size',wt.UINT)]
class QVMI(ctypes.Structure): _fields_=[('hProcess',ctypes.c_void_p),('hAdapter',wt.UINT),('Group',wt.UINT),('Budget',ctypes.c_ulonglong),('CurrentUsage',ctypes.c_ulonglong),('AvailableForReservation',ctypes.c_ulonglong),('CurrentReservation',ctypes.c_ulonglong),('PhysicalAdapterIndex',wt.UINT)]
class ADAPTERTYPE(ctypes.Structure): _fields_=[('Value',wt.UINT)]
GB=1024**3
e=ENUMADAPTERS2(); gdi.D3DKMTEnumAdapters2(ctypes.byref(e)); n=e.NumAdapters
arr=(ADAPTERINFO*n)(); e.pAdapters=arr; st=gdi.D3DKMTEnumAdapters2(ctypes.byref(e)); assert st==0, hex(st&0xffffffff)
pids=[int(a) for a in sys.argv[1:]]
for i in range(e.NumAdapters):
    a=arr[i]
    seg=SEGMENTSIZEINFO(); q=QUERYADAPTERINFO(a.hAdapter, 3, ctypes.addressof(seg), ctypes.sizeof(seg)); st=gdi.D3DKMTQueryAdapterInfo(ctypes.byref(q))
    class SGS(ctypes.Structure): _fields_=[('PhysicalAdapterIndex',wt.UINT),('pad',wt.UINT),('Legacy',SEGMENTSIZEINFO),('LocalMemory',ctypes.c_ulonglong),('NonLocalMemory',ctypes.c_ulonglong)]
    sg=SGS(0,0); q3=QUERYADAPTERINFO(a.hAdapter, 42, ctypes.addressof(sg), ctypes.sizeof(sg)); st3=gdi.D3DKMTQueryAdapterInfo(ctypes.byref(q3))
    at=ADAPTERTYPE(); q2=QUERYADAPTERINFO(a.hAdapter, 15, ctypes.addressof(at), ctypes.sizeof(at)); gdi.D3DKMTQueryAdapterInfo(ctypes.byref(q2))
    flags=at.Value; sw = bool(flags & 0x4) or bool(flags & 0x2)  # RenderSupported=1, DisplaySupported=2, SoftwareDevice=4
    print(f"   segmentgroup(42) status={hex(st3&0xffffffff)} local={sg.LocalMemory/GB:.2f}GiB nonlocal={sg.NonLocalMemory/GB:.2f}GiB legacyShared={sg.Legacy.SharedSystem/GB:.2f}GiB legacyDedVid={sg.Legacy.DedicatedVideo/GB:.2f}GiB")
    print(f"adapter {i} hAdapter={a.hAdapter} luid={a.Luid.High:08x}-{a.Luid.Low:08x} typeflags=0x{flags:x} segsize_status={hex(st&0xffffffff)} dedicatedVideo={seg.DedicatedVideo/GB:.2f}GiB dedicatedSystem={seg.DedicatedSystem/GB:.2f}GiB sharedSystem={seg.SharedSystem/GB:.2f}GiB ({seg.SharedSystem/1024**2:.0f} MiB)")
    for grp,name in ((0,'LOCAL'),(1,'NON_LOCAL')):
        v=QVMI(None, a.hAdapter, grp, 0,0,0,0, 0); st=gdi.D3DKMTQueryVideoMemoryInfo(ctypes.byref(v))
        print(f"   {name:9s} self   : status={hex(st&0xffffffff)} budget={v.Budget/GB:.2f}GiB usage={v.CurrentUsage/GB:.2f}GiB availForReservation={v.AvailableForReservation/GB:.2f}GiB reservation={v.CurrentReservation/GB:.2f}GiB")
        for pid in pids:
            h=k32.OpenProcess(0x1000|0x0400, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION|PROCESS_QUERY_INFORMATION
            v=QVMI(h, a.hAdapter, grp, 0,0,0,0, 0); st=gdi.D3DKMTQueryVideoMemoryInfo(ctypes.byref(v)); k32.CloseHandle(h)
            print(f"   {name:9s} pid {pid:6d}: status={hex(st&0xffffffff)} budget={v.Budget/GB:.2f}GiB usage={v.CurrentUsage/GB:.2f}GiB availForReservation={v.AvailableForReservation/GB:.2f}GiB reservation={v.CurrentReservation/GB:.2f}GiB")
mem=ctypes.c_ulonglong(); k32.GetPhysicallyInstalledSystemMemory(ctypes.byref(mem)); print(f"installed RAM {mem.value/1024**2:.1f} GiB")

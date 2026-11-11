# Machine inventory (probed 2026-11-11)

All Panther Lake boxes are Intel Core Ultra X7 358H (4P + 8E + 4LPE = 16 threads, Arc B390 Xe3 iGPU, NPU 5).
GPU-visible memory is what OpenVINO reports as `GPU_DEVICE_TOTAL_MEM_SIZE` (the shared-memory window the GPU plugin can allocate).

| Role | Host | Hardware | RAM | GPU-visible | OS / driver | Network | Notes |
|---|---|---|---|---|---|---|---|
| 32 GB PTL #1 | alpha (ASRock NUC BOX-358H) | X7 358H, Arc B390 | 31.5 GB DDR5-4800 (2x16 KF564S38-16, XMP off) | 16.46 GiB | Win 11 Pro WS 26200, GPU 32.0.101.9033, no NPU driver | 2.5 GbE LAN 192.168.0.101 | hosts honyaku r0 (paused during runs) |
| 32 GB PTL #2 | beta (ASRock NUC BOX-358H) | X7 358H, Arc B390 | 31.5 GB DDR5-4800 | 16.46 GiB | Win 11 Pro WS 26200 | 2.5 GbE LAN 192.168.0.103 | hosts honyaku r1+r2 (paused during runs), GH runner |
| 32 GB PTL #3 | charlie (ASRock NUC BOX-358H) | X7 358H, Arc B390 | 31.5 GB DDR5-5600 (Crucial) | 16.46 GiB | Win 11 Pro WS 26200 | 2.5 GbE LAN 192.168.0.188 | hosts Acrow demo node (3 GB VLM on GPU), GH runner |
| 32 GB PTL (laptop, extra) | delta (ASUS Zenbook S14 UX5406AA) | X7 358H, Arc B390, NPU | 31.4 GB LPDDR5X-9600 (8x4 GB) | 16.4 GiB | Win 11 Pro 26200, GPU 32.0.101.8724, NPU 32.0.100.5540 | Wi-Fi only | booth staging node (qwen3-8b OVMS) |
| 64 GB PTL (Tiber) | tate-07 (PDX88-PA0794, Intel Tiber AI Cloud) | X7 358H, Arc B390, NPU | 63.4 GB | 48.39 GiB | Win 11 Pro 26200, GPU 32.0.101.9150 | Tiber LAN; reached via tailnet (DERP relay from the lab, ~15 ms) | dev box; enterprise node (gemma-4-26b) stopped during runs |
| 64 GB PTL (Tiber, Linux, spare) | tate-08 (pdx88-pk0881) | X7 358H, Arc B390, NPU | 61.3 GB | n/a | Ubuntu, OVMS 2026.4 | tailnet | SWE-bench rig, idle since 2026-10-20; holds the 35B IR |

Software on every Windows box for this benchmark: `cascadia` runtime v0.2.7 (bundled OpenVINO GenAI 2026.4.1, core 2026.4.1) at `C:\ecgbench\rt`,
Python venv `C:\ecgbench\venv` (openvino 2026.4.1, numpy, huggingface_hub), Intel SoC Watch 2026.2 (driver 2.20.5) at `C:\ecgbench\socwatch\64`.

Not used: tate-09 (64 GB PTL Linux, a teammate's production node), tate-04 (64 GB PTL engineering sample, no GPU driver), the Lunar Lake 258V boxes (matias/pawan), Arrow Lake boxes (tate-02/03).

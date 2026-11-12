# D3b: Qwen3.5-122B-A10B (GPTQ-sym build), 3 even stages on alpha/beta/charlie with the dxgkrnl commit limit at 85%

Same tree as D3 (20.7 / 24.7 / 25.0 GB stages, manifest 3cc2ddd74fbf15e4) but every NUC now has a 26.81 GiB WDDM shared segment and a 26.06 GiB
per-process budget (`GraphicsDrivers\MemoryManager\SystemPartitionCommitLimitPercentage` = 85, see report 6.1). All three ranks are resident
(VidMm usage 19.4-20.8 GiB, copy engines 1-9%), pipeline healthy 14 s after launch.

- TTFT short / medium / long: 1.2-1.5 / 5.7-6.3 / 41-45 s (D3: 3.8 / 12 / 79 s). Decode 1.9-4.1 tok/s across prompts, steady 2.9 tok/s (D3: 0.57).
- Chain-wide 60 s window: alpha 8.7 + beta 8.9 + charlie 6.7 = 24.3 W, 0.12 tok/J; GPU compute 14-15% busy per rank, DDR 5-6 GB/s per box:
  the 122B's decode on these iGPUs is kernel-launch / expert-gather bound, not memory bound, once the weights are resident.
- GSM8K-20: 17/20, token-identical to the 4-stage relay run D2sym (same 5,482 completion tokens; misses 8, 12, 13 are all 400-token truncations).
  Wall 2,438 s vs 3,463 s over the relay (1.4x).
- rank0-alpha/, rank1-beta/, rank2-charlie/ hold the per-rank samplers, SoC Watch windows and logs. honyaku paused on alpha/beta, Acrow stopped on charlie for the run.

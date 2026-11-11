# D2sym: Qwen3.5-122B-A10B (GPTQ-sym build), 4 stages: alpha -> beta -> charlie -> tate-07 (Tiber) tail

Tree `q122-sym-stages-4` (13 / 16 / 16 / 26 GB; layer split 10,20,30), manifest 8caabfd79f413639 on all four ranks. Every stage fits its GPU's
resident segment (NUCs 18.4 GB; tate-07 48 GiB window): head GPU shared 13.2 GB, copy engine 3% (no paging). Pipeline healthy 21 s after the
head launched. charlie -> tate-07 and tate-07 -> alpha cross the Tailscale relay (110-350 ms), so each token pays two relay crossings.

- TTFT short / medium / long: 2.0 / 18.5 / 108-137 s; decode 1.2-2.7 tok/s (medium 1.6-2.4, long 1.9-2.0); flat vs prompt length = network-bound.
- Head: 3.1 W idle, 6.8 W decoding, GPU busy 5%, CPU 5%. Chain-wide 60 s SoC Watch window: alpha 7.6 + beta 8.3 + charlie 4.5 + tate-07 8.3 = 28.7 W
  (`rank-*/steady-*.sw.json`), 0.07 tok/J: four GPUs idling on the relay.
- GSM8K-20 (greedy, thinking off, 400-token cap): 17/20. All three misses (ids 8, 12, 13) hit the 400-token cap; the 35B scored 18/20 (A1) and 19/20 (A6)
  on the same questions. No measurable capability gain at this sample size.
- Parity vs the whole 35B is not meaningful (different model); the 6 parity prompts are kept for completeness.

What this shows: the `--expert-sym` builder fix makes the 122B run correctly end to end on Panther Lake GPUs; the 3-NUC all-local layout (D3) is
blocked by the 18.4 GB resident segment per iGPU, and a 4th *local* 32 GB node (not available here: delta has 6 GB of disk) would make the chain LAN-bound,
estimated 5-8 tok/s from the 35B chain's scaling. tate-07's enterprise `cascadia-node` service was disabled for the run and restored afterwards.

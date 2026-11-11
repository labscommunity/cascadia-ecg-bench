# Cascadia on Panther Lake — sharded vs. whole-model serving (one-pager, 2026-11-11)

**Hardware.** Three 32 GB Intel Core Ultra X7 358H NUCs (Arc B390 iGPU, 17.7 GB GPU window, 2.5 GbE) and one 64 GB X7 358H in Intel Tiber (52 GB GPU window).
**Software.** Cascadia runtime v0.2.7 (OpenVINO GenAI 2026.4.1), official INT4 Qwen3.6-35B-A3B IR (19.4 GB), greedy, thinking off, SoC Watch power.

## Qwen3.6-35B-A3B — what each layout delivers (single stream)

| Layout | TTFT @ 1k-token prompt | Decode tok/s | Package power | tok/J | GPU memory per box | GSM8K-40 |
|---|---|---|---|---|---|---|
| Whole model, one 64 GB box (GPU) | 0.60 s | 42–48 | 34 W | 1.23 | 19.1 GB | 37/40 |
| 2 or 3 shards co-located on the 64 GB box | 1.56 s | 27 | 30 W | 0.9 | 18.4 GB | 36/40 |
| Whole model, one 32 GB NUC (GPU) | 1.29 s | **1.7** (oversubscribed) | 23 W | 0.07 | 17.9 GB | — |
| Whole model, one 32 GB NUC (CPU) | 53 s | ~12 e2e, RAM saturated | — | — | 27 GB RSS | — |
| 2 shards, one per NUC (2.5 GbE) | 3.5 s | 19 | 31 W total (15 + 16) | 0.61 | 9.1 GB | — |
| 3 shards, one per NUC | 3.5 s | 18 | 28 W total (9 + 9 + 10) | 0.66 | 6.1 GB | 36/40 |

- **32 GB nodes cannot serve the 35B alone** (19.4 GB > 17.7 GB GPU window): 1.7 tok/s on GPU, minute-long first tokens on CPU.
- **Sharding across 2–3 NUCs makes it work: 18–19 tok/s, 11x the single-NUC whole model**, same task accuracy, 6–9 GB and 9–15 W per node.
- **A 64 GB node is 2.3x faster and 2x more energy-efficient per stream** than the NUC chain; sharding on one box costs 35% decode and 2.6x TTFT.
- **Sharding hurts prefill most**: TTFT on a 7.7k-token prompt goes from 2.9 s (whole) to 11 s (co-located) and 22–31 s (across NUCs).
- **Accuracy**: sharded outputs are not token-identical to the whole model (f16 near-tie flips after the first sentence) but task accuracy is unchanged
  (36/40 vs 37/40); the whole model is deterministic run-to-run (6/6 exact).
- **NPU** is idle in every configuration; CPU load is 5–17% on GPU layouts. Decode is memory-bandwidth-bound (77 GB/s DDR on the 64 GB box).

## Qwen3.5-122B-A10B
- INT4 IR = **64.3 GB** (built here from the GPTQ-Int4 checkpoint; no public OpenVINO IR exists). It fits **no single Panther Lake box** (52 GB GPU window /
  61 GB RAM at 64 GB; 17.7 GB at 32 GB); the smallest GPU layouts are 2 x 64 GB boxes (29 + 33 GB) or 3 NUCs + a 64 GB tail (12–26 GB per stage).
- **GPU compile failure found and fixed**: the GPTQ-built IR's experts are symmetric (zero point 8 everywhere) and the OpenVINO 2026.4.1 GPU MoE fusion
  rejects that form; the builder now emits signed INT4 experts (`--expert-sym`), which compile. The rebuilt 35B validates the fix at model scale (A6). All-local on three 32 GB NUCs the 122B **runs but thrashes (0.57 tok/s)**: its 20–23 GB stages exceed the 18.4 GB the
  driver keeps resident per iGPU, so the 122B needs stages under ~18 GB: four or more 32 GB nodes, or a 64 GB node for the tail. {{D2SYM_1P}}
- On the vendor's benchmarks the 122B-A10B is 1–3 points ahead of the 35B-A3B on knowledge/reasoning and behind on coding/agentic tasks, at 3.3x the
  weights and 3.3x the active parameters per token (~3x slower per stream on the same silicon).

## Follow-up round (same day)
- **iGPU window on 32 GB boxes: 17.7 → 24.8 GiB** with one driver registry value (`GpuSystemMemoryPinninglimit` = 85%) + reboot. It does not rescue the
  whole 35B (the driver keeps an 18.4 GB resident segment; decode 1.8–2.0 tok/s vs 1.5–1.7) but gives sharded ranks more KV headroom. Left enabled.
- **Concurrency (OVMS continuous batching, 64 GB box):** 32 tok/s at 1 stream → 132 tok/s combined at 8 streams (16.6 each) at 34–36 W: 3x the tok/J.
- **Device mix (Qwen3-8B dense on one 32 GB box):** GPU 22 tok/s and 0.3 s TTFT at 1k tokens; CPU 11 tok/s and 22 s TTFT. CPU decode is a 2x loss and
  CPU prefill a 55–75x loss. The NPU does not load either the 8B or the 0.6B (OpenVINO 2026.4.1 NPU compiler error); no engine offers NPU-prefill /
  GPU-decode for one model. A 35B shard pair with the tail rank on a CPU (C3) halves decode (10–13 vs 19 tok/s), cuts it 5x on long prompts and
  makes TTFT 5–8x slower than the all-GPU pair, while needing 2x the stage size in RAM.
  OpenVINO `HETERO:GPU,CPU` on the whole 35B puts everything on the GPU anyway (1.3–1.4 tok/s, 20% slower than plain GPU).
- **122B GPU failure fixed in the builder** (`--expert-sym`: signed INT4 experts, no zero point). The rebuilt 35B runs whole on the 64 GB GPU **9% faster**
  than Intel's export (53 vs 48 tok/s) at equal accuracy (19/20 GSM8K). The 122B itself now compiles and runs on PTL GPUs (D3/D2sym below).

## ECG takeaways
1. For 32 GB edge boxes, Cascadia sharding is the only way to run a 35B-class model, and it works: 3 ordinary NUCs = 18 tok/s, 28 W, 6 GB per box.
2. If one 64 GB box fits the budget, use it whole: faster, more efficient, and it supports multi-stream serving via OVMS.
3. Keep shards on a local 2.5 GbE segment and keep prompts short (prefill is the sharding tax); validate with task-level accuracy, not token parity.
4. Default to Qwen3.6-35B-A3B; the 122B is a selective upgrade that needs two 64 GB nodes and a builder fix before it can be measured.

Repo: github.com/labscommunity/cascadia-ecg-bench (harness, raw results, full report, published-benchmark tables).

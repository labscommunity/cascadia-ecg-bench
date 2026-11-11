# Cascadia on Panther Lake: whole-model vs. sharded Qwen MoE serving

*Status: DRAFT, measurements being collected 2026-11-11. Numbers marked TBD are filled from `results/`.*

## 1. What was asked
Measure, on Intel Panther Lake AI PCs, the KPIs in the "Cascadia ECG Benchmarking" doc for Qwen3.6-35B-A3B and Qwen3.5-122B-A10B:
TTFT and tok/s, power, CPU/iGPU/NPU/memory utilization, sharded vs. non-sharded (accuracy side-by-side, performance and utilization
multipliers vs. number of shards), and the capability gained from the larger model. Machines: one 64 GB PTL in Tiber (tate-07) and three
32 GB PTL NUCs (alpha, beta, charlie). Shards were sized for the 32 GB and 64 GB memory limits, run co-located on one XPU, then spread
one per NUC.

## 2. Memory sizing (why sharding is needed at all)
The iGPU on these boxes can only address part of system RAM. OpenVINO reports the window as `GPU_DEVICE_TOTAL_MEM_SIZE`:

| Box | RAM | GPU-addressable window |
|---|---|---|
| 32 GB NUC (alpha/beta/charlie) | 31.5 GB | 16.46 GiB (17.7 GB) |
| 32 GB laptop (delta) | 31.4 GB | 16.4 GiB |
| 64 GB Tiber (tate-07) | 63.4 GB | 48.4 GiB (52 GB) |

INT4 weight footprints (from the configs; experts at 4.125 bits = u4 + f16 scale per 128, other matmuls INT4 asym, embeddings INT8):

| Model | Params | INT4 IR | Per decoder layer | Fits one 32 GB GPU window? | Fits the 64 GB GPU window? |
|---|---|---|---|---|---|
| Qwen3.6-35B-A3B | 35B (3B active) | 19.4 GB (official OpenVINO IR, asym g64) | ~0.46 GB | **No** (19.4 > 17.7; loads oversubscribed, see B1) | Yes (19.4 of 52) |
| Qwen3.5-122B-A10B | 122B (10B active) | 64.3 GB measured (62.6 GB language model + 0.8 GB embeddings + 0.9 GB vision/merger; built here from Qwen/Qwen3.5-122B-A10B-GPTQ-Int4 with the runtime's GPTQ builder, 21.5 min on 8 vCPUs) | ~1.30 GB | No | **No** (64 > 52, and > 61 GB RAM) |

Consequences used for the shard plan:
- 35B on a 32 GB NUC: 2 shards (8.1 + 9.9 GB) or 3 shards (5.3 / 6.5 / 7.4 GB) each fit the 17.7 GB window with room for KV/activations.
- 35B on the 64 GB box: whole model fits; co-locating 2 or 3 shards on the same XPU tests the pure cost of sharding.
- 122B: no single Panther Lake box (32 or 64 GB) can hold it. The smallest GPU-only layout with the hardware here is **4 stages**:
  three 10-layer stages (~13.5 GB each) on the NUCs plus an 18-layer tail (~24 GB) on the 64 GB box. The CPU path is not an escape
  hatch: the OpenVINO CPU plugin holds ~2x the IR in RSS (40 GB measured for the 35B), so the 35B does not fit a 32 GB NUC on CPU
  either, and the 122B would need ~130 GB.

## 3. Method
- Runtime: labscommunity/cascadia v0.2.7 (OpenVINO GenAI 2026.4.1). Whole model: `cascadia run --engine ov-genai --device GPU`.
  Sharded: `cascadia shard` (IR surgery at layer boundaries, no re-quantization) then `cascadia run <tree> --engine qwen35` (all
  shards in one process on one XPU) or `cascadia worker --rank i --total N` per box (pipeline over 2.5 GbE).
- Client on the serving box (loopback), streaming, greedy, thinking off. TTFT = first content delta; decode tok/s = (tokens-1)/(last-first).
  Prompts: short (~30 tok), medium (~700 tok, incident log), long (~4.5k tok, hour of camera telemetry). 1 warmup + 3 repeats, medians.
- Power: Intel SoC Watch package power + DDR bandwidth, 60 s window during a continuous decode loop; 30 s idle with the model loaded.
- Utilization: 1 s Windows perf-counter sampler (CPU, GPU engines incl. the NPU "neural" engine, GPU shared memory, process working set).
- Accuracy: identical greedy prompts whole vs. sharded (exact match / common prefix) and GSM8K-40 exact match.

## 4. Results
All tables are generated from `results/` by `harness/report_tables.py` into `report/tables.md`; the highlights below quote them.
Configs: **A** = 64 GB Tiber box (tate-07), **B** = one 32 GB NUC (charlie), **C** = NUC pipelines (alpha→beta→charlie, 2.5 GbE), **D** = 122B.

### 4.1 Qwen3.6-35B-A3B

**Whole model on the 64 GB box (A1b, GPU).** TTFT 0.12 s / 0.60 s / 2.9 s for 31 / 975 / 7,690-token prompts; decode 42–48 tok/s
(41.9 tok/s median over a 90 s continuous loop, 38 tok/s end-to-end including prefill). Package power 34.2 W while decoding vs 7.2 W idle with
the model resident; DDR traffic 79.5 GB/s (77 GB/s reads), i.e. the decode is memory-bandwidth-bound exactly as a 3B-active MoE should be.
GPU 98% busy, CPU 16%, GPU shared memory 19.1 GB, process working set 19.8 GB, system commit 33 GB. 1.23 tokens per joule.

**Whole model on a 32 GB NUC (B1b/B1, GPU).** It loads (OpenVINO over-commits the 17.7 GB GPU window) and prefill is almost normal
(TTFT 0.67 / 1.29 / 4.2 s) but decode collapses to **1.7 tok/s**: 256-token answers take 164 s instead of 6 s. Package power 23 W, GPU 95% busy,
DDR only 8 GB/s — the GPU is stalled on residency churn (weights paged in and out of the window every token), not on bandwidth.
**Whole model on a 32 GB NUC (B2, CPU).** Also loads; once warm it produces ~11.6 tok/s end-to-end for 256 tokens at 47% CPU, but RAM is saturated
(27 GB working set, 410 MB available) and first-call costs are enormous (447 s before the first token on the 7.7k prompt, 53 s at 975 tokens).
Neither 32 GB whole-model path is deployable; this is the quantitative case for sharding on 32 GB Panther Lake.

**Shards co-located on one XPU (A3 = 2 shards, A4 = 3 shards, 64 GB box).** Both give the same result: decode 27 tok/s steady (0.65x the whole
model), TTFT 2.6x longer at 975 tokens (1.56 s) and 3.9x longer at 7.7k tokens (11.4 s) because the staged engine prefills in 256-token chunks per
stage. Power drops to 30–31 W (0.9x) but tokens-per-joule falls to 0.88–0.90 (0.72x). Memory is unchanged (18.4 GB GPU shared). The copy engine
runs at 86% (hidden-state hand-offs between stages). Going from 2 to 3 shards costs nothing extra on one box: the overhead is per-pipeline, not
per-stage.

**One shard per NUC (C1 = 2 NUCs, C2 = 3 NUCs).** TBD — see `report/tables.md` once `results/C1-2nuc-2shard` and `results/C2-3nuc-3shard` land
(decode, TTFT, per-NUC power, aggregate power, GSM8K on the 3-NUC chain).

**Whole model on CPU, 64 GB box (A2).** TBD.

### 4.2 Qwen3.5-122B-A10B
The INT4 IR is 64.3 GB, so it fits no single Panther Lake box in this fleet (52 GB GPU window / 61 GB RAM on the 64 GB box; 17.7 GB window on 32 GB).
Measured layout: 2 shards across two 64 GB boxes in Tiber (tate-07 Windows rank 0: 29 GB; tate-08 Linux rank 1: 33 GB) linked over a 15 ms relay hop.
A 4-shard layout over the three 32 GB NUCs plus one 64 GB tail was cut as well, but the NUC↔Tiber path measured 110–350 ms round trip, so it was not run.
Results: TBD (`results/D1-122b-2x64gb`).

### 4.3 Sharded vs. whole: accuracy, performance multiplier, utilization multiplier
- **Token-level parity.** The whole model is deterministic: re-running it after a server restart with the same client reproduces all six 160-token greedy outputs byte-for-byte (A1c vs A1b, 6/6). The sharded engine is *not* token-identical to it: 2 or 3 co-located shards agree on the first ~50 characters of every answer and then take a different (equally coherent) continuation (A3/A4 vs A1b: 0/6 exact, ~8% common prefix). This is the f16 fusion-order / near-tie behaviour the exporter documents (its own check still shows chain-vs-full top-1 match and 8/8 greedy tokens on a short probe), so token agreement over long generations is the wrong yardstick; task accuracy is the right one. A side finding: the request path matters too, since the first client (streaming requests, no 1-token warm call) got different continuations from the same whole model (A1 vs A1b: 0/6), which argues for pinning the client method when comparing deployments.
- **Task-level accuracy** is the right comparison: GSM8K-40 whole 35B = 37/40 (92.5%); sharded chain and 122B rows TBD.
- **Performance multiplier** (vs. whole on 64 GB): 2 or 3 co-located shards = 0.65x decode, 2.6–3.9x TTFT; NUC pipelines TBD.
- **Utilization multiplier:** sharding does not reduce total memory (same 18–19 GB resident; split across boxes in C1/C2), lowers single-box power 10%
  and tokens-per-joule 28%; per-NUC numbers for the pipelines TBD.

### 4.4 Capability from model size
Vendor benchmarks (docs/published_benchmarks.md) put the 122B-A10B 1–3 points above the newer 35B-A3B on knowledge-heavy evals (MMLU-Pro 86.7 vs 85.2,
SuperGPQA 67.1 vs 64.7, HLE 25.3 vs 21.4) and ahead on long video, while the 35B-A3B is ahead on several coding/agentic rows (LiveCodeBench 80.4 vs 78.9,
Terminal-Bench 51.5 vs 49.4, SWE-bench Verified 73.4 vs 72.0) and on detection/grounding. Our own GSM8K-40: 35B = 92.5%; 122B = TBD.
The cost side is unambiguous: 3.3x the weights (64 vs 19 GB) and 3.3x the active parameters per token (10B vs 3B), so on the same silicon the 122B
needs two 64 GB boxes instead of one and will decode roughly 3x slower per stream.

## 5. What this means for ECG use cases
TBD after the pipeline and 122B rows land.

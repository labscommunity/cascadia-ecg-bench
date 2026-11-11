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
TBD — filled from `results/` by `harness/summarize.py`.

### 4.1 Qwen3.6-35B-A3B
### 4.2 Qwen3.5-122B-A10B
### 4.3 Sharded vs. whole: accuracy, performance multiplier, utilization multiplier
### 4.4 Capability from model size

## 5. What this means for ECG use cases
TBD.

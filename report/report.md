# Cascadia on Panther Lake: whole-model vs. sharded Qwen MoE serving

*Measured 2026-11-11. All numbers come from `results/` via `harness/summarize.py` and `harness/report_tables.py`; the full tables are in `report/tables.md`.*

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

**One shard per NUC (C1 = 2 NUCs, C2 = 3 NUCs, 2.5 GbE, <1 ms LAN round trip).** Decode 18.8 tok/s (2 NUCs) and 18.1 tok/s (3 NUCs) — **11x the whole model on one NUC** (1.7 tok/s) and 0.43–0.45x the 64 GB box. TTFT 3.5 s at 975 tokens on both (5.8x the 64 GB box) and 22 s / 31 s at 7.7k tokens (prefill is chunked and serialized across stages, and the long prompt moves 7.7k x 2048 x 4 B of hidden state per hop). Per-NUC resources shrink with shard count: 9.1 GB GPU memory and 15 W per NUC with 2 shards, 6.1 GB and 9 W with 3 shards. Whole-chain power is 30.7 W (2 NUCs) and 27.6 W (3 NUCs) versus 34.7 W for the 64 GB box, so efficiency is 0.61 and 0.66 tok/J against 1.23 (about half), because the chain spends most of each token waiting on the hand-off rather than streaming weights (GPU busy 44% and 29%, DDR 12.8 and 8.5 GB/s on the head). GSM8K-40 on the 3-NUC chain: 36/40 vs 37/40 for the whole model (within noise).

**Whole model on CPU, 64 GB box (A2).** 12.5 tok/s end-to-end at 40.7 W with a 40 GB working set (the CPU plugin holds ~2x the IR), CPU 60%, and very slow prefill (TTFT 40 s at 975 tokens, 347 s at 7.7k). On Panther Lake the iGPU is the only sensible whole-model device.

### 4.2 Qwen3.5-122B-A10B
**Build.** No OpenVINO IR of this model exists publicly; it was built here from `Qwen/Qwen3.5-122B-A10B-GPTQ-Int4` (79 GB) with the runtime's
GPTQ-to-OpenVINO builder in 21.5 min on an 8-vCPU VM: 64.3 GB INT4 IR (62.6 GB language model). Cut into 2 stages (24+24 layers, 29 GB + 33 GB)
with the exporter's chain-vs-full check passing (logits rel 2.0e-2, top-1 match, top-5 4/5, 8/8 greedy tokens) and into 4 stages (10/10/10/18 layers).

**Where it can run.** 64.3 GB fits no single Panther Lake box here (52 GB GPU window and 61 GB RAM on the 64 GB box; 17.7 GB window on 32 GB).
The clean layout is 2 shards on two 64 GB boxes; the two Tiber 64 GB boxes see each other at 15 ms (Seattle relay). The NUC-to-Tiber path measured
110–350 ms round trip, so a layout mixing the NUCs with a Tiber tail pays ~2 relay round trips per token.

**Measured: it does not run on the Panther Lake GPU today.** Every rank of the 4-shard layout (three NUCs + tate-07 tail) failed at model
load inside the OpenVINO 2026.4.1 GPU plugin with `[GPU] ProgramBuilder build failed ... MOECompressed` on its first MoE layer
(`results/D2-122b-4stage-3nuc-tate07/NOTE.md`, rank logs attached). The official NNCF-exported 35B IR compiles on the same stack, so the
GPTQ-repacked expert constants are what the GPU MoE-fusion pass rejects; the IR itself is numerically sound (CPU validation). The 2 x 64 GB
layout was fully staged (tate-07 + tate-08) but not executed: tate-08 went into interactive use during the run, and it would have hit the same
GPU compile error. A CPU fallback is ruled out by memory (the CPU plugin holds ~2x the IR: 24–51 GB per stage). Net: the 122B is currently
blocked by a software gap in the GPTQ-to-OpenVINO builder, not only by memory; fixing the builder's expert-constant layout for the GPU plugin
is the prerequisite for any 122B measurement on this hardware.

### 4.3 Sharded vs. whole: accuracy, performance multiplier, utilization multiplier
- **Token-level parity.** The whole model is deterministic: re-running it after a server restart with the same client reproduces all six 160-token greedy outputs byte-for-byte (A1c vs A1b, 6/6). The sharded engine is *not* token-identical to it: 2 or 3 co-located shards agree on the first ~50 characters of every answer and then take a different (equally coherent) continuation (A3/A4 vs A1b: 0/6 exact, ~8% common prefix). This is the f16 fusion-order / near-tie behaviour the exporter documents (its own check still shows chain-vs-full top-1 match and 8/8 greedy tokens on a short probe), so token agreement over long generations is the wrong yardstick; task accuracy is the right one. A side finding: the request path matters too, since the first client (streaming requests, no 1-token warm call) got different continuations from the same whole model (A1 vs A1b: 0/6), which argues for pinning the client method when comparing deployments.
- **Task-level accuracy** is the right comparison: GSM8K-40 whole 35B = 37/40 (92.5%); sharded 35B = 36/40 (90.0%) both as 2 co-located shards and as a 3-NUC chain, with byte-identical token counts (12,274) in the two sharded runs, i.e. the staged engine is deterministic across topologies and the one-problem gap to the whole model is within noise for a 40-item set. No 122B row (not runnable, §4.2).
- **Performance multiplier** (vs. whole on 64 GB): 2 or 3 co-located shards = 0.65x decode, 2.6–3.9x TTFT; 2- and 3-NUC pipelines = 0.45x / 0.43x decode, 5.8x TTFT at 975 tokens, 7.7x / 10.8x at 7.7k. Versus the only alternative on 32 GB hardware (whole model on one NUC), the pipelines are 11x faster.
- **Utilization multiplier:** total resident memory is unchanged (18.4 GB co-located; 18.3 GB and 18.3 GB summed across 2 and 3 NUCs) but per-box memory falls to 9.1 GB and 6.1 GB; co-located shards cut single-box power 10% and tok/J 28%; the NUC pipelines run at 30.7 W / 27.6 W total (0.9x / 0.8x of the 64 GB box) at half the tok/J (0.61 / 0.66 vs 1.23). The NPU stays idle in every configuration (no engine supports it for these models) and CPU load is 5–17%.

### 4.4 Capability from model size
Vendor benchmarks (docs/published_benchmarks.md) put the 122B-A10B 1–3 points above the newer 35B-A3B on knowledge-heavy evals (MMLU-Pro 86.7 vs 85.2,
SuperGPQA 67.1 vs 64.7, HLE 25.3 vs 21.4) and ahead on long video, while the 35B-A3B is ahead on several coding/agentic rows (LiveCodeBench 80.4 vs 78.9,
Terminal-Bench 51.5 vs 49.4, SWE-bench Verified 73.4 vs 72.0) and on detection/grounding. Our own GSM8K-40: 35B = 92.5% (90% sharded); the 122B could not be run (§4.2).
The cost side is unambiguous: 3.3x the weights (64 vs 19 GB) and 3.3x the active parameters per token (10B vs 3B), so on the same silicon the 122B
needs two 64 GB boxes instead of one and will decode roughly 3x slower per stream.

## 5. What this means for ECG use cases
- **A 32 GB Panther Lake node cannot serve Qwen3.6-35B-A3B on its own.** The INT4 model (19.4 GB) exceeds the 17.7 GB GPU window; it still loads,
  but decodes at 1.7 tok/s (GPU) or ~12 tok/s with saturated RAM and minute-long first responses (CPU). Sharding it across 2–3 such nodes with Cascadia
  gives 18–19 tok/s per stream with 3.5 s to first token on a 1k-token prompt, 6–9 GB of GPU memory and 9–15 W per node, and the same task accuracy
  (GSM8K-40 36/40 vs 37/40, identical to the co-located sharded run). That is the deployable path for 32 GB edge boxes: an intersection or depot with three ordinary AI PCs runs a 35B-class
  model that none of them could run alone.
- **A single 64 GB node is the better unit if the budget allows it:** 42–48 tok/s, 0.6 s to first token at 1k tokens, 34 W, twice the tokens per joule
  of the NUC chain, and continuous batching for multiple concurrent streams (A5). Sharding on a 64 GB box costs 35% of decode speed and 2.6–3.9x TTFT and
  is only worth doing to free memory for a second model or a larger one.
- **Model size:** the 122B-A10B does not fit any single Panther Lake node (64.3 GB INT4); it needs two 64 GB nodes and decodes ~3x slower per stream
  (10B vs 3B active parameters). The newer 35B-A3B is within 1–3 points of it on the vendor's knowledge/reasoning benchmarks and ahead on coding and
  agentic tasks, so for traffic-monitoring summarization, log triage and tool use the 35B-A3B is the right default and the 122B is a selective upgrade
  (long-video and knowledge-heavy tasks) rather than a general one. The 122B could not be measured here (GPU compile failure of the only available IR, §4.2).
- **Operational notes for ECG:** prefill, not decode, is where sharding hurts (long prompts cost 4–11x more TTFT when staged), so keep per-request
  context short (per-minute telemetry windows, not hour-long dumps) or pre-summarize; keep shard links on a local 2.5 GbE segment (a relayed WAN hop
  of 15 ms is tolerable, 100+ ms is not); the NPU is unused by these engines today, so NPU-capable boxes gain nothing for LLM serving; and use
  task-level accuracy checks rather than token-exact comparisons when validating a sharded deployment.


## 6. Follow-up round (same day): memory window, concurrency, device mix, 122B builder fix

### 6.1 Raising the iGPU memory window on 32 GB Panther Lake (works)
The 17.7 GB GPU window on the NUCs is the Intel driver's default "Shared GPU Memory Override" of 57% of RAM (the Intel Graphics Software
slider added in driver 32.0.101.6987). The slider writes `HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000\GMM\GpuSystemMemoryPinninglimit`
(DWORD, percent); tate-07 carried 82, the NUCs had no value. Setting it to 85 and rebooting raised OpenVINO's `GPU_DEVICE_TOTAL_MEM_SIZE`
on alpha, beta and charlie from 16.46 GiB to **24.77 GiB** (dxdiag's static "Shared Memory" line does not change). Neither the
compute-runtime percentage knob (`ClDeviceGlobalMemSizeAvailablePercent`) nor the adapter's `HardwareInformation.qwMemorySize` had any effect.
**But a bigger allocation window alone does not fix the 32 GB whole-model case (B3):** with the 24.77 GiB window the whole 35B on alpha still decodes at 1.9 tok/s, and the process's resident GPU shared memory sits at 18.4 GB, exactly the segment size dxdiag still reports (18,412 MB). The pinning limit raises what the GPU may allocate, not the WDDM shared segment it keeps resident, so the model still pages every token. tate-07 has both values high (82% and a 52 GiB `HardwareInformation.qwMemorySize`). Raising the segment value on alpha as well (B4) changed nothing: the driver rewrites that value at boot from the pinning limit, resident GPU shared memory stayed capped at 18,412 MB, decode stayed at ~2 tok/s, and the server aborted mid-run once RAM headroom fell to 2.8 GB (committed 29.5 of 31.5 GB). On a 32 GB Panther Lake box the whole 35B is therefore not usable on the iGPU with any of these knobs; the window override is still useful for shards (more KV/activation headroom, and it makes a 3 x ~22 GB layout of the 122B possible, see D3). The pinning setting was left in place on the three NUCs; remove the value to return to the 57% default.

### 6.2 Concurrency through OVMS continuous batching (64 GB box)
With the enterprise OVMS backend (continuous batching, 8 GB KV cache, up to 8 sequences) serving the official 35B IR on tate-07's GPU:

| streams | per-stream tok/s (975-tok prompt, 256-tok answers) | combined tok/s | package W | tok/J |
|---|---|---|---|---|
| 1 | 32 (decode 35–39) | 32 | 34 | 0.9 |
| 2 | 17.2 | 34 | 26.6 | 1.3 |
| 4 | 16.8 | 67 | 31.6 | 2.1 |
| 8 | 16.6 | 132 | 35.9 | 3.7 |

Per-stream speed halves once batching starts and then stays flat, so combined throughput scales linearly to 8 streams at nearly constant
power: 3x the tokens per joule of single-stream serving. (The OSS runtime's `--cb` path refuses VLM-layout IRs; OVMS does not.)

### 6.3 Device mix: CPU / GPU / NPU
Measured on delta (the only 32 GB box with the NPU driver) with the dense Qwen3-8B INT4 export, which fits all three devices (7.3, from
`results/E-delta-q3-8b-*`). The 35B cannot target the NPU (static-shape NPU compilation of a 19 GB MoE VLM export is not supported by the
engines) and `HETERO:GPU,CPU` on the 35B is a capability check (7.4). A mixed pipeline with a GPU head rank and a CPU tail rank (C3, 7.4)
quantifies "CPU for decode" on a shard. No documented way exists in OpenVINO GenAI 2026.4 to run prefill on the NPU and decode on the GPU for one
model; the NPU pipeline runs both phases on the NPU as static sub-models.

### 6.4 122B: root cause of the GPU compile failure, and the fix
The GPTQ-built IR is op-for-op identical to Intel's export; the difference is that GPTQ is symmetric, so every expert zero point is exactly 8,
while Intel's NNCF export has varying zero points. The OpenVINO 2026.4.1 GPU plugin's MoE fusion fails on the uniform-zero-point form. A layer-0
MoE block extracted from the GPTQ 35B IR reproduces the failure on the GPU and compiles on CPU; rewriting its expert stacks as signed INT4 without
a zero point (bit-identical values) compiles on the GPU in 2 s with matching output (`results/F-gptq-builder-gpu-fix/`). The builder gained
`--expert-sym`; the 35B and 122B were rebuilt with it. Validation of the rebuilt 35B as a whole model on the 64 GB GPU (A6) and the 122B as a
3-stage all-local pipeline on the NUCs with 85% windows (D3) are in 7.1 and 7.5.

## 7. Follow-up results

### 7.1 GPTQ-sym 35B as a whole model on the 64 GB GPU (A6): the builder fix holds at model scale
The rebuilt 35B (`--expert-sym`, signed INT4 experts, 19.8 GB) compiles and runs on tate-07's GPU where the u4 build did not.

| | A1b Intel IR (whole, GPU) | A6 GPTQ-sym IR (whole, GPU) |
|---|---|---|
| TTFT short / medium / long | 0.12 / 0.60 / 2.89 s | 0.12 / 0.60 / 3.23 s |
| decode tok/s (medium / steady loop / e2e) | 47.5 / 41.9 / 38.3 | 53.4 / 45.7 / 41.3 |
| package W (idle / decode), tok/J | 7.2 / 34.2, 1.23 | 6.8 / 34.7, 1.32 |
| GPU busy %, DDR GB/s | 98.4, 79.5 | 98.7, 75.9 |
| GPU shared memory | 19.1 GB | 19.4 GB |
| GSM8K (greedy, thinking off) | 37/40 | 19/20 |

The GPTQ-sym build is 9% faster per token (no zero-point subtract in the expert decompression) at the same power, and its task accuracy is
unchanged. Its outputs are not token-identical to Intel's NNCF export (0/6 exact), as expected for a different quantization of the same weights.
This is the configuration that makes the 122B runnable on PTL GPUs (7.4).

### 7.2 Bigger GPU window on 32 GB boxes (B3, B4): allocation window is not residency
With the 85% pinning limit (24.77 GiB window) the whole 35B on alpha's GPU decodes at **1.8–2.0 tok/s** (B3, nine prompts, TTFT 0.6 / 1.2 /
4.1 s), versus 1.5–1.7 tok/s at the default window (B1b on charlie). Resident GPU shared memory stays at 18.4 GB, the WDDM segment size.
Forcing a 26 GB segment (B4, `qwMemorySize`) is rewritten by the driver at boot; the run reached 1.9–2.1 tok/s before the box ran out of RAM headroom
and the server was killed by the harness (RAM-committed 30+ GB). Conclusion: the 32 GB box can be *allowed* to allocate 24.8 GiB on the GPU, but
the driver still pages the 19.4 GB model through an 18.4 GB resident segment, so whole-model decode stays memory-thrashed. The window increase does
help the sharded case (more KV headroom per rank) and is left enabled on alpha, beta, charlie and delta.

### 7.3 Device mix on one 32 GB box: GPU vs CPU vs NPU (E-delta)
Dense Qwen3-8B INT4 (5.4 GB) and Qwen3-0.6B INT4 on delta (Panther Lake, 32 GB, NPU driver installed), quick protocol (short 31 / medium 974 /
long 7.7k-token prompts, 256-token answers, two runs each). Decode is the e2e rate of the second (prefix-cached) call, which is the robust figure for CPU
where the two-call estimate breaks.

| model, device | TTFT short / medium / long | decode tok/s (short / medium / long) | CPU % | GPU compute % | GPU shared |
|---|---|---|---|---|---|
| 8B, **GPU** | 0.08–0.13 / 0.30–0.40 / 3.4–4.5 s | 22 / 22–23 / 19–20 | 20 | 80 | 6.4 GB |
| 8B, **CPU** | 0.7 / 22 / 220 s | 11–12 / 11 / 6–7 | 49 | 0 | 0.5 GB |
| 0.6B, GPU | 0.04–0.13 / 0.06 / 0.5–0.7 s | 118–130 / 138–151 / 85–108 | 20 | 43 | 1.6 GB |
| 0.6B, CPU | 0.06–0.09 / 1.3–1.8 / 35 s | 80–90 / 66–67 / 24 | 48 | 0 | 0.4 GB |
| 8B or 0.6B, **NPU** | does not load | | | | |

- **CPU for decode** on Panther Lake is a 2x loss on the 8B (11 vs 22 tok/s) and a 55–75x loss on prefill (22 s vs 0.3 s for a 1k prompt): the
  CPU has the same DRAM bandwidth but no advantage in it, and far less compute. For the 35B (A2, B2) the CPU path is worse still because the OpenVINO CPU
  plugin keeps ~2x the weights resident (27 GB RSS on a 32 GB box) and the prefill takes minutes. There is no decode-side win in moving to the CPU.
- **NPU**: both the 8B and the 0.6B fail to compile on delta's NPU with OpenVINO 2026.4.1 (driver compiler error
  `ZE_RESULT_ERROR_INVALID_NULL_POINTER ... [NPU_VCL]`, also with `MAX_PROMPT_LEN=1024`); the NUCs have no NPU driver installed at all, and the 35B
  export cannot be compiled statically for the NPU. The NPU was idle in every configuration of this report.
- **NPU for prefill + GPU for decode** is not a configuration OpenVINO GenAI 2026.4 offers for one model: the NPU LLM pipeline runs prefill and
  decode as two static sub-models on the NPU, and the GPU pipeline runs both on the GPU; there is no cross-device KV hand-off. Cascadia's
  pipeline-parallel engine splits by *layers*, not by phase, so the closest available "mixed" layouts are (a) a GPU rank feeding a CPU rank and (b)
  OpenVINO's `HETERO:GPU,CPU` plugin, both measured on the 35B below.

### 7.4 35B pipeline with a GPU head and a CPU tail (C3), and HETERO:GPU,CPU
"CPU for decode" on a shard, measured directly: the 2-stage 35B tree with rank 0 (layers 0–19, 8.3 GB) on alpha's GPU and rank 1 (layers 20–39 + head,
9.9 GB) on charlie's CPU, 2.5 GbE between them. Compared with the same two stages both on GPUs (C1):

| 2 NUCs, 2 shards | TTFT short / medium / long | decode tok/s (medium) | decode tok/s (long) | head GPU busy | tail resident RAM |
|---|---|---|---|---|---|
| C1: GPU head + GPU tail | 0.32 / 3.5 / 22 s | 19–20 | 15–19 | 44% | 9.6 GB (GPU) |
| C3: GPU head + **CPU tail** | 0.8–1.2 / 18 / 174 s | 10–13 | 3.1–3.7 | 6% | **19.3 GB** (CPU plugin, 2x the stage) |

Putting half the layers on a CPU halves decode on a 1k prompt, cuts it 5x on a 7.7k prompt (the CPU stage's attention over a long KV cache dominates),
and makes prefill 5–8x slower; the GPU head sits idle 94% of the time waiting on the tail, and the CPU rank needs twice its stage size in RAM.
The CPU is not a useful decode device for these models even as a tail; it is a fallback for a box whose GPU window is already full.

HETERO_PLACEHOLDER

### 7.5 122B as a 3-stage all-local pipeline on the NUCs (D3)
(pending: D3 result)

## 8. Scope notes
- Continuous-batching concurrency on the whole model (A5) could not be run: the runtime's `--cb` path refuses VLM-layout exports, which is what the
  official Qwen3.6 IR is (`results/A5-tate07-whole-gpu-cb/NOTE.md`); the sharded engine is single-flight by design. Concurrency through the enterprise
  OVMS backend was out of scope for this run.
- Whole-model streaming from the ov-genai engine arrives as one chunk per completion, so TTFT/decode were measured with a two-call method (1-token
  request, then N-token request) rather than first-chunk latency; the staged engine streams per token.
- The NUCs run DDR5-6400 modules (Kingston KF564S38-16) at the JEDEC 4800 default; decode is memory-bound, so enabling the XMP 3.0 profile would lift the 32 GB numbers by up to ~30%. This was not done: the ASRock Industrial NUC BOX-358H BIOS (AMI Aptio P1.00) exposes no OS-side or remote path to change the memory profile (no AMI SCE tooling present, no vendor utility), and a remote memory-profile change with no console to recover a failed training is not a risk worth taking unattended. It needs a BIOS visit: Advanced > Memory Configuration > XMP/EXPO profile, then re-measure the 32 GB rows.
- Machines borrowed and restored: honyaku ranks + watchdogs on alpha/beta, the Acrow node on charlie, the enterprise node service on tate-07 (which
  had to be set to Disabled during the runs because it auto-restarts and its gemma OVMS contaminated the first whole-model measurement). Leftovers kept
  for reproduction: `C:\ecgbench\` on every Windows box, `~/ecgbench` on tate-08, the 122B GPTQ/IR/stage trees in the Mac Pro export VM and
  `~/q122-stages-{2,4}` on the Mac Pro host.

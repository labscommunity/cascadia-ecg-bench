# Cascadia on Panther Lake — sharded vs. whole-model serving (one-pager, 2026-11-11)

**Hardware.** Three 32 GB Intel Core Ultra X7 358H NUCs (Arc B390 iGPU, 17.2 GiB GPU budget as shipped, 26.1 GiB after the window fix, 2.5 GbE) and one 64 GB X7 358H in Intel Tiber (52 GB GPU window).
**Software.** Cascadia runtime v0.2.7 (OpenVINO GenAI 2026.4.1), official INT4 Qwen3.6-35B-A3B IR (19.4 GB), greedy, thinking off, SoC Watch power.

## Qwen3.6-35B-A3B — what each layout delivers (single stream)

| Layout | TTFT @ 1k-token prompt | Decode tok/s | Package power | tok/J | GPU memory per box | GSM8K-40 |
|---|---|---|---|---|---|---|
| Whole model, one 64 GB box (GPU) | 0.60 s | 42–48 | 34 W | 1.23 | 19.1 GB | 37/40 |
| 2 or 3 shards co-located on the 64 GB box | 1.56 s | 27 | 30 W | 0.9 | 18.4 GB | 36/40 |
| Whole model, one 32 GB NUC (GPU) | 1.29 s | **1.7** (oversubscribed) | 23 W | 0.07 | 17.9 GB | — |
| Whole model, one 32 GB NUC (GPU), **GPU window raised to 85%** | 0.75 s | **30–33** | 33.5 W | 0.91 | 19.0 GB | 6/6 identical to 64 GB box |
| Whole model, one 32 GB NUC (CPU) | 53 s | ~12 e2e, RAM saturated | — | — | 27 GB RSS | — |
| 2 shards, one per NUC (2.5 GbE) | 3.5 s | 19 | 31 W total (15 + 16) | 0.61 | 9.1 GB | — |
| 3 shards, one per NUC | 3.5 s | 18 | 28 W total (9 + 9 + 10) | 0.66 | 6.1 GB | 36/40 |

- **32 GB nodes cannot serve the 35B alone as shipped** (19.4 GB > 17.2 GiB video-memory budget): 1.7 tok/s on GPU, minute-long first tokens on CPU.
  **With the dxgkrnl commit limit at 85% (one registry value + reboot) the same NUC serves it whole at 30–33 tok/s**, 70% of the 64 GB box.
- **Sharding across 2–3 NUCs makes it work: 18–19 tok/s, 11x the single-NUC whole model**, same task accuracy, 6–9 GB and 9–15 W per node.
- **A 64 GB node is 2.3x faster and 2x more energy-efficient per stream** than the NUC chain; sharding on one box costs 35% decode and 2.6x TTFT.
- **Sharding hurts prefill most**: TTFT on a 7.7k-token prompt goes from 2.9 s (whole) to 11 s (co-located) and 22–31 s (across NUCs).
- **Accuracy**: sharded outputs are not token-identical to the whole model (f16 near-tie flips after the first sentence) but task accuracy is unchanged
  (36/40 vs 37/40); the whole model is deterministic run-to-run (6/6 exact).
- **NPU** is idle in every configuration; CPU load is 5–17% on GPU layouts. Decode is memory-bandwidth-bound (77 GB/s DDR on the 64 GB box).

## Qwen3.5-122B-A10B
- INT4 IR = **64.3 GB** (built here from the GPTQ-Int4 checkpoint; no public OpenVINO IR exists). It fits **no single Panther Lake box** (52 GB GPU window /
  61 GB RAM at 64 GB; 17.7 GB at 32 GB); the smallest GPU layouts are 2 x 64 GB boxes (29 + 33 GB) or 3 NUCs + a 64 GB tail (12–26 GB per stage).
- **Build:** the IR comes from the runtime's GPTQ-to-OpenVINO builder with `--expert-sym` (signed INT4 experts; the OpenVINO 2026.4.1 GPU MoE fusion rejects a uniform
  zero point). **All-local on three 32 GB NUCs: 10.6 tok/s** (stages 20.7 / 24.7 / 25.0 GB inside 26.1 GiB budgets, GPU keep-alive on), GSM8K-20 17/20 (3 misses = 400-token
  truncations; 35B: 18–19/20 on the same questions). With a 64 GB Tiber box as the tail over the relay: 1.2–2.7 tok/s (two 110–350 ms hops per token).
- On the vendor's benchmarks the 122B-A10B is 1–3 points ahead of the 35B-A3B on knowledge/reasoning and behind on coding/agentic tasks, at 3.3x the
  weights and 3.3x the active parameters per token (~3x slower per stream on the same silicon).

## Configuration and the current numbers
- **GPU memory window.** The 32 GB boxes run with dxgkrnl's `GraphicsDrivers\MemoryManager\SystemPartitionCommitLimitPercentage` = 85 (Intel's INF installs 57; the
  Intel Graphics Software "Shared GPU Memory Override" slider writes it). Per-process GPU budget 26.1 GiB. **Whole 35B on one NUC: 30–33 tok/s**, 0.75 s TTFT at 1k
  tokens, 33.5 W, output byte-identical to the 64 GB box.
- **122B on three NUCs, all-local: 10.6 tok/s** (TTFT 0.62 / 5.5 / 41 s on 31 / 975 / 7.7k tokens), 58 W for the chain, GSM8K-20 17/20. The IR is built with the
  runtime's GPTQ-to-OpenVINO builder and `--expert-sym` (the GPU MoE fusion needs signed experts); the ranks run with `CASCADIA_QWEN36_GPU_KEEPALIVE_MS=2`,
  which keeps each iGPU busy while it waits on the other boxes (an idle iGPU holding 20–25 GB is charged ~0.5 s on 40–50% of its next steps).
- **Concurrency (OVMS continuous batching, 64 GB box):** 32 tok/s at 1 stream, 132 tok/s combined at 8 streams (16.6 each) at 34–36 W.
- **Device mix:** GPU 22 tok/s vs CPU 11 on a dense 8B (prefill 0.3 s vs 22 s at 1k tokens); a 35B shard pair with its tail on a CPU runs at 10–13 tok/s vs 19 all-GPU;
  the NPU does not load these models (OpenVINO 2026.4.1); `HETERO:GPU,CPU` places everything on the GPU. No engine splits prefill and decode across devices.
- **Speculative decoding is a net loss here:** GenAI prompt lookup 31–32 tok/s vs 47 on the whole 35B (64 GB box); staged n-gram speculation 14–15 vs 31.6 on the
  co-located 35B and 0.55x on the 122B chain (acceptance 2–23%, DeltaNet snapshot/rollback). A draft model is refused on VLM-layout exports. Off by default.
- **GPU clocks are not a lever:** pinning the iGPU at 2.5 GHz or raising the OpenVINO queue priority changes nothing on either model.

## ECG takeaways
1. Raise the GPU memory window on every 32 GB box first (`SystemPartitionCommitLimitPercentage` = 85): a single NUC then serves the 35B whole at 30–33 tok/s.
   Sharding still works (3 NUCs = 18 tok/s, 28 W, 6 GB per box) and is what makes the 122B run (3 NUCs, 2.9–3.3 tok/s), but it is no longer the only option for the 35B.
2. If one 64 GB box fits the budget, use it whole: faster, more efficient, and it supports multi-stream serving via OVMS.
3. Keep shards on a local 2.5 GbE segment and keep prompts short (prefill is the sharding tax); validate with task-level accuracy, not token parity.
4. Default to Qwen3.6-35B-A3B; the 122B now runs (builder fixed) on three 32 GB NUCs at ~3 tok/s and scored the same as the 35B on GSM8K-20, so it is a selective upgrade at ~10x the per-token cost.

Repo: github.com/labscommunity/cascadia-ecg-bench (harness, raw results, full report, published-benchmark tables).

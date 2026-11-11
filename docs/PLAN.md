# Test plan (from the "Cascadia ECG Benchmarking" doc)

## KPIs
- LLM performance: TTFT (streaming, first content delta) and decode tok/s (greedy, thinking off), short / medium (~700 tok) / long (~4.5k tok) prompts; concurrency where the engine supports it.
- Power: Intel SoC Watch package power (mW avg) and DDR bandwidth during sustained decode; idle baseline with the model loaded.
- Utilization: CPU %, GPU engine utilization (3D/compute/copy), NPU engine (neural) utilization, GPU shared memory, process working set, system committed memory (1 s sampler).
- Sharded vs whole-model: side-by-side greedy outputs (exact match + common prefix), performance multiplier (tok/s, TTFT) and utilization multiplier (memory, bandwidth, power) vs. number of shards.
- Capability from model size: GSM8K subset (40 problems, exact match), plus published model-card benchmarks.

## Matrix
| # | Model | Where | Config | Engine |
|---|---|---|---|---|
| A1 | Qwen3.6-35B-A3B int4 | tate-07 (64 GB) | whole model, GPU | ov-genai |
| A2 | " | tate-07 | whole model, CPU | ov-genai |
| A3 | " | tate-07 | 2 shards co-located, one XPU | qwen35 (`run` on a 2-stage tree) |
| A4 | " | tate-07 | 3 shards co-located, one XPU | qwen35 (3-stage tree) |
| B1 | " | charlie (32 GB) | whole model, GPU (expected not to fit: 19.4 GB > 16.5 GiB GPU-visible) | ov-genai |
| B2 | " | charlie (32 GB) | whole model, CPU (expected not to fit: ~40 GB RSS) | ov-genai |
| B3 | " | charlie (32 GB) | 2 shards co-located (same memory as whole) | qwen35 |
| C1 | " | alpha + charlie | 2 shards, one per NUC, 2.5 GbE | qwen35 worker chain |
| C2 | " | alpha + beta + charlie | 3 shards, one per NUC | qwen35 worker chain |
| D0 | Qwen3.5-122B-A10B int4 | sizing | int4 IR ~63–70 GB: does not fit 64 GB whole; needs >=4 x 32 GB GPU windows | analysis |
| D1 | " | alpha + beta + charlie + tate-07 | 4 shards (3 NUCs + 64 GB box, uneven split) | qwen35 worker chain |
| E | both | best config each | GSM8K-40 capability eval | — |

## Protocol
1 warmup + 3 repeats per prompt (medians reported), max_tokens 128/256/256, greedy, thinking off, prefix cache off for the staged engine.
Power/utilization: 60 s SoC Watch window + 1 s sampler during a continuous decode loop on the medium prompt; 30 s idle window with the model loaded.
Chain runs: start the last rank first; the API lives on rank 0; the client runs on rank 0's box (loopback) so network latency between client and server is excluded.

## Performance (medians of 3 repeats; greedy, thinking off)

| config | TTFT short (31 tok) | TTFT medium (975 tok) | TTFT long (7.7k tok) | decode tok/s (medium) | decode tok/s (steady loop) | e2e tok/s (steady, incl. prefill) |
|---|---|---|---|---|---|---|
| A1b-tate07-whole-gpu | 0.12 s | 0.60 s | 2.89 s | 47.5 | 41.9 | 38.3 |
| A3-tate07-2shard-colocated | 0.26 s | 1.56 s | 11.37 s | 34.0 | 27.3 | 23.5 |
| A4-tate07-3shard-colocated | 0.28 s | 1.58 s | 11.54 s | 32.7 | 27.1 | 23.1 |
| A2-tate07-whole-cpu | 1.32 s | 40.25 s | 347.20 s |  |  | 12.5 |
| B1b-charlie-whole-gpu | 0.67 s | 1.29 s | 4.23 s | 1.7 |  |  |
| B2-charlie-whole-cpu | 1.72 s | 52.69 s | 446.94 s |  |  |  |
| C1-2nuc-2shard | 0.32 s | 3.54 s | 22.24 s | 20.1 | 18.8 | 15.3 |
| C2-3nuc-3shard | 0.86 s | 3.48 s | 31.19 s | 17.8 | 18.1 | 13.8 |
| A1c-tate07-whole-gpu-rerun | 0.12 s | 0.61 s | 3.27 s | 48.0 | 42.7 | 38.9 |
| A6-tate07-whole-gpu-gptq-sym | 0.12 s | 0.60 s | 3.23 s | 53.4 | 45.7 | 41.3 |
| B3-alpha-whole-gpu-pin85 | 0.59 s | 1.18 s | 4.16 s | 1.9 |  |  |
| B4-alpha-whole-gpu-pin85-seg26 | 0.52 s | 1.20 s | 4.06 s | 2.1 |  |  |
| B5-alpha-whole-gpu-commit85 | 0.15 s | 0.75 s | 3.90 s | 33.2 | 30.4 | 27.8 |
| B5a-alpha-whole-gpu-commit85-honyaku-coresident | 0.15 s | 0.77 s | 3.97 s | 33.2 | 30.4 | 27.7 |
| C3-mixed-alphaGPU-charlieCPU | 1.01 s | 18.00 s | 174.39 s | 11.4 |  |  |
| D2sym-122b-4stage-3nuc-tate07 | 2.04 s | 18.50 s | 122.60 s | 2.0 |  |  |
| D3-122b-3stage-3nuc | 3.84 s | 12.15 s | 79.36 s | 0.6 |  |  |
| D3b-122b-3stage-3nuc-commit85 | 1.33 s | 6.15 s | 44.23 s | 3.2 | 2.9 | 2.7 |
| E-charlie-35b-hetero3 | 0.73 s | 1.34 s | 3.97 s | 1.4 |  |  |
| E-delta-q3-0.6b-CPU | 0.07 s | 1.52 s | 35.52 s | 118.1 |  |  |
| E-delta-q3-0.6b-GPU | 0.09 s | 0.06 s | 0.60 s | 149.2 |  |  |
| E-delta-q3-8b-CPU | 0.73 s | 22.15 s | 222.70 s | 258.4 |  |  |
| E-delta-q3-8b-GPU | 0.11 s | 0.35 s | 3.99 s | 22.9 |  |  |

## Power and utilization (60 s SoC Watch window during sustained decode; 30 s idle with model loaded; for pipelines decode W = sum over ranks, memory = head rank)

| config | idle W | decode W | tok/J | DDR GB/s (decode) | CPU % | GPU busy % | GPU copy % | NPU % | GPU shared mem GB | process WS GB | committed GB |
|---|---|---|---|---|---|---|---|---|---|---|---|
| A1b-tate07-whole-gpu | 7.2 | 34.2 | 1.23 | 79.5 | 16.4 | 98.4 | 8.2 |  | 19.1 | 19.8 | 33.1 |
| A3-tate07-2shard-colocated | 6.8 | 30.9 | 0.88 | 57.5 | 16.95 | 100.4 | 86.0 | 0.0 | 18.4 | 18.8 | 32.1 |
| A4-tate07-3shard-colocated | 7.4 | 30.0 | 0.9 | 55.98 | 16.6 | 97.65 | 86.3 | 0.0 | 18.4 | 18.8 | 32.1 |
| A2-tate07-whole-cpu | 6.5 | 40.7 |  | 13.15 | 60.45 | 0.0 | 0.0 | 0.0 | 0.3 | 40.4 | 36.8 |
| B1b-charlie-whole-gpu | 3.0 | 23.0 |  | 8.08 | 20.35 | 95.4 | 1.2 |  | 17.9 | 19.5 | 23.2 |
| B2-charlie-whole-cpu |  |  |  |  |  |  |  |  |  |  |  |
| C1-2nuc-2shard | 3.4 | 30.7 | 0.61 | 12.75 | 7.95 | 43.85 | 41.3 | 0.0 | 9.1 | 9.6 | 13.3 |
| C2-3nuc-3shard | 3.5 | 27.6 | 0.65 | 8.5 | 5.25 | 28.9 | 27.65 | 0.0 | 6.1 | 6.6 | 10.3 |
| A1c-tate07-whole-gpu-rerun |  | 34.7 | 1.23 | 81.13 | 17.35 | 97.3 | 8.6 | 0.0 | 19.1 | 19.5 | 32.9 |
| A6-tate07-whole-gpu-gptq-sym | 6.8 | 34.7 | 1.32 | 75.89 | 16.5 | 98.7 | 9 | 0 | 19.4 | 19.9 | 33.0 |
| B3-alpha-whole-gpu-pin85 | 3.7 | 25.4 |  | 7.39 | 21.15 | 107.25 | 1.5 | 0.0 | 17.9 | 19.6 | 23.2 |
| B4-alpha-whole-gpu-pin85-seg26 | 8.6 | 3.2 |  | 0.24 | 0.8 | 0.0 | 0.0 | 0.0 | 0.0 | 5.5 | 9.0 |
| B5-alpha-whole-gpu-commit85 | 3.3 | 33.5 | 0.91 | 56.11 | 14.1 | 97.8 | 5.7 | 0 | 19.0 | 19.6 | 23.2 |
| B5a-alpha-whole-gpu-commit85-honyaku-coresident | 7.1 | 33.9 | 0.9 | 56.2 | 14.45 | 97.75 | 5.8 | 0.0 | 24.4 | 24.7 | 28.7 |
| C3-mixed-alphaGPU-charlieCPU |  |  |  |  |  |  |  |  |  |  |  |
| D2sym-122b-4stage-3nuc-tate07 | 3.1 | 6.8 |  | 2.53 | 3.6 | 4.55 | 3.6 | 0.0 | 13.1 | 13.5 | 17.0 |
| D3-122b-3stage-3nuc | 3.3 |  |  |  |  |  |  |  |  |  |  |
| D3b-122b-3stage-3nuc-commit85 | 3.3 | 24.3 | 0.12 | 4.85 | 4.35 | 9.75 | 7.5 | 0.0 | 20.5 | 20.8 | 24.4 |
| E-charlie-35b-hetero3 |  |  |  |  |  |  |  |  |  |  |  |
| E-delta-q3-0.6b-CPU |  |  |  |  |  |  |  |  |  |  |  |
| E-delta-q3-0.6b-GPU |  |  |  |  |  |  |  |  |  |  |  |
| E-delta-q3-8b-CPU |  |  |  |  |  |  |  |  |  |  |  |
| E-delta-q3-8b-GPU |  |  |  |  |  |  |  |  |  |  |  |

## Per-rank package power during chain decode (W)

- C1-2nuc-2shard: rank0 15.0 W, rank1 15.7 W -> total 30.7 W
- C2-3nuc-3shard: rank0 9.0 W, rank1 9.1 W, rank2 9.5 W -> total 27.6 W
- D3b-122b-3stage-3nuc-commit85: rank0 8.7 W, rank1 8.9 W, rank2 6.7 W -> total 24.3 W

## Sharding multipliers (relative to the whole model on the 64 GB box, A1b)

| config | shards | decode tok/s | TTFT medium | TTFT long | decode power (total) | tok/J | GPU memory (total across boxes) |
|---|---|---|---|---|---|---|---|
| A3-tate07-2shard-colocated | 2 | 0.65x | 2.60x | 3.93x | 0.90x | 0.72x | 0.96x |
| A4-tate07-3shard-colocated | 3 | 0.65x | 2.63x | 3.99x | 0.88x | 0.73x | 0.96x |
| A2-tate07-whole-cpu | 1 |  | 67.08x | 120.14x | 1.19x |  | 0.02x |
| B1b-charlie-whole-gpu | 1 |  | 2.15x | 1.46x | 0.67x |  | 0.94x |
| B2-charlie-whole-cpu | 1 |  | 87.82x | 154.65x |  |  |  |
| C1-2nuc-2shard | 2 | 0.45x | 5.90x | 7.70x | 0.90x | 0.50x | 0.96x |
| C2-3nuc-3shard | 3 | 0.43x | 5.80x | 10.79x | 0.81x | 0.53x | 0.96x |
| A1c-tate07-whole-gpu-rerun | 1 | 1.02x | 1.02x | 1.13x | 1.01x | 1.00x | 1.00x |
| A6-tate07-whole-gpu-gptq-sym | 1 | 1.09x | 1.00x | 1.12x | 1.01x | 1.07x | 1.02x |
| B3-alpha-whole-gpu-pin85 | 1 |  | 1.97x | 1.44x | 0.74x |  | 0.94x |
| B4-alpha-whole-gpu-pin85-seg26 | 1 |  | 2.00x | 1.40x | 0.09x |  |  |
| B5-alpha-whole-gpu-commit85 | 1 | 0.72x | 1.25x | 1.35x | 0.98x | 0.74x | 0.99x |
| B5a-alpha-whole-gpu-commit85-honyaku-coresident | 1 | 0.73x | 1.28x | 1.37x | 0.99x | 0.73x | 1.28x |
| C3-mixed-alphaGPU-charlieCPU | 2 |  | 30.00x | 60.34x |  |  |  |
| D2sym-122b-4stage-3nuc-tate07 | 4 |  | 30.83x | 42.42x | 0.20x |  | 0.69x |
| D3-122b-3stage-3nuc | 3 |  | 20.25x | 27.46x |  |  |  |
| D3b-122b-3stage-3nuc-commit85 | 3 | 0.07x | 10.25x | 15.30x | 0.71x | 0.10x | 3.16x |
| E-charlie-35b-hetero3 | 1 |  | 2.23x | 1.37x |  |  |  |
| E-delta-q3-0.6b-CPU | 1 |  | 2.53x | 12.29x |  |  |  |
| E-delta-q3-0.6b-GPU | 1 |  | 0.10x | 0.21x |  |  |  |
| E-delta-q3-8b-CPU | 1 |  | 36.92x | 77.06x |  |  |  |
| E-delta-q3-8b-GPU | 1 |  | 0.58x | 1.38x |  |  |  |

## Output parity vs. the whole model (same greedy prompts, 160 tokens)

| config | prompts | exact match | mean common-prefix fraction |
|---|---|---|---|
| A1c-tate07-whole-gpu-rerun (whole model again after a server restart, same client method = determinism check) | 6 | 6/6 | 1.0 |
| A1-tate07-whole-gpu (whole model, first client: streaming request path = request-path sensitivity) | 6 | 0/6 | 0.068 |
| A3-tate07-2shard-colocated | 6 | 0/6 | 0.085 |
| A4-tate07-3shard-colocated | 6 | 0/6 | 0.085 |
| A2-tate07-whole-cpu | 6 | 0/6 | 0.106 |
| C1-2nuc-2shard | 6 | 0/6 | 0.085 |
| C2-3nuc-3shard | 6 | 0/6 | 0.085 |
| A1c-tate07-whole-gpu-rerun | 6 | 6/6 | 1.0 |
| A6-tate07-whole-gpu-gptq-sym | 6 | 0/6 | 0.028 |
| B3-alpha-whole-gpu-pin85 | 6 | 6/6 | 1.0 |
| B4-alpha-whole-gpu-pin85-seg26 | 0 | 0/0 | 0.0 |
| B5-alpha-whole-gpu-commit85 | 6 | 6/6 | 1.0 |
| B5a-alpha-whole-gpu-commit85-honyaku-coresident | 6 | 6/6 | 1.0 |
| D2sym-122b-4stage-3nuc-tate07 | 6 | 0/6 | 0.025 |
| D3b-122b-3stage-3nuc-commit85 | 6 | 0/6 | 0.025 |

## GSM8K-40 (exact match, greedy, thinking off, max 512 tokens)

| run | correct | accuracy | completion tokens | wall s |
|---|---|---|---|---|
| A1-tate07-whole-gpu-eval | 37/40 | 92.5% | 11923 | 279.5 |
| A3-tate07-2shard-colocated-eval | 36/40 | 90.0% | 12274 | 369.8 |
| A6-tate07-whole-gpu-gptq-sym-eval | 19/20 | 95.0% | 5697 | 119.0 |
| C2-3nuc-3shard-eval | 36/40 | 90.0% | 12274 | 1080.4 |
| D2sym-122b-4stage-3nuc-tate07-eval | 17/20 | 85.0% | 5482 | 3463.3 |
| D3b-122b-3stage-3nuc-commit85-eval | 17/20 | 85.0% | 5482 | 2437.9 |

Notes: B1b-charlie-whole-gpu: power/utilization from the B1 window (same server state); steady decode there was measured end-to-end

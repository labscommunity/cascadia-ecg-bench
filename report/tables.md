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
| B6-beta-whole-gpu-pin | 0.15 s | 0.78 s | 3.92 s | 33.0 |  |  |
| C3-mixed-alphaGPU-charlieCPU | 1.01 s | 18.00 s | 174.39 s | 11.4 |  |  |
| D2sym-122b-4stage-3nuc-tate07 | 2.04 s | 18.50 s | 122.60 s | 2.0 |  |  |
| D3-122b-3stage-3nuc | 3.84 s | 12.15 s | 79.36 s | 0.6 |  |  |
| D3b-122b-3stage-3nuc-commit85 | 1.33 s | 6.15 s | 44.23 s | 3.2 | 2.9 | 2.7 |
| D3k-122b-3stage-3nuc-keepalive | 0.63 s | 5.53 s | 41.30 s | 10.6 | 10.6 | 8.6 |
| E-charlie-35b-hetero3 | 0.73 s | 1.34 s | 3.97 s | 1.4 |  |  |
| E-delta-q3-0.6b-CPU | 0.07 s | 1.52 s | 35.52 s | 118.1 |  |  |
| E-delta-q3-0.6b-GPU | 0.09 s | 0.06 s | 0.60 s | 149.2 |  |  |
| E-delta-q3-8b-CPU | 0.73 s | 22.15 s | 222.70 s | 258.4 |  |  |
| E-delta-q3-8b-GPU | 0.11 s | 0.35 s | 3.99 s | 22.9 |  |  |
| G1-122b-3nuc-pin2500 | 1.84 s | 6.11 s | 42.50 s | 1.8 |  |  |
| G2-122b-3nuc-throttle-high | 2.05 s | 7.03 s | 47.86 s | 2.6 |  |  |
| K1-122b-3nuc-keepalive5 | 0.69 s | 5.62 s | 44.65 s | 5.1 |  |  |
| K3-122b-3nuc-keepalive5-pin2500 | 0.62 s | 5.47 s | 40.98 s | 10.5 |  |  |
| K4-122b-3nuc-keepalive25 | 0.90 s | 5.91 s | 48.38 s | 3.6 |  |  |
| K5-122b-3nuc-keepalive2 | 0.62 s | 5.51 s | 41.11 s | 10.5 |  |  |
| P0-122b-3nuc-newbin-base | 1.81 s | 7.40 s | 51.50 s | 3.0 |  |  |
| P1-122b-3nuc-spec-n3k5 | 1.99 s | 7.27 s | 51.56 s | 1.6 |  |  |
| S0-tate07-35b-worker-base | 0.13 s | 0.62 s | 3.21 s | 48.2 |  |  |
| S0b-tate07-35b-worker-base-nonce | 0.31 s | 0.75 s | 3.28 s | 43.0 |  |  |
| S0c-tate07-35b-worker-base-newbin | 0.11 s | 0.61 s | 3.25 s | 47.3 |  |  |
| S1p-tate07-35b-prompt-lookup3-k5 | 0.13 s | 1.22 s | 9.84 s | 30.9 |  |  |
| S2p-tate07-35b-prompt-lookup2-k8 | 0.12 s | 1.22 s | 9.72 s | 31.9 |  |  |
| S7p-tate07-35b-staged3-base | 0.30 s | 0.33 s | 0.59 s | 31.6 |  |  |
| S8p-tate07-35b-staged3-spec-n3k5 | 0.33 s | 0.36 s | 0.64 s | 14.8 |  |  |

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
| B6-beta-whole-gpu-pin |  |  |  |  |  |  |  |  |  |  |  |
| C3-mixed-alphaGPU-charlieCPU |  |  |  |  |  |  |  |  |  |  |  |
| D2sym-122b-4stage-3nuc-tate07 | 3.1 | 6.8 |  | 2.53 | 3.6 | 4.55 | 3.6 | 0.0 | 13.1 | 13.5 | 17.0 |
| D3-122b-3stage-3nuc | 3.3 |  |  |  |  |  |  |  |  |  |  |
| D3b-122b-3stage-3nuc-commit85 | 3.3 | 24.3 | 0.12 | 4.85 | 4.35 | 9.75 | 7.5 | 0.0 | 20.5 | 20.8 | 24.4 |
| D3k-122b-3stage-3nuc-keepalive | 3.7 | 58.1 | 0.18 | 16.66 | 6.1 | 95.45 | 87.2 | 0.0 | 20.6 | 20.9 | 24.6 |
| E-charlie-35b-hetero3 |  |  |  |  |  |  |  |  |  |  |  |
| E-delta-q3-0.6b-CPU |  |  |  |  |  |  |  |  |  |  |  |
| E-delta-q3-0.6b-GPU |  |  |  |  |  |  |  |  |  |  |  |
| E-delta-q3-8b-CPU |  |  |  |  |  |  |  |  |  |  |  |
| E-delta-q3-8b-GPU |  |  |  |  |  |  |  |  |  |  |  |
| G1-122b-3nuc-pin2500 |  | 33.2 |  |  |  |  |  |  |  |  |  |
| G2-122b-3nuc-throttle-high |  | 27.9 |  |  |  |  |  |  |  |  |  |
| K1-122b-3nuc-keepalive5 |  | 34.2 |  |  |  |  |  |  |  |  |  |
| K3-122b-3nuc-keepalive5-pin2500 |  | 55.5 |  |  |  |  |  |  |  |  |  |
| K4-122b-3nuc-keepalive25 |  | 25.9 |  |  |  |  |  |  |  |  |  |
| K5-122b-3nuc-keepalive2 |  | 57.8 |  |  |  |  |  |  |  |  |  |
| P0-122b-3nuc-newbin-base |  |  |  |  |  |  |  |  |  |  |  |
| P1-122b-3nuc-spec-n3k5 |  | 26.6 |  |  |  |  |  |  |  |  |  |
| S0-tate07-35b-worker-base |  |  |  |  |  |  |  |  |  |  |  |
| S0b-tate07-35b-worker-base-nonce |  |  |  |  |  |  |  |  |  |  |  |
| S0c-tate07-35b-worker-base-newbin |  |  |  |  |  |  |  |  |  |  |  |
| S1p-tate07-35b-prompt-lookup3-k5 |  |  |  |  |  |  |  |  |  |  |  |
| S2p-tate07-35b-prompt-lookup2-k8 |  |  |  |  |  |  |  |  |  |  |  |
| S7p-tate07-35b-staged3-base |  |  |  |  |  |  |  |  |  |  |  |
| S8p-tate07-35b-staged3-spec-n3k5 |  |  |  |  |  |  |  |  |  |  |  |

## Per-rank package power during chain decode (W)

- C1-2nuc-2shard: rank0 15.0 W, rank1 15.7 W -> total 30.7 W
- C2-3nuc-3shard: rank0 9.0 W, rank1 9.1 W, rank2 9.5 W -> total 27.6 W
- D3b-122b-3stage-3nuc-commit85: rank0 8.7 W, rank1 8.9 W, rank2 6.7 W -> total 24.3 W
- D3k-122b-3stage-3nuc-keepalive: rank0 19.9 W, rank1 18.8 W, rank2 19.4 W -> total 58.1 W
- G1-122b-3nuc-pin2500: rank0 13.1 W, rank1 8.6 W, rank2 11.5 W -> total 33.2 W
- G2-122b-3nuc-throttle-high: rank0 10.2 W, rank1 8.7 W, rank2 9.0 W -> total 27.9 W
- K1-122b-3nuc-keepalive5: rank0 12.6 W, rank1 10.4 W, rank2 11.2 W -> total 34.2 W
- K3-122b-3nuc-keepalive5-pin2500: rank0 19.4 W, rank1 17.2 W, rank2 18.9 W -> total 55.5 W
- K4-122b-3nuc-keepalive25: rank0 9.4 W, rank1 8.3 W, rank2 8.2 W -> total 25.9 W
- K5-122b-3nuc-keepalive2: rank0 19.9 W, rank1 18.4 W, rank2 19.5 W -> total 57.8 W
- P1-122b-3nuc-spec-n3k5: rank0 8.3 W, rank1 9.4 W, rank2 8.9 W -> total 26.6 W

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
| B6-beta-whole-gpu-pin | 1 |  | 1.30x | 1.36x |  |  |  |
| C3-mixed-alphaGPU-charlieCPU | 2 |  | 30.00x | 60.34x |  |  |  |
| D2sym-122b-4stage-3nuc-tate07 | 4 |  | 30.83x | 42.42x | 0.20x |  | 0.69x |
| D3-122b-3stage-3nuc | 3 |  | 20.25x | 27.46x |  |  |  |
| D3b-122b-3stage-3nuc-commit85 | 3 | 0.07x | 10.25x | 15.30x | 0.71x | 0.10x | 3.16x |
| D3k-122b-3stage-3nuc-keepalive | 3 | 0.25x | 9.22x | 14.29x | 1.70x | 0.15x | 3.18x |
| E-charlie-35b-hetero3 | 1 |  | 2.23x | 1.37x |  |  |  |
| E-delta-q3-0.6b-CPU | 1 |  | 2.53x | 12.29x |  |  |  |
| E-delta-q3-0.6b-GPU | 1 |  | 0.10x | 0.21x |  |  |  |
| E-delta-q3-8b-CPU | 1 |  | 36.92x | 77.06x |  |  |  |
| E-delta-q3-8b-GPU | 1 |  | 0.58x | 1.38x |  |  |  |
| G1-122b-3nuc-pin2500 | 3 |  | 10.18x | 14.71x | 0.97x |  | 3.17x |
| G2-122b-3nuc-throttle-high | 3 |  | 11.72x | 16.56x | 0.82x |  | 3.17x |
| K1-122b-3nuc-keepalive5 | 3 |  | 9.37x | 15.45x | 1.00x |  | 3.17x |
| K3-122b-3nuc-keepalive5-pin2500 | 3 |  | 9.12x | 14.18x | 1.62x |  | 3.19x |
| K4-122b-3nuc-keepalive25 | 3 |  | 9.85x | 16.74x | 0.76x |  | 3.17x |
| K5-122b-3nuc-keepalive2 | 3 |  | 9.18x | 14.22x | 1.69x |  | 3.19x |
| P0-122b-3nuc-newbin-base | 3 |  | 12.33x | 17.82x |  |  |  |
| P1-122b-3nuc-spec-n3k5 | 3 |  | 12.12x | 17.84x | 0.78x |  | 3.17x |
| S0-tate07-35b-worker-base | 1 |  | 1.03x | 1.11x |  |  |  |
| S0b-tate07-35b-worker-base-nonce | 1 |  | 1.25x | 1.13x |  |  |  |
| S0c-tate07-35b-worker-base-newbin | 1 |  | 1.02x | 1.12x |  |  |  |
| S1p-tate07-35b-prompt-lookup3-k5 | 1 |  | 2.03x | 3.40x |  |  |  |
| S2p-tate07-35b-prompt-lookup2-k8 | 1 |  | 2.03x | 3.36x |  |  |  |
| S7p-tate07-35b-staged3-base | 1 |  | 0.55x | 0.20x |  |  |  |
| S8p-tate07-35b-staged3-spec-n3k5 | 1 |  | 0.60x | 0.22x |  |  |  |

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
| D3k-122b-3stage-3nuc-keepalive | 6 | 0/6 | 0.025 |

## GSM8K-40 (exact match, greedy, thinking off, max 512 tokens)

| run | correct | accuracy | completion tokens | wall s |
|---|---|---|---|---|
| A1-tate07-whole-gpu-eval | 37/40 | 92.5% | 11923 | 279.5 |
| A3-tate07-2shard-colocated-eval | 36/40 | 90.0% | 12274 | 369.8 |
| A6-tate07-whole-gpu-gptq-sym-eval | 19/20 | 95.0% | 5697 | 119.0 |
| C2-3nuc-3shard-eval | 36/40 | 90.0% | 12274 | 1080.4 |
| D2sym-122b-4stage-3nuc-tate07-eval | 17/20 | 85.0% | 5482 | 3463.3 |
| D3b-122b-3stage-3nuc-commit85-eval | 17/20 | 85.0% | 5482 | 2437.9 |
| D3k-122b-3stage-3nuc-keepalive-eval | 17/20 | 85.0% | 5464 | 580.9 |

Notes: B1b-charlie-whole-gpu: power/utilization from the B1 window (same server state); steady decode there was measured end-to-end

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

## Power and utilization (60 s SoC Watch window during sustained decode; 30 s idle with model loaded)

| config | idle W | decode W | tok/J | DDR GB/s (decode) | CPU % | GPU busy % | GPU copy % | NPU % | GPU shared mem GB | process WS GB | committed GB |
|---|---|---|---|---|---|---|---|---|---|---|---|
| A1b-tate07-whole-gpu | 7.2 | 34.2 | 1.23 | 79.5 | 16.4 | 98.4 | 8.2 |  | 19.1 | 19.8 | 33.1 |
| A3-tate07-2shard-colocated | 6.8 | 30.9 | 0.88 | 57.5 | 16.95 | 100.4 | 86.0 | 0.0 | 18.4 | 18.8 | 32.1 |
| A4-tate07-3shard-colocated | 7.4 | 30.0 | 0.9 | 55.98 | 16.6 | 97.65 | 86.3 | 0.0 | 18.4 | 18.8 | 32.1 |
| A2-tate07-whole-cpu | 6.5 | 40.7 |  | 13.15 | 60.45 | 0.0 | 0.0 | 0.0 | 0.3 | 40.4 | 36.8 |
| B1b-charlie-whole-gpu | 3.0 | 23.0 |  | 8.08 | 20.35 | 95.4 | 1.2 |  | 17.9 | 19.5 | 23.2 |
| B2-charlie-whole-cpu |  |  |  |  |  |  |  |  |  |  |  |
| C1-2nuc-2shard | 3.4 | 14.5 | 1.3 | 12.75 | 7.95 | 43.85 | 41.3 | 0.0 | 9.1 | 9.6 | 13.3 |
| C2-3nuc-3shard | 3.5 | 10.6 | 1.7 | 8.5 | 5.25 | 28.9 | 27.65 | 0.0 | 6.1 | 6.6 | 10.3 |
| A1c-tate07-whole-gpu-rerun |  | 34.7 | 1.23 | 81.13 | 17.35 | 97.3 | 8.6 | 0.0 | 19.1 | 19.5 | 32.9 |

## Per-rank package power during chain decode (W)

- C1-2nuc-2shard: rank0 15.0 W, rank1 15.7 W -> total 30.7 W

## Sharding multipliers (relative to the whole model on the 64 GB box, A1b)

| config | shards | decode tok/s | TTFT medium | TTFT long | decode power | tok/J | GPU shared mem |
|---|---|---|---|---|---|---|---|
| A3-tate07-2shard-colocated | 2 | 0.65x | 2.60x | 3.93x | 0.90x | 0.72x | 0.96x |
| A4-tate07-3shard-colocated | 3 | 0.65x | 2.63x | 3.99x | 0.88x | 0.73x | 0.96x |
| A2-tate07-whole-cpu | 1 |  | 67.08x | 120.14x | 1.19x |  | 0.02x |
| B1b-charlie-whole-gpu | 1 |  | 2.15x | 1.46x | 0.67x |  | 0.94x |
| B2-charlie-whole-cpu | 1 |  | 87.82x | 154.65x |  |  |  |
| C1-2nuc-2shard | 2 | 0.45x | 5.90x | 7.70x | 0.42x | 1.06x | 0.48x |
| C2-3nuc-3shard | 3 | 0.43x | 5.80x | 10.79x | 0.31x | 1.38x | 0.32x |
| A1c-tate07-whole-gpu-rerun | 1 | 1.02x | 1.02x | 1.13x | 1.01x | 1.00x | 1.00x |

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

## GSM8K-40 (exact match, greedy, thinking off, max 512 tokens)

| run | correct | accuracy | completion tokens | wall s |
|---|---|---|---|---|
| A1-tate07-whole-gpu-eval | 37/40 | 92.5% | 11923 | 279.5 |

Notes: B1b-charlie-whole-gpu: power/utilization from the B1 window (same server state); steady decode there was measured end-to-end

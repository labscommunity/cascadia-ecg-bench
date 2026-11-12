# B5: whole Qwen3.6-35B-A3B (official INT4 IR, 19.4 GB) on alpha's GPU with the dxgkrnl commit limit at 85% (26.06 GiB budget)

Same model and protocol as B1b/B3 (which decoded at 1.5-1.9 tok/s inside a 17.2 GiB budget). With the real window raised (report 6.1):
TTFT 0.15 / 0.75 / 3.9 s (short / 975 / 7.7k tokens), decode 33 tok/s on the 975-token prompt, steady-loop 30.2-33.7 tok/s (median 30.4),
e2e 28-30 tok/s; package 33.5 W decoding (3.3 W idle), DDR 56 GB/s, GPU compute 95% busy, copy engine 12% (26% when it was paging),
GPU shared memory 19.0 GB, CPU 15%. Output parity vs the 64 GB box's whole model: see tables.md (same IR, greedy).

Note: this directory holds two runs appended by the client: the first 9 bench rows / 10 steady rows were taken with a 5.5 GB honyaku rank
co-resident on the GPU (B5a, same numbers within 1 tok/s; also kept as results/B5a-alpha-whole-gpu-commit85-honyaku-coresident), the second half with
honyaku stopped. The SoC Watch windows and the summary above are from the clean run.

# End-to-end validation of the upstream branch `feat/qwen35-keepalive-profiling` (2026-11-13)

Build: labscommunity/cascadia `feat/qwen35-keepalive-profiling` @ 7a911d22 (7 commits on v0.2.7), Windows release build
(`--features openvino`, MSVC target) on tate-07, deployed as `C:\ecgbench\rt\clean\cascadia.exe` (sha256 3acd4beb…) on
alpha, beta, charlie and tate-07. OpenVINO GenAI 2026.4.1. The branch carries only what changed a number: the qwen35 GPU
keep-alive (`--gpu-keepalive-ms`), per-token profiling (`CASCADIA_QWEN36_PROFILE=1`), the GenAI prefix-cache fix for the
prompt-lookup / draft pipelines, the GPTQ builder `--expert-sym`, and the WDDM GPU budget in `doctor` / `profile-stages`.

## Qwen3.5-122B-A10B, 3 NUCs (alpha / beta / charlie, one 16-layer stage per iGPU, 2.5 GbE), release-layout tree `q122-sym-3`

| run | keep-alive | decode tok/s short / medium / long | TTFT short / medium / long | steady 90 s | GSM8K-20 | parity |
|---|---|---|---|---|---|---|
| `D4k-122b-3stage-3nuc-clean-keepalive2` | `--gpu-keepalive-ms 2` | 10.5–10.8 / 10.5–10.6 / 10.0–10.1 | 0.59–0.63 / 4.9 / 36.9 s | 10.5 | 17/20 in 569 s | 8/8 identical to D3b (release v0.2.7) and D3k |
| `K9-122b-3nuc-clean-nokeepalive` | off | 1.5–4.1 / 2.5–2.8 / 4.2–5.4 | 1.2–1.9 / 6.8–7.1 / 48 s | — | — | 3/3 bench outputs identical to D4k; relay stage infer 33.8 / 440 ms (p50 / p95), keepalive_infers=0 |
| reference `D3k` (branch ecg/spec-decode, env var 2 ms) | 2 ms | 10.5–11 / 10.5–10.7 / 10.0–10.2 | 0.62 / 5.5 / 41.3 s | 10.6 | 17/20 in 581 s | — |
| reference `D3b` (release v0.2.7) | n/a | 3.2–4.6 / 2.9–3.3 / 2.8 | 1.2–1.5 / 5.7–6.3 / 41–45 s | 2.9 | 17/20 in 2438 s | — |

Keep-alive engaged on every rank with the synthetic 1×16 model (`qwen35 GPU keep-alive on period_ms=2 model="synthetic"`),
ka.infer p50 ≈ 120 µs; relays logged ~7,400 keep-alive infers per 267-step task. Relay stage infer with keep-alive:
beta 30.8 / 31.7 ms, charlie 31.6 / 32.5 ms (p50 / p95), i.e. the 250–550 ms p95 tails of the stock build are gone.

## Qwen3.6-35B-A3B on tate-07 (64 GB Panther Lake; the enterprise `cascadia-node` + gemma OVMS stayed running, so tok/s are not clean numbers)

| run | config | requests | medium decode tok/s | outputs |
|---|---|---|---|---|
| `S0q-tate07-35b-clean-worker-base` | whole model, `worker --total 1`, ov-genai GPU | 6/6 ok | 46.8 | 3/3 prompts identical to `A1b` (release v0.2.7) |
| `S1q-tate07-35b-clean-prompt-lookup3-k5` | whole model, `--prompt-lookup 3 --spec-k 5` | 6/6 ok (repeated prompts no longer trip GenAI's prefix-cache assertion) | 29.4 | differs from the base on 2/3 prompts (GenAI's speculative path; not a recommended mode) |
| `S7q-tate07-35b-clean-staged3-base` | sliced tree `q36-3stage`, qwen35 engine, 3 stages in one process | 6/6 ok | 27.3 | 3/3 prompts identical to `C2` (release v0.2.7, same tree over 3 NUCs) |

## `cascadia doctor` (new WDDM lines)

- alpha (32 GB, commit limit 85): `GPU: GPU_DEVICE_TOTAL_MEM_SIZE 24.77 GiB`; `WDDM GPU budget — shared segment 26.81 GiB, per-process budget 26.06 GiB`; `✓ GPU memory — OpenVINO total 24.77 GiB within the WDDM per-process budget 26.06 GiB`.
- tate-07 (64 GB, commit limit 82): `shared segment 51.95 GiB, per-process budget 51.20 GiB`; `✓ OpenVINO total 48.39 GiB within the WDDM per-process budget`.
Both match `tools/vidmem.py` (D3DKMTQueryVideoMemoryInfo).

## Not re-run here

GPTQ builder `--expert-sym` end-to-end (the 122B IR used above was built with the same transform on 2026-11-11, `results/F-gptq-builder-gpu-fix/`); the nibble transform has unit tests in the branch.

# Published model-card benchmarks (Hugging Face, fetched 2026-11-11)

Used for the "capability increase from LLM size" section alongside our own GSM8K-40 measurement. Scores are the vendors' own
(thinking mode, full-precision weights); our deployment runs INT4 weights with thinking off, so treat these as upper bounds.

## Qwen3.6-35B-A3B vs. Qwen3.5-122B-A10B (language, selected common rows)

| Benchmark | Qwen3.5-35B-A3B | Qwen3.6-35B-A3B | Qwen3.5-122B-A10B |
|---|---|---|---|
| MMLU-Pro | 85.3 | 85.2 | 86.7 |
| MMLU-Redux | 93.3 | 93.3 | 94.0 |
| SuperGPQA | 63.4 | 64.7 | 67.1 |
| GPQA (Diamond) | 84.2 | 86.0 | 86.6 |
| HLE (w/ CoT) | 22.4 | 21.4 | 25.3 |
| LiveCodeBench v6 | 74.6 | 80.4 | 78.9 |
| SWE-bench Verified | 70.0 (69.2) | 73.4 | 72.0 |
| Terminal-Bench 2.0 | 40.5 | 51.5 | 49.4 |
| HMMT Feb 25 | 89.0 | 90.7 | 91.4 |
| DeepPlanning | 22.8 | 25.9 | 24.1 |
| WideSearch | 59.1 (57.1) | 60.1 | 60.5 |
| VITA-Bench | 29.1 (31.9) | 35.6 | 33.6 |

(Qwen3.5-35B-A3B values differ slightly between the two cards; the 122B card's value is in parentheses where it differs.)

## Vision-language (selected, relevant to traffic monitoring)

| Benchmark | Qwen3.6-35B-A3B | Qwen3.5-122B-A10B |
|---|---|---|
| MMMU / MMMU-Pro | 81.7 / 75.3 | 83.9 / 76.9 |
| RealWorldQA | 85.3 | 85.1 |
| HallusionBench | 69.8 | 67.6 |
| OmniDocBench 1.5 | 89.9 | 89.8 |
| CC-OCR | 81.9 | 81.8 |
| ODInW13 (detection) | 50.8 | 44.5 |
| RefCOCO avg (grounding) | 92.0 | 91.3 |
| VideoMME w/o subtitles | 82.5 | 83.9 |
| LVBench (long video) | 71.4 | 74.4 |
| Nuscene (driving) | — | 15.4 |

## Architecture
| | Qwen3.6-35B-A3B | Qwen3.5-122B-A10B |
|---|---|---|
| Total / active params | 35B / 3B | 122B / 10B |
| Layers | 40 (30 GatedDeltaNet + 10 full attention) | 48 (36 GatedDeltaNet + 12 full attention) |
| Hidden size | 2048 | 3072 |
| Experts | 256 (8 routed + 1 shared) | 256 (8 routed + 1 shared) |
| Native context | 262k | 262k |
| INT4 OpenVINO IR | 19.4 GB (official OpenVINO/Qwen3.6-35B-A3B-int4-ov) | built here from Qwen/Qwen3.5-122B-A10B-GPTQ-Int4 (see results) |

Takeaway: the newer 35B-A3B closes most of the gap to the 122B-A10B on the vendor's benchmarks (within ~1–3 points on knowledge/reasoning;
ahead on several agentic/coding rows), while the 122B keeps a small edge on knowledge-heavy evals (MMLU-Pro, SuperGPQA, HLE) and long video.

# cascadia-ecg-bench

Benchmark data and report for the **Cascadia ECG Benchmarking** request: Qwen3.6-35B-A3B and Qwen3.5-122B-A10B, whole-model vs. sharded
(pipeline-parallel) on Intel Panther Lake AI PCs — 3x 32 GB NUCs locally and a 64 GB box in Intel Tiber AI Cloud.

- `docs/PLAN.md` — KPIs, test matrix, protocol
- `inventory/` — machines and software versions
- `harness/` — benchmark client, utilization sampler, SoC Watch wrapper, launch helpers, prompt sets, GSM8K subset, output comparer
- `results/<run>/` — raw JSONL per run (bench, utilization, power) + notes
- `report/` — one-pager and the shareable report

Runtime: labscommunity/cascadia v0.2.7 (`cascadia run` for whole models via OpenVINO GenAI; `cascadia worker --engine qwen35` for the staged MoE pipeline).

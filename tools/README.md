# Orchestration scripts (run from a Mac with ssh access to the fleet)

- `hosts.sh` — ssh targets for alpha/beta/charlie/delta/tate07/tate08.
- `wps.sh <host> <file.ps1>` — run a PowerShell script remotely (encoded), `wbg.sh` — launch a detached command via WMI.
- `run_config.sh <host> <label>` — one configuration end to end: launch server, health, calib, idle window, bench, parity, steady power window, stop, collect. Env: MODEL, ENGINE, DEVICE, EXTRA, NOLAUNCH, NOSTOP, QUICK, REPEATS, TAGS.
- `run_chain.sh <label>` — N-rank pipeline across Windows hosts (TREE, HOSTS, IPS), then the same measurement on the head, a chain-wide power window, optional eval, stop, collect.
- `run_eval.sh <host> <label>` — GSM8K-N against a running server. `run_conc.sh` — continuous-batching sweep (not supported for VLM-layout IRs).
- `run_d1.sh` / `d2_chain.sh` — the two 122B layouts (2 x 64 GB; 3 NUCs + 64 GB tail). `restore_nucs.sh` — bring honyaku/Acrow back.

## Follow-up round orchestrators (2026-11-11 PM)
- `alpha_mixed_v3.sh` / `hetero_v4.sh`: C3 mixed GPU-head/CPU-tail 35B pipeline and the HETERO:GPU,CPU whole-model check (note: quote the device for PowerShell, an unquoted `HETERO:GPU,CPU` becomes an array).
- `stage0_copy.sh`: tate-07 -> alpha stage copy streamed through the Mac (`scp -3`).
- `d3_chain.sh` + `d3_cut_now.sh`: D3 (122B sym 3 stages on alpha/beta/charlie), distribution from the Mac Pro, and the cut-over once the thrash case was established.
- `stage3_to_tate07.sh`, `tate07_fix.sh`, `stage1_pipeline.sh`, `stage2_after.sh`: moving the 4-stage sym tree out of the export VM (slirp NIC, ~22 MB/s single stream) to the Mac Pro, then to the NUCs (LAN) and tate-07 (bastion/tailnet). `scp -3 -r dir host:dest/` into a non-existent `dest` puts the files in `dest` itself: create directories first and copy files one by one.
- `d2sym_chain.sh` -> `d2sym_run.sh`: D2sym (4 stages: alpha/beta/charlie + tate-07 tail) with byte-exact completeness and manifest checks before taking tate-07's node down; measurement, chain-wide window, GSM8K-20, restore of tate-07's service and the NUC workloads.
- `report/src/`: `assemble_page.py` + `followup_section.html` build the published page from the original page.

## Round 3 (2026-11-13): speculative decoding, GPU clocks, stage profile
- `vidmem.py` (WDDM segment + per-process budget via D3DKMTQueryVideoMemoryInfo), `zefreq.py` / `zepin.py` (Level Zero Sysman: sample / pin the iGPU frequency), `stage_profile.py` (direct OpenVINO decode profile of one stage: per-step wall, PERF_COUNT op breakdown, NSTEP/SLEEP_MS env for stall hunting), `unslice_logits.py` (XML-only rewrite of a last-stage IR to full [1,T,vocab] logits).
- `nuc_clocks.sh` (G1 pinned 2500 MHz, G2 GPU_QUEUE_THROTTLE/PRIORITY=HIGH, stage profiles, B6 whole 35B pinned/unpinned), `stall_diag.sh` / `stall_diag2.sh` (300-step standalone profiles with memory counters; idle-gap experiment), `nuc_spec122.sh` / `nuc_spec122b.sh` (122B pipeline with the ecg/spec-decode build: profiled baseline, n-gram variants, parity), `t07_spec4.sh` / `t07_spec5.sh` (whole-model prompt lookup / draft and the single-box staged 35B on tate-07), `t07_rebuild_after.sh` (MSVC-target build of the branch on tate-07).
- Launcher `harness/win/server.ps1` gained `-Exe` (alternate runtime binary) and `-Env "A=1;B=2"`; the orchestrators pass `EXE` / `ENVS` / `CLIENT_EXTRA` env vars. `bench_client.py --nonce` makes every request prompt unique.
- `keepalive_chain.sh` / `keepalive_chain2.sh`: build + deploy the keep-alive runtime, then K1 (5 ms), K3 (5 ms + pinned 2.5 GHz), K4 (25 ms), K5 (2 ms) quick runs and the full D3k protocol + GSM8K-20 on the best (K5: `CASCADIA_QWEN36_GPU_KEEPALIVE_MS=2`). `stage_profile.py` gained `HEARTBEAT=paced|busy` to reproduce the idle-stall fix standalone.

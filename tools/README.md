# Orchestration scripts (run from a Mac with ssh access to the fleet)

- `hosts.sh` — ssh targets for alpha/beta/charlie/delta/tate07/tate08.
- `wps.sh <host> <file.ps1>` — run a PowerShell script remotely (encoded), `wbg.sh` — launch a detached command via WMI.
- `run_config.sh <host> <label>` — one configuration end to end: launch server, health, calib, idle window, bench, parity, steady power window, stop, collect. Env: MODEL, ENGINE, DEVICE, EXTRA, NOLAUNCH, NOSTOP, QUICK, REPEATS, TAGS.
- `run_chain.sh <label>` — N-rank pipeline across Windows hosts (TREE, HOSTS, IPS), then the same measurement on the head, a chain-wide power window, optional eval, stop, collect.
- `run_eval.sh <host> <label>` — GSM8K-N against a running server. `run_conc.sh` — continuous-batching sweep (not supported for VLM-layout IRs).
- `run_d1.sh` / `d2_chain.sh` — the two 122B layouts (2 x 64 GB; 3 NUCs + 64 GB tail). `restore_nucs.sh` — bring honyaku/Acrow back.

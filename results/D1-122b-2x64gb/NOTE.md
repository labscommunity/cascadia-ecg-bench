# D1 — Qwen3.5-122B-A10B INT4, 2 shards on two 64 GB boxes (tate-07 Windows + tate-08 Linux): NOT RUN

Staged completely (29 GB stage0 on tate-07, 33 GB stage1 on tate-08, Linux runtime v0.2.7 + samplers on tate-08, 15 ms relay between them),
but tate-08 was taken into interactive use (a `tester` login installing the Cascadia desktop stack and running an enterprise node) while this
benchmark ran, and the brief allowed borrowing only idle machines. Independently, D2 showed that this IR does not compile on the GPU plugin,
so this layout would have failed the same way on tate-07's rank. `run_d1.sh` (scratchpad) is the launcher if a second idle 64 GB box becomes
available after the builder's GPU issue is fixed.

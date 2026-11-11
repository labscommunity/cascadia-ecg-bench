# D2 — Qwen3.5-122B-A10B INT4, 4-stage pipeline (alpha, beta, charlie + tate-07 tail): NOT RUNNABLE ON GPU

All four ranks exited at model load with the same OpenVINO GPU-plugin error (rank logs in `rank-logs/`):

    [GPU] ProgramBuilder build failed!
    Exception from src\plugins\intel_gpu\src\graph\program.cpp:929:
    Node which is about to be added in between two other nodes should not have any existing dependencies.
    Node: constant:Constant_25976_postponed_decompression_byfx_moecompressed:__module.model.model.language_model.layers.0.mlp/aten::sum/ReduceSum_Reshape/MOECompressed ( reorder ).
    Next: moecompressed:...layers.0.mlp/aten::sum/ReduceSum_Reshape/MOECompressed ( moe_3gemm... )

Stack: cascadia v0.2.7 with OpenVINO GenAI 2026.4.1 (core 2026.4.1), Intel Arc B390 driver 32.0.101.9033/9150, Windows 11.
The IR was built from `Qwen/Qwen3.5-122B-A10B-GPTQ-Int4` with the runtime's GPTQ-to-OpenVINO builder (`tools/qwen36_surgery/gptq_builder`)
and validated on CPU in the build VM (chain-vs-full logits rel 2.0e-2, top-1 match, 8/8 greedy tokens for the 2-stage cut). The GPU plugin's
MoE weight-decompression fusion (`MOECompressed`) rejects the builder's expert constant graph; the official Intel IR of the 35B (NNCF-exported)
compiles fine on the same stack, so the difference is in how the GPTQ-repacked expert constants are wired (the builder's design doc already
flagged "retest on GPU" as pending). Fixing this is OpenVINO graph work on the builder, not a runtime or hardware limit.

Stage sizes as distributed: stage0 12.1 GB (layers 0-9 + embeddings), stage1 15.7 GB, stage2 15.7 GB, stage3 25.7 GB (layers 30-47 + lm_head).
The CPU plugin needs ~2x the IR in RSS, so a CPU fallback does not fit beta/charlie (31.5 GB) for these stages either.

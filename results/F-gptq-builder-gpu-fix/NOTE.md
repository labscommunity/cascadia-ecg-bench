# GPTQ-to-OpenVINO builder: GPU MoE-fusion failure, root cause and fix

Symptom (D2): every rank of the GPTQ-built Qwen3.5-122B IR failed on the OpenVINO 2026.4.1 GPU plugin at compile:
`[GPU] ProgramBuilder build failed ... Node which is about to be added in between two other nodes should not have any existing
dependencies. Node: constant:..._postponed_decompression_byfx_moecompressed:...mlp/aten::sum/ReduceSum_Reshape/MOECompressed`.

Diagnosis: layer-0 of the GPTQ-built 35B IR is op-for-op identical to Intel's official IR (two u4 expert stacks for gate/up plus down,
each Convert -> Subtract(zero point) -> Multiply(scale) -> Reshape -> Convert -> bmm). The difference is in the data: GPTQ is symmetric,
so every zero point is exactly 8, while Intel's NNCF export has varying per-group zero points. The GPU plugin's MoE fusion (MOECompressed)
takes a different path for uniform zero points and fails.

Test (`extract_moe_block.py`, results in `moe_l0_pattern_test_tate07.txt`): layer-0's MoE block extracted into a standalone 427 MB model,
once as built (u4 + zp=8) and once with the expert stacks rewritten as signed i4 without a zero point (bit-identical values: nibble ^ 0x8).
On tate-07 (Arc B390, OV 2026.4.1): the u4+zp block compiles on CPU but fails on GPU with the exact error above; the i4 block compiles on
both and its GPU output matches the CPU reference (max abs diff 6e-4 at mean |y| 4e-3, f16 noise).

Fix: `gptq_to_ov.py --expert-sym` (this directory) emits the expert stacks as i4 constants with Convert -> Multiply (NNCF INT4_SYM pattern).
The 35B and 122B were rebuilt with it (see D-series results for the GPU runs).

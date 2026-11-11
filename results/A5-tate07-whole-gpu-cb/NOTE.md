# A5 (whole model, continuous batching, concurrency sweep): not run

`cascadia worker --engine ov-genai --cb` refuses the official Qwen3.6-35B-A3B IR:

    Error: invalid configuration: --cb is not supported on VLM-layout exports; ContinuousBatchingPipeline needs a plain LM export

The OpenVINO/Qwen3.6-35B-A3B-int4-ov export is VLM-layout (text embeddings + language model + vision merger IRs), so the OSS runtime
serves it through `VLMPipeline`, which is single-request. Concurrent serving of this model on one box requires either a text-only
re-export or the enterprise OVMS backend (continuous batching with `pipeline_type` text generation), which was not part of this run.
The staged (sharded) engine is single-flight by design (batch = 1), so no concurrency comparison is possible between whole and sharded here.

# D3: Qwen3.5-122B-A10B (GPTQ-sym build) as 3 even stages on alpha/beta/charlie (85% GPU windows)

Stages 19.8 / 23 / 23 GB on alpha / beta / charlie, 2.5 GbE LAN. All three ranks load on the GPU (20-21 GB resident each) and the pipeline
is healthy 14 s after launch: the `--expert-sym` builder fix works at 122B scale. Decode is 0.57 tok/s on every prompt (TTFT 3.8 / 12 / 79 s)
because each stage is larger than the 18.4 GB segment the driver keeps resident per iGPU (see B3/B4): head GPU shared memory sits at 18.0 GB,
GPU copy engine 26%, compute 30%. STATUS=PARTIAL: the standard protocol (3 repeats + steady window + GSM8K-20) was cut after 2 x short/medium
and 1 x long because the run would have taken ~5 hours at this speed and the result is already unambiguous. rank-beta/ and rank-charlie/ hold
the other ranks' logs. The accuracy pass moved to D2sym (4 stages that fit their GPUs).

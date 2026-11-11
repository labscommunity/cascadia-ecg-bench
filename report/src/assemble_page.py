#!/usr/bin/env python3
"""Assemble the published page: insert the follow-up section and revise the 122B finding/section, takeaways and scope notes."""
import sys, re
page='/private/tmp/claude-501/-Users-tatef-Workspaces/fc0a4af2-c75b-4225-bb73-ca56207fff04/scratchpad/report/cascadia-panther-lake-benchmark.html'
sec=open(page.replace('cascadia-panther-lake-benchmark.html','followup_section.html')).read()
s=open(page).read()
assert '{{' not in sec, 'placeholders left in followup_section.html'
def rep(old,new,count=1):
    global s; assert old in s, old[:60]; s=s.replace(old,new,count)
# 1. finding box for the 122B
i=s.index('<div class="finding warn"><b>The 122B cannot run here today</b>'); j=s.index('</div>', i)+6
s=s[:i]+'<div class="finding"><b>The 122B runs after a builder fix, and needs stages under 18 GB</b><p>Its 64.3 GB INT4 IR fits no single box. The GPTQ-to-OpenVINO build first failed in the GPU plugin\'s MoE fusion; the fix (signed INT4 experts) makes it compile. Three 32 GB NUCs run it at 0.57 tok/s (every stage pages through the 18.4 GB resident segment); with four stages that fit their GPUs it runs at D2SYM_RATE tok/s, relay-bound, and scores D2SYM_GSM on GSM8K-20.</p></div>'+s[j:]
# 2. 122B section heading + "Not runnable" paragraph
rep('<h2>Qwen3.5-122B-A10B: built, sized, not runnable on the GPU</h2>','<h2>Qwen3.5-122B-A10B: built, sized, first blocked on the GPU, then fixed</h2>')
i=s.index('<p><b>Not runnable.</b>'); j=s.index('</div>\n</div>', i)
s=s[:i]+'<p><b>Blocked, then fixed.</b> Every rank of the 4-stage layout first failed at load in the OpenVINO 2026.4.1 GPU plugin, on its first MoE layer:</p>\n'+s[s.index('<pre>',i):s.index('</pre>',i)+6]+'\n<p>The official NNCF-exported 35B compiles on the same stack. The cause (follow-up round below): GPTQ experts are symmetric, every zero point is 8, and the GPU MoE fusion rejects that form. Emitting signed INT4 experts without a zero point compiles, and the 122B measurements in the follow-up section were made with that build.</p>\n'+s[j:]
# 3. takeaways
rep('<li><b>The NPU plays no part</b> in LLM serving with these engines today; NPU-capable SKUs gain nothing here (they still help the vision models that run beside the LLM).</li>',
    '<li><b>The NPU plays no part</b> in LLM serving with these engines today (the 8B and 0.6B do not even compile for it), NPU-capable SKUs gain nothing here, and there is no NPU-prefill / GPU-decode split to be had. CPU decode is a 2x loss on a dense 8B and worse on a 35B shard.</li>')
rep('<li><b>Default to Qwen3.6-35B-A3B.</b> The 122B is a selective upgrade that needs two 64 GB nodes and a builder fix before it can even be measured.</li>',
    '<li><b>Default to Qwen3.6-35B-A3B.</b> The 122B now runs on Panther Lake (builder fixed) but needs stages under ~18 GB: four or more 32 GB nodes, or 64 GB nodes; three NUCs alone thrash at 0.57 tok/s. Through the relay to a 64 GB tail it reached D2SYM_RATE tok/s and D2SYM_GSM on GSM8K-20.</li>')
# 4. scope note on concurrency
m=re.search(r'<li>Continuous batching could not be measured.*?</li>', s, re.S); assert m, 'cb bullet'
s=s[:m.start()]+'<li>Continuous batching: the runtime\'s <span class="mono">--cb</span> path refuses VLM-layout exports (which is what the official Qwen3.6 IR is) and the staged engine is single-flight by design; concurrency was measured through the enterprise OVMS backend instead (follow-up round).</li>'+s[m.end():]
# 5. insert the follow-up section before the ECG section
rep('<h2>What this means for ECG deployments</h2>', sec+'\n<h2>What this means for ECG deployments</h2>')
# 6. lede/meta mention
rep('measured 11 Nov 2026</div>','measured 11 Nov 2026 · follow-up round the same day</div>')
left=re.findall(r'D2SYM_[A-Z]+|\{\{[A-Z_0-9]+\}\}', s)
out=sys.argv[1] if len(sys.argv)>1 else page
open(out,'w').write(s); print('assembled', len(s), 'bytes; placeholders left:', sorted(set(left)))

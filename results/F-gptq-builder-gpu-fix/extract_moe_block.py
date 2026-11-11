"""Extract layer-0's MoE block from a Qwen3.5-MoE OpenVINO IR into a standalone model, plus an INT4-symmetric variant
(u4 + uniform zero point -> signed i4, no Subtract; numerically identical). usage: extract_moe.py <ir_dir> <out_dir>"""
import sys, os, numpy as np, openvino as ov
from openvino import opset13 as ops
src, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True)
core = ov.Core(); m = core.read_model(os.path.join(src, 'openvino_language_model.xml'))
def find(pred): return [n for n in m.get_ops() if pred(n.get_friendly_name(), n.get_type_name())]
ln = sorted(find(lambda nm, t: 'layers.0.post_attention_layernorm' in nm and t == 'Multiply'), key=lambda n: len(n.output(0).get_target_inputs()), reverse=True)[0]
add = find(lambda nm, t: nm.endswith('layers.0.mlp/aten::add/Add') and t == 'Add')[0]
print('block input:', ln.get_friendly_name(), 'output:', add.get_friendly_name())
param = ops.parameter(ln.output(0).get_partial_shape(), ov.Type.f32, name='hidden')
for ti in list(ln.output(0).get_target_inputs()): ti.replace_source_output(param.output(0))
res = ops.result(add.output(0), name='moe_out')
extra = [p for p in m.get_parameters() if p.get_friendly_name() == 'inputs_embeds']
sub = ov.Model([res], [param] + extra, 'moe_l0')
ov.save_model(sub, os.path.join(out, 'moe_l0_gptq.xml'), compress_to_fp16=False)
print('saved GPTQ-pattern block; params:', [p.get_friendly_name() for p in sub.get_parameters()], 'u4 consts:', sum(1 for n in sub.get_ops() if n.get_type_name() == 'Constant' and n.get_element_type() == ov.Type.u4))
def unpack_u4(c):  # OpenVINO hands u4 constant data back as packed bytes (low nibble first)
    raw = np.asarray(c.get_data()).view(np.uint8).reshape(-1)
    v = np.empty(raw.size * 2, np.uint8); v[0::2] = raw & 0xF; v[1::2] = raw >> 4
    return v.reshape(list(c.get_output_shape(0)))
def pack_i4(w):  # w int8 in [-8,7], last dim even -> i4 tensor, low nibble first
    v = (w.astype(np.int16) & 0xF).astype(np.uint8).reshape(-1)
    packed = (v[0::2] | (v[1::2] << 4)).astype(np.uint8)
    return ov.Tensor(packed, ov.Shape(list(w.shape)), ov.Type.i4)
sub2 = core.read_model(os.path.join(out, 'moe_l0_gptq.xml')); changed = skipped = 0; keep = []
for n in list(sub2.get_ops()):
    if n.get_type_name() != 'Subtract': continue
    ca, cb = n.input_value(0).get_node(), n.input_value(1).get_node()
    if ca.get_type_name() != 'Convert' or cb.get_type_name() != 'Convert': continue
    wq, zq = ca.input_value(0).get_node(), cb.input_value(0).get_node()
    if not (wq.get_type_name() == 'Constant' and zq.get_type_name() == 'Constant' and wq.get_element_type() == ov.Type.u4): continue
    z = unpack_u4(zq).astype(np.int16)
    if not np.all(z == z.flat[0]): skipped += 1; print('  non-uniform zp:', zq.get_friendly_name()[:80], 'unique', np.unique(z)[:6]); continue
    w = unpack_u4(wq).astype(np.int16) - int(z.flat[0])
    if w.min() < -8 or w.max() > 7: skipped += 1; continue
    t = pack_i4(w.astype(np.int8)); keep.append(t)
    wi4 = ov.op.Constant(t, shared_memory=False); wi4.set_friendly_name(wq.get_friendly_name() + '_i4')
    conv = ops.convert(wi4, ov.Type.f16); conv.set_friendly_name(ca.get_friendly_name() + '_sym')
    for ti in list(n.output(0).get_target_inputs()): ti.replace_source_output(conv.output(0))
    changed += 1
sub2.validate_nodes_and_infer_types()
ov.save_model(sub2, os.path.join(out, 'moe_l0_sym.xml'), compress_to_fp16=False)
print('sym variant: folded', changed, 'uniform zero points; skipped', skipped)
# parity check on CPU: both variants must agree on random input
np.random.seed(0); x = (np.random.randn(1, 4, 2048) * 0.5).astype(np.float32); e = np.zeros((1, 4, 2048), np.float32)
ca_ = core.compile_model(core.read_model(os.path.join(out, 'moe_l0_gptq.xml')), 'CPU'); cb_ = core.compile_model(core.read_model(os.path.join(out, 'moe_l0_sym.xml')), 'CPU')
ya = ca_({'hidden': x, 'inputs_embeds': e})[0]; yb = cb_({'hidden': x, 'inputs_embeds': e})[0]
print('CPU parity gptq vs sym: max_abs', float(np.abs(ya - yb).max()), 'rel', float(np.abs(ya - yb).max() / (np.abs(ya).max() + 1e-9)))
for f in sorted(os.listdir(out)): print(f, round(os.path.getsize(os.path.join(out, f)) / 1e6, 1), 'MB')

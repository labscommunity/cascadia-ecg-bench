# Rewire a Qwen3.5 surgery last-stage IR so the Result reads the lm_head MatMul directly (full [1,T,vocab] logits),
# removing the final Slice and its constant inputs. XML-only: the .bin is untouched. usage: unslice_logits.py stage.xml
import xml.etree.ElementTree as ET, sys, shutil, os
p=sys.argv[1]; tree=ET.parse(p); root=tree.getroot(); layers=root.find('layers'); edges=root.find('edges')
L={l.get('id'):l for l in layers}
res=[l for l in layers if l.get('type')=='Result']; assert len(res)==1, [r.get('name') for r in res]; r=res[0]
e_in=[e for e in edges if e.get('to-layer')==r.get('id')]; assert len(e_in)==1
sl=L[e_in[0].get('from-layer')]; assert sl.get('type')=='Slice', sl.get('type')
sl_in=[e for e in edges if e.get('to-layer')==sl.get('id')]; data=[e for e in sl_in if e.get('to-port')=='0']; assert len(data)==1
src_layer, src_port = data[0].get('from-layer'), data[0].get('from-port'); print('Result <- Slice <-', L[src_layer].get('name'), 'port', src_port)
consts=[e.get('from-layer') for e in sl_in if e.get('to-port')!='0']
for e in sl_in: edges.remove(e)
e_in[0].set('from-layer', src_layer); e_in[0].set('from-port', src_port)
layers.remove(sl)
for c in consts:
    if L[c].get('type')=='Const' and not any(e.get('from-layer')==c for e in edges): layers.remove(L[c])
shutil.copy(p, p+'.sliced'); tree.write(p, encoding='utf-8', xml_declaration=True); print('rewired; removed Slice + %d consts; backup at %s.sliced' % (len(consts), p))

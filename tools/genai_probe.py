import importlib.util, sys
m=importlib.util.find_spec('openvino_genai'); print('genai py present:', m is not None)
if m:
    import openvino_genai as g; print('version', g.__version__)
    print('top:', [x for x in dir(g) if any(k in x.lower() for k in ('draft','spec','mtp','eagle','assist'))])
    print('cfg:', [x for x in dir(g.GenerationConfig) if any(k in x.lower() for k in ('assist','draft','spec','mtp','eagle','num_assistant'))])
import openvino as ov; print('ov', ov.__version__)

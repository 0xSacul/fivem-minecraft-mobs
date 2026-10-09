"""Evaluate only the installed dragon's declarative createBodyLayer builder bytecode.

No Java code is run. Unknown opcodes or builder calls stop extraction rather than
silently substituting guessed geometry. Input classes are read-only references.
"""
import copy
import re


def geometry(reference):
    constants = reference['constants']
    code = bytes.fromhex(next(m['bytecode_hex'] for m in reference['methods'] if m['name']=='createBodyLayer'))
    stack, local, cursor, iterations = [], {}, 0, 0
    root = {'name':'root','pivot':[0,0,0],'rotation':[0,0,0],'cubes':[],'children':[]}
    def call(ref, static):
        owner, name, descriptor = ref.split(' ',2)
        arguments = re.findall(r'L[^;]+;|\[[A-Z]|[BCDFIJSZ]', descriptor[1:descriptor.index(')')])
        args = [stack.pop() for _ in arguments][::-1]
        obj = None if static else stack.pop()
        result = None
        if name=='<init>': pass
        elif name=='getRoot': result=root
        elif name=='create' and owner.endswith('CubeListBuilder'): result={'cubes':[],'mirror':False}
        elif name=='mirror': obj['mirror']=True if not args else args[0];result=obj
        elif name=='addBox':
            assert len(args)==9, (ref,args)
            obj['cubes'].append({'name':args[0],'box':args[1:7],'uv':args[7:9],'mirror':obj['mirror']})
            result=obj
        elif name=='offset': result={'pivot':args,'rotation':[0,0,0]}
        elif name=='offsetAndRotation': result={'pivot':args[:3],'rotation':args[3:]}
        elif name=='addOrReplaceChild':
            result={'name':args[0],**args[2],'cubes':copy.deepcopy(args[1]['cubes']),'children':[]}
            obj['children'].append(result)
        elif name in ['neckName','tailName']: result=name[:-4]+str(args[0])
        elif name=='create' and owner.endswith('LayerDefinition'): result={'root':root,'texture_size':args[1:]}
        else: raise ValueError('Unrecognized model builder: '+ref)
        if descriptor.split(')')[1]!='V': stack.append(result)
    while cursor<len(code):
        iterations+=1
        assert iterations<10000, 'Unexpected model-builder loop'
        start=cursor;op=code[cursor];cursor+=1
        def byte():
            nonlocal cursor
            val=code[cursor];cursor+=1;return val
        def short(signed=False):
            nonlocal cursor
            val=int.from_bytes(code[cursor:cursor+2],'big',signed=signed);cursor+=2;return val
        if op==0: pass
        elif 2<=op<=8: stack.append(op-3)
        elif 11<=op<=13: stack.append(float(op-11))
        elif op==16: v=byte();stack.append(v if v<128 else v-256)
        elif op==17: stack.append(short(True))
        elif op in [18,19]: stack.append(constants[str(byte() if op==18 else short())])
        elif op in [21,23,25]: stack.append(local[byte()])
        elif 26<=op<=45:
            base=26 if op<30 else 34 if 34<=op<=37 else 42 if op>=42 else -1
            assert base>=0,hex(op);stack.append(local[op-base])
        elif op in [54,56,58]: local[byte()]=stack.pop()
        elif 59<=op<=78:
            base=59 if op<63 else 67 if 67<=op<=70 else 75 if op>=75 else -1
            assert base>=0,hex(op);local[op-base]=stack.pop()
        elif op==87: stack.pop()
        elif op==89: stack.append(stack[-1])
        elif op in [96,98,100,102,104,106]:
            b,a=stack.pop(),stack.pop();stack.append(a+b if op in [96,98] else a-b if op in [100,102] else a*b)
        elif op==132: k,v=byte(),byte();local[k]+=v if v<128 else v-256
        elif op==134: stack.append(float(stack.pop()))
        elif op==162:
            offset=short(True);b,a=stack.pop(),stack.pop()
            if a>=b: cursor=start+offset
        elif op==167: cursor=start+short(True)
        elif op==187: short();stack.append({})
        elif op in [182,183,184]: call(constants[str(short())],op==184)
        elif op==176: return stack.pop()
        else: raise ValueError(f'Unsupported opcode {op:02x} at {start}')
    raise ValueError('Missing model return')


def lua_table(value):
    if isinstance(value,dict): return '{'+','.join(f'{k}={lua_table(v)}' for k,v in value.items())+'}'
    if isinstance(value,list): return '{'+','.join(lua_table(v) for v in value)+'}'
    if isinstance(value,str): return "'"+value.replace("'","\\'")+"'"
    if isinstance(value,bool): return 'true' if value else 'false'
    return str(value)

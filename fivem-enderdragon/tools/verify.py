"""No-install, mocked logic verification. This does not replace FiveM play-testing."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
sys.dont_write_bytecode=True
from lua_runtime import Lua
from classfile import class_reference
from model_reference import geometry
ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--lua-dll',default='C:/Program Files/obs-studio/bin/64bit/lua51.dll')
    parser.add_argument('--check-sources',action='store_true',help='Also check the original Minecraft files recorded in provenance')
    args=parser.parse_args()
    os.chdir(ROOT);lua=Lua(args.lua_dll)
    try:
        scripts=list(ROOT.rglob('*.lua'))
        for p in scripts:lua.load(p.read_bytes(),str(p))
        print(f'PASS: {len(scripts)} Lua files parse with the already installed OBS LuaJIT')
        for p in ['shared/config.lua','shared/math.lua','shared/model.lua']:lua.load((ROOT/p).read_bytes(),p,True)
        lua.load('math.atan=math.atan2','Lua 5.4 atan compatibility',True)
        lua.load((ROOT/'tools/tests.lua').read_bytes(),'behavior tests',True)
    finally:lua.close()
    model=geometry(class_reference((ROOT/'assets/reference/EnderDragonModel.class').read_bytes()))
    assert model==json.loads((ROOT/'assets/reference/model.json').read_text()), 'Reference model drift'
    provenance=json.loads((ROOT/'assets/provenance.json').read_text())
    for record in provenance['assets']:
        assert hashlib.sha1((ROOT/record['destination']).read_bytes()).hexdigest()==record['sha1'],record['destination']
        if args.check_sources and record.get('conversion')=='None: original OGG Vorbis':
            assert hashlib.sha1(Path(record['source']).read_bytes()).hexdigest()==record['sha1']
    if args.check_sources:
        for name,key in [('jar','jar_sha1'),('asset_index','asset_index_sha1')]:
            assert hashlib.sha1(Path(provenance[name]).read_bytes()).hexdigest()==provenance[key]
        print('PASS: original local JAR/index/sound hashes')
    print(f'PASS: model reconstruction and {len(provenance["assets"])} packaged asset hashes')
    subprocess.run(['node','--check',str(ROOT/'assets/audio/audio.js')],check=True)
    subprocess.run(['node',str(ROOT/'tools/test_audio.cjs')],check=True)


if __name__=='__main__':main()

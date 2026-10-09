"""No-install validation. These are mocked behavioral tests, not a FiveM play-test."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
sys.dont_write_bytecode=True
from lua_runtime import Lua
ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--lua-dll',default='C:/Program Files/obs-studio/bin/64bit/lua51.dll')
    parser.add_argument('--check-sources',action='store_true',help='Also check the original Minecraft files recorded in provenance')
    args=parser.parse_args();os.chdir(ROOT)
    lua=Lua(args.lua_dll)
    try:
        scripts=list(ROOT.rglob('*.lua'))
        for path in scripts: lua.load(path.read_bytes(),str(path))
        print(f'PASS: {len(scripts)} Lua files parse using existing OBS LuaJIT')
        for path in ['shared/config.lua','shared/math.lua','shared/model.lua']:
            lua.load((ROOT/path).read_bytes(),path,True)
        lua.load('math.atan=math.atan2','Lua 5.4 atan compatibility',True)
        lua.load((ROOT/'tools/tests.lua').read_bytes(),'behavior tests',True)
    finally: lua.close()
    provenance=json.loads((ROOT/'assets/provenance.json').read_text())
    for asset in provenance['assets']:
        assert hashlib.sha1((ROOT/asset['destination']).read_bytes()).hexdigest()==asset['sha1'],asset['destination']
        if args.check_sources and asset.get('conversion')=='None: original OGG Vorbis':
            assert hashlib.sha1(Path(asset['source']).read_bytes()).hexdigest()==asset['sha1'],asset['source']
    if args.check_sources:
        for name,key in [('jar','jar_sha1'),('asset_index','asset_index_sha1')]:
            assert hashlib.sha1(Path(provenance[name]).read_bytes()).hexdigest()==provenance[key]
        print('PASS: original local JAR/index/sound hashes')
    print(f'PASS: {len(provenance["assets"])} packaged asset hashes')
    subprocess.run(['node','--check',str(ROOT/'assets/audio/audio.js')],check=True)
    subprocess.run(['node',str(ROOT/'tools/test_audio.cjs')],check=True)
    print('PASS: spatial audio, voice limits, whitelist and pending fuse cancellation')


if __name__=='__main__': main()

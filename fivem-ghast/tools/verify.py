"""No-install verifier using the existing OBS LuaJIT/5.1 DLL (syntax is a 5.4 subset).
This is a mocked logic test, not a FiveM runtime or multiplayer certification.
"""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua-dll', default='C:/Program Files/obs-studio/bin/64bit/lua51.dll')
    parser.add_argument('--check-sources', action='store_true', help='Also check the original Minecraft files recorded in provenance')
    args = parser.parse_args()
    os.chdir(ROOT)
    lua = ctypes.CDLL(args.lua_dll)
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lua.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
    lua.luaL_loadbuffer.restype = ctypes.c_int
    lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    lua.lua_pcall.restype = ctypes.c_int
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    lua.lua_tolstring.restype = ctypes.c_char_p
    lua.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lua.lua_close.argtypes = [ctypes.c_void_p]
    state = lua.luaL_newstate()
    lua.luaL_openlibs(state)

    def load(content, name, execute=False):
        result = lua.luaL_loadbuffer(state, content, len(content), name.encode())
        if not result and execute:
            result = lua.lua_pcall(state, 0, 0, 0)
        if result:
            raise AssertionError(lua.lua_tolstring(state, -1, None).decode(errors='replace'))
        if not execute:
            lua.lua_settop(state, 0)

    try:
        scripts = sorted(ROOT.rglob('*.lua'))
        for script in scripts:
            load(script.read_bytes(), str(script))
        print(f'PASS: syntax for {len(scripts)} Lua files (existing OBS LuaJIT)')
        load((ROOT / 'shared/config.lua').read_bytes(), 'config', True)
        load((ROOT / 'shared/math.lua').read_bytes(), 'math', True)
        # LuaJIT atan has one argument; FiveM Lua 5.4 atan supports atan(y, x).
        load(b'math.atan = math.atan2', 'atan compatibility', True)
        load((ROOT / 'tools/tests.lua').read_bytes(), 'tests', True)
        print('PASS: geometry, movement, attack timing, swept collision, replication, server ownership and reflection checks')
    finally:
        lua.lua_close(state)
    provenance = json.loads((ROOT / 'assets/provenance.json').read_text())
    for asset in provenance['assets']:
        destination = ROOT / asset['destination']
        assert hashlib.sha1(destination.read_bytes()).hexdigest() == asset['sha1'], destination
        path, separator, member = asset['source'].partition('!/')
        if args.check_sources and not separator and asset.get('conversion') == 'None: original OGG Vorbis is supported by NUI':
            assert hashlib.sha1(Path(path).read_bytes()).hexdigest() == asset['sha1'], path
    if args.check_sources:
        for name, key in [('jar', 'jar_sha1'), ('asset_index', 'asset_index_sha1')]:
            assert hashlib.sha1(Path(provenance[name]).read_bytes()).hexdigest() == provenance[key]
        print('PASS: original local JAR/index/sound hashes')
    print(f"PASS: {len(provenance['assets'])} packaged asset hashes")
    subprocess.run(['node', '--check', str(ROOT / 'assets/audio/audio.js')], check=True)
    subprocess.run(['node', str(ROOT / 'tools/test_audio.cjs')], check=True)
    print('PASS: NUI JavaScript syntax and spatial-audio behavior')


if __name__ == '__main__':
    main()

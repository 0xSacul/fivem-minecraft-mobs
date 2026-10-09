"""Use the already installed OBS LuaJIT DLL for compatible Lua source/logic checks."""
import ctypes


class Lua:
    def __init__(self, path='C:/Program Files/obs-studio/bin/64bit/lua51.dll'):
        self.dll = ctypes.CDLL(path)
        functions = {
            'luaL_newstate':([],ctypes.c_void_p),
            'luaL_openlibs':([ctypes.c_void_p],None),
            'luaL_loadbuffer':([ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p],ctypes.c_int),
            'lua_pcall':([ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int],ctypes.c_int),
            'lua_tolstring':([ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)],ctypes.c_char_p),
            'lua_settop':([ctypes.c_void_p,ctypes.c_int],None),
            'lua_getfield':([ctypes.c_void_p,ctypes.c_int,ctypes.c_char_p],None),
            'lua_close':([ctypes.c_void_p],None)
        }
        for name,(args,result) in functions.items():
            function=getattr(self.dll,name);function.argtypes=args;function.restype=result
        self.state=self.dll.luaL_newstate();self.dll.luaL_openlibs(self.state)

    def load(self, content, name, execute=False):
        if isinstance(content,str): content=content.encode()
        result=self.dll.luaL_loadbuffer(self.state,content,len(content),name.encode())
        if not result and execute: result=self.dll.lua_pcall(self.state,0,0,0)
        if result: raise AssertionError(self.dll.lua_tolstring(self.state,-1,None).decode(errors='replace'))
        if not execute: self.dll.lua_settop(self.state,0)

    def close(self): self.dll.lua_close(self.state)

    def global_string(self, name):
        self.dll.lua_getfield(self.state,-10002,name.encode()) # LUA_GLOBALSINDEX, LuaJIT 5.1
        value=self.dll.lua_tolstring(self.state,-1,None)
        self.dll.lua_settop(self.state,0)
        return value.decode() if value else None

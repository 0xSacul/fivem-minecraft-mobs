# Development and verification

The resources are separate at runtime. This repository also preserves their extraction tools, offline reference geometry, and mocked tests.

## Run the existing checks

From the repository root, with Python 3, Node.js, and a **64-bit LuaJIT/Lua 5.1 shared library compatible with your Python process**:

```powershell
python fivem-creeper/tools/verify.py --lua-dll "C:/path/to/lua51.dll"
python fivem-ghast/tools/verify.py --lua-dll "C:/path/to/lua51.dll"
python fivem-enderdragon/tools/verify.py --lua-dll "C:/path/to/lua51.dll"
```

The historical default is the Windows OBS Studio library at `C:/Program Files/obs-studio/bin/64bit/lua51.dll`. OBS is not a mob runtime dependency. Supply a compatible library path if that default is unavailable. These scripts target the LuaJIT/5.1 C API; a plain Lua 5.4 DLL is not interchangeable. The compatible source subset and an `atan` shim let the mocks run, but do not reproduce FiveM's runtime.

Checks cover Lua syntax, mocked gameplay/replication/cleanup behavior, packaged asset SHA-1 hashes, and NUI JavaScript/audio behavior. Dragon verification also checks reconstruction of the saved Java model reference. **They require no local Minecraft installation by default.**

To additionally compare the original source JAR, index, and sounds against the recorded extraction environment, append `--check-sources` to each command. This opt-in check uses the paths in `assets/provenance.json`; it requires those source files to exist. Re-extraction updates the records for your installation.

Audio tests can also run independently:

```powershell
node fivem-creeper/tools/test_audio.cjs
node fivem-ghast/tools/test_audio.cjs
node fivem-enderdragon/tools/test_audio.cjs
```

Automated checks provide evidence about mocked logic and file integrity. Actual visual/audio behavior, native collision results, entity control, and multiplayer performance require a FiveM session. See each resource README for play-test scenarios, and the root README for profiling priorities.

## Optional extraction and reference generation

The bundled runtime files are already present; extraction is not required to try the resources. Extraction reads an existing local Minecraft installation and writes outputs inside the corresponding resource. It does not download Minecraft.

```powershell
python fivem-creeper/tools/extract_assets.py --minecraft "C:/path/to/.minecraft" --version 26.3
python fivem-ghast/tools/extract_assets.py --minecraft "C:/path/to/.minecraft" --version 26.3
python fivem-enderdragon/tools/extract_assets.py --minecraft "C:/path/to/.minecraft" --version 26.3
```

These tools were written for the recorded 26.3 installation and asset index 34; other versions may have different paths, hashes, or bytecode. Inspect their assumptions before re-extracting. Extraction needs Pillow. Offline `tools/reference_geometry.py` generation additionally needs NumPy and a compatible LuaJIT library for the Creeper/dragon scripts. Those scripts currently use the historical OBS library default. Install optional Python libraries with `python -m pip install Pillow numpy` in your development environment if needed.

The OBJ files, preview PNGs, and dragon animation GIF are offline references. They are not native FiveM drawable exports or screenshots.

## Contributing

Bug reports are most useful with the resource name, config changes, FiveM build, OneSync/routing setup, client count, and a small reproduction. For optimization changes, include before/after measurements in the same scene with the same mob count and hardware. Please keep the three resources independently usable and preserve asset attribution.

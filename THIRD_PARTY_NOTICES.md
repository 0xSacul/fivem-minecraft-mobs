# Third-party materials

The root MIT license covers the original Lua/JavaScript/Python implementation, tools, tests, and project documentation. It does **not** relicense Minecraft content, extracted data, or derivatives of that content, wherever they appear in this repository.

The three resources contain artwork, audio, and reference material extracted from a local Minecraft Java Edition 26.3 installation (asset index 34). Minecraft artwork, sounds, and Java reference code remain the property of their respective rights holders, including Mojang/Microsoft. Including them here does not transfer ownership or grant additional reuse or distribution rights.

Excluded material includes:

- `fivem-*/assets/textures/`: extracted textures.
- `fivem-*/assets/sounds/`: original OGG audio.
- `fivem-*/assets/runtime/`: upscaled textures and derived overlays/sprites.
- `fivem-*/assets/reference/`: extracted Java `.class` files, bytecode dumps, source excerpts, reconstructed model/geometry data, OBJ/MTL files, and preview images/animations.
- Minecraft-derived model tables and dimensions embedded in `shared/model.lua`, renderer/model reconstruction code, and generated data. Original surrounding implementation remains under MIT; the notice does not claim ownership of extracted Minecraft material.

The files in `assets/audio/` are original project NUI playback code, rather than Minecraft sound assets.

Detailed source records and hashes are preserved for each resource:

| Resource | Source notes | Machine-readable provenance |
| --- | --- | --- |
| Creeper | [SOURCES.md](fivem-creeper/assets/SOURCES.md) | [provenance.json](fivem-creeper/assets/provenance.json) |
| Ghast | [SOURCES.md](fivem-ghast/assets/SOURCES.md) | [provenance.json](fivem-ghast/assets/provenance.json) |
| Ender Dragon | [SOURCES.md](fivem-enderdragon/assets/SOURCES.md) | [provenance.json](fivem-enderdragon/assets/provenance.json) |

Recorded absolute source paths describe the original extraction environment; they are not runtime dependencies. Provenance establishes where files came from, not permission to redistribute them. Check the applicable terms and permissions before using those materials in another release.

Minecraft names and branding belong to their respective owners. This repository is an unofficial fan project with no endorsement or affiliation from Mojang, Microsoft, Rockstar Games, or Cfx.re.

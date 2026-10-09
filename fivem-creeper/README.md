# FiveM Creeper prototype

> **Experimental: not intended for production servers as-is.** See the [root README](../README.md) for performance costs and [asset/license scope](../THIRD_PARTY_NOTICES.md).

An independent Lua resource using the original Creeper texture, geometry references, and ten sound files from the local Minecraft Java 26.3 installation. The visible mob is six textured cuboids with four independently animated legs and a turning head. No GTA ped model is used.

## Start

In the server console:

```text
refresh
ensure fivem-creeper
```

Outdoors in game, use `/creeper`. It spawns on walkable ground about 12 meters ahead of you. `/creeperclear` removes your Creepers. Defaults allow two per player, eight overall. This resource can run alongside `fivem-ghast` and does not depend on it.

Modern FiveM with OneSync is required. No new software, model exporter, framework, npm dependency, or external sound resource is needed. Existing startup configuration was left alone; add `ensure fivem-creeper` there when ready for automatic startup.

## Behavior

- Wanders slowly, or pursues visible player/NPC peds within 32 meters. Players receive a small target-selection preference. Set `Config.TargetNPCs = false` to target players only.
- Four legs swing in opposing pairs using the installed Java model's cosine formula. Head yaw/pitch follow the target. The original Creeper cube dimensions, pivots, and UV offsets are stored in `shared/model.lua`.
- Ground probes reject missing floor, excessive steps/drops, and steep slopes. Two asynchronous capsule traces test its lower body and head before accepting each movement step. Completed results are retained while another trace is pending. Simple steering attempts to move around obstacles.
- Starts priming within three meters. Stops walking, plays the original fuse hiss, swells, and flashes white. Checks its primed target more frequently while fusing. The original renderer's nonlinear horizontal/vertical swelling formula is reproduced; three pre-baked white-overlay variants approximate its white flash.
- Continues priming while its original target is visible and within seven meters. Losing LOS, escaping that range, or target death requests defusing. Progress winds down at the same rate it accumulated; another visible target cannot silently replace the originally primed target until progress reaches zero.
- The **server** advances the 30-tick / 1.5-second fuse. Stale client intent stops advancement and causes unwinding. Clients can report movement and target visibility, but cannot directly trigger a detonation event.
- Detonation removes the Creeper exactly once, plays an original Minecraft explosion sample, and causes one visible GTA grenade-style explosion. Native explosion damage and sound are disabled to avoid duplicating the scripted damage and original sound. Cover-aware splash damage falls off within six meters, affecting nearby players, controlled/local NPCs, vehicles, and destructible props.
- Player bullets and nearby melee swings can damage the procedural body. Hurt and normal death use their original sounds. Killing it during the fuse removes it without exploding. Fuse audio is stopped on defuse/removal, including a clip still being decoded.
- Creepers have **no ambient sound event** in the inspected sound map, so they remain silent while wandering. The prototype does not add persistent fire to their explosion.

## Original assets

Minecraft was read from `C:\Users\lucas\AppData\Roaming\.minecraft`, using `versions/26.3/26.3.jar` and `assets/indexes/34.json`. Nothing in that installation was modified.

| Use | Local original |
| --- | --- |
| Artwork | JAR `assets/minecraft/textures/entity/creeper/creeper.png` (64×32) |
| Hurt | Asset-index keys `minecraft/sounds/mob/creeper/say1.ogg` through `say4.ogg` |
| Death | `minecraft/sounds/mob/creeper/death.ogg` |
| Priming | `minecraft/sounds/random/fuse.ogg` |
| Explosion | `minecraft/sounds/random/explode1.ogg` through `explode4.ogg` |
| Model/animation | Compiled CreeperModel and ModelPart$Cube references |
| Fuse/rendering | Compiled Creeper, SwellGoal, and CreeperRenderer references |

[assets/SOURCES.md](assets/SOURCES.md) records every exact source path, including each hashed sound object and its asset-index key. [assets/provenance.json](assets/provenance.json) includes hashes, output sizes, and transformations. The original artwork/audio remain Mojang/Microsoft assets.

The untouched original PNG is in `assets/textures`. RGBA runtime PNGs are upscaled 16× with nearest-neighbor sampling. White flash and red hurt variants are derived from that original. OGG files are copied unchanged and decoded by the hidden NUI page, with Web Audio HRTF panning, distance attenuation, bounded voices, and no input focus.

The charged Creeper armor texture was also found but was not needed or copied. Charged/lightning behavior is outside this prototype.

## Visual entity and geometry reference

The installed Creeper model is compiled Java cube-building code rather than an importable GTA model. This follows the Ghast's procedural fallback: FiveM [textured world triangles](https://docs.fivem.net/natives/?_0x29280002282F1928) draw the Minecraft UV net around an invisible local object anchor. No GTA mesh is visible. Movement traces use [START_SHAPE_TEST_CAPSULE](https://raw.githubusercontent.com/citizenfx/natives/master/SHAPETEST/StartShapeTestCapsule.md); completed trace handles are retained only as results, following [Cfx's documented invalidation behavior](https://raw.githubusercontent.com/citizenfx/natives/master/SHAPETEST/GetShapeTestResult.md).

The model has a native-scale visual height of 1.625 meters: an 8×8×8 head, 8×12×4 body, and four 4×6×4 feet. Parts rotate procedurally without bones or extra child entities. `stream/` is reserved for a future rigged drawable export.

[assets/reference/creeper.obj](assets/reference/creeper.obj) and its material are a reconstructed static mesh exported from the **actual Lua renderer** for a later modelling pass. [geometry.json](assets/reference/geometry.json) records that mesh, source references, and timing. [geometry-preview.png](assets/reference/geometry-preview.png) is an offline CPU reference render; it is not a FiveM screenshot.

## Networking and limits

The server owns logical IDs, health, fuse timing, owner validation, proximity checks, spawn caps, movement bounds, and routing-bucket isolation. A fixed spawning client runs ground movement and LOS checks. Server state is broadcast every 100 ms; clients interpolate remote positions, heading, legs, and head pose. Three-second snapshots handle late joins and reconciliation.

These are local object replicas synchronized through application state, as in the Ghast prototype. There is no GTA entity ownership migration. Disconnects, bucket changes, and owner timeouts remove the group. `/creeperclear`, normal death, detonation, snapshots, and resource stop remove anchors and stop fuse audio. Only the spawning client emits the native network explosion; each player applies its own scripted damage, and NPC/vehicle/prop damage runs on the entity's controlling client.

Current limitations:

- Ground following and local obstacle steering are conservative approximations, with no full navigation mesh, jumping, swimming, falling simulation, or GTA skeletal/mesh collision. Complicated stairs, fences, tunnels, and unloaded collision areas need in-game testing. AI sees only peds streamed to its fixed owner.
- Textured triangles do not cast a native Creeper shadow. The damage box approximates moving limbs/head and swelling. Gun damage uses aim intersection per firing interval rather than weapon/pellet tables; explosives against the Creeper and NPC attacks against it are not implemented.
- There is no charged variant, cat avoidance, drops, music discs, block destruction, or interaction/damage between this resource's logical mobs and the separate Ghast resource.
- Client-reported LOS, hits, and damage remain trusted prototype inputs. This is not a production anti-cheat system. Enable `Config.RequireAce` and grant `creeper.spawn` to restrict spawning when preparing a public server.

## Files and verification

`client/main.lua` handles commands, anchors, replication, and cleanup. Rendering, targeting, movement, fuse intent/combat input, explosion damage, and spatial audio each have their own client module. `server/main.lua` owns the registry and fuse. `shared/` contains config, math, and the original model table. `assets/` contains only the copied inputs and derived runtime/reference outputs.

Run from the repository:

```powershell
python fivem-creeper/tools/verify.py
```

The verifier uses a compatible LuaJIT/5.1 library for Lua syntax/behavior checks and Node for NUI tests. It checks fuse timing and unwinding, stale intent, ownership and bucket isolation, death during fuse, movement bounds, missing/steep ground, multiple pending collision handles, original mesh bounds/UVs/winding, leg animation and swelling, client boot/interpolation/cleanup, single-owner explosions, spatial sound, voice caps, and cancellation during audio decoding. It also checks all packaged asset hashes. See [development instructions](../DEVELOPMENT.md) for prerequisites, `--lua-dll`, and optional `--check-sources` verification of the local Minecraft inputs.

To reproduce extraction or the offline reference mesh:

```powershell
python fivem-creeper/tools/extract_assets.py --version 26.3
python fivem-creeper/tools/reference_geometry.py
```

**Automated checks pass; actual FiveM rendering, native ground/collision behavior, NUI playback, and real multiplayer sessions have not been play-tested.** The server resource was not started automatically.

Suggested in-game checks: spawn on flat ground and a slope; approach to trigger the hiss, then escape or break LOS; shoot it during the fuse; let one detonate near a vehicle and behind cover; join with a second client; change routing buckets or disconnect the owner; then clear/stop/restart and check for leftover anchors/audio. Check `resmon` with several Creepers and the Ghast resource together.

# FiveM Ghast prototype

> **Experimental: not intended for production servers as-is.** See the [root README](../README.md) for performance costs and [asset/license scope](../THIRD_PARTY_NOTICES.md).

A standalone Lua resource using the Ghast artwork and sounds from the locally installed Minecraft Java Edition 26.3 client. The visible Ghast is a textured 4.5-meter cube with nine moving cuboid tentacles. It uses no GTA ped model.

## Run

Copy this directory into your test server's resources directory. In the **server console**, run:

```text
refresh
ensure fivem-ghast
```

Then, outdoors in FiveM, use `/ghast`. The body bottom spawns about 20 meters ahead and 15 meters above the detected ground. `/ghastclear` removes your Ghast and its fireballs. The default limit is one Ghast per player, six overall.

For startup persistence, add `ensure fivem-ghast` to the server's startup configuration yourself when ready. No existing config or other resource was changed. Modern FiveM with OneSync is required; no ESX, sound resource, npm package, or model editor is required.

## Behavior

- Slow wandering, gentle vertical bobbing, obstacle sweeps, and smooth yaw toward the selected target.
- Searches streamed player and NPC peds within 64 meters. Tests up to eight nearest candidates, with a small preference for keeping its current target. Blocked targets cannot start an attack; LOS is checked again before warning and launch.
- After 0.5 seconds of visible acquisition, plays the original charge sound and switches to the original shooting texture. Fires 0.5 seconds later, with a two-second recovery before the next acquisition cycle. Continuous visible targets receive about one shot every three seconds, matching the installed Java goal's 10/20/-40 tick cycle.
- Each fireball has an actual moving `CObject` replica. A camera-facing original fire charge sprite and orange light provide its visible appearance. It travels at the configured speed (currently 32 m/s); a swept sphere tests each movement segment against world geometry, objects, peds, and vehicles. An unresolved trace freezes movement rather than allowing tunneling.
- Confirmed impacts emit one visible GTA rocket explosion. Scripted splash damage falls off within five meters and checks cover. Each player applies their own damage; local/network-owned NPCs, vehicles, and props receive damage on their controlling client. Ground impacts create a small fire removed after six seconds. Native explosion damage is disabled to avoid adding a second damage pass; fire can still cause GTA fire damage.
- Original ambient samples play at randomized 7–15 second intervals. Shooting, warning, hurt, and death use their corresponding original sounds through Web Audio HRTF panning and distance attenuation. No NUI focus is taken.
- Aiming and shooting at the procedural body applies damage, with a muzzle-to-hit cover check. Melee can damage the body when it is close enough. At zero health, death audio plays and the Ghast is removed.
- Initial melee reflection is implemented: swing near an incoming fireball (about 2.8 meters), facing it. The server forwards the attempt to the projectile owner, which checks range and cover. Your camera aim sets the reflected direction when you own the simulation; another player's reflection uses that player's facing direction. A returned hit does 100 damage, enough to kill the default Ghast. Reflection can be disabled in config.

## Assets found and provenance

The installation inspected was `C:\Users\lucas\AppData\Roaming\.minecraft`. Common PrismLauncher, MultiMC, CurseForge, local program, and modelling tool locations were also checked. `26.3/26.3.jar` is installed (41,483,720 bytes); `26.4-snapshot-2` has a version JSON but no local JAR or local asset index 35. The installed asset index is `assets/indexes/34.json`.

Copied inputs:

| Purpose | Original local asset |
| --- | --- |
| Normal / attack artwork | JAR `assets/minecraft/textures/entity/ghast/ghast.png` and `ghast_shooting.png` (128×64) |
| Fireball artwork | JAR `assets/minecraft/textures/item/fire_charge.png` (16×16) |
| Ambient | Index keys `minecraft/sounds/mob/ghast/moan1.ogg` through `moan7.ogg` |
| Hurt | `minecraft/sounds/mob/ghast/scream1.ogg` through `scream5.ogg` |
| Death | `minecraft/sounds/mob/ghast/death.ogg` |
| Warning / charge | `minecraft/sounds/mob/ghast/charge.ogg` |
| Shoot / fire charge | `minecraft/sounds/mob/ghast/fireball4.ogg` |
| Geometry, texture net, timing, projectile reference | Compiled GhastModel, ModelPart$Cube, GhastRenderer, GhastShootFireballGoal, ThrownItemRenderer, Fireball, and random-source classes; fire charge model JSON |

[assets/SOURCES.md](assets/SOURCES.md) lists the full absolute source path for **every** copied or converted file, including each hashed sound object and its asset-index key. [assets/provenance.json](assets/provenance.json) records source/output SHA-1 hashes, sizes, and transformations. Minecraft assets remain Mojang/Microsoft artwork and audio; provenance does not change their ownership.

The original PNGs remain in `assets/textures`. The renderer loads generated RGBA PNGs in `assets/runtime`, upscaled 16× with nearest-neighbor sampling to keep their pixel detail. OGG Vorbis is used unchanged because FiveM's NUI browser decodes it directly. No sound conversion or downloaded asset pack is needed.

Other useful assets found but **not copied**: Ghast tear/spawn-egg art, dried Ghast models, Happy Ghast art and harnesses, `affectionate_scream.ogg`, and the Ender Dragon fireball texture. The dragon fireball is a different projectile; the installed Fireball class uses the fire charge item. The copied sound-event excerpt confirms warn/shoot/ambient/hurt/death mappings.

## Geometry and tentacles

There is no importable Ghast mesh in this client JAR: the Java model constructs cubes. No Blender, Sollumz, or CodeWalker executable was found in the locations checked, so a fully rigged `.ydr`/`.yft` export was outside the available toolchain.

The selected fallback uses FiveM's [DRAW_TEXTURED_POLY](https://docs.fivem.net/natives/?_0x29280002282F1928) and [CREATE_RUNTIME_TEXTURE_FROM_IMAGE](https://github.com/citizenfx/fivem/blob/master/ext/native-decls/CreateRuntimeTextureFromImage.md). It reconstructs the installed cube UV net using a 64×32 logical atlas (the original PNG is a 2× equivalent). Invisible, frozen, non-colliding pool-ball objects serve only as transform anchors; their GTA meshes are never shown.

The model reference specifies nine 2×length×2 tentacles, generated with seed 1660 and lengths `[8,13,9,11,11,10,12,9,12]`. Their exact grid offsets and swing formula `0.2 * sin(ageInTicks * 0.3 + i) + 0.4` are reproduced. Each tentacle rotates independently about its attachment. This provides animation without bones or nine additional objects per Ghast.

Separate child **entities** are viable after exporting one textured tentacle drawable: create nine objects, attach them to a body object with `AttachEntityToEntity`, and update local attachment rotation. A rigged skeleton is also viable with a Ghast drawable and authored animation clips. Neither approach can turn the compiled Java model directly into a GTA skeleton. The procedural approach already animates all nine parts while keeping the model-export step optional.

[assets/reference/ghast.obj](assets/reference/ghast.obj) and its material provide a reconstructed static mesh for a future modelling pass. [geometry.json](assets/reference/geometry.json) records dimensions, animation, and timing. [geometry-preview.png](assets/reference/geometry-preview.png) is a CPU reference render used to inspect UVs and shape; **it is not a FiveM screenshot**.

### Current limits

- Procedural triangles have no GTA skeleton, native mesh collision, or cast shadow. Weapon and returned-projectile hits use an oriented body box. Tentacles are decorative and do not take damage. Renderer depth behavior, appearance under different game builds, and performance need an in-game check.
- Damage from player gun aim is approximated per firing interval; weapon damage tables, explosives against the Ghast, shotgun pellet counts, and NPC attacks against the Ghast are not modelled.
- Melee reflection is a nearby-swing approximation. Remote swings use player facing rather than synchronized camera pitch. It needs timing and latency tuning in game.
- This implements the requested targeting of NPCs as well as players; Minecraft's hostile target selection is narrower. GTA movement, explosion visuals, fire damage, and configurable health are approximations of Minecraft behavior.

## Networking

One fixed spawning client runs each Ghast and its projectiles. A server-owned logical registry assigns IDs, owns health, validates owners/positions/cooldowns, and relays state every 100 ms to clients in the same routing bucket. Clients render local object replicas and interpolate remote positions. Three-second snapshots support late joins, bucket changes, and reconciliation. Impacts consume an ID exactly once; only the owner emits the native network explosion. Disconnects, owner timeouts, bucket changes, `/ghastclear`, expiry, and resource stop clean up entities and fires.

This is **application-level replication**, not engine-networked Ghast/projectile objects. It avoids competing GTA object controllers for the first prototype. NPC targeting is limited to peds streamed to the simulation owner. There is no host migration: the group is removed when that owner disconnects or changes bucket. A future networked drawable can use server-created objects and entity state bags while keeping these modules, IDs, and single-authority gameplay boundaries. See [Cfx OneSync documentation](https://docs.fivem.net/docs/scripting-reference/onesync/).

The server checks ownership, routing bucket, proximity, caps, finite coordinates, movement bounds, charge time, and attack cooldowns. Client-reported gun hits, LOS, melee input, and splash damage are trusted prototype inputs. These checks are not a production anti-cheat system. `Config.RequireAce = true` restricts spawning to `ghast.spawn` when preparing a public server.

## Module layout

| File | Responsibility |
| --- | --- |
| `shared/config.lua` | Tuning, limits, and spawn permissions |
| `shared/math.lua` | Serialization-safe vectors and oriented body intersection |
| `client/main.lua` | Commands, asset loading, local anchors, replication, render/update loops, cleanup |
| `client/ghast.lua` | Attack/ambient cycle and player damage/reflection input |
| `client/movement.lua` | Wander, bob, obstacle sweep, heading |
| `client/targeting.lua` | Candidate selection, cover and LOS |
| `client/fireball.lua` | Moving projectile collision, reflection, splash damage, fire lifecycle |
| `client/renderer.lua` | Original texture net, animated cuboids, projectile sprite |
| `client/audio.lua` / `assets/audio` | Spatial original sound playback |
| `server/main.lua` | Logical authority, health, validation, events, snapshots, cleanup |
| `stream/` | Reserved for a future native model export |
| `tools/` | Read-only extraction, reconstructed geometry, and no-install verification |

## Verification

Run from the repository:

```powershell
python fivem-ghast/tools/verify.py
```

It uses a compatible LuaJIT/5.1 library to parse Lua and run mocked behavioral checks (the source uses syntax compatible with Lua 5.1 and FiveM's Lua 5.4). It checks rotated body intersections, charge/cooldown timing, loss of LOS, pending/boolean collision results, returned hits, geometry winding/UV ranges, owner/routing-bucket checks, damage throttling, duplicate impacts, disconnect cleanup, packaged file hashes, and NUI audio behavior. See [development instructions](../DEVELOPMENT.md) for prerequisites, `--lua-dll`, and optional `--check-sources` verification of the local Minecraft inputs.

To reproduce asset extraction or the reference mesh:

```powershell
python fivem-ghast/tools/extract_assets.py --version 26.3
python fivem-ghast/tools/reference_geometry.py
```

**Automated checks passed. FiveM rendering, actual native collision results, Web Audio playback inside NUI, and real OneSync sessions have not been play-tested.** No running server configuration was edited or resource started automatically.

Suggested test-session checks (these alone do not establish production readiness):

1. Start the resource; spawn outdoors and confirm the original face, nine animated tentacles, height, movement, and ambient audio.
2. Stand in sight, then move behind a wall. Confirm warning before every shot and no launches through cover. Put an NPC within range to check NPC selection.
3. Watch a fireball travel into a wall, ground, vehicle, and ped. Confirm one explosion, cover-aware splash damage, short-lived fire, and no leftover projectile.
4. Shoot the body until it dies. Confirm hurt sounds, death sound, and cleanup. Swing toward a low incoming fireball; aim a returned shot at the body and confirm its death.
5. Join with a second client during flight. Confirm snapshots, smooth replicas, spatial audio, remote reflection, single explosions, and no duplicate damage. Test a different routing bucket and an owner disconnect.
6. Use `/ghastclear` and stop/restart the resource. Confirm anchors, fireballs, sounds, and script fires are removed. Check `resmon` with the configured cap of six Ghasts.

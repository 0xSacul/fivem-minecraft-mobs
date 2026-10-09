# FiveM Ender Dragon prototype

> **Experimental: not intended for production servers as-is.** See the [root README](../README.md) for performance costs and [asset/license scope](../THIRD_PARTY_NOTICES.md).

A standalone Lua resource using the original assets in the locally installed Minecraft Java 26.3.
It reconstructs the dragon's actual cuboids and UVs rather than displaying a GTA ped or vehicle.
Minecraft and the existing Ghast/Creeper resources were left unchanged. No software was installed.

## Start and spawn

Run these in the FiveM **server console**:

```text
refresh
ensure fivem-enderdragon
```

Then use `/enderdragon` in game, outdoors. The body spawns about 40m ahead and 30m above the
ground, circles its spawn area, then swoops toward visible players or NPC peds. Use
`/enderdragonclear` to remove your dragon, its projectiles and your breath clouds.
The defaults allow one dragon per player and two server-wide. Modern OneSync is required.
There are no framework, model-export, sound-resource or Ghast/Creeper dependencies.
Add `ensure fivem-enderdragon` to your startup config yourself if you want automatic startup;
this implementation does not edit server configuration or start the live server.

## Behavior

- Original head, jaw, body, four articulated legs, five neck segments, twelve tail segments,
  and two wings with independently hinged tips. Transparent wing skins render on both sides.
- Procedural flapping, curved neck/tail motion, steering, bank and pitch. Fully extended
  wingspan is approximately 24.8m at the configurable 0.10m/model-unit scale.
- Circling at 12m/s, swooping at up to 17m/s, and climbing back to cruise height. A swept
  sphere checks the body against world objects; detected obstacles trigger a climbing turn.
- Searches streamed players and NPC peds within 120m; prefers players and the current
  target. Only visible candidates are selected. LOS is checked again from the mouth before firing.
- Warns with an original growl, opens its jaw, then fires after 900ms. Attack cooldown is 5s.
  The dragon's original shoot event uses the same `fireball4.ogg` as the Ghast.
- Fireballs are moving **local CObject entities** with the original dragon fireball sprite.
  Their trajectories advance only after swept-sphere collision resolves. They move at 14m/s,
  expire after 14s, and create a visible impact and a damaging breath cloud on contact.
- Breath lasts 9s, covers a 5m horizontal radius, and deals 9 damage per 500ms tick.
  Damage respects cover; each client handles its own player and locally controlled NPCs/vehicles.
- Spatial original growls, wing flaps, hurt and death sounds via a hidden Web Audio page.
  No NUI focus or visible UI is used. Audio fades with distance.
- Shoot/melee the posed hitboxes to damage it. Default health is 1200; head/jaw hits deal
  double damage. Death plays the original sound and fades the exploding texture over 4.5s.

## Vehicle contact explosions

**Enabled by default.** Contact with the dragon's body, head, neck, tail, legs, wing bones or
wing membranes destroys the vehicle with a visible, audible vehicle explosion.
This applies to occupied vehicles as well as empty ones. Normal GTA vehicle-explosion damage
can injure occupants and nearby entities.

The dragon simulator checks the vehicle's oriented model bounds against the animated model's
oriented hitboxes. It samples intermediate poses during fast movement and flaps, rather than
checking only distance from the body center. Wing membranes use thin rectangular bounds;
their transparent cutouts are not collision holes.

For a networked vehicle, the simulator reports its network ID. The server checks dragon ownership,
routing bucket, entity type, proximity and rate limits, consumes duplicate contacts, and asks the
vehicle's **current controlling client** to explode it. That client checks control before calling
`NetworkExplodeVehicle(vehicle, true, false, false)`. Unacknowledged requests follow ownership
changes for up to 5s. A vehicle that stays unstreamed or cannot yield control can time out.
Non-networked local vehicles explode directly on the simulator. Damageability is enabled on
contact so mission/invincibility flags do not ordinarily prevent the requested destruction.

Configure this in `shared/config.lua`:

```lua
VehicleContact = {
    Enabled = true,
    -- other existing settings ...
}
```

## Architecture and synchronization

| Module | Responsibility |
| --- | --- |
| `shared/config.lua`, `shared/math.lua` | Tuning, vector math, box tests |
| `shared/model.lua` | Generated original model geometry and hierarchy |
| `client/renderer.lua` | Textured mesh, animation, matching hitboxes, reference exports |
| `client/movement.lua` | Circling/swooping/obstacle recovery |
| `client/targeting.lua` | Candidate selection and LOS |
| `client/dragon.lua` | Attacks, ambient sounds and player weapon hits |
| `client/vehicles.lua` | Animated contact, control-aware vehicle explosions |
| `client/fireball.lua` | Moving entity projectiles and breath |
| `client/audio.lua`, `assets/audio/` | Spatial OGG playback |
| `client/main.lua` | Commands, local entities, replicas, cleanup |
| `server/main.lua` | Registry, health, cooldowns, bucket routing, vehicle-owner dispatch |

The spawning client simulates a dragon and its projectiles. The server owns logical IDs,
health, attack timing, cloud expiry and vehicle-explosion requests. It forwards 100ms state updates
only within the correct routing bucket. Other clients interpolate replicas; snapshots every 3s
reconcile removals and allow late joiners to see active breath. Animation phase travels with the
state, independent of client clock offsets. Owner disconnect, bucket changes and stale ownership
remove its dragon. Resource stop deletes local anchors and stops audio.

These are application-level replicas using **local**, invisible, frozen, non-colliding CObject
anchors, not networked native dragon meshes. There is no host migration. Strict entity lockdown
may prevent local anchor creation; a notification explains object-creation failure.
Damage, LOS and exact vehicle contact are client-reported; server checks are bounded validation,
not production anti-cheat. For a public server, enable `RequireAce` and grant `enderdragon.spawn`.

## Geometry and prototype limits

A fully rigged native GTA drawable requires a suitable model-export workflow. The existing
machine did not have Blender/Sollumz/CodeWalker available during the earlier mob inspection,
so this version draws textured triangles and animates a hierarchy of part transforms in Lua.
It uses the original 65 cuboids, with 374 rendered quads including the two-sided wing skins.
The `.obj` reference is inspectable geometry, not a FiveM streamable drawable.

Scripted hitboxes cover the posed mesh for weapons and vehicle contact. They do not physically
push the dragon, peds or vehicles. World avoidance covers the body; long wings/tail may clip
buildings. Flight works best in open areas and does not reproduce Minecraft's End-specific path
graph. It includes circling and swooping, but no landing/perching, crystals, block destruction,
XP drops, exact boss phases or rideable dragon. Breath uses animated original sprites instead
of depending on a GTA particle effect that might vary across builds. Weapon detection uses
shooting/aim intersection, so per-weapon ballistic damage and NPC attacks against the mesh are
not implemented. Death is a simplified textured fade, not the full Minecraft ray sequence.

Tentacle-style child entities are unnecessary here: wing tips, jaw and all leg segments are
animated under parent transforms. A future rig can map these same transforms to actual bones
while keeping flight, targeting, projectile and vehicle logic separate.

## Assets and reproducibility

Every copied/converted input has an exact source and SHA-1 in `assets/provenance.json` and
`assets/SOURCES.md`. Textures came from the installed client JAR; OGG Vorbis files came from
Minecraft's SHA-1 asset objects using index 34. Sounds need no conversion. Runtime PNGs are
RGBA with 4x nearest-neighbor scaling; the hurt variant is a red overlay.
Only needed files were copied; the entire JAR or assets tree is not included. The copied
compiled classes are reference files and are excluded from the client resource download.

`tools/model_reference.py` reads the declarative `createBodyLayer` builder bytecode without
running Java. Unsupported opcodes/calls stop extraction. `shared/model.lua` and the saved JSON
contain original dimensions, texture offsets, mirror flags, part pivots and parent hierarchy.
`tools/reference_geometry.py` exports the actual Lua mesh to OBJ/JSON, a CPU reference image and
a wing-animation GIF. Those previews are not in-game screenshots.

Using Python, Node, and a compatible LuaJIT/5.1 library (Pillow/NumPy are additionally needed for reference generation):

```powershell
python fivem-enderdragon/tools/verify.py
python fivem-enderdragon/tools/reference_geometry.py
# Optional re-extraction, writes only inside this resource:
python fivem-enderdragon/tools/extract_assets.py --version 26.3
```

## Validation

Automated Lua syntax and mocked behavioral checks cover model/UV/winding, wing and tail
animation, matching hitboxes, flight recovery, target/charge/cooldown behavior, ownership,
bucket isolation, duplicate impact consumption, moving projectile sweeps, late-join breath,
headshot/death behavior, body/wing vehicle contact, control restrictions, ownership migration,
duplicate vehicle explosions, replica interpolation, cleanup and cover-aware damage ticks.
NUI checks cover HRTF spatial audio, asset allowlisting, voice limits and canceled pending sounds.
Asset hashes verify packaged outputs; `--check-sources` additionally checks the recorded local Minecraft source files. See [development instructions](../DEVELOPMENT.md) for prerequisites and `--lua-dll`. Original OGGs were decoded
with the existing FFmpeg installation. These checks use mocks and the compatible Lua subset;
they **do not establish a successful in-game FiveM test**.

Suggested in-game checks: spawn in an open area, watch circling/flaps and a dive, shoot the head
and body, seek cover from a fireball/breath cloud, drive a car under the wings, and repeat with
a second player's occupied networked car. Confirm one explosion on contact, late join/bucket
isolation, owner disconnect cleanup and resource restart. Set `Config.Debug = true` to draw
the current weapon/vehicle hitboxes during this check.

Minecraft assets retain their original ownership. This resource does not transfer rights to them.

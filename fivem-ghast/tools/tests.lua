local M = GhastMath
local function near(a, b) assert(math.abs(a - b) < 0.0001, tostring(a) .. ' != ' .. tostring(b)) end
local function point(x, y, z) return { x = x or 0, y = y or 0, z = z or 0 } end
local center = point()
near(M.segmentBody(point(0, -10), point(0, 10), center, 0, 0), (10 - Config.BodySize / 2) / 20)
assert(M.segmentBody(point(8, -10), point(8, 10), center, 0, 0) == nil)
near(M.segmentBody(center, point(0, 10), center, 45, 0), 0)
assert(M.segmentBody(point(2.7, -10), point(2.7, 10), center, 45, 0))
assert(not M.valid(point(0/0, 0, 0)))
assert(not M.valid(point(math.huge, 0, 0)))
assert(M.hit(true) and M.hit(1) and not M.hit(false) and not M.hit(0))
near(M.heading(point(), point(0, 1)), 0)
near(M.heading(point(), point(-1, 0)), 90)
near(M.angleDelta(350, 10), 20)

local events, handlers, clock, bucket, players = {}, {}, 0, { [1] = 0, [2] = 0, [3] = 1 }, { '1', '2', '3' }
function GetGameTimer() return clock end
function RegisterNetEvent(name, fn) handlers[name] = fn end
function AddEventHandler(name, fn) handlers[name] = fn end
function CreateThread() end
function GetPlayers() return players end
function GetPlayerRoutingBucket(src) return bucket[src] end
function GetPlayerPed(src) return src end
function GetEntityCoords() return point() end
function GetPlayerName(src) return 'player' .. src end
function IsPlayerAceAllowed() return true end
function TriggerClientEvent(name, target, ...)
    events[#events + 1] = { name = name, target = target, args = { ... } }
end
function TriggerServerEvent(name, ...)
    events[#events + 1] = { name = name, args = { ... } }
end
local function invoke(name, src, ...)
    source = src
    assert(handlers['fivem-ghast:' .. name], name)(...)
end
local function last(name)
    for i = #events, 1, -1 do if events[i].name == 'fivem-ghast:' .. name then return events[i] end end
end
local function total(name)
    local n = 0
    for _, event in ipairs(events) do if event.name == 'fivem-ghast:' .. name then n = n + 1 end end
    return n
end
local function loadResource(path) dofile(path) end
-- verify.py runs with resource root as the current working directory.
loadResource('server/main.lua')
invoke('spawn', 1, point(0, 20, 17.25), 0)
local g = last('ghast').args[1]
assert(g.hp == Config.Health and g.owner == 1)
for _, event in ipairs(events) do assert(event.target ~= 3, 'Cross-bucket event leak') end
local gid = g.id
clock = 100
invoke('warn', 2, gid)
assert(not last('sound'), 'Non-owner warning accepted')
invoke('shoot', 1, gid, g.pos, point(0, -1))
assert(not last('projectile'), 'Uncharged shot accepted')
invoke('warn', 1, gid)
assert(last('sound').args[1] == 'warn')
invoke('shoot', 1, gid, g.pos, point(0, -1))
assert(not last('projectile'), 'Instant shot accepted')
clock = 600
invoke('shoot', 1, gid, g.pos, point(0, -1))
local p = last('projectile').args[1]
assert(p and M.length(p.direction) == 1)
local oldProjectiles = total('projectile')
invoke('warn', 1, gid)
invoke('shoot', 1, gid, g.pos, point(0, -1))
assert(total('projectile') == oldProjectiles, 'Cooldown bypass')
invoke('damage', 3, gid, 'bullet')
assert(last('ghast').args[1].hp == Config.Health, 'Cross-bucket damage accepted')
clock = 1000
invoke('damage', 2, gid, 'bullet')
assert(last('ghast').args[1].hp == Config.Health - Config.BulletDamage)
local hp = last('ghast').args[1].hp
invoke('damage', 2, gid, 'bullet')
assert(last('ghast').args[1].hp == hp, 'Damage throttle bypass')
invoke('update', 2, { { id = gid, pos = point(5, 20, 17.25), heading = 0 } }, {})
invoke('requestSnapshot', 2)
assert(last('snapshot').args[1][1].pos.x == 0, 'Non-owner movement accepted')
clock = 1300
invoke('update', 1, { { id = gid, pos = point(40, 20, 17.25), heading = 0 } }, {})
invoke('requestSnapshot', 1)
assert(last('snapshot').args[1][1].pos.x == 0, 'Teleport accepted')
clock = 2600
-- Move projectile near player using valid bounded steps.
for i = 1, 20 do
    clock = clock + 200
    invoke('update', 1, {}, { { id = p.id, pos = point(0, 20 - i, 17.25 - i * 0.7) } })
end
p.pos = point(0, 0, 3.25)
invoke('reflect', 2, p.id)
assert(last('tryReflect'), 'Nearby reflection not forwarded')
invoke('reflected', 2, p.id, 2, point(0, 1))
assert(not last('applyReflection'), 'Non-owner reflection accepted')
invoke('reflected', 1, p.id, 2, point(0, 1))
assert(last('applyReflection'), 'Owner reflection not accepted')
-- Return toward the Ghast in bounded steps below the configured speed.
for i = 1, 20 do
    clock = clock + 200
    invoke('update', 1, {}, { { id = p.id, pos = point(0, i, 3.25 + i * 0.7) } })
end
invoke('impact', 2, p.id, point(0, 20, 17.25), gid)
assert(not last('impactFx'), 'Non-owner impact accepted')
invoke('impact', 1, p.id, point(0, 20, 17.25), gid)
assert(last('impactFx') and last('removeGhast'), 'Returned fireball should kill Ghast')
assert(last('sound').args[1] == 'death')
local impacts = total('impactFx')
invoke('impact', 1, p.id, point(0, 20, 17.25), gid)
assert(total('impactFx') == impacts, 'Duplicate impact accepted')
clock = clock + 5000
invoke('spawn', 1, point(0, 20, 17.25), 0)
assert(last('ghast').args[1].id ~= gid)
source = 1; handlers.playerDropped()
assert(last('removeGhast').args[1] == last('ghast').args[1].id, 'Disconnect cleanup failed')

-- Client attack cycle with real logic and mocked natives/target visibility.
GhastTargeting = { find = function() return 9 end, visible = function() return true end, aim = function() return point(0, 0, 1) end }
GhastMovement = { update = function() end }
function DoesEntityExist() return true end
function IsEntityDead() return false end
loadResource('client/ghast.lua')
events = {}
g = { id = 'test', pos = point(0, 20, 20), heading = 180, origin = point(0, 20, 20), nextAmbient = 999999 }
GhastEntity.update(g, 0.016, 0)
GhastEntity.update(g, 0.016, 499)
assert(not last('warn'))
GhastEntity.update(g, 0.016, 500)
assert(last('warn'))
GhastEntity.update(g, 0.016, 999)
assert(not last('shoot'))
GhastEntity.update(g, 0.016, 1000)
assert(last('shoot') and g.nextAttack == 3000)
local shots = total('shoot')
GhastEntity.update(g, 0.016, 2999)
assert(total('shoot') == shots)
GhastEntity.update(g, 0.016, 3000)
GhastEntity.update(g, 0.016, 3500)
GhastTargeting.visible = function() return false end
GhastEntity.update(g, 0.016, 4000)
assert(total('shoot') == shots, 'Fired after line of sight was lost')

-- Swept projectile: boolean hit results, pending traces, and reflected cube collision.
loadResource('client/fireball.lua')
GhastWorld = { ghasts = {}, projectiles = {} }
local status, hit, hitPoint = 1, false, point()
function GetShapeTestResult() return status, hit, hitPoint, point(), 0 end
function StartShapeTestSweptSphere(...) return 77 end
events = {}
p = { id = 'ptest', pos = point(), direction = point(0, 1), born = 0, entity = 77 }
GhastFireball.update(p, 0.05, 50)
near(p.pos.y, 0)
GhastFireball.update(p, 0.05, 100)
near(p.pos.y, 0)
status = 2
GhastFireball.update(p, 0.05, 150)
near(p.pos.y, Config.Fireball.Speed * 0.05)
hit, hitPoint = true, point(0, Config.Fireball.Speed * 0.05 + 0.2)
GhastFireball.update(p, 0.05, 200)
assert(p.ending and last('impact'), 'Boolean collision ignored')
local n = total('impact')
GhastFireball.update(p, 0.05, 250)
assert(total('impact') == n, 'Projectile hit twice')
p = { id = 'preflect', pos = point(0, -3), direction = point(0, 1), born = 0, entity = 77, reflected = true }
GhastWorld.ghasts.test = { pos = point(), heading = 0 }
hit = false
GhastFireball.update(p, 0.05, 50)
GhastFireball.update(p, 0.05, 100)
GhastFireball.update(p, 0.05, 150)
assert(p.ending and last('impact').args[3] == 'test', 'Returned projectile missed procedural collider')

-- Geometry renders ten outward cubes, with UV values bounded by the original atlas.
local triangles = {}
function CreateRuntimeTxd() return 1 end
function CreateRuntimeTextureFromImage() return 2 end
function DrawTexturedPoly(...) triangles[#triangles + 1] = { ... } end
loadResource('client/renderer.lua')
GhastRenderer.init()
GhastRenderer.ghast({pos = point(), heading = 0}, 0)
assert(#triangles == 120, 'Expected ten cubes, 12 triangles each')
local a, b, c = triangles[7], nil, nil -- front face, first triangle
local va, vb, vc = point(a[1],a[2],a[3]), point(a[4],a[5],a[6]), point(a[7],a[8],a[9])
local ab, ac = M.sub(vb,va), M.sub(vc,va)
local normalY = ab.z * ac.x - ab.x * ac.z
assert(normalY > 0, 'Front face must face GTA +Y')
for _, tri in ipairs(triangles) do
    for _, offset in ipairs({16,19,22}) do
        assert(tri[offset] >= 0 and tri[offset] <= 1 and tri[offset+1] >= 0 and tri[offset+1] <= 1)
        assert(tri[offset+2] == 1)
    end
end

-- Movement must not treat native boolean false as a hit.
loadResource('client/movement.lua')
g = { pos = point(0, 0, 20), origin = point(0, 0, 20), heading = 0, entity = 7 }
status, hit = 2, false
GhastMovement.update(g, 0.05, 0)
local destination = M.coords(g.moveEnd)
GhastMovement.update(g, 0.05, 50)
near(M.distance(g.pos, destination), 0)
status, hit = 2, true
local position = M.coords(g.pos)
GhastMovement.update(g, 0.05, 100)
near(M.distance(g.pos, position), 0)

-- Boot the actual client coordinator, then verify local replicas/interpolation/reconciliation/stop cleanup.
local threads, deleted, entities, explosions = {}, {}, 100, 0
function GetHashKey() return 123 end
function RegisterCommand() end
function CreateThread(fn) threads[#threads + 1] = fn end
function Wait() coroutine.yield() end
function IsModelInCdimage() return true end
function IsModelValid() return true end
function RequestModel() end
function HasModelLoaded() return true end
function PlayerId() return 1 end
function PlayerPedId() return 1 end
function GetPlayerServerId(player) return player end
function IsPedShooting() return false end
function IsPedPerformingMeleeAction() return false end
function GetGameplayCamCoord() return point() end
function GetGameplayCamRot() return point() end
function CreateObjectNoOffset() entities = entities + 1; return entities end
function SetEntityAsMissionEntity() end
function SetEntityVisible() end
function SetEntityAlpha() end
function SetEntityCollision() end
function FreezeEntityPosition() end
function SetEntityInvincible() end
function SetEntityCoordsNoOffset() end
function SetEntityHeading() end
function DeleteEntity(entity) deleted[#deleted + 1] = entity end
function DrawLightWithRange() end
function GetGamePool() return {} end
function GetGroundZFor_3dCoord() return false, 0 end
function GetCurrentResourceName() return 'fivem-ghast' end
function SendNUIMessage() end
function SetModelAsNoLongerNeeded() end
Citizen = { InvokeNative = function(hash, ...)
    assert(hash == 0xE3AD2BDBAEE269AC)
    local args = { ... }
    assert(#args == 9 and args[9] == true, 'Native damage must be disabled')
    explosions = explosions + 1
end }
GhastAudio = {play = function() end, listener = function() end}
loadResource('client/main.lua')
local loop = coroutine.create(threads[1])
local function resume()
    local ok, error = coroutine.resume(loop)
    assert(ok, error)
end
resume()
local replica = {id = 'remote',owner = 2,pos = point(0,20,17.25),origin = point(0,20,17.25),heading = 350,hp = 100}
handlers['fivem-ghast:ghast'](replica)
assert(GhastWorld.ghasts.remote.entity == 101)
local moved = {id = 'remote',owner = 2,pos = point(2,20,17.25),origin = replica.origin,heading = 10,hp = 100}
handlers['fivem-ghast:state']({moved},{})
clock = clock + Config.SyncIntervalMs / 2
resume()
near(GhastWorld.ghasts.remote.pos.x, 1)
near(GhastWorld.ghasts.remote.heading, 0)
clock = clock + Config.SyncIntervalMs / 2
resume()
near(GhastWorld.ghasts.remote.pos.x, 2)
handlers['fivem-ghast:projectile']({id = 'remoteP',owner = 2,pos = point(0,5,3),direction = point(0,1),reflected = false})
resume()
assert(GhastWorld.projectiles.remoteP.entity == 102)
handlers['fivem-ghast:snapshot']({moved},{})
assert(not GhastWorld.projectiles.remoteP and #deleted == 1)
GhastFireball.impact(point(100,100,20), 2)
assert(explosions == 0, 'Replica emitted network explosion')
GhastFireball.impact(point(100,100,20), 1)
assert(explosions == 1, 'Owner should emit exactly one network explosion')
handlers.onResourceStop('fivem-ghast')
assert(not next(GhastWorld.ghasts) and not next(GhastWorld.projectiles) and #deleted == 2)

print('Lua behavioral assertions passed')

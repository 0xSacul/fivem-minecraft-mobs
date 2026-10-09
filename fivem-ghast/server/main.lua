-- Logical server registry. Clients make local object replicas; one fixed owner simulates each group.
-- A drawable export can later replace local anchors with server-created networked objects.
local M = GhastMath
local ghasts, projectiles, rates, serial = {}, {}, {}, 0
local function now() return GetGameTimer() end
local function id(prefix) serial = serial + 1; return prefix .. serial end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local function allowed(src, key, interval)
    rates[src] = rates[src] or {}
    if now() < (rates[src][key] or 0) then return false end
    rates[src][key] = now() + interval
    return true
end
local function broadcast(bucket, event, ...)
    for _, player in ipairs(GetPlayers()) do
        local src = tonumber(player)
        if GetPlayerRoutingBucket(src) == bucket then TriggerClientEvent('fivem-ghast:' .. event, src, ...) end
    end
end
local function own(src, entry)
    return entry and entry.owner == src and GetPlayerRoutingBucket(src) == entry.bucket
end
local function playerNear(src, position, range, bucket)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetPlayerRoutingBucket(src) == bucket and M.distance(M.coords(GetEntityCoords(ped)), position) <= range
end
local function public(entry)
    return { id = entry.id, owner = entry.owner, pos = entry.pos, heading = entry.heading, origin = entry.origin,
             hp = entry.hp, charging = entry.charging, ghastId = entry.ghastId,
             direction = entry.direction, reflected = entry.reflected == true }
end
local function removeProjectile(p)
    broadcast(p.bucket, 'removeProjectile', p.id)
    projectiles[p.id] = nil
end
local function removeGhast(g)
    broadcast(g.bucket, 'removeGhast', g.id)
    ghasts[g.id] = nil
    for _, p in pairs(projectiles) do if p.ghastId == g.id then removeProjectile(p) end end
end
local function damage(g, amount)
    g.hp = math.max(0, g.hp - amount)
    broadcast(g.bucket, 'sound', g.hp == 0 and 'death' or 'hurt', g.pos, g.id)
    if g.hp == 0 then removeGhast(g) else broadcast(g.bucket, 'ghast', public(g)) end
end

RegisterNetEvent('fivem-ghast:spawn', function(position, heading)
    local src = source
    if not allowed(src, 'spawn', Config.SpawnCooldownMs) or not M.valid(position) or not M.finite(heading) then return end
    if Config.RequireAce and not IsPlayerAceAllowed(src, 'ghast.spawn') then
        TriggerClientEvent('fivem-ghast:notice', src, 'Missing ghast.spawn permission.'); return
    end
    local owned = 0
    for _, g in pairs(ghasts) do if g.owner == src then owned = owned + 1 end end
    if owned >= Config.MaxGhastsPerPlayer or count(ghasts) >= Config.MaxGhasts then
        TriggerClientEvent('fivem-ghast:notice', src, 'Ghast limit reached. Use /ghastclear to remove yours.'); return
    end
    local bucket = GetPlayerRoutingBucket(src)
    if not playerNear(src, position, 75.0, bucket) then return end
    local g = { id = id('g'), owner = src, bucket = bucket, pos = position, origin = M.coords(position),
                heading = heading % 360, hp = Config.Health, charging = false, updated = now(),
                lastMove = now(), nextAttack = 0, nextAmbient = 0 }
    ghasts[g.id] = g
    broadcast(bucket, 'ghast', public(g))
end)
RegisterNetEvent('fivem-ghast:requestSnapshot', function()
    local src = source
    if not allowed(src, 'snapshot', 1000) then return end
    local bucket, gs, ps = GetPlayerRoutingBucket(src), {}, {}
    for _, g in pairs(ghasts) do if g.bucket == bucket then gs[#gs + 1] = public(g) end end
    for _, p in pairs(projectiles) do if p.bucket == bucket then ps[#ps + 1] = public(p) end end
    TriggerClientEvent('fivem-ghast:snapshot', src, gs, ps)
end)
RegisterNetEvent('fivem-ghast:update', function(gs, ps)
    local src = source
    if not allowed(src, 'update', math.floor(Config.SyncIntervalMs * 0.75)) or type(gs) ~= 'table' or type(ps) ~= 'table'
       or #gs > Config.MaxGhasts or #ps > Config.Fireball.MaxActive then return end
    local buckets = {}
    for _, state in ipairs(gs) do
        if type(state) == 'table' then
            local g = ghasts[state.id]
            if own(src, g) and M.valid(state.pos) and M.finite(state.heading)
               and M.distance(state.pos, g.origin) <= Config.WanderRadius + 12 then
                local elapsed = math.min(1.0, (now() - g.lastMove) / 1000)
                if M.distance(g.pos, state.pos) <= Config.WanderSpeed * elapsed * 2 + 0.8 then
                    g.pos, g.heading, g.updated, g.lastMove = state.pos, state.heading % 360, now(), now()
                    buckets[g.bucket] = buckets[g.bucket] or { {}, {} }
                    table.insert(buckets[g.bucket][1], public(g))
                end
            end
        end
    end
    for _, state in ipairs(ps) do
        if type(state) == 'table' then
            local p = projectiles[state.id]
            if own(src, p) and M.valid(state.pos) then
                local elapsed = math.min(1.0, (now() - p.updated) / 1000)
                if M.distance(state.pos, p.pos) <= Config.Fireball.Speed * elapsed * 1.5 + 0.8 then
                    p.pos, p.updated = state.pos, now()
                    buckets[p.bucket] = buckets[p.bucket] or { {}, {} }
                    table.insert(buckets[p.bucket][2], public(p))
                end
            end
        end
    end
    for bucket, entries in pairs(buckets) do broadcast(bucket, 'state', entries[1], entries[2]) end
end)
RegisterNetEvent('fivem-ghast:warn', function(gid)
    local g = ghasts[gid]
    if not own(source, g) or g.charging or now() < g.nextAttack then return end
    g.charging, g.chargeAt = true, now()
    broadcast(g.bucket, 'sound', 'warn', g.pos, g.id)
    broadcast(g.bucket, 'ghast', public(g))
end)
RegisterNetEvent('fivem-ghast:cancelCharge', function(gid)
    local g = ghasts[gid]
    if not own(source, g) or not g.charging then return end
    g.charging = false
    broadcast(g.bucket, 'ghast', public(g))
end)
RegisterNetEvent('fivem-ghast:shoot', function(gid, position, direction)
    local g = ghasts[gid]
    if not own(source, g) or not g.charging or now() - g.chargeAt < Config.ChargeMs - 100
       or now() < g.nextAttack or not M.valid(position) or not M.valid(direction)
       or M.distance(position, g.pos) > Config.BodySize + 2 or M.length(direction) < 0.01 then return end
    g.charging, g.nextAttack = false, now() + Config.AttackCooldownMs
    broadcast(g.bucket, 'ghast', public(g))
    if count(projectiles) >= Config.Fireball.MaxActive then return end
    local p = { id = id('p'), owner = g.owner, bucket = g.bucket, ghastId = gid, pos = position,
                direction = M.normalize(direction), reflected = false, born = now(), updated = now() }
    projectiles[p.id] = p
    broadcast(g.bucket, 'sound', 'shoot', g.pos, g.id)
    broadcast(g.bucket, 'projectile', public(p))
end)
RegisterNetEvent('fivem-ghast:ambient', function(gid)
    local g = ghasts[gid]
    if not own(source, g) or now() < g.nextAmbient then return end
    g.nextAmbient = now() + Config.AmbientMinMs
    broadcast(g.bucket, 'sound', 'ambient', g.pos, g.id)
end)
RegisterNetEvent('fivem-ghast:damage', function(gid, kind)
    local src, g = source, ghasts[gid]
    if not g or (kind ~= 'bullet' and kind ~= 'melee') or not allowed(src, 'damage', Config.DamageIntervalMs) then return end
    if not playerNear(src, g.pos, kind == 'melee' and 7.0 or Config.RenderDistance, g.bucket) then return end
    damage(g, kind == 'melee' and Config.MeleeDamage or Config.BulletDamage)
end)
RegisterNetEvent('fivem-ghast:reflect', function(pid)
    local src, p = source, projectiles[pid]
    if not Config.Fireball.Reflection or not p or not allowed(src, 'reflect', Config.Fireball.ReflectCooldownMs)
       or not playerNear(src, p.pos, Config.Fireball.ReflectDistance + 1.5, p.bucket) then return end
    p.reflectPlayer, p.reflectUntil = src, now() + 1500
    TriggerClientEvent('fivem-ghast:tryReflect', p.owner, pid, src)
end)
RegisterNetEvent('fivem-ghast:reflected', function(pid, player, direction)
    local p = projectiles[pid]
    if not own(source, p) or p.reflectPlayer ~= player or now() > (p.reflectUntil or 0) or not M.valid(direction)
       or not playerNear(player, p.pos, Config.Fireball.ReflectDistance + 2.0, p.bucket) then return end
    p.reflected, p.direction, p.reflectPlayer = true, M.normalize(direction), nil
    broadcast(p.bucket, 'applyReflection', pid, p.direction)
    broadcast(p.bucket, 'projectile', public(p))
end)
RegisterNetEvent('fivem-ghast:impact', function(pid, position, hitGhast)
    local p = projectiles[pid]
    if not own(source, p) or not M.valid(position) or M.distance(position, p.pos) > 5.0 then return end
    projectiles[pid] = nil -- consume once before any damage or FX
    broadcast(p.bucket, 'impactFx', pid, position, p.owner)
    local g = ghasts[hitGhast]
    if p.reflected and g and g.bucket == p.bucket and M.distance(position, g.pos) <= Config.BodySize + 1 then
        damage(g, Config.ReflectedDamage)
    end
end)
RegisterNetEvent('fivem-ghast:expire', function(pid)
    local p = projectiles[pid]
    if own(source, p) then removeProjectile(p) end
end)
RegisterNetEvent('fivem-ghast:clear', function()
    local src = source
    if not allowed(src, 'clear', 500) then return end
    for _, g in pairs(ghasts) do if g.owner == src then removeGhast(g) end end
end)
AddEventHandler('playerDropped', function()
    local src = source
    for _, g in pairs(ghasts) do if g.owner == src then removeGhast(g) end end
    rates[src] = nil
end)
CreateThread(function()
    while true do
        Wait(1000)
        for _, g in pairs(ghasts) do
            if not GetPlayerName(g.owner) or GetPlayerRoutingBucket(g.owner) ~= g.bucket
               or now() - g.updated > Config.OwnerTimeoutMs then removeGhast(g) end
        end
        for _, p in pairs(projectiles) do
            if now() - p.born > Config.Fireball.LifetimeMs + 1000 then removeProjectile(p) end
        end
    end
end)

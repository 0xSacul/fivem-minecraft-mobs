GhastWorld = { ghasts = {}, projectiles = {} }
local W, M = GhastWorld, GhastMath
local model, initialized = GetHashKey(Config.AnchorModel), false

local function notify(message)
    print('[fivem-ghast] ' .. message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end
local function deleteEntry(collection, id)
    local entry = collection[id]
    if entry and entry.entity and DoesEntityExist(entry.entity) then DeleteEntity(entry.entity) end
    collection[id] = nil
end
local function anchor(position)
    local entity = CreateObjectNoOffset(model, position.x, position.y, position.z, false, false, false)
    if entity == 0 then return nil end
    SetEntityAsMissionEntity(entity, true, true)
    SetEntityVisible(entity, false, false)
    SetEntityAlpha(entity, 0, false)
    SetEntityCollision(entity, false, false)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    return entity
end

local function upsert(collection, data, projectile)
    if not initialized then return end
    local entry = collection[data.id]
    local now = GetGameTimer()
    if not entry then
        entry = { id = data.id, entity = anchor(data.pos), pos = M.coords(data.pos), heading = data.heading or 0.0,
                  born = now, origin = data.origin, nextAmbient = now + math.random(Config.AmbientMinMs, Config.AmbientMaxMs) }
        if not entry.entity then notify('Object creation failed. Check entity lockdown settings.'); return end
        collection[data.id] = entry
    end
    entry.owner, entry.hp = data.owner, data.hp
    if entry.owner ~= GetPlayerServerId(PlayerId()) then
        entry.from, entry.to, entry.received = M.coords(entry.pos), M.coords(data.pos), now
        entry.fromHeading, entry.toHeading = entry.heading, data.heading or 0.0
        entry.charging = data.charging == true
    end
    if projectile then
        entry.direction, entry.reflected, entry.ghastId = data.direction, data.reflected, data.ghastId
    end
end

RegisterNetEvent('fivem-ghast:notice', notify)
RegisterNetEvent('fivem-ghast:ghast', function(data) upsert(W.ghasts, data, false) end)
RegisterNetEvent('fivem-ghast:projectile', function(data) upsert(W.projectiles, data, true) end)
RegisterNetEvent('fivem-ghast:state', function(ghasts, projectiles)
    for _, g in ipairs(ghasts) do upsert(W.ghasts, g, false) end
    for _, p in ipairs(projectiles) do upsert(W.projectiles, p, true) end
end)
RegisterNetEvent('fivem-ghast:snapshot', function(ghasts, projectiles)
    local seenG, seenP = {}, {}
    for _, g in ipairs(ghasts) do seenG[g.id] = true; upsert(W.ghasts, g, false) end
    for _, p in ipairs(projectiles) do seenP[p.id] = true; upsert(W.projectiles, p, true) end
    for id in pairs(W.ghasts) do if not seenG[id] then deleteEntry(W.ghasts, id) end end
    for id in pairs(W.projectiles) do if not seenP[id] then deleteEntry(W.projectiles, id) end end
end)
RegisterNetEvent('fivem-ghast:removeGhast', function(id) deleteEntry(W.ghasts, id) end)
RegisterNetEvent('fivem-ghast:removeProjectile', function(id) deleteEntry(W.projectiles, id) end)
RegisterNetEvent('fivem-ghast:sound', function(event, position, id)
    GhastAudio.play(event, position)
    if event == 'hurt' and W.ghasts[id] then W.ghasts[id].hurtUntil = GetGameTimer() + 250 end
end)
RegisterNetEvent('fivem-ghast:impactFx', function(id, position, owner)
    deleteEntry(W.projectiles, id)
    if M.distance(M.coords(GetEntityCoords(PlayerPedId())), position) <= Config.RenderDistance then
        GhastFireball.impact(position, owner)
    end
end)
RegisterNetEvent('fivem-ghast:tryReflect', GhastFireball.reflect)
RegisterNetEvent('fivem-ghast:applyReflection', GhastFireball.applyReflection)

RegisterCommand('ghast', function()
    if not initialized then notify('Ghast assets are still loading.'); return end
    CreateThread(function()
        local ped = PlayerPedId()
        local front = M.coords(GetOffsetFromEntityInWorldCoords(ped, 0.0, Config.SpawnForward, 0.0))
        local deadline, found, ground = GetGameTimer() + 2000, false, nil
        repeat
            RequestCollisionAtCoord(front.x, front.y, front.z)
            found, ground = GetGroundZFor_3dCoord(front.x, front.y, front.z + 150.0, false)
            if not found then Wait(50) end
        until found or GetGameTimer() >= deadline
        if not found then notify('Ground could not be found ahead. Move outdoors and try /ghast again.'); return end
        TriggerServerEvent('fivem-ghast:spawn', { x = front.x, y = front.y, z = ground + Config.SpawnHeight + Config.BodySize / 2 },
                           GetEntityHeading(ped))
    end)
end, false)
RegisterCommand('ghastclear', function() TriggerServerEvent('fivem-ghast:clear') end, false)

CreateThread(function()
    if not IsModelInCdimage(model) or not IsModelValid(model) then notify('Configured anchor model is unavailable.'); return end
    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(25) end
    if not HasModelLoaded(model) then notify('Anchor model load timed out.'); return end
    GhastRenderer.init()
    initialized = true
    TriggerServerEvent('fivem-ghast:requestSnapshot')
    local previous = GetGameTimer()
    while true do
        local now, mine = GetGameTimer(), GetPlayerServerId(PlayerId())
        local dt = math.min((now - previous) / 1000.0, 0.1)
        previous = now
        local camera = M.coords(GetGameplayCamCoord())
        for _, collection in ipairs({ W.ghasts, W.projectiles }) do
            for _, entry in pairs(collection) do
                local projectile = collection == W.projectiles
                if entry.owner == mine then
                    if projectile then GhastFireball.update(entry, dt, now) else GhastEntity.update(entry, dt, now) end
                elseif entry.to then
                    local t = math.min(1.0, (now - entry.received) / Config.SyncIntervalMs)
                    entry.pos = M.lerp(entry.from, entry.to, t)
                    entry.heading = (entry.fromHeading + M.angleDelta(entry.fromHeading, entry.toHeading) * t) % 360
                end
                if entry.entity and DoesEntityExist(entry.entity) then
                    SetEntityCoordsNoOffset(entry.entity, entry.pos.x, entry.pos.y, entry.pos.z, false, false, false)
                    SetEntityHeading(entry.entity, entry.heading)
                end
                if M.distance(camera, entry.pos) <= Config.RenderDistance and not entry.ending then
                    if projectile then GhastRenderer.fireball(entry) else GhastRenderer.ghast(entry, now) end
                    if Config.Debug then
                        DrawMarker(28, entry.pos.x, entry.pos.y, entry.pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                   0.3, 0.3, 0.3, 255, 180, 80, 160, false, false, 2, false, nil, nil, false)
                    end
                end
            end
        end
        GhastEntity.playerCombat(now)
        Wait(0)
    end
end)
CreateThread(function()
    while true do
        Wait(Config.SyncIntervalMs)
        if initialized then
            local ghasts, projectiles, mine = {}, {}, GetPlayerServerId(PlayerId())
            for _, g in pairs(W.ghasts) do
                if g.owner == mine then ghasts[#ghasts + 1] = { id = g.id, pos = g.pos, heading = g.heading } end
            end
            for _, p in pairs(W.projectiles) do
                if p.owner == mine and not p.ending then projectiles[#projectiles + 1] = { id = p.id, pos = p.pos } end
            end
            if #ghasts > 0 or #projectiles > 0 then TriggerServerEvent('fivem-ghast:update', ghasts, projectiles) end
        end
        GhastAudio.listener()
        GhastFireball.cleanup(GetGameTimer(), false)
    end
end)
CreateThread(function()
    while true do Wait(Config.SnapshotIntervalMs); if initialized then TriggerServerEvent('fivem-ghast:requestSnapshot') end end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(W.ghasts) do deleteEntry(W.ghasts, id) end
    for id in pairs(W.projectiles) do deleteEntry(W.projectiles, id) end
    GhastFireball.cleanup(0, true)
    SendNUIMessage({ action = 'stop' })
    SetModelAsNoLongerNeeded(model)
end)

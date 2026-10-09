GhastFireball = {}
local F, M = GhastFireball, GhastMath
local fires = {}
local function finish(p, point, ghastId)
    if p.ending then return end
    p.ending = true
    TriggerServerEvent('fivem-ghast:impact', p.id, point, ghastId)
end
function F.update(p, dt, now)
    if p.ending then return end
    if now - p.born > Config.Fireball.LifetimeMs then
        p.ending = true
        TriggerServerEvent('fivem-ghast:expire', p.id)
        return
    end
    if p.probe then
        local status, hit, point = GetShapeTestResult(p.probe)
        if status == 1 then return end -- never advance through unresolved world collision
        if status ~= 2 then
            p.ending = true
            TriggerServerEvent('fivem-ghast:expire', p.id)
            return
        end
        local worldPoint = M.hit(hit) and M.coords(point) or p.stepEnd
        local ghastId, bodyT
        if p.reflected then
            for id, g in pairs(GhastWorld.ghasts) do
                local t = M.segmentBody(p.pos, worldPoint, g.pos, g.heading, Config.Fireball.Radius)
                if t and (not bodyT or t < bodyT) then bodyT, ghastId = t, id end
            end
        end
        if ghastId then finish(p, M.lerp(p.pos, worldPoint, bodyT), ghastId)
        elseif M.hit(hit) then finish(p, worldPoint)
        else p.pos = p.stepEnd end
        p.probe = nil
        if p.ending then return end
    end
    p.stepEnd = M.add(p.pos, M.mul(p.direction, Config.Fireball.Speed * math.min(dt, 0.05)))
    p.probe = StartShapeTestSweptSphere(p.pos.x, p.pos.y, p.pos.z, p.stepEnd.x, p.stepEnd.y, p.stepEnd.z,
                                      Config.Fireball.Radius, 511, p.entity, 7)
end

-- Only the logical projectile owner changes its trajectory; server forwards a nearby player's swing.
function F.reflect(id, playerId)
    local p = GhastWorld.projectiles[id]
    if not p or p.owner ~= GetPlayerServerId(PlayerId()) or p.ending then return end
    local player = GetPlayerFromServerId(playerId)
    if player == -1 then return end
    local ped = GetPlayerPed(player)
    local hand = M.coords(GetPedBoneCoords(ped, 57005, 0.0, 0.0, 0.0))
    local delta = M.sub(p.pos, hand)
    if M.length(delta) > Config.Fireball.ReflectDistance + 0.5 then return end
    if M.dot(M.normalize(delta), M.coords(GetEntityForwardVector(ped))) < -0.2 then return end
    local valid, hit, _, entity = GhastTargeting.ray(hand, p.pos, ped)
    if not valid or (hit and entity ~= p.entity) then return end
    local direction
    if playerId == GetPlayerServerId(PlayerId()) then direction = M.cameraDirection(GetGameplayCamRot(2))
    else direction = M.coords(GetEntityForwardVector(ped)) end
    TriggerServerEvent('fivem-ghast:reflected', id, playerId, M.normalize(direction))
end
function F.applyReflection(id, direction)
    local p = GhastWorld.projectiles[id]
    if not p then return end
    p.reflected, p.direction, p.probe = true, direction, nil
end

local function damageEntity(entity, position)
    local distance = M.distance(position, M.coords(GetEntityCoords(entity)))
    if distance > Config.Fireball.BlastRadius then return end
    local valid, hit, _, blocking = GhastTargeting.ray(M.add(position, { x = 0, y = 0, z = 0.15 }),
                                                     M.coords(GetEntityCoords(entity)), 0)
    if not valid or (hit and blocking ~= entity) then return end
    local damage = math.floor(Config.Fireball.Damage * (1.0 - distance / Config.Fireball.BlastRadius))
    if damage <= 0 then return end
    if IsEntityAPed(entity) then ApplyDamageToPed(entity, damage, false)
    elseif IsEntityAVehicle(entity) then
        SetVehicleEngineHealth(entity, GetVehicleEngineHealth(entity) - damage * 8)
        SetVehicleBodyHealth(entity, GetVehicleBodyHealth(entity) - damage * 4)
    elseif IsEntityAnObject(entity) then
        SetEntityHealth(entity, math.max(0, GetEntityHealth(entity) - damage))
    end
end

function F.impact(position, owner)
    -- Exactly one client emits the GTA network explosion. Native damage disabled: bounded splash below.
    if owner == GetPlayerServerId(PlayerId()) then
        -- Explicit native invocation preserves the ninth noDamage parameter on older Lua wrappers.
        Citizen.InvokeNative(0xE3AD2BDBAEE269AC, position.x, position.y, position.z,
                             Config.Fireball.ExplosionType, 0.0, true, false, 0.3, true)
    end
    local me = PlayerPedId()
    if not IsEntityDead(me) then damageEntity(me, position) end
    for _, pool in ipairs({ 'CPed', 'CVehicle', 'CObject' }) do
        for _, entity in ipairs(GetGamePool(pool)) do
            if entity ~= me and not (IsEntityAPed(entity) and IsPedAPlayer(entity)) and not IsEntityDead(entity)
               and (not NetworkGetEntityIsNetworked(entity) or NetworkHasControlOfEntity(entity)) then
                damageEntity(entity, position)
            end
        end
    end
    local found, z = GetGroundZFor_3dCoord(position.x, position.y, position.z + 1.0, false)
    if found and math.abs(position.z - z) < 2.0 then
        local fire = StartScriptFire(position.x, position.y, z, 2, false)
        if fire ~= -1 then fires[#fires + 1] = { handle = fire, expires = GetGameTimer() + Config.Fireball.FireLifetimeMs } end
    end
end
function F.cleanup(now, all)
    for i = #fires, 1, -1 do
        if all or now >= fires[i].expires then RemoveScriptFire(fires[i].handle); table.remove(fires, i) end
    end
end

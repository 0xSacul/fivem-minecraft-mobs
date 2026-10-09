GhastEntity = {}
local G, M = GhastEntity, GhastMath
function G.update(g, dt, now)
    GhastMovement.update(g, dt, now)
    if now >= (g.nextScan or 0) then
        g.target = GhastTargeting.find(g)
        g.nextScan = now + Config.TargetScanMs
        g.targetVisible = g.target ~= nil
    end
    if not g.target or not DoesEntityExist(g.target) or IsEntityDead(g.target) then g.targetVisible = false end
    if not g.targetVisible then
        if g.attackStart then TriggerServerEvent('fivem-ghast:cancelCharge', g.id) end
        g.attackStart, g.charging = nil, false
    elseif now >= (g.nextAttack or 0) then
        if not g.attackStart then g.attackStart = now end
        local elapsed = now - g.attackStart
        if elapsed >= Config.WarningDelayMs and not g.charging then
            -- Recheck LOS at both warning and launch, even between regular target scans.
            if not GhastTargeting.visible(g, g.target) then g.targetVisible = false; return end
            g.charging = true
            TriggerServerEvent('fivem-ghast:warn', g.id)
        end
        if elapsed >= Config.WarningDelayMs + Config.ChargeMs then
            if GhastTargeting.visible(g, g.target) then
                local origin = M.add(g.pos, M.mul(M.forward(g.heading), Config.BodySize / 2 + 0.65))
                origin.z = origin.z - Config.BodySize * 0.15
                TriggerServerEvent('fivem-ghast:shoot', g.id, origin, M.normalize(M.sub(GhastTargeting.aim(g.target), origin)))
            else TriggerServerEvent('fivem-ghast:cancelCharge', g.id) end
            g.charging, g.attackStart, g.nextAttack = false, nil, now + Config.AttackCooldownMs
        end
    end
    if now >= (g.nextAmbient or 0) then
        TriggerServerEvent('fivem-ghast:ambient', g.id)
        g.nextAmbient = now + math.random(Config.AmbientMinMs, Config.AmbientMaxMs)
    end
end

-- Procedural mesh cannot receive native weapon events; intersect actual aim with its oriented box.
function G.playerCombat(now)
    local ped = PlayerPedId()
    local shooting, melee = IsPedShooting(ped), IsPedPerformingMeleeAction(ped)
    if IsEntityDead(ped) or not (shooting or melee) then return end
    if now < (G.nextDamage or 0) then return end
    local start, ending
    if shooting then
        start = M.coords(GetGameplayCamCoord())
        ending = M.add(start, M.mul(M.cameraDirection(GetGameplayCamRot(2)), Config.RenderDistance))
    else
        start = M.coords(GetPedBoneCoords(ped, 57005, 0.0, 0.0, 0.0))
        ending = M.add(start, M.mul(M.coords(GetEntityForwardVector(ped)), 3.0))
    end
    local nearest, closest
    for _, g in pairs(GhastWorld.ghasts) do
        local t = M.segmentBody(start, ending, g.pos, g.heading, melee and 0.5 or 0.0)
        if t and (not closest or t < closest) then nearest, closest = g, t end
    end
    if nearest then
        local point = M.lerp(start, ending, closest)
        -- Use weapon muzzle origin for cover check (camera may peek over a wall).
        local muzzle = M.coords(GetPedBoneCoords(ped, 57005, 0.0, 0.0, 0.0))
        local valid, hit = GhastTargeting.ray(muzzle, point, ped)
        if valid and not hit then
            TriggerServerEvent('fivem-ghast:damage', nearest.id, melee and 'melee' or 'bullet')
            G.nextDamage = now + Config.DamageIntervalMs
        end
    end
    if melee and Config.Fireball.Reflection and now >= (G.nextReflection or 0) then
        local hand = M.coords(GetPedBoneCoords(ped, 57005, 0.0, 0.0, 0.0))
        local id, distance
        for _, p in pairs(GhastWorld.projectiles) do
            local d = M.distance(hand, p.pos)
            if d <= Config.Fireball.ReflectDistance and (not distance or d < distance) then id, distance = p.id, d end
        end
        if id then
            TriggerServerEvent('fivem-ghast:reflect', id)
            G.nextReflection = now + Config.Fireball.ReflectCooldownMs
        end
    end
end

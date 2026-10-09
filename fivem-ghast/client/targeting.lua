GhastTargeting = {}
local T, M = GhastTargeting, GhastMath
function T.aim(ped)
    local pos = M.coords(GetEntityCoords(ped))
    pos.z = pos.z + 0.6
    return pos
end
function T.ray(a, b, ignore)
    local probe = StartExpensiveSynchronousShapeTestLosProbe(a.x, a.y, a.z, b.x, b.y, b.z, 511, ignore or 0, 7)
    local status, hit, position, _, entity = GetShapeTestResult(probe)
    return status == 2, M.hit(hit), position and M.coords(position) or b, entity
end
function T.visible(g, ped)
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return false end
    local point = T.aim(ped)
    if M.distance(g.pos, point) > Config.TargetRange then return false end
    local valid, hit, _, entity = T.ray(g.pos, point, g.entity)
    return valid and (not hit or entity == ped or (IsPedInAnyVehicle(ped, false) and entity == GetVehiclePedIsIn(ped, false)))
end
function T.find(g)
    local candidates = {}
    for _, ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            local distance = M.distance(g.pos, M.coords(GetEntityCoords(ped)))
            if distance <= Config.TargetRange then candidates[#candidates + 1] = { ped = ped, distance = distance } end
        end
    end
    table.sort(candidates, function(a, b)
        local aScore = a.distance - (a.ped == g.target and 8 or 0)
        local bScore = b.distance - (b.ped == g.target and 8 or 0)
        return aScore < bScore
    end)
    for i = 1, math.min(#candidates, Config.MaxLosCandidates) do
        if T.visible(g, candidates[i].ped) then return candidates[i].ped end
    end
    return nil -- blocked candidates never start an attack
end

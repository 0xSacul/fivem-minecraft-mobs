CreeperTargeting = {}
local T, M = CreeperTargeting, CreeperMath
function T.eyes(c) return M.add(c.pos, { x = 0, y = 0, z = 22 * Config.Scale }) end
function T.aim(ped) return M.add(M.coords(GetEntityCoords(ped)), { x = 0, y = 0, z = 0.8 }) end
function T.ray(a, b, ignore, flags)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(a.x,a.y,a.z,b.x,b.y,b.z,flags or 511,ignore or 0,4)
    local status, hit, position, normal, entity = GetShapeTestResult(handle)
    if status ~= 2 then return false, false, b, nil, 0 end
    return true, M.hit(hit), M.coords(position), normal and M.coords(normal), entity
end
function T.visible(c, ped)
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return false end
    if M.distance(c.pos, M.coords(GetEntityCoords(ped))) > Config.TargetRange then return false end
    local valid, hit, _, _, entity = T.ray(T.eyes(c), T.aim(ped), c.entity)
    return valid and (not hit or entity == ped or (IsPedInAnyVehicle(ped,false) and entity == GetVehiclePedIsIn(ped,false)))
end
function T.find(c)
    -- Keep the originally primed target until fuse is zero, like SwellGoal.
    if (c.fuseRatio or 0) > 0 and c.fuseTarget then return c.fuseTarget end
    local candidates = {}
    for _, ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) and IsPedHuman(ped) and (Config.TargetNPCs or IsPedAPlayer(ped)) then
            local distance = M.distance(c.pos,M.coords(GetEntityCoords(ped)))
            if distance <= Config.TargetRange then
                candidates[#candidates+1] = {ped=ped,score=distance-(IsPedAPlayer(ped) and 4 or 0)-(ped==c.target and 2 or 0)}
            end
        end
    end
    table.sort(candidates,function(a,b) return a.score < b.score end)
    for i=1,math.min(#candidates,Config.MaxLosCandidates) do
        if T.visible(c,candidates[i].ped) then return candidates[i].ped end
    end
end

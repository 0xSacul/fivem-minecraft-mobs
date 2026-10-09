DragonTargeting = {}
local T,M=DragonTargeting,DragonMath
function T.aim(ped) return M.add(M.coords(GetEntityCoords(ped)),{x=0,y=0,z=.6}) end
function T.ray(a,b,ignore)
    local handle=StartExpensiveSynchronousShapeTestLosProbe(a.x,a.y,a.z,b.x,b.y,b.z,511,ignore or 0,7)
    local status,hit,point,_,entity=GetShapeTestResult(handle)
    return status==2,M.hit(hit),point and M.coords(point) or b,entity
end
function T.visible(g,ped,origin)
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return false end
    if M.distance(g.pos,T.aim(ped))>Config.TargetRange then return false end
    local valid,hit,_,entity=T.ray(origin or g.pos,T.aim(ped),g.entity)
    return valid and (not hit or entity==ped or (IsPedInAnyVehicle(ped,false) and entity==GetVehiclePedIsIn(ped,false)))
end
function T.find(g)
    local candidates={}
    for _,ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) and (IsPedAPlayer(ped) or Config.TargetNpcPeds)
           and M.distance(M.coords(GetEntityCoords(ped)),g.origin)<=Config.Flight.ArenaRadius then
            local distance=M.distance(g.pos,T.aim(ped))
            if distance<=Config.TargetRange then candidates[#candidates+1]={ped=ped,score=distance-(ped==g.target and 12 or 0)-(Config.PreferPlayers and IsPedAPlayer(ped) and 30 or 0)} end
        end
    end
    table.sort(candidates,function(a,b) return a.score<b.score end)
    for i=1,math.min(#candidates,Config.MaxLosCandidates) do if T.visible(g,candidates[i].ped) then return candidates[i].ped end end
end

DragonVehicles = {}
local V,M=DragonVehicles,DragonMath
local contacts,queue,completed={},{},{}
function V.box(entity)
    local minimum,maximum=GetModelDimensions(GetEntityModel(entity))
    local forward,right,up,position=GetEntityMatrix(entity)
    local centerLocal={x=(minimum.x+maximum.x)/2,y=(minimum.y+maximum.y)/2,z=(minimum.z+maximum.z)/2}
    local axes={M.coords(right),M.coords(forward),M.coords(up)}
    return {center=M.add(M.coords(position),M.add(M.mul(axes[1],centerLocal.x),M.add(M.mul(axes[2],centerLocal.y),M.mul(axes[3],centerLocal.z)))),
        axes=axes,half={(maximum.x-minimum.x)/2,(maximum.y-minimum.y)/2,(maximum.z-minimum.z)/2}}
end
function V.explode(entity)
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) or IsEntityDead(entity) then return false end
    local networked=NetworkGetEntityIsNetworked(entity)
    if networked and not NetworkHasControlOfEntity(entity) then return false end
    -- Restore damageability for contact to reliably destroy even mission/player vehicles.
    SetEntityInvincible(entity,false)
    SetEntityProofs(entity,false,false,false,false,false,false,false,false)
    SetVehicleCanBreak(entity,true)
    SetVehicleEngineHealth(entity,-4000.0)
    SetVehiclePetrolTankHealth(entity,-1000.0)
    if networked then NetworkExplodeVehicle(entity,true,false,false) else ExplodeVehicle(entity,true,false) end
    return true
end
function V.scan(g,now)
    if not Config.VehicleContact.Enabled or now<(g.nextVehicleScan or 0) then return end
    g.nextVehicleScan=now+Config.VehicleContact.ScanMs
    -- Include intermediate poses, so a fast pass/wing flap cannot jump through a car.
    local poses={g}
    if g.vehiclePrevious then
        local prev=g.vehiclePrevious
        local steps=math.min(8,math.max(2,math.ceil(M.distance(prev.pos,g.pos)/.6)))
        for i=1,steps-1 do
            local t=i/steps
            poses[#poses+1]={pos=M.lerp(prev.pos,g.pos,t),heading=prev.heading+M.angleDelta(prev.heading,g.heading)*t,
                pitch=prev.pitch+(g.pitch-prev.pitch)*t,bank=prev.bank+(g.bank-prev.bank)*t,
                turn=g.turn,headYaw=g.headYaw,headPitch=g.headPitch,flapPhase=prev.flapPhase+(g.flapPhase-prev.flapPhase)*t,poseTime=now}
        end
    end
    g.vehiclePrevious={pos=M.coords(g.pos),heading=g.heading,pitch=g.pitch or 0,bank=g.bank or 0,flapPhase=g.flapPhase or 0}
    local groups={}
    for _,pose in ipairs(poses) do groups[#groups+1]=DragonRenderer.boxes(pose,now) end
    for _,vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and not IsEntityDead(vehicle) and now>=(contacts[vehicle] or 0)
           and M.distance(g.pos,M.coords(GetEntityCoords(vehicle)))<=Config.VehicleContact.Range then
            local car,hit=V.box(vehicle),false
            for _,boxes in ipairs(groups) do
                for _,box in ipairs(boxes) do if M.boxOverlap(box,car,.04) then hit=true;break end end
                if hit then break end
            end
            if hit then
                contacts[vehicle]=now+Config.VehicleContact.CooldownMs
                if NetworkGetEntityIsNetworked(vehicle) then
                    TriggerServerEvent('fivem-enderdragon:vehicleContact',g.id,NetworkGetNetworkIdFromEntity(vehicle))
                else V.explode(vehicle) end
            end
        end
    end
end
function V.enqueue(netId,model,token)
    if completed[token] then TriggerServerEvent('fivem-enderdragon:vehicleExploded',token);return end
    queue[token]={netId=netId,model=model,expires=GetGameTimer()+Config.VehicleContact.TimeoutMs}
end
function V.update(now)
    for token,entry in pairs(queue) do
        if now>entry.expires then queue[token]=nil
        elseif NetworkDoesEntityExistWithNetworkId(entry.netId) then
            local entity=NetworkGetEntityFromNetworkId(entry.netId)
            if DoesEntityExist(entity) and IsEntityAVehicle(entity) and GetEntityModel(entity)==entry.model then
                if IsEntityDead(entity) or V.explode(entity) then
                    completed[token]=now+Config.VehicleContact.CooldownMs;queue[token]=nil
                    TriggerServerEvent('fivem-enderdragon:vehicleExploded',token)
                else NetworkRequestControlOfEntity(entity) end
            end
        end
    end
    for entity,untilTime in pairs(contacts) do if now>=untilTime or not DoesEntityExist(entity) then contacts[entity]=nil end end
    for token,untilTime in pairs(completed) do if now>=untilTime then completed[token]=nil end end
end
function V.cleanup() contacts,queue,completed={},{},{} end

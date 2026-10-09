CreeperWorld={creepers={}}
local W,M=CreeperWorld,CreeperMath
local model,initialized=GetHashKey(Config.AnchorModel),false
local function notify(message)
    print('[fivem-creeper] '..message)
    BeginTextCommandThefeedPost('STRING');AddTextComponentSubstringPlayerName(message);EndTextCommandThefeedPostTicker(false,false)
end
local function remove(id)
    local c=W.creepers[id]
    CreeperAudio.stopFuse(id)
    if c and c.entity and DoesEntityExist(c.entity) then DeleteEntity(c.entity) end
    W.creepers[id]=nil
end
local function anchor(pos)
    local entity=CreateObjectNoOffset(model,pos.x,pos.y,pos.z,false,false,false)
    if entity==0 then return nil end
    SetEntityAsMissionEntity(entity,true,true);SetEntityVisible(entity,false,false);SetEntityAlpha(entity,0,false)
    SetEntityCollision(entity,false,false);FreezeEntityPosition(entity,true);SetEntityInvincible(entity,true)
    return entity
end
local function upsert(data)
    if not initialized then return end
    local c,time=W.creepers[data.id],GetGameTimer()
    if not c then
        c={id=data.id,entity=anchor(data.pos),pos=M.coords(data.pos),origin=data.origin,heading=data.heading,
           walkPhase=data.walkPhase or 0,walkAmount=data.walkAmount or 0,headYaw=data.headYaw or 0,headPitch=data.headPitch or 0}
        if not c.entity then notify('Creeper anchor creation failed.');return end
        W.creepers[data.id]=c
    end
    c.owner,c.hp,c.fuse,c.fuseDir,c.fuseReceived=data.owner,data.hp,data.fuse,data.fuseDir,time
    c.fuseRatio=M.fuseProgress(c,time)
    if c.fuseDir<0 then CreeperAudio.stopFuse(c.id) end
    if c.owner~=GetPlayerServerId(PlayerId()) then
        c.from,c.to,c.received=M.coords(c.pos),M.coords(data.pos),time
        c.fromHeading,c.toHeading=c.heading,data.heading
        c.fromPhase,c.toPhase=c.walkPhase,data.walkPhase
        c.fromAmount,c.toAmount=c.walkAmount,data.walkAmount
        c.fromYaw,c.toYaw=c.headYaw,data.headYaw;c.fromPitch,c.toPitch=c.headPitch,data.headPitch
    end
end
RegisterNetEvent('fivem-creeper:notice',notify)
RegisterNetEvent('fivem-creeper:creeper',upsert)
RegisterNetEvent('fivem-creeper:state',function(list) for _, data in ipairs(list) do upsert(data) end end)
RegisterNetEvent('fivem-creeper:snapshot',function(list)
    local seen={}
    for _, data in ipairs(list) do seen[data.id]=true;upsert(data) end
    for id in pairs(W.creepers) do if not seen[id] then remove(id) end end
end)
RegisterNetEvent('fivem-creeper:remove',remove)
RegisterNetEvent('fivem-creeper:sound',function(kind,position,id)
    CreeperAudio.play(kind,position,id)
    if kind=='hurt' and W.creepers[id] then W.creepers[id].hurtUntil=GetGameTimer()+250 end
end)
RegisterNetEvent('fivem-creeper:detonate',function(id,position,owner)
    remove(id)
    if owner==GetPlayerServerId(PlayerId()) or M.distance(M.coords(GetEntityCoords(PlayerPedId())),position)<=Config.RenderDistance then
        CreeperExplosion.detonate(position,owner)
    end
end)
RegisterCommand('creeper',function()
    if not initialized then notify('Creeper assets are still loading.');return end
    CreateThread(function()
        local ped=PlayerPedId();local front=M.coords(GetOffsetFromEntityInWorldCoords(ped,0.0,Config.SpawnForward,0.0))
        local deadline,position=GetGameTimer()+2000,nil
        repeat
            RequestCollisionAtCoord(front.x,front.y,front.z)
            local valid,hit,point,normal=CreeperTargeting.ray(M.add(front,{x=0,y=0,z=2}),M.add(front,{x=0,y=0,z=-10}),ped,1+16+64)
            if valid and hit and normal and normal.z>=Config.MinGroundNormalZ then position=point;position.z=position.z+0.01
            else Wait(50) end
        until position or GetGameTimer()>=deadline
        if not position then notify('No walkable ground ahead. Move outdoors and try /creeper again.');return end
        TriggerServerEvent('fivem-creeper:spawn',position,GetEntityHeading(ped))
    end)
end,false)
RegisterCommand('creeperclear',function() TriggerServerEvent('fivem-creeper:clear') end,false)
CreateThread(function()
    if not IsModelInCdimage(model) or not IsModelValid(model) then notify('Creeper anchor model is unavailable.');return end
    RequestModel(model);local deadline=GetGameTimer()+5000
    while not HasModelLoaded(model) and GetGameTimer()<deadline do Wait(25) end
    if not HasModelLoaded(model) then notify('Creeper anchor model load timed out.');return end
    CreeperRenderer.init();initialized=true;TriggerServerEvent('fivem-creeper:requestSnapshot')
    while true do
        local time,mine=GetGameTimer(),GetPlayerServerId(PlayerId());local camera=M.coords(GetGameplayCamCoord())
        for _, c in pairs(W.creepers) do
            if c.owner==mine then CreeperEntity.update(c,time)
            elseif c.to then
                local t=math.min(1,(time-c.received)/Config.SyncIntervalMs)
                c.pos=M.lerp(c.from,c.to,t);c.heading=(c.fromHeading+M.angleDelta(c.fromHeading,c.toHeading)*t)%360
                c.walkPhase=(c.fromPhase+((c.toPhase-c.fromPhase+5000)%10000-5000)*t)%10000
                c.walkAmount=c.fromAmount+(c.toAmount-c.fromAmount)*t
                c.headYaw=c.fromYaw+(c.toYaw-c.fromYaw)*t;c.headPitch=c.fromPitch+(c.toPitch-c.fromPitch)*t
            end
            if c.entity and DoesEntityExist(c.entity) then
                SetEntityCoordsNoOffset(c.entity,c.pos.x,c.pos.y,c.pos.z,false,false,false);SetEntityHeading(c.entity,c.heading)
            end
            if M.distance(camera,c.pos)<=Config.RenderDistance then CreeperRenderer.draw(c,time) end
        end
        CreeperEntity.playerCombat(time)
        Wait(0)
    end
end)
CreateThread(function()
    while true do
        Wait(Config.SyncIntervalMs)
        if initialized then
            local list,mine={},GetPlayerServerId(PlayerId())
            for _, c in pairs(W.creepers) do
                if c.owner==mine then list[#list+1]={id=c.id,pos=c.pos,heading=c.heading,walkPhase=c.walkPhase or 0,
                    walkAmount=c.walkAmount or 0,headYaw=c.headYaw or 0,headPitch=c.headPitch or 0,
                    wantSwell=c.wantSwell==true,targetPosition=c.targetPosition} end
            end
            if #list>0 then TriggerServerEvent('fivem-creeper:update',list) end
        end
        CreeperAudio.listener()
    end
end)
CreateThread(function()
    while true do Wait(Config.SnapshotIntervalMs);if initialized then TriggerServerEvent('fivem-creeper:requestSnapshot') end end
end)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    for id in pairs(W.creepers) do remove(id) end
    SendNUIMessage({action='stop'});SetModelAsNoLongerNeeded(model)
end)

DragonWorld = { dragons={}, projectiles={}, clouds={} }
local W,M=DragonWorld,DragonMath
local model,initialized=GetHashKey(Config.AnchorModel),false
local function notify(message)
    print('[fivem-enderdragon] '..message)
    BeginTextCommandThefeedPost('STRING');AddTextComponentSubstringPlayerName(message);EndTextCommandThefeedPostTicker(false,false)
end
local function deleteEntry(collection,id)
    local entry=collection[id]
    if entry and entry.entity and DoesEntityExist(entry.entity) then DeleteEntity(entry.entity) end
    if collection==W.dragons then DragonAudio.cancel(id) end
    collection[id]=nil
end
local function anchor(pos)
    local entity=CreateObjectNoOffset(model,pos.x,pos.y,pos.z,false,false,false)
    if entity==0 then return nil end
    SetEntityAsMissionEntity(entity,true,true);SetEntityVisible(entity,false,false);SetEntityAlpha(entity,0,false)
    SetEntityCollision(entity,false,false);FreezeEntityPosition(entity,true);SetEntityInvincible(entity,true)
    return entity
end
local function upsert(collection,data,projectile)
    if not initialized then return end
    local entry,now=collection[data.id],GetGameTimer()
    if not entry then
        entry={id=data.id,entity=anchor(data.pos),pos=M.coords(data.pos),heading=data.heading or 0,
            origin=data.origin,born=now,pitch=data.pitch or 0,bank=data.bank or 0,headYaw=data.headYaw or 0,
            headPitch=data.headPitch or 0,flapPhase=data.flapPhase or 0,poseTime=now,
            nextAmbient=now+math.random(Config.AmbientMinMs,Config.AmbientMaxMs)}
        if not entry.entity then notify('Object creation failed. Check entity lockdown settings.');return end
        collection[data.id]=entry
    end
    entry.owner,entry.hp=data.owner,data.hp
    if data.deathRemainingMs and not entry.deathAt then
        entry.deathAt=now-(Config.DeathDurationMs-data.deathRemainingMs)
        entry.charging=false;DragonAudio.cancel(entry.id)
    end
    if entry.owner~=GetPlayerServerId(PlayerId()) then
        entry.from,entry.to,entry.received=M.coords(entry.pos),M.coords(data.pos),now
        entry.fromHeading,entry.toHeading=entry.heading,data.heading or 0
        entry.fromPose,entry.toPose={},{}
        for _,key in ipairs({'pitch','bank','turn','headYaw','headPitch'}) do entry.fromPose[key]=entry[key] or 0;entry.toPose[key]=data[key] or 0 end
        entry.flapPhase,entry.poseTime=data.flapPhase or 0,now
        entry.charging,entry.flightMode=data.charging==true,data.flightMode
    end
    if projectile then entry.direction,entry.dragonId=data.direction,data.dragonId end
end
RegisterNetEvent('fivem-enderdragon:notice',notify)
RegisterNetEvent('fivem-enderdragon:dragon',function(data) upsert(W.dragons,data,false) end)
RegisterNetEvent('fivem-enderdragon:projectile',function(data) upsert(W.projectiles,data,true) end)
RegisterNetEvent('fivem-enderdragon:cloud',DragonFireball.cloud)
RegisterNetEvent('fivem-enderdragon:removeCloud',function(id) W.clouds[id]=nil end)
RegisterNetEvent('fivem-enderdragon:state',function(gs,ps)
    for _,g in ipairs(gs) do upsert(W.dragons,g,false) end
    for _,p in ipairs(ps) do upsert(W.projectiles,p,true) end
end)
RegisterNetEvent('fivem-enderdragon:snapshot',function(gs,ps,cs)
    local seenG,seenP,seenC={},{},{}
    for _,g in ipairs(gs) do seenG[g.id]=true;upsert(W.dragons,g,false) end
    for _,p in ipairs(ps) do seenP[p.id]=true;upsert(W.projectiles,p,true) end
    for _,c in ipairs(cs) do seenC[c.id]=true;DragonFireball.cloud(c) end
    for id in pairs(W.dragons) do if not seenG[id] then deleteEntry(W.dragons,id) end end
    for id in pairs(W.projectiles) do if not seenP[id] then deleteEntry(W.projectiles,id) end end
    for id in pairs(W.clouds) do if not seenC[id] then W.clouds[id]=nil end end
end)
RegisterNetEvent('fivem-enderdragon:removeDragon',function(id) deleteEntry(W.dragons,id) end)
RegisterNetEvent('fivem-enderdragon:removeProjectile',function(id) deleteEntry(W.projectiles,id) end)
RegisterNetEvent('fivem-enderdragon:cancelWarn',DragonAudio.cancel)
RegisterNetEvent('fivem-enderdragon:explodeVehicle',DragonVehicles.enqueue)
RegisterNetEvent('fivem-enderdragon:sound',function(event,pos,id)
    DragonAudio.play(event,pos,id)
    if event=='hurt' and W.dragons[id] then W.dragons[id].hurtUntil=GetGameTimer()+250 end
end)
RegisterNetEvent('fivem-enderdragon:impactFx',function(id,pos,owner)
    deleteEntry(W.projectiles,id)
    if M.distance(M.coords(GetEntityCoords(PlayerPedId())),pos)<=Config.RenderDistance then DragonFireball.impact(pos,owner) end
end)
RegisterCommand('enderdragon',function()
    if not initialized then notify('Dragon assets are still loading.');return end
    CreateThread(function()
        local ped=PlayerPedId()
        local front=M.coords(GetOffsetFromEntityInWorldCoords(ped,0,Config.SpawnForward,0))
        local found,ground,deadline=false,nil,GetGameTimer()+2000
        repeat
            RequestCollisionAtCoord(front.x,front.y,front.z)
            found,ground=GetGroundZFor_3dCoord(front.x,front.y,front.z+200,false)
            if not found then Wait(50) end
        until found or GetGameTimer()>=deadline
        if not found then notify('Ground could not be found. Try /enderdragon outdoors.');return end
        TriggerServerEvent('fivem-enderdragon:spawn',{x=front.x,y=front.y,z=ground+Config.SpawnHeight},GetEntityHeading(ped))
    end)
end,false)
RegisterCommand('enderdragonclear',function() TriggerServerEvent('fivem-enderdragon:clear') end,false)
CreateThread(function()
    if not IsModelInCdimage(model) or not IsModelValid(model) then notify('Anchor model unavailable.');return end
    RequestModel(model);local deadline=GetGameTimer()+5000
    while not HasModelLoaded(model) and GetGameTimer()<deadline do Wait(25) end
    if not HasModelLoaded(model) then notify('Anchor model load timed out.');return end
    DragonRenderer.init();initialized=true;TriggerServerEvent('fivem-enderdragon:requestSnapshot')
    local previous=GetGameTimer()
    while true do
        local now,mine=GetGameTimer(),GetPlayerServerId(PlayerId())
        local dt=math.min(.1,math.max(0,(now-previous)/1000));previous=now
        local camera=M.coords(GetGameplayCamCoord())
        for _,collection in ipairs({W.dragons,W.projectiles}) do
            for _,entry in pairs(collection) do
                local projectile=collection==W.projectiles
                if not entry.deathAt then
                    if entry.owner==mine then
                        if projectile then DragonFireball.update(entry,dt,now) else DragonEntity.update(entry,dt,now) end
                    elseif entry.to then
                        local t=math.min(1,(now-entry.received)/Config.SyncIntervalMs)
                        entry.pos=M.lerp(entry.from,entry.to,t)
                        entry.heading=(entry.fromHeading+M.angleDelta(entry.fromHeading,entry.toHeading)*t)%360
                        for key,v in pairs(entry.toPose) do entry[key]=entry.fromPose[key]+(v-entry.fromPose[key])*t end
                    end
                end
                if entry.entity and DoesEntityExist(entry.entity) then
                    SetEntityCoordsNoOffset(entry.entity,entry.pos.x,entry.pos.y,entry.pos.z,false,false,false)
                    SetEntityHeading(entry.entity,entry.heading)
                end
                if M.distance(camera,entry.pos)<=Config.RenderDistance and not entry.ending then
                    if projectile then DragonRenderer.fireball(entry) else
                        DragonRenderer.draw(entry,now)
                        if Config.Debug then DragonRenderer.debug(entry,now) end
                        if not entry.deathAt and now>=(entry.nextFlap or 0) then
                            DragonAudio.play('flap',entry.pos,entry.id);entry.nextFlap=now+math.floor(1000/Config.Flight.FlapsPerSecond)
                        end
                    end
                end
            end
        end
        DragonFireball.clouds(now,true);DragonEntity.playerCombat(now);Wait(0)
    end
end)
CreateThread(function()
    while true do
        Wait(Config.SyncIntervalMs)
        if initialized then
            local gs,ps,mine={},{},GetPlayerServerId(PlayerId())
            for _,g in pairs(W.dragons) do
                if g.owner==mine and not g.deathAt then
                    gs[#gs+1]={id=g.id,pos=g.pos,heading=g.heading,pitch=g.pitch,bank=g.bank,turn=g.turn,
                        headYaw=g.headYaw,headPitch=g.headPitch,flapPhase=g.flapPhase,flightMode=g.flightMode}
                end
            end
            for _,p in pairs(W.projectiles) do if p.owner==mine and not p.ending then ps[#ps+1]={id=p.id,pos=p.pos} end end
            if #gs>0 or #ps>0 then TriggerServerEvent('fivem-enderdragon:update',gs,ps) end
        end
        local now=GetGameTimer()
        DragonAudio.listener();DragonFireball.clouds(now,false);DragonVehicles.update(now)
    end
end)
CreateThread(function()
    while true do Wait(Config.SnapshotIntervalMs);if initialized then TriggerServerEvent('fivem-enderdragon:requestSnapshot') end end
end)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    for id in pairs(W.dragons) do deleteEntry(W.dragons,id) end
    for id in pairs(W.projectiles) do deleteEntry(W.projectiles,id) end
    W.clouds={};DragonVehicles.cleanup();SendNUIMessage({action='stop'});SetModelAsNoLongerNeeded(model)
end)

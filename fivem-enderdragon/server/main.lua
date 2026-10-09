-- OneSync-aware logical registry; a fixed spawning client simulates local replicas.
local M=DragonMath
local dragons,projectiles,clouds,rates,vehicles={},{},{},{},{}
local serial=0
local function now() return GetGameTimer() end
local function id(prefix) serial=serial+1;return prefix..serial end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function allowed(src,key,interval)
    rates[src]=rates[src] or {}
    if now()<(rates[src][key] or 0) then return false end
    rates[src][key]=now()+interval;return true
end
local function broadcast(bucket,event,...)
    for _,player in ipairs(GetPlayers()) do
        local src=tonumber(player)
        if GetPlayerRoutingBucket(src)==bucket then TriggerClientEvent('fivem-enderdragon:'..event,src,...) end
    end
end
local function own(src,entry) return entry and entry.owner==src and GetPlayerRoutingBucket(src)==entry.bucket end
local function near(src,pos,distance,bucket)
    local ped=GetPlayerPed(src)
    return ped~=0 and GetPlayerRoutingBucket(src)==bucket and M.distance(M.coords(GetEntityCoords(ped)),pos)<=distance
end
local function public(entry)
    return {id=entry.id,owner=entry.owner,pos=entry.pos,origin=entry.origin,heading=entry.heading,hp=entry.hp,
        charging=entry.charging,pitch=entry.pitch or 0,bank=entry.bank or 0,turn=entry.turn or 0,
        headYaw=entry.headYaw or 0,headPitch=entry.headPitch or 0,flapPhase=entry.flapPhase or 0,
        flightMode=entry.flightMode or 'circle',dragonId=entry.dragonId,direction=entry.direction,
        deathRemainingMs=entry.deathUntil and math.max(0,entry.deathUntil-now()) or nil}
end
local function cloudPublic(c) return {id=c.id,pos=c.pos,remainingMs=math.max(0,c.expires-now())} end
local function removeProjectile(p)
    projectiles[p.id]=nil;broadcast(p.bucket,'removeProjectile',p.id)
end
local function removeDragon(g)
    dragons[g.id]=nil;broadcast(g.bucket,'removeDragon',g.id)
    for _,p in pairs(projectiles) do if p.dragonId==g.id then removeProjectile(p) end end
end
RegisterNetEvent('fivem-enderdragon:spawn',function(position,heading)
    local src=source
    if not allowed(src,'spawn',Config.SpawnCooldownMs) or not M.valid(position) or not M.finite(heading) then return end
    if Config.RequireAce and not IsPlayerAceAllowed(src,'enderdragon.spawn') then
        TriggerClientEvent('fivem-enderdragon:notice',src,'Missing enderdragon.spawn permission.');return
    end
    local owned=0;for _,g in pairs(dragons) do if g.owner==src then owned=owned+1 end end
    if owned>=Config.MaxDragonsPerPlayer or count(dragons)>=Config.MaxDragons then
        TriggerClientEvent('fivem-enderdragon:notice',src,'Dragon limit reached. Use /enderdragonclear to remove yours.');return
    end
    local bucket=GetPlayerRoutingBucket(src)
    if not near(src,position,100,bucket) then return end
    local g={id=id('d'),owner=src,bucket=bucket,pos=M.coords(position),origin=M.coords(position),heading=heading%360,
        hp=Config.Health,charging=false,updated=now(),lastMove=now(),nextAttack=0,nextAmbient=0}
    dragons[g.id]=g;broadcast(bucket,'dragon',public(g))
end)
RegisterNetEvent('fivem-enderdragon:requestSnapshot',function()
    local src=source
    if not allowed(src,'snapshot',1000) then return end
    local bucket,gs,ps,cs=GetPlayerRoutingBucket(src),{},{},{}
    for _,g in pairs(dragons) do if g.bucket==bucket then gs[#gs+1]=public(g) end end
    for _,p in pairs(projectiles) do if p.bucket==bucket then ps[#ps+1]=public(p) end end
    for _,c in pairs(clouds) do if c.bucket==bucket and c.expires>now() then cs[#cs+1]=cloudPublic(c) end end
    TriggerClientEvent('fivem-enderdragon:snapshot',src,gs,ps,cs)
end)
RegisterNetEvent('fivem-enderdragon:update',function(gs,ps)
    local src=source
    if not allowed(src,'update',math.floor(Config.SyncIntervalMs*.75)) or type(gs)~='table' or type(ps)~='table'
       or #gs>Config.MaxDragons or #ps>Config.Fireball.MaxActive then return end
    local buckets={}
    for _,state in ipairs(gs) do
        if type(state)=='table' then
            local g=dragons[state.id]
            if own(src,g) and not g.deathUntil and M.valid(state.pos) and M.finite(state.heading)
               and M.distance(state.pos,g.origin)<=Config.Flight.ArenaRadius then
                local elapsed=math.min(1,(now()-g.lastMove)/1000)
                if M.distance(g.pos,state.pos)<=Config.Flight.SwoopSpeed*elapsed*1.8+1.0 then
                    g.pos,g.heading,g.lastMove,g.updated=M.coords(state.pos),state.heading%360,now(),now()
                    for _,key in ipairs({'pitch','bank','turn','headYaw','headPitch','flapPhase'}) do
                        if M.finite(state[key]) then g[key]=key=='flapPhase' and state[key] or M.clamp(state[key],-90,90) end
                    end
                    if state.flightMode=='circle' or state.flightMode=='swoop' or state.flightMode=='recover' then g.flightMode=state.flightMode end
                    buckets[g.bucket]=buckets[g.bucket] or {{},{}};table.insert(buckets[g.bucket][1],public(g))
                end
            end
        end
    end
    for _,state in ipairs(ps) do
        if type(state)=='table' then
            local p=projectiles[state.id]
            if own(src,p) and M.valid(state.pos) then
                local elapsed=math.min(1,(now()-p.updated)/1000)
                if M.distance(state.pos,p.pos)<=Config.Fireball.Speed*elapsed*1.8+1 then
                    p.pos,p.updated=M.coords(state.pos),now()
                    buckets[p.bucket]=buckets[p.bucket] or {{},{}};table.insert(buckets[p.bucket][2],public(p))
                end
            end
        end
    end
    for bucket,entries in pairs(buckets) do broadcast(bucket,'state',entries[1],entries[2]) end
end)
RegisterNetEvent('fivem-enderdragon:warn',function(gid)
    local g=dragons[gid]
    if not own(source,g) or g.deathUntil or g.charging or now()<g.nextAttack then return end
    g.charging,g.chargeAt=true,now();broadcast(g.bucket,'sound','warn',g.pos,g.id)
    broadcast(g.bucket,'dragon',public(g))
end)
RegisterNetEvent('fivem-enderdragon:cancelCharge',function(gid)
    local g=dragons[gid]
    if not own(source,g) or not g.charging then return end
    g.charging=false;broadcast(g.bucket,'cancelWarn',gid);broadcast(g.bucket,'dragon',public(g))
end)
RegisterNetEvent('fivem-enderdragon:shoot',function(gid,position,direction)
    local g=dragons[gid]
    if not own(source,g) or g.deathUntil or not g.charging or now()-g.chargeAt<Config.ChargeMs-100
       or now()<g.nextAttack or not M.valid(position) or not M.valid(direction)
       or M.distance(position,g.pos)>Config.ModelScale*120+2 or M.length(direction)<.01 then return end
    g.charging,g.nextAttack=false,now()+Config.AttackCooldownMs
    broadcast(g.bucket,'dragon',public(g))
    if count(projectiles)>=Config.Fireball.MaxActive then return end
    local p={id=id('p'),owner=g.owner,bucket=g.bucket,dragonId=gid,pos=M.coords(position),
        direction=M.normalize(direction),born=now(),updated=now()}
    projectiles[p.id]=p;broadcast(g.bucket,'sound','shoot',position,g.id);broadcast(g.bucket,'projectile',public(p))
end)
RegisterNetEvent('fivem-enderdragon:ambient',function(gid)
    local g=dragons[gid]
    if not own(source,g) or g.deathUntil or now()<g.nextAmbient then return end
    g.nextAmbient=now()+Config.AmbientMinMs;broadcast(g.bucket,'sound','ambient',g.pos,g.id)
end)
RegisterNetEvent('fivem-enderdragon:damage',function(gid,kind,head)
    local src,g=source,dragons[gid]
    if not g or g.deathUntil or (kind~='bullet' and kind~='melee') or not allowed(src,'damage',Config.DamageIntervalMs)
       or not near(src,g.pos,kind=='melee' and 30 or Config.RenderDistance,g.bucket) then return end
    local amount=(kind=='melee' and Config.MeleeDamage or Config.BulletDamage)*(head==true and Config.HeadDamageMultiplier or 1)
    g.hp=math.max(0,g.hp-amount)
    if g.hp==0 then
        g.charging,g.deathUntil=false,now()+Config.DeathDurationMs
        broadcast(g.bucket,'cancelWarn',gid);broadcast(g.bucket,'sound','death',g.pos,g.id)
        for _,p in pairs(projectiles) do if p.dragonId==gid then removeProjectile(p) end end
    else broadcast(g.bucket,'sound','hurt',g.pos,g.id) end
    broadcast(g.bucket,'dragon',public(g))
end)
RegisterNetEvent('fivem-enderdragon:impact',function(pid,position)
    local p=projectiles[pid]
    if not own(source,p) or not M.valid(position) or M.distance(position,p.pos)>6 then return end
    projectiles[pid]=nil -- consume before FX/cloud creation; duplicate impacts are harmless
    broadcast(p.bucket,'impactFx',pid,position,p.owner)
    if count(clouds)<Config.Breath.MaxActive then
        local c={id=id('c'),owner=p.owner,bucket=p.bucket,pos=M.coords(position),expires=now()+Config.Breath.DurationMs}
        clouds[c.id]=c;broadcast(c.bucket,'cloud',cloudPublic(c))
    end
end)
RegisterNetEvent('fivem-enderdragon:expire',function(pid)
    local p=projectiles[pid];if own(source,p) then removeProjectile(p) end
end)
local function dispatchVehicle(entry)
    if not DoesEntityExist(entry.entity) or GetEntityType(entry.entity)~=2 then return false end
    if GetEntityRoutingBucket(entry.entity)~=entry.bucket then return false end
    local controller=NetworkGetEntityOwner(entry.entity)
    if not controller or controller<1 then controller=entry.reporter end
    if GetPlayerRoutingBucket(controller)~=entry.bucket then return false end
    entry.sentTo,entry.nextRetry=controller,now()+Config.VehicleContact.RetryMs
    TriggerClientEvent('fivem-enderdragon:explodeVehicle',controller,entry.netId,entry.model,entry.token)
    return true
end
RegisterNetEvent('fivem-enderdragon:vehicleContact',function(gid,netId)
    local src,g=source,dragons[gid]
    if not Config.VehicleContact.Enabled or not own(src,g) or g.deathUntil or not M.finite(netId)
       or netId<1 or netId%1~=0 then return end
    rates[src]=rates[src] or {}
    local r=rates[src]
    if now()>=(r.vehicleWindow or 0) then r.vehicleWindow,r.vehicleReports=now()+1000,0 end
    r.vehicleReports=r.vehicleReports+1
    if r.vehicleReports>Config.VehicleContact.MaxReportsPerSecond then return end
    local entity=NetworkGetEntityFromNetworkId(netId)
    if entity==0 or not DoesEntityExist(entity) or GetEntityType(entity)~=2 or GetEntityRoutingBucket(entity)~=g.bucket
       or M.distance(M.coords(GetEntityCoords(entity)),g.pos)>Config.VehicleContact.Range then return end
    local previous=vehicles[netId]
    if previous and previous.entity==entity and now()<previous.cooldownUntil then return end
    local entry={entity=entity,netId=netId,model=GetEntityModel(entity),bucket=g.bucket,reporter=src,
        token=id('v'),expires=now()+Config.VehicleContact.TimeoutMs,cooldownUntil=now()+Config.VehicleContact.CooldownMs}
    vehicles[netId]=entry;dispatchVehicle(entry)
end)
RegisterNetEvent('fivem-enderdragon:vehicleExploded',function(token)
    for _,entry in pairs(vehicles) do
        if entry.token==token and entry.sentTo==source then entry.done=true;break end
    end
end)
RegisterNetEvent('fivem-enderdragon:clear',function()
    local src=source
    if not allowed(src,'clear',500) then return end
    for _,g in pairs(dragons) do if g.owner==src then removeDragon(g) end end
    for cid,c in pairs(clouds) do if c.owner==src then clouds[cid]=nil;broadcast(c.bucket,'removeCloud',cid) end end
end)
AddEventHandler('playerDropped',function()
    local src=source
    for _,g in pairs(dragons) do if g.owner==src then removeDragon(g) end end
    rates[src]=nil
end)
CreateThread(function()
    while true do
        Wait(250)
        for _,g in pairs(dragons) do
            if not GetPlayerName(g.owner) or GetPlayerRoutingBucket(g.owner)~=g.bucket
               or (g.deathUntil and now()>=g.deathUntil) or (not g.deathUntil and now()-g.updated>Config.OwnerTimeoutMs) then removeDragon(g) end
        end
        for _,p in pairs(projectiles) do if now()-p.born>Config.Fireball.LifetimeMs+1000 then removeProjectile(p) end end
        for cid,c in pairs(clouds) do if now()>=c.expires then clouds[cid]=nil;broadcast(c.bucket,'removeCloud',cid) end end
        for netId,entry in pairs(vehicles) do
            if now()>=entry.cooldownUntil or not DoesEntityExist(entry.entity) then vehicles[netId]=nil
            elseif not entry.done and now()<entry.expires and now()>=(entry.nextRetry or 0) then dispatchVehicle(entry) end
        end
    end
end)

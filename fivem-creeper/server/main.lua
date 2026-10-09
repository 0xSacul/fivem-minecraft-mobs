-- Server owns IDs, health, and fuse time. One fixed client owns movement/LOS per Creeper.
local M = CreeperMath
local creepers,rates,serial = {},{},0
local function now() return GetGameTimer() end
local function count() local total=0;for _ in pairs(creepers) do total=total+1 end;return total end
local function allowed(src,key,interval)
    rates[src]=rates[src] or {}
    if now()<(rates[src][key] or 0) then return false end
    rates[src][key]=now()+interval;return true
end
local function broadcast(bucket,event,...)
    for _, player in ipairs(GetPlayers()) do
        local src=tonumber(player)
        if GetPlayerRoutingBucket(src)==bucket then TriggerClientEvent('fivem-creeper:'..event,src,...) end
    end
end
local function own(src,c) return c and c.owner==src and GetPlayerRoutingBucket(src)==c.bucket end
local function near(src,pos,range,bucket)
    local ped=GetPlayerPed(src)
    return ped~=0 and GetPlayerRoutingBucket(src)==bucket and M.distance(M.coords(GetEntityCoords(ped)),pos)<=range
end
local function public(c)
    return {id=c.id,owner=c.owner,pos=c.pos,origin=c.origin,heading=c.heading,hp=c.hp,
            fuse=c.fuse,fuseDir=c.fuseDir,walkPhase=c.walkPhase,walkAmount=c.walkAmount,
            headYaw=c.headYaw,headPitch=c.headPitch}
end
local function remove(c)
    creepers[c.id]=nil
    broadcast(c.bucket,'remove',c.id)
end
RegisterNetEvent('fivem-creeper:spawn',function(position,heading)
    local src=source
    if not allowed(src,'spawn',Config.SpawnCooldownMs) or not M.valid(position) or not M.finite(heading) then return end
    if Config.RequireAce and not IsPlayerAceAllowed(src,'creeper.spawn') then
        TriggerClientEvent('fivem-creeper:notice',src,'Missing creeper.spawn permission.');return
    end
    local owned=0
    for _, c in pairs(creepers) do if c.owner==src then owned=owned+1 end end
    if owned>=Config.MaxPerPlayer or count()>=Config.MaxCreepers then
        TriggerClientEvent('fivem-creeper:notice',src,'Creeper limit reached. Use /creeperclear to remove yours.');return
    end
    local bucket=GetPlayerRoutingBucket(src)
    if not near(src,position,Config.SpawnForward+8,bucket) then return end
    serial=serial+1
    local c={id='c'..serial,owner=src,bucket=bucket,pos=position,origin=M.coords(position),heading=heading%360,
             hp=Config.Health,fuse=0,fuseDir=-1,walkPhase=0,walkAmount=0,headYaw=0,headPitch=0,
             updated=now(),lastMove=now(),intentAt=0,wantSwell=false}
    creepers[c.id]=c;broadcast(bucket,'creeper',public(c))
end)
RegisterNetEvent('fivem-creeper:requestSnapshot',function()
    local src=source
    if not allowed(src,'snapshot',1000) then return end
    local bucket,list=GetPlayerRoutingBucket(src),{}
    for _, c in pairs(creepers) do if c.bucket==bucket then list[#list+1]=public(c) end end
    TriggerClientEvent('fivem-creeper:snapshot',src,list)
end)
RegisterNetEvent('fivem-creeper:update',function(list)
    local src=source
    if type(list)~='table' or #list>Config.MaxPerPlayer or not allowed(src,'update',Config.SyncIntervalMs*0.75) then return end
    for _, state in ipairs(list) do
        if type(state)=='table' then
            local c=creepers[state.id]
            if own(src,c) and M.valid(state.pos) and M.finite(state.heading) and M.finite(state.walkPhase)
               and M.finite(state.walkAmount) and M.finite(state.headYaw) and M.finite(state.headPitch)
               and M.distance(state.pos,c.origin)<=Config.RoamLimit then
                local elapsed=math.min(1,(now()-c.lastMove)/1000)
                if M.distance(state.pos,c.pos)<=Config.ChaseSpeed*elapsed*2+Config.MaxStepHeight+0.25 then
                    c.pos,c.heading,c.lastMove,c.updated=state.pos,state.heading%360,now(),now()
                    c.walkPhase=state.walkPhase%10000;c.walkAmount=M.clamp(state.walkAmount,0,0.8)
                    c.headYaw=M.clamp(state.headYaw,-45,45);c.headPitch=M.clamp(state.headPitch,-30,30)
                    local limit=c.fuse>0 and Config.CancelDistance or Config.PrimeDistance
                    c.wantSwell=state.wantSwell==true and M.valid(state.targetPosition)
                                and M.distance(c.pos,state.targetPosition)<=limit+0.35 or false
                    c.intentAt=now()
                end
            end
        end
    end
end)
RegisterNetEvent('fivem-creeper:damage',function(cid,kind)
    local src,c=source,creepers[cid]
    if not c or (kind~='bullet' and kind~='melee') or not allowed(src,'damage',Config.DamageIntervalMs) then return end
    if not near(src,c.pos,kind=='melee' and 4 or Config.RenderDistance,c.bucket) then return end
    c.hp=math.max(0,c.hp-(kind=='melee' and Config.MeleeDamage or Config.BulletDamage))
    broadcast(c.bucket,'sound',c.hp==0 and 'death' or 'hurt',c.pos,c.id)
    if c.hp==0 then remove(c) else broadcast(c.bucket,'creeper',public(c)) end
end)
RegisterNetEvent('fivem-creeper:clear',function()
    local src=source
    if not allowed(src,'clear',500) then return end
    for _, c in pairs(creepers) do if c.owner==src then remove(c) end end
end)
AddEventHandler('playerDropped',function()
    local src=source
    for _, c in pairs(creepers) do if c.owner==src then remove(c) end end
    rates[src]=nil
end)
CreateThread(function()
    local previous,nextSync=now(),now()
    while true do
        Wait(Config.StepMs)
        local time=now();local dt=M.clamp(time-previous,0,200);previous=time
        for _, c in pairs(creepers) do
            if not GetPlayerName(c.owner) or GetPlayerRoutingBucket(c.owner)~=c.bucket or time-c.updated>Config.OwnerTimeoutMs then
                remove(c)
            else
                local increase=c.wantSwell and time-c.intentAt<=Config.IntentTimeoutMs
                c.fuseDir=increase and 1 or -1
                if increase and c.fuse==0 then broadcast(c.bucket,'sound','primed',c.pos,c.id) end
                c.fuse=M.clamp(c.fuse+c.fuseDir*dt,0,Config.FuseMs)
                if c.fuse>=Config.FuseMs then
                    creepers[c.id]=nil -- consume once before FX; no client detonation event exists
                    local position=M.add(c.pos,{x=0,y=0,z=0.8})
                    broadcast(c.bucket,'sound','explode',position,c.id)
                    broadcast(c.bucket,'detonate',c.id,position,c.owner)
                end
            end
        end
        if time>=nextSync then
            nextSync=time+Config.SyncIntervalMs
            local buckets={}
            for _, c in pairs(creepers) do
                buckets[c.bucket]=buckets[c.bucket] or {};table.insert(buckets[c.bucket],public(c))
            end
            for bucket,list in pairs(buckets) do broadcast(bucket,'state',list) end
        end
    end
end)

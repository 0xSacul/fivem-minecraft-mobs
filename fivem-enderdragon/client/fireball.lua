DragonFireball = {}
local F,M=DragonFireball,DragonMath
function F.update(p,dt,now)
    if p.ending then return end
    if now-p.born>Config.Fireball.LifetimeMs then
        p.ending=true;TriggerServerEvent('fivem-enderdragon:expire',p.id);return
    end
    if p.probe then
        local status,hit,point=GetShapeTestResult(p.probe)
        if status==1 then return end
        p.probe=nil
        if status~=2 then p.ending=true;TriggerServerEvent('fivem-enderdragon:expire',p.id);return end
        if M.hit(hit) then
            p.ending=true;TriggerServerEvent('fivem-enderdragon:impact',p.id,M.coords(point));return
        end
        p.pos=p.stepEnd
    end
    p.stepEnd=M.add(p.pos,M.mul(p.direction,Config.Fireball.Speed*math.min(dt,.05)))
    p.probe=StartShapeTestSweptSphere(p.pos.x,p.pos.y,p.pos.z,p.stepEnd.x,p.stepEnd.y,p.stepEnd.z,
        Config.Fireball.Radius,511,p.entity,7)
end
function F.cloud(data)
    -- Skip native particles whose availability varies by build; original fireball sprites form the cloud.
    local now=GetGameTimer()
    local old=DragonWorld.clouds[data.id]
    DragonWorld.clouds[data.id]={id=data.id,pos=data.pos,expires=now+data.remainingMs,born=old and old.born or now,
        nextDamage=old and old.nextDamage or now}
end
local function damage(entity,cloud)
    local pos=M.coords(GetEntityCoords(entity));local d=M.sub(pos,cloud.pos)
    if d.x*d.x+d.y*d.y>Config.Breath.Radius^2 or math.abs(d.z)>Config.Breath.Height then return end
    local valid,hit,_,blocking=DragonTargeting.ray(M.add(cloud.pos,{x=0,y=0,z=.4}),pos,0)
    if not valid or (hit and blocking~=entity) then return end
    if IsEntityAPed(entity) then ApplyDamageToPed(entity,Config.Breath.Damage,false)
    elseif IsEntityAVehicle(entity) then SetVehicleEngineHealth(entity,GetVehicleEngineHealth(entity)-Config.Breath.Damage*4) end
end
function F.clouds(now,render)
    for id,cloud in pairs(DragonWorld.clouds) do
        if now>=cloud.expires then DragonWorld.clouds[id]=nil
        else
            if render and M.distance(M.coords(GetGameplayCamCoord()),cloud.pos)<Config.RenderDistance then
                local fade=math.min(1,(cloud.expires-now)/1500)
                for i=1,16 do
                    local phase=(now-cloud.born)*.0005+i*2.39996
                    local radius=math.sqrt(i/16)*Config.Breath.Radius*.9
                    local pos=M.add(cloud.pos,{x=math.cos(phase)*radius,y=math.sin(phase)*radius,z=.3+(i%4)*.4+math.sin(phase*2)*.15})
                    DragonRenderer.sprite(pos,1.5,'dragon_fireball',math.floor(110*fade))
                end
            end
            if not render and now>=(cloud.nextDamage or 0) then
                cloud.nextDamage=now+Config.Breath.TickMs
                local me=PlayerPedId()
                if not IsEntityDead(me) then damage(me,cloud) end
                for _,pool in ipairs({'CPed','CVehicle'}) do
                    for _,entity in ipairs(GetGamePool(pool)) do
                        if entity~=me and not IsEntityDead(entity) and not (IsEntityAPed(entity) and IsPedAPlayer(entity))
                           and (not NetworkGetEntityIsNetworked(entity) or NetworkHasControlOfEntity(entity)) then damage(entity,cloud) end
                    end
                end
            end
        end
    end
end
function F.impact(position,owner)
    if owner==GetPlayerServerId(PlayerId()) then
        -- Visible impact with native damage disabled; persistent breath supplies bounded damage.
        Citizen.InvokeNative(0xE3AD2BDBAEE269AC,position.x,position.y,position.z,4,0.0,false,false,.15,true)
    end
end

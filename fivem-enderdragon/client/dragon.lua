DragonEntity = {}
local D,M=DragonEntity,DragonMath
function D.update(g,dt,now)
    g.flapPhase=(g.flapPhase or 0)+dt*Config.Flight.FlapsPerSecond*math.pi*2;g.poseTime=now
    if now>=(g.nextScan or 0) then g.target=DragonTargeting.find(g);g.nextScan=now+Config.TargetScanMs end
    local visible=g.target and DoesEntityExist(g.target) and not IsEntityDead(g.target)
    if visible then
        local point=DragonTargeting.aim(g.target)
        g.headYaw=M.clamp(M.angleDelta(g.heading,M.heading(g.pos,point)),-40,40)
        local diff=M.sub(point,g.pos)
        g.headPitch=M.clamp((g.pitch or 0)-math.deg(math.atan(diff.z,math.sqrt(diff.x^2+diff.y^2))),-35,35)
    else g.target=nil;g.headYaw,g.headPitch=0,0 end
    DragonMovement.update(g,dt,now)
    DragonVehicles.scan(g,now)
    -- Attack only while the target is broadly in front; launch from the posed mouth.
    local canAttack=visible and math.abs(M.angleDelta(g.heading,M.heading(g.pos,DragonTargeting.aim(g.target))))<65
    if not canAttack then
        if g.charging then TriggerServerEvent('fivem-enderdragon:cancelCharge',g.id);DragonAudio.cancel(g.id) end
        g.charging,g.attackStart=false,nil
    elseif now>=(g.nextAttack or 0) then
        local mouth=DragonRenderer.mouth(g,now)
        if not g.attackStart and DragonTargeting.visible(g,g.target,mouth) then
            g.attackStart=now;g.charging=true;TriggerServerEvent('fivem-enderdragon:warn',g.id)
        elseif g.attackStart and now-g.attackStart>=Config.ChargeMs then
            if DragonTargeting.visible(g,g.target,mouth) then
                TriggerServerEvent('fivem-enderdragon:shoot',g.id,mouth,M.normalize(M.sub(DragonTargeting.aim(g.target),mouth)))
            else TriggerServerEvent('fivem-enderdragon:cancelCharge',g.id) end
            g.charging,g.attackStart,g.nextAttack=false,nil,now+Config.AttackCooldownMs
        end
    end
    if now>=(g.nextAmbient or 0) then
        TriggerServerEvent('fivem-enderdragon:ambient',g.id)
        g.nextAmbient=now+math.random(Config.AmbientMinMs,Config.AmbientMaxMs)
    end
end
function D.playerCombat(now)
    local ped=PlayerPedId()
    local shooting,melee=IsPedShooting(ped),IsPedPerformingMeleeAction(ped)
    if IsEntityDead(ped) or not (shooting or melee) or now<(D.nextDamage or 0) then return end
    local start=shooting and M.coords(GetGameplayCamCoord()) or M.coords(GetPedBoneCoords(ped,57005,0,0,0))
    local direction=shooting and M.cameraDirection(GetGameplayCamRot(2)) or M.coords(GetEntityForwardVector(ped))
    local ending=M.add(start,M.mul(direction,shooting and Config.RenderDistance or 3))
    local nearest,part,first
    for _,g in pairs(DragonWorld.dragons) do
        if not g.deathAt then
            for _,box in ipairs(DragonRenderer.boxes(g,now)) do
                local t=M.segmentBox(start,ending,box,melee and .3 or 0)
                if t and (not first or t<first) then nearest,part,first=g,box.part,t end
            end
        end
    end
    if nearest then
        local point=M.lerp(start,ending,first)
        local muzzle=M.coords(GetPedBoneCoords(ped,57005,0,0,0))
        local valid,hit=DragonTargeting.ray(muzzle,point,ped)
        if valid and not hit then
            TriggerServerEvent('fivem-enderdragon:damage',nearest.id,melee and 'melee' or 'bullet',part=='head' or part=='jaw')
            D.nextDamage=now+Config.DamageIntervalMs
        end
    end
end

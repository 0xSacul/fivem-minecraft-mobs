CreeperEntity = {}
local C, M = CreeperEntity, CreeperMath
function C.update(c, now)
    c.fuseRatio = M.fuseProgress(c,now)
    if c.fuseRatio == 0 then c.fuseTarget=nil end
    if now >= (c.nextScan or 0) then
        c.target = CreeperTargeting.find(c)
        c.targetVisible = c.target and CreeperTargeting.visible(c,c.target) or false
        local active = c.fuseRatio > 0 or (c.fuseDir == 1 and c.wantSwell)
        local limit = active and Config.CancelDistance or Config.PrimeDistance
        c.targetPosition = c.targetVisible and M.coords(GetEntityCoords(c.target)) or nil
        c.wantSwell = c.targetPosition and M.distance(c.pos,c.targetPosition) < limit or false
        if c.wantSwell then c.fuseTarget=c.target end
        c.nextScan = now+((active or c.wantSwell) and math.min(100,Config.TargetScanMs) or Config.TargetScanMs)
    end
    if c.target and (not DoesEntityExist(c.target) or IsEntityDead(c.target)) then
        c.targetVisible,c.wantSwell,c.targetPosition=false,false,nil
    end
    local faceDt = math.min(0.10,(now-(c.lastFace or now))/1000)
    c.lastFace=now
    if c.targetVisible and (c.wantSwell or c.fuseRatio>0) then
        local desired=M.heading(c.pos,c.targetPosition or M.coords(GetEntityCoords(c.target)))
        c.heading=(c.heading+M.clamp(M.angleDelta(c.heading,desired),-Config.TurnSpeed*faceDt,Config.TurnSpeed*faceDt))%360
    end
    CreeperMovement.update(c,now)
    if c.targetVisible then
        local aim, eyes = CreeperTargeting.aim(c.target), CreeperTargeting.eyes(c)
        local delta = M.sub(aim,eyes)
        c.headYaw = M.clamp(M.angleDelta(c.heading,M.heading(eyes,aim)),-45,45)
        c.headPitch = M.clamp(-math.deg(math.atan(delta.z,math.sqrt(delta.x*delta.x+delta.y*delta.y))),-30,30)
    else c.headYaw,c.headPitch=0,0 end
end
function C.playerCombat(now)
    local ped = PlayerPedId()
    if IsEntityDead(ped) or now < (C.nextDamage or 0) then return end
    local shooting, melee = IsPedShooting(ped),IsPedPerformingMeleeAction(ped)
    if not shooting and not melee then return end
    local a,b
    if shooting then
        a = M.coords(GetGameplayCamCoord())
        b = M.add(a,M.mul(M.cameraDirection(GetGameplayCamRot(2)),Config.RenderDistance))
    else
        a = M.coords(GetPedBoneCoords(ped,57005,0.0,0.0,0.0))
        b = M.add(a,M.mul(M.coords(GetEntityForwardVector(ped)),2.6))
    end
    local nearest,t
    for _, c in pairs(CreeperWorld.creepers) do
        local hit = M.segmentBody(a,b,c,melee and 0.15 or 0)
        if hit and (not t or hit < t) then nearest,t=c,hit end
    end
    if nearest then
        local point = M.lerp(a,b,t)
        local muzzle = M.coords(GetPedBoneCoords(ped,57005,0.0,0.0,0.0))
        local valid,hit = CreeperTargeting.ray(muzzle,point,ped)
        if valid and not hit then
            TriggerServerEvent('fivem-creeper:damage',nearest.id,melee and 'melee' or 'bullet')
            C.nextDamage=now+Config.DamageIntervalMs
        end
    end
end

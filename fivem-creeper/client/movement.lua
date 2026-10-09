CreeperMovement = {}
local V, M = CreeperMovement, CreeperMath
local function blocked(c, now)
    c.walkAmount=0
    c.steerUntil, c.steerAngle = now + 900, (c.steerAngle and -c.steerAngle or (math.random(2)==1 and 75 or -75))
    c.nextMove = now + 150
    c.wanderUntil = 0
end
function V.floor(c, destination)
    local start = {x=destination.x,y=destination.y,z=c.pos.z+Config.MaxStepHeight+0.1}
    local ending = {x=destination.x,y=destination.y,z=c.pos.z-Config.MaxDrop-0.1}
    local valid, hit, position, normal = CreeperTargeting.ray(start,ending,c.entity,1+16+64)
    if not valid or not hit or not normal or normal.z < Config.MinGroundNormalZ then return nil end
    local delta = position.z-c.pos.z
    if delta > Config.MaxStepHeight or delta < -Config.MaxDrop then return nil end
    destination.z = position.z+0.01
    return destination
end
function V.update(c, now)
    local shouldStop = c.wantSwell or (c.fuseRatio or 0) > 0 or c.ending
    if c.probes then
        local pending, collision = false, false
        for _, probe in ipairs(c.probes) do
            if not probe.finished then
                local status, hit = GetShapeTestResult(probe.handle)
                if status == 1 then pending = true
                else probe.finished, probe.blocked = true, status ~= 2 or M.hit(hit) end
            end
            collision = collision or probe.blocked
        end
        if pending then return end
        if not collision and not shouldStop then
            local distance = M.distance(c.pos,c.moveEnd)
            c.pos = c.moveEnd
            c.walkPhase = ((c.walkPhase or 0)+distance*8)%10000
            c.walkAmount = math.min(0.65, c.moveSpeed/Config.ChaseSpeed*0.65)
        elseif collision then blocked(c,now) end
        c.probes = nil
    end
    if shouldStop then c.walkAmount = 0; c.lastMove = now; return end
    if now < (c.nextMove or 0) then return end
    local dt = math.min(0.10,math.max(Config.StepMs/1000,(now-(c.lastMove or now))/1000))
    c.lastMove, c.nextMove = now, now+Config.StepMs
    local destination, speed
    if c.targetVisible and c.target and DoesEntityExist(c.target) then
        destination, speed = M.coords(GetEntityCoords(c.target)), Config.ChaseSpeed
    else
        if now >= (c.wanderUntil or 0) or not c.destination or M.distance(c.pos,c.destination) < 0.5 then
            local angle, radius = math.random()*math.pi*2, math.random()*Config.WanderRadius
            c.destination = {x=c.origin.x+math.cos(angle)*radius,y=c.origin.y+math.sin(angle)*radius,z=c.pos.z}
            c.wanderUntil = now+math.random(4000,8000)
        end
        destination, speed = c.destination, Config.WanderSpeed
    end
    local direction = M.sub(destination,c.pos); direction.z=0
    local distance = M.length(direction)
    if distance < 0.15 then c.walkAmount=0; return end
    direction = M.normalize(direction)
    if now < (c.steerUntil or 0) then
        local r = math.rad(c.steerAngle)
        direction = {x=direction.x*math.cos(r)-direction.y*math.sin(r),y=direction.x*math.sin(r)+direction.y*math.cos(r),z=0}
    end
    local proposed = M.add(c.pos,M.mul(direction,math.min(distance,speed*dt)))
    if M.distance(proposed,c.origin) > Config.RoamLimit then c.target=nil; c.targetVisible=false; c.destination=c.origin; return end
    proposed = V.floor(c,proposed)
    if not proposed then c.walkAmount=0; blocked(c,now); return end
    c.moveEnd, c.moveSpeed, c.probes = proposed, speed, {}
    -- Two swept spheres cover legs/body and head; results are retained because completed handles invalidate.
    local lift = math.max(0,proposed.z-c.pos.z)
    for _, height in ipairs({0.85,1.30}) do
        local handle = StartShapeTestCapsule(c.pos.x,c.pos.y,c.pos.z+height+lift,
                       proposed.x,proposed.y,proposed.z+height,Config.CollisionRadius,511,c.entity,4)
        c.probes[#c.probes+1] = {handle=handle}
    end
    local desired = M.heading(c.pos,M.add(c.pos,direction))
    c.heading = (c.heading+M.clamp(M.angleDelta(c.heading,desired),-Config.TurnSpeed*dt,Config.TurnSpeed*dt))%360
end

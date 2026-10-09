DragonMovement = {}
local V,M=DragonMovement,DragonMath
local function recover(g,now)
    g.flightMode='recover';g.modeUntil=now+Config.Flight.RecoverMs
end
function V.update(g,dt,now)
    if g.moveProbe then
        local status,hit=GetShapeTestResult(g.moveProbe)
        if status==1 then return end
        if status==2 and not M.hit(hit) then g.pos=g.moveEnd else recover(g,now);g.avoidUntil=now+1800 end
        g.moveProbe=nil
    end
    g.flightMode=g.flightMode or 'circle'
    if (g.flightMode=='swoop' or g.flightMode=='recover') and now>=(g.modeUntil or 0) then
        if g.flightMode=='swoop' then recover(g,now) else g.flightMode='circle' end
    end
    if g.flightMode=='circle' and g.target and now>=(g.nextSwoop or (g.born+4000)) then
        g.flightMode='swoop';g.modeUntil=now+Config.Flight.SwoopDurationMs
        g.nextSwoop=now+Config.Flight.SwoopIntervalMs
        -- Commit to a pass rather than circling tightly around a moving victim forever.
        g.swoopGoal=M.add(DragonTargeting.aim(g.target),{x=0,y=0,z=Config.Flight.SwoopHeight})
    end
    g.orbitAngle=(g.orbitAngle or math.rad(g.heading))+dt*Config.Flight.CruiseSpeed/Config.Flight.OrbitRadius
    local a=g.orbitAngle+.65
    local destination={x=g.origin.x+math.cos(a)*Config.Flight.OrbitRadius,
        y=g.origin.y+math.sin(a)*Config.Flight.OrbitRadius,z=g.origin.z+math.sin(now*.0005)*3}
    local speed=Config.Flight.CruiseSpeed
    if g.flightMode=='swoop' then
        destination=g.swoopGoal;speed=Config.Flight.SwoopSpeed
        if M.distance(g.pos,destination)<5 then recover(g,now) end
    elseif g.flightMode=='recover' then destination.z=g.origin.z+8 end
    if now<(g.avoidUntil or 0) then
        destination=M.add(g.pos,M.mul(M.forward(g.heading+90),20));destination.z=g.pos.z+15
    end
    -- Returning to the arena takes priority over the attack trajectory.
    if M.distance(g.pos,g.origin)>Config.Flight.ArenaRadius-20 then destination=M.coords(g.origin);recover(g,now) end
    local diff=M.sub(destination,g.pos)
    local delta=M.angleDelta(g.heading,M.heading(g.pos,destination))
    local rotation=M.clamp(delta,-Config.Flight.TurnSpeed*dt,Config.Flight.TurnSpeed*dt)
    g.heading=(g.heading+rotation)%360
    g.turn=dt>0 and rotation/dt or 0
    g.bank=(g.bank or 0)+(M.clamp(-g.turn*.38,-20,20)-(g.bank or 0))*math.min(1,dt*3)
    local vertical=M.clamp(diff.z*.65,-Config.Flight.VerticalSpeed,Config.Flight.VerticalSpeed)
    if math.abs(delta)>100 then speed=speed*.6 end
    g.pitch=(g.pitch or 0)+(math.deg(math.atan(vertical,speed))-(g.pitch or 0))*math.min(1,dt*3)
    local velocity=M.mul(M.forward(g.heading),speed);velocity.z=vertical
    local ending=M.add(g.pos,M.mul(velocity,math.min(dt,.05)))
    RequestCollisionAtCoord(ending.x,ending.y,ending.z)
    local found,ground=GetGroundZFor_3dCoord(ending.x,ending.y,ending.z+3,false)
    if found and ending.z<ground+Config.Flight.GroundClearance then
        ending.z=ground+Config.Flight.GroundClearance;recover(g,now)
    end
    g.moveEnd=ending
    -- World/object collision only: vehicles must remain reachable for scripted contact.
    g.moveProbe=StartShapeTestSweptSphere(g.pos.x,g.pos.y,g.pos.z,ending.x,ending.y,ending.z,
        Config.Flight.BodyProbeRadius,1+16+64,g.entity,7)
end

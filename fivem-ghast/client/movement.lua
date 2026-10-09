GhastMovement = {}
local V, M = GhastMovement, GhastMath
function V.update(g, dt, now)
    if g.moveProbe then
        local status, hit = GetShapeTestResult(g.moveProbe)
        if status == 1 then return end
        if status == 2 and not M.hit(hit) then g.pos = g.moveEnd else g.wanderUntil = 0 end
        g.moveProbe = nil
    end
    if not g.wanderUntil or now >= g.wanderUntil or M.distance(g.pos, g.destination) < 1.0 then
        local angle, radius = math.random() * math.pi * 2, math.random() * Config.WanderRadius
        g.destination = { x = g.origin.x + math.cos(angle) * radius,
                          y = g.origin.y + math.sin(angle) * radius,
                          z = g.origin.z + math.random() * 6 - 3 }
        g.wanderUntil = now + math.random(4000, 9000)
    end
    local direction = M.normalize(M.sub(g.destination, g.pos))
    local velocity = M.mul(direction, Config.WanderSpeed)
    velocity.z = velocity.z + Config.BobAmplitude * Config.BobFrequency * math.cos(now / 1000 * Config.BobFrequency)
    g.moveEnd = M.add(g.pos, M.mul(velocity, math.min(dt, 0.05)))
    -- Bounding sphere encloses the cube; tentacles are decorative and have no collider.
    local radius = Config.BodySize * math.sqrt(3) / 2
    g.moveProbe = StartShapeTestSweptSphere(g.pos.x, g.pos.y, g.pos.z, g.moveEnd.x, g.moveEnd.y, g.moveEnd.z,
                                         radius, 1 + 16, g.entity, 7)
    local face = g.target and DoesEntityExist(g.target) and M.coords(GetEntityCoords(g.target)) or g.destination
    local delta = M.angleDelta(g.heading, M.heading(g.pos, face))
    local maxTurn = Config.TurnSpeed * dt
    g.heading = (g.heading + math.max(-maxTurn, math.min(maxTurn, delta))) % 360
end

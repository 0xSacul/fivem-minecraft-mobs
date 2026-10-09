CreeperMath = {}
local M = CreeperMath
function M.add(a, b) return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z } end
function M.sub(a, b) return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z } end
function M.mul(a, n) return { x = a.x * n, y = a.y * n, z = a.z * n } end
function M.dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
function M.length(a) return math.sqrt(M.dot(a, a)) end
function M.distance(a, b) return M.length(M.sub(a, b)) end
function M.normalize(a)
    local length = M.length(a)
    return length > 0.00001 and M.mul(a, 1.0 / length) or { x = 0, y = 1, z = 0 }
end
function M.coords(v) return { x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0 } end
function M.finite(n) return type(n) == 'number' and n == n and math.abs(n) < 100000 end
function M.valid(v) return type(v) == 'table' and M.finite(v.x) and M.finite(v.y) and M.finite(v.z) end
function M.hit(value) return value == true or value == 1 end
function M.clamp(n, low, high) return math.max(low, math.min(high, n)) end
function M.lerp(a, b, t) return M.add(a, M.mul(M.sub(b, a), t)) end
function M.angleDelta(a, b) return (b - a + 180) % 360 - 180 end
function M.heading(a, b) local d = M.sub(b, a); return math.deg(math.atan(-d.x, d.y)) % 360 end
function M.cameraDirection(rotation)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    return { x = -math.sin(yaw) * math.cos(pitch), y = math.cos(yaw) * math.cos(pitch), z = math.sin(pitch) }
end
function M.fuseProgress(c, now)
    local age = c.fuseReceived and math.min(Config.IntentTimeoutMs, now - c.fuseReceived) or 0
    return M.clamp((c.fuse or 0) + (c.fuseDir or -1) * age, 0, Config.FuseMs) / Config.FuseMs
end
-- Accurate renderer scale formula from the installed CreeperRenderer.
function M.swellScale(f)
    local jitter = 1 + math.sin(f * 100) * f * 0.01
    local swell = M.clamp(f, 0, 1) ^ 4
    return (1 + swell * 0.4) * jitter, (1 + swell * 0.1) / jitter
end
-- Yaw-oriented full-body box, including the four feet. Static hit collider approximates leg/head poses.
function M.segmentBody(a, b, c, padding)
    local yaw, extra = math.rad(c.heading), padding or 0
    local function localPoint(p)
        local d = M.sub(p, c.pos)
        return { x = d.x * math.cos(yaw) + d.y * math.sin(yaw),
                 y = -d.x * math.sin(yaw) + d.y * math.cos(yaw), z = d.z }
    end
    a, b = localPoint(a), localPoint(b)
    local direction = M.sub(b, a)
    local sx, sz = M.swellScale(c.fuseRatio or 0)
    local bounds = { x = { -4 * Config.Scale * sx - extra, 4 * Config.Scale * sx + extra },
                     y = { -6 * Config.Scale * sx - extra, 6 * Config.Scale * sx + extra },
                     z = { -extra, 26 * Config.Scale * sz + extra } }
    local enter, leave = 0, 1
    for _, axis in ipairs({ 'x', 'y', 'z' }) do
        local low, high = bounds[axis][1], bounds[axis][2]
        if math.abs(direction[axis]) < 0.000001 then
            if a[axis] < low or a[axis] > high then return nil end
        else
            local t1, t2 = (low - a[axis]) / direction[axis], (high - a[axis]) / direction[axis]
            if t1 > t2 then t1, t2 = t2, t1 end
            enter, leave = math.max(enter, t1), math.min(leave, t2)
            if enter > leave then return nil end
        end
    end
    return enter
end

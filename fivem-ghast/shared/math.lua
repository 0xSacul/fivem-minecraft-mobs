-- Plain tables on the wire; these helpers also run in stock Lua for verification.
GhastMath = {}
local M = GhastMath
function M.add(a, b) return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z } end
function M.sub(a, b) return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z } end
function M.mul(a, n) return { x = a.x * n, y = a.y * n, z = a.z * n } end
function M.dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
function M.length(a) return math.sqrt(M.dot(a, a)) end
function M.distance(a, b) return M.length(M.sub(a, b)) end
function M.normalize(a)
    local length = M.length(a)
    return length > 0.00001 and M.mul(a, 1.0 / length) or { x = 0.0, y = 1.0, z = 0.0 }
end
function M.coords(v) return { x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0 } end
function M.finite(n) return type(n) == 'number' and n == n and math.abs(n) < 100000.0 end
function M.valid(v) return type(v) == 'table' and M.finite(v.x) and M.finite(v.y) and M.finite(v.z) end
function M.hit(flag) return flag == true or flag == 1 end
function M.lerp(a, b, t) return M.add(a, M.mul(M.sub(b, a), t)) end
function M.heading(a, b) local d = M.sub(b, a); return math.deg(math.atan(-d.x, d.y)) % 360 end
function M.angleDelta(a, b) return (b - a + 180) % 360 - 180 end
function M.forward(heading)
    local r = math.rad(heading)
    return { x = -math.sin(r), y = math.cos(r), z = 0.0 }
end
function M.cameraDirection(rotation)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    return { x = -math.sin(yaw) * math.cos(pitch), y = math.cos(yaw) * math.cos(pitch), z = math.sin(pitch) }
end

-- Slab intersection of a segment against a Ghast's yaw-rotated body. Returns first t in [0,1].
function M.segmentBody(a, b, center, heading, padding)
    local r = math.rad(heading)
    local function localPoint(p)
        local d = M.sub(p, center)
        return { x = d.x * math.cos(r) + d.y * math.sin(r),
                 y = -d.x * math.sin(r) + d.y * math.cos(r), z = d.z }
    end
    a, b = localPoint(a), localPoint(b)
    local direction, half = M.sub(b, a), Config.BodySize * 0.5 + (padding or 0)
    local enter, leave = 0.0, 1.0
    for _, axis in ipairs({ 'x', 'y', 'z' }) do
        if math.abs(direction[axis]) < 0.000001 then
            if a[axis] < -half or a[axis] > half then return nil end
        else
            local t1, t2 = (-half - a[axis]) / direction[axis], (half - a[axis]) / direction[axis]
            if t1 > t2 then t1, t2 = t2, t1 end
            enter, leave = math.max(enter, t1), math.min(leave, t2)
            if enter > leave then return nil end
        end
    end
    return enter
end

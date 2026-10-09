CreeperRenderer = {}
local R, M = CreeperRenderer, CreeperMath
local dict = 'minecraft_creeper_runtime'
local nativePoly = DrawTexturedPoly or DrawSpritePoly
local unpack = table.unpack or unpack
local faces = {
    { { 6, 5, 1, 2 }, 'top', 255 }, { { 3, 4, 8, 7 }, 'bottom', 190 },
    { { 1, 5, 8, 4 }, 'left', 220 }, { { 2, 1, 4, 3 }, 'front', 255 },
    { { 6, 2, 3, 7 }, 'right', 235 }, { { 5, 6, 7, 8 }, 'back', 215 }
}
function R.init()
    local txd = CreateRuntimeTxd(dict)
    for _, name in ipairs({ 'creeper', 'creeper_flash50', 'creeper_flash75', 'creeper_flash100', 'creeper_hurt' }) do
        assert(CreateRuntimeTextureFromImage(txd, name, 'assets/runtime/' .. name .. '.png'), 'Creeper texture failed: ' .. name)
    end
end
local function triangle(a, b, c, texture, uvA, uvB, uvC, tint)
    local call = nativePoly or function(...) Citizen.InvokeNative(0x29280002282F1928, ...) end
    call(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, tint, tint, tint, 255, dict, texture,
         uvA[1], uvA[2], 1.0, uvB[1], uvB[2], 1.0, uvC[1], uvC[2], 1.0)
end
-- Also used by the offline OBJ/preview generator so it verifies the same mesh as the client.
function R.mesh(c, now)
    local sx, sz = M.swellScale(c.fuseRatio or 0)
    local heading = math.rad(c.heading)
    local result = {}
    for _, part in ipairs(CreeperModel) do
        local box, pivot = part.box, part.pivot
        local x, y, z, dx, dy, dz = unpack(box)
        local pitch, yaw = 0, 0
        if part.phase then pitch = math.cos((c.walkPhase or 0) * 0.6662 + part.phase) * 1.4 * (c.walkAmount or 0)
        elseif part.name == 'head' then pitch, yaw = math.rad(c.headPitch or 0), math.rad(c.headYaw or 0) end
        local raw = { {x,y,z},{x+dx,y,z},{x+dx,y+dy,z},{x,y+dy,z},
                      {x,y,z+dz},{x+dx,y,z+dz},{x+dx,y+dy,z+dz},{x,y+dy,z+dz} }
        local vertices = {}
        for i, v in ipairs(raw) do
            local yy, zz = v[2] * math.cos(pitch) - v[3] * math.sin(pitch), v[2] * math.sin(pitch) + v[3] * math.cos(pitch)
            local xx = v[1] * math.cos(yaw) + zz * math.sin(yaw)
            zz = -v[1] * math.sin(yaw) + zz * math.cos(yaw)
            xx, yy, zz = (xx + pivot[1]) * Config.Scale * sx, -(zz + pivot[3]) * Config.Scale * sx,
                         (24 - yy - pivot[2]) * Config.Scale * sz
            vertices[i] = { x = c.pos.x + xx * math.cos(heading) - yy * math.sin(heading),
                            y = c.pos.y + xx * math.sin(heading) + yy * math.cos(heading), z = c.pos.z + zz }
        end
        local rectangles = {
            top = { dz, 0, dz+dx, dz }, bottom = { dz+dx, dz, dz+dx+dx, 0 },
            left = { 0, dz, dz, dz+dy }, front = { dz, dz, dz+dx, dz+dy },
            right = { dz+dx, dz, dz+dx+dz, dz+dy }, back = { dz+dx+dz, dz, dz+dx+dz+dx, dz+dy }
        }
        for _, face in ipairs(faces) do
            local t, order, u, v = rectangles[face[2]], face[1], part.uv[1], part.uv[2]
            local uv = { { (u+t[3])/64, (v+t[2])/32 }, { (u+t[1])/64, (v+t[2])/32 },
                         { (u+t[1])/64, (v+t[4])/32 }, { (u+t[3])/64, (v+t[4])/32 } }
            result[#result + 1] = { vertices = {vertices[order[4]],vertices[order[3]],vertices[order[2]],vertices[order[1]]},
                                   uv = {uv[4],uv[3],uv[2],uv[1]}, tint = face[3], part = part.name }
        end
    end
    return result
end
function R.draw(c, now)
    c.fuseRatio = M.fuseProgress(c, now)
    local f, texture = c.fuseRatio, 'creeper'
    if now < (c.hurtUntil or 0) then texture = 'creeper_hurt'
    elseif math.floor(f * 10) % 2 ~= 0 then
        texture = f < 0.625 and 'creeper_flash50' or (f < 0.875 and 'creeper_flash75' or 'creeper_flash100')
    end
    for _, face in ipairs(R.mesh(c, now)) do
        local a, b, d, e = unpack(face.vertices)
        triangle(a, b, d, texture, face.uv[1], face.uv[2], face.uv[3], face.tint)
        triangle(a, d, e, texture, face.uv[1], face.uv[3], face.uv[4], face.tint)
    end
end

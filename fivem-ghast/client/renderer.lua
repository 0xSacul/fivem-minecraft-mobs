GhastRenderer = {}
local R, M = GhastRenderer, GhastMath
local dict = 'minecraft_ghast_runtime'
local lengths = { 8, 13, 9, 11, 11, 10, 12, 9, 12 } -- Java random seed 1660, nextInt(7)+8
local nativePoly = DrawTexturedPoly or DrawSpritePoly

function R.init()
    local txd = CreateRuntimeTxd(dict)
    for _, name in ipairs({ 'ghast', 'ghast_shooting', 'fire_charge' }) do
        assert(CreateRuntimeTextureFromImage(txd, name, 'assets/runtime/' .. name .. '.png'),
               'Could not load Ghast texture ' .. name)
    end
end

local function triangle(a, b, c, texture, uvA, uvB, uvC, tint)
    local call = nativePoly or function(...) Citizen.InvokeNative(0x29280002282F1928, ...) end
    call(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z,
         tint, tint, tint, 255, dict, texture,
         uvA[1], uvA[2], 1.0, uvB[1], uvB[2], 1.0, uvC[1], uvC[2], 1.0)
end

local function quad(vertices, indices, texture, uv, tint)
    local a, b, c, d = vertices[indices[1]], vertices[indices[2]], vertices[indices[3]], vertices[indices[4]]
    triangle(a, b, c, texture, uv[1], uv[2], uv[3], tint)
    triangle(a, c, d, texture, uv[1], uv[3], uv[4], tint)
end

-- Same vertex order and UV net as installed ModelPart$Cube. Minecraft X right, Y down, Z back.
local faces = {
    { indices = { 6, 5, 1, 2 }, side = 'top', tint = 255 },
    { indices = { 3, 4, 8, 7 }, side = 'bottom', tint = 190 },
    { indices = { 1, 5, 8, 4 }, side = 'left', tint = 225 },
    { indices = { 2, 1, 4, 3 }, side = 'front', tint = 255 },
    { indices = { 6, 2, 3, 7 }, side = 'right', tint = 235 },
    { indices = { 5, 6, 7, 8 }, side = 'back', tint = 220 }
}

local function cube(center, heading, x, y, z, dx, dy, dz, pivot, angle, texture, hurt)
    local size = Config.BodySize / 16.0
    local cosH, sinH, cosA, sinA = math.cos(math.rad(heading)), math.sin(math.rad(heading)), math.cos(angle), math.sin(angle)
    local raw = { { x, y, z }, { x + dx, y, z }, { x + dx, y + dy, z }, { x, y + dy, z },
                  { x, y, z + dz }, { x + dx, y, z + dz }, { x + dx, y + dy, z + dz }, { x, y + dy, z + dz } }
    local vertices = {}
    for i, v in ipairs(raw) do
        local yy, zz = v[2] * cosA - v[3] * sinA + pivot.y, v[2] * sinA + v[3] * cosA + pivot.z
        local xx = v[1] + pivot.x
        -- Ghast local front (-Z in Minecraft) becomes +Y in GTA.
        xx, yy, zz = xx * size, -zz * size, -yy * size
        vertices[i] = { x = center.x + xx * cosH - yy * sinH,
                        y = center.y + xx * sinH + yy * cosH, z = center.z + zz }
    end
    local rectangles = {
        top = { dz, 0, dz + dx, dz }, bottom = { dz + dx, dz, dz + dx + dx, 0 },
        left = { 0, dz, dz, dz + dy }, front = { dz, dz, dz + dx, dz + dy },
        right = { dz + dx, dz, dz + dx + dz, dz + dy },
        back = { dz + dx + dz, dz, dz + dx + dz + dx, dz + dy }
    }
    for _, face in ipairs(faces) do
        local t = rectangles[face.side]
        -- LayerDefinition logical atlas is 64x32; installed PNG is a 128x64 equivalent.
        local uv = { { t[3] / 64.0, t[2] / 32.0 }, { t[1] / 64.0, t[2] / 32.0 },
                     { t[1] / 64.0, t[4] / 32.0 }, { t[3] / 64.0, t[4] / 32.0 } }
        -- Coordinate conversion has negative determinant: reverse winding for outward GTA faces.
        local indices = face.indices
        quad(vertices, { indices[4], indices[3], indices[2], indices[1] }, texture,
             { uv[4], uv[3], uv[2], uv[1] }, hurt and 170 or face.tint)
    end
end

function R.ghast(g, now)
    local texture = g.charging and 'ghast_shooting' or 'ghast'
    cube(g.pos, g.heading, -8, -8, -8, 16, 16, 16, { x = 0, y = 0, z = 0 }, 0.0, texture, now < (g.hurtUntil or 0))
    for i = 0, 8 do
        local xo = ((i % 3 - math.floor(i / 3) % 2 * 0.5 + 0.25) / 2 * 2 - 1) * 5
        local zo = (math.floor(i / 3) / 2 * 2 - 1) * 5
        -- Installed body pivot Y=17.6, tentacle pivot Y=24.6: offset 7 model units.
        local angle = 0.2 * math.sin((now / 50.0) * 0.3 + i) + 0.4
        cube(g.pos, g.heading, -1, 0, -1, 2, lengths[i + 1], 2,
             { x = xo, y = 7, z = zo }, angle, texture, false)
    end
end

function R.fireball(p)
    local cam = GetGameplayCamRot(2)
    local yaw = math.rad(cam.z)
    local right = { x = math.cos(yaw), y = math.sin(yaw), z = 0.0 }
    local forward = M.cameraDirection(cam)
    local up = { x = right.y * forward.z, y = -right.x * forward.z,
                 z = right.x * forward.y - right.y * forward.x }
    local half, v = Config.Fireball.SpriteSize / 2.0, {}
    for i, corner in ipairs({ { -1, 1 }, { 1, 1 }, { 1, -1 }, { -1, -1 } }) do
        v[i] = M.add(p.pos, M.add(M.mul(right, half * corner[1]), M.mul(up, half * corner[2])))
    end
    local uv = { { 0.0, 0.0 }, { 1.0, 0.0 }, { 1.0, 1.0 }, { 0.0, 1.0 } }
    quad(v, { 1, 2, 3, 4 }, 'fire_charge', uv, 255)
    quad(v, { 4, 3, 2, 1 }, 'fire_charge', { uv[4], uv[3], uv[2], uv[1] }, 255)
    DrawLightWithRange(p.pos.x, p.pos.y, p.pos.z, 255, 105, 30, 4.0, 1.0)
end

-- Read from installed 26.3 CreeperModel.createBodyLayer. Y down; Z toward the back.
-- Coordinates are model units, not meters. Feet rest at Y=24, crown at Y=-2.
CreeperModel = {
    { name = 'head', box = { -4, -8, -4, 8, 8, 8 }, pivot = { 0, 6, 0 }, uv = { 0, 0 } },
    { name = 'body', box = { -4, 0, -2, 8, 12, 4 }, pivot = { 0, 6, 0 }, uv = { 16, 16 } },
    { name = 'right_hind_leg', box = { -2, 0, -2, 4, 6, 4 }, pivot = { -2, 18, 4 }, uv = { 0, 16 }, phase = math.pi },
    { name = 'left_hind_leg', box = { -2, 0, -2, 4, 6, 4 }, pivot = { 2, 18, 4 }, uv = { 0, 16 }, phase = 0 },
    { name = 'right_front_leg', box = { -2, 0, -2, 4, 6, 4 }, pivot = { -2, 18, -4 }, uv = { 0, 16 }, phase = 0 },
    { name = 'left_front_leg', box = { -2, 0, -2, 4, 6, 4 }, pivot = { 2, 18, -4 }, uv = { 0, 16 }, phase = math.pi }
}

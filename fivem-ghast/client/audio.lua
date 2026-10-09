GhastAudio = {}
local A, M = GhastAudio, GhastMath
local ready, queue = false, {}
local groups = {
    ambient = { 'moan1', 'moan2', 'moan3', 'moan4', 'moan5', 'moan6', 'moan7' },
    hurt = { 'scream1', 'scream2', 'scream3', 'scream4', 'scream5' },
    death = { 'death' }, warn = { 'charge' }, shoot = { 'fireball4' }
}
RegisterNUICallback('ready', function(_, cb)
    ready = true
    SendNUIMessage({ action = 'config', distance = Config.Audio.Distance,
                     volume = Config.Audio.Volume, maxVoices = Config.Audio.MaxVoices })
    for _, message in ipairs(queue) do SendNUIMessage(message) end
    queue = {}
    cb({ ok = true })
end)
function A.play(event, position)
    local names = groups[event]
    if not names or M.distance(M.coords(GetGameplayCamCoord()), position) > Config.Audio.Distance then return end
    local message = { action = 'play', name = names[math.random(#names)], pos = position }
    if ready then SendNUIMessage(message) elseif #queue < Config.Audio.MaxVoices then queue[#queue + 1] = message end
end
function A.listener()
    if not ready then return end
    local cam = GetGameplayCamRot(2)
    local f = M.cameraDirection(cam)
    local yaw = math.rad(cam.z)
    local right = { x = math.cos(yaw), y = math.sin(yaw), z = 0.0 }
    local up = { x = right.y * f.z, y = -right.x * f.z, z = right.x * f.y - right.y * f.x }
    SendNUIMessage({ action = 'listener', pos = M.coords(GetGameplayCamCoord()), forward = f, up = up })
end

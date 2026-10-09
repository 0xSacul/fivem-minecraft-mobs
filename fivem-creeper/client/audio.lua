CreeperAudio = {}
local A,M = CreeperAudio,CreeperMath
local ready,queue=false,{}
local groups = {hurt={'say1','say2','say3','say4'},death={'death'},primed={'fuse'},explode={'explode1','explode2','explode3','explode4'}}
RegisterNUICallback('ready',function(_,cb)
    ready=true
    SendNUIMessage({action='config',distance=Config.Audio.Distance,volume=Config.Audio.Volume,maxVoices=Config.Audio.MaxVoices})
    for _, message in ipairs(queue) do SendNUIMessage(message) end
    queue={};cb({ok=true})
end)
function A.play(kind,position,id)
    local choices=groups[kind]
    if not choices or M.distance(M.coords(GetGameplayCamCoord()),position)>Config.Audio.Distance then return end
    local message={action='play',name=choices[math.random(#choices)],pos=position,
                   id=kind=='primed' and id and (id..':primed') or nil}
    if ready then SendNUIMessage(message) elseif #queue<Config.Audio.MaxVoices then queue[#queue+1]=message end
end
function A.stopFuse(id)
    for i=#queue,1,-1 do if queue[i].id==id..':primed' then table.remove(queue,i) end end
    if ready then SendNUIMessage({action='stopEmitter',id=id..':primed'}) end
end
function A.listener()
    if not ready then return end
    local cam=GetGameplayCamRot(2);local forward=M.cameraDirection(cam);local yaw=math.rad(cam.z)
    local right={x=math.cos(yaw),y=math.sin(yaw),z=0}
    local up={x=right.y*forward.z,y=-right.x*forward.z,z=right.x*forward.y-right.y*forward.x}
    SendNUIMessage({action='listener',pos=M.coords(GetGameplayCamCoord()),forward=forward,up=up})
end

DragonAudio = {}
local A,M=DragonAudio,DragonMath
local ready,queue=false,{}
local groups={ambient={'growl1','growl2','growl3','growl4'},warn={'growl1','growl2','growl3','growl4'},
    hurt={'hit1','hit2','hit3','hit4'},death={'end'},shoot={'fireball4'},flap={'wings1','wings2','wings3','wings4','wings5','wings6'}}
RegisterNUICallback('ready',function(_,cb)
    ready=true
    SendNUIMessage({action='config',distance=Config.Audio.Distance,volume=Config.Audio.Volume,maxVoices=Config.Audio.MaxVoices})
    for _,msg in ipairs(queue) do SendNUIMessage(msg) end;queue={};cb({ok=true})
end)
function A.play(event,position,id)
    if not groups[event] or M.distance(M.coords(GetGameplayCamCoord()),position)>Config.Audio.Distance then return end
    local names=groups[event]
    local msg={action='play',name=names[math.random(#names)],pos=position,id=event=='warn' and id..':warn' or nil}
    if ready then SendNUIMessage(msg) elseif #queue<Config.Audio.MaxVoices then queue[#queue+1]=msg end
end
function A.cancel(id)
    local key=id..':warn'
    for i=#queue,1,-1 do if queue[i].id==key then table.remove(queue,i) end end
    if ready then SendNUIMessage({action='stopEmitter',id=key}) end
end
function A.listener()
    if not ready then return end
    local r=GetGameplayCamRot(2);local f=M.cameraDirection(r)
    local right={x=math.cos(math.rad(r.z)),y=math.sin(math.rad(r.z)),z=0}
    SendNUIMessage({action='listener',pos=M.coords(GetGameplayCamCoord()),forward=f,up=M.cross(right,f)})
end

local M=CreeperMath
local function point(x,y,z) return {x=x or 0,y=y or 0,z=z or 0} end
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a)..' != '..tostring(b)) end
assert(not M.valid(point(0/0,0,0)) and not M.valid(point(math.huge,0,0)))
assert(M.hit(true) and M.hit(1) and not M.hit(false) and not M.hit(0))
near(M.segmentBody(point(0,-10,1),point(0,10,1),{pos=point(),heading=0}),0.48125)
assert(not M.segmentBody(point(0,-10,2),point(0,10,2),{pos=point(),heading=0}))
assert(M.segmentBody(point(0.3,-10,1),point(0.3,10,1),{pos=point(),heading=45}))
near(M.fuseProgress({fuse=500,fuseDir=-1,fuseReceived=0},600),0)
near(M.fuseProgress({fuse=1400,fuseDir=1,fuseReceived=0},200),1)

-- Server coroutine runs the actual fuse clock; event inputs have native stubs.
local clock,handlers,events,threads,players,buckets=0,{},{},{},{'1','2','3'},{[1]=0,[2]=0,[3]=1}
function GetGameTimer() return clock end
function RegisterNetEvent(name,fn) handlers[name]=fn end
function AddEventHandler(name,fn) handlers[name]=fn end
function CreateThread(fn) threads[#threads+1]=fn end
function Wait() coroutine.yield() end
function GetPlayers() return players end
function GetPlayerPed(src) return src end
function GetEntityCoords() return point(0,2,0) end
function GetPlayerRoutingBucket(src) return buckets[src] end
function GetPlayerName(src) return 'player'..src end
function IsPlayerAceAllowed() return true end
function TriggerClientEvent(name,target,...)
    events[#events+1]={name=name,target=target,args={...}}
end
function TriggerServerEvent(name,...)
    events[#events+1]={name=name,args={...}}
end
local function invoke(name,src,...)
    source=src;assert(handlers['fivem-creeper:'..name],name)(...)
end
local function last(name)
    for i=#events,1,-1 do if events[i].name=='fivem-creeper:'..name then return events[i] end end
end
local function total(name)
    local n=0;for _,event in ipairs(events) do if event.name=='fivem-creeper:'..name then n=n+1 end end;return n
end
local function lastSound(kind)
    for i=#events,1,-1 do if events[i].name=='fivem-creeper:sound' and events[i].args[1]==kind then return events[i] end end
end
dofile('server/main.lua')
local server=coroutine.create(threads[1])
local function resumeServer() local ok,error=coroutine.resume(server);assert(ok,error) end
resumeServer()
local function tick() clock=clock+50;resumeServer() end
invoke('spawn',1,point(),0)
local id=last('creeper').args[1].id
for _,event in ipairs(events) do assert(event.target~=3,'Cross-bucket leak') end
local function update(cid,owner,want,target,position)
    invoke('update',owner,{{id=cid,pos=position or point(),heading=0,walkPhase=0,walkAmount=0,headYaw=0,headPitch=0,
                           wantSwell=want,targetPosition=target or point(0,2,0)}})
end
update(id,2,true)
tick();assert(not lastSound('primed'),'Non-owner primed Creeper')
update(id,1,true,point(0,10,0))
tick();assert(not lastSound('primed'),'Distant target primed Creeper');tick()
update(id,1,true)
tick();assert(lastSound('primed'))
for _=1,7 do tick() end
invoke('requestSnapshot',2)
assert(last('snapshot').args[1][1].fuse==400)
-- Target escapes: fuse winds down and never detonates.
update(id,1,false)
for _=1,8 do tick() end
assert(not last('detonate'))
for _=1,20 do tick() end;invoke('requestSnapshot',2)
assert(last('snapshot').args[1][1].fuse==0)
update(id,1,true)
for i=1,29 do
    tick();if i%2==0 then update(id,1,true) end
end
assert(not last('detonate'),'Fuse detonated early')
tick();assert(last('detonate'),'Fuse did not detonate at 30 ticks')
assert(lastSound('explode') and not lastSound('death'),'Detonation should use explosion audio')
local detonations=total('detonate')
for _=1,10 do tick() end
assert(total('detonate')==detonations,'Duplicate detonation')
invoke('damage',1,id,'bullet')
assert(total('detonate')==detonations,'Dead Creeper accepted damage')

for _=1,40 do tick() end;invoke('spawn',1,point(),0);id=last('creeper').args[1].id
update(id,1,true);tick()
local before=total('detonate')
-- Without fresh owner intent, the fuse must unwind rather than completing.
for _=1,45 do tick() end
assert(total('detonate')==before,'Stale owner intent exploded')
for _=1,20 do tick() end;invoke('requestSnapshot',2)
assert(last('snapshot').args[1][1].fuse==0)
invoke('damage',3,id,'bullet')
assert(not lastSound('hurt'),'Cross-bucket damage accepted')
invoke('damage',2,id,'bullet')
assert(lastSound('hurt') and last('creeper').args[1].hp==88)
invoke('damage',2,id,'bullet');assert(last('creeper').args[1].hp==88,'Damage throttle bypass')
for _=1,4 do for _=1,4 do tick() end;invoke('damage',2,id,'melee') end
assert(lastSound('death') and last('remove').args[1]==id,'Killed Creeper was not removed')
assert(total('detonate')==before,'Killed Creeper exploded')
for _=1,40 do tick() end;invoke('spawn',1,point(),0);id=last('creeper').args[1].id
update(id,1,false,nil,point(50,0,0))
for _=1,20 do tick() end;invoke('requestSnapshot',2)
assert(last('snapshot').args[1][1].pos.x==0,'Teleport accepted')
source=1;handlers.playerDropped();assert(last('remove').args[1]==id)

-- Client state selects 3m initial and 7m continuation; LOS loss requests defuse.
local targetPos,visible=point(0,2,0),true
function DoesEntityExist() return true end
function IsEntityDead() return false end
function GetEntityCoords() return targetPos end
CreeperTargeting={find=function() return 9 end,visible=function() return visible end,
    eyes=function(c) return M.add(c.pos,point(0,0,1.375)) end,aim=function() return M.add(targetPos,point(0,0,0.8)) end}
CreeperMovement={update=function() end}
dofile('client/creeper.lua')
local c={pos=point(),origin=point(),heading=0,fuse=0,fuseDir=-1}
CreeperEntity.update(c,0);assert(c.wantSwell)
targetPos=point(0,6,0);c.fuse=300;c.fuseDir=1;c.fuseReceived=250
CreeperEntity.update(c,250);assert(c.wantSwell,'Continuation hysteresis lost')
visible=false;CreeperEntity.update(c,500);assert(not c.wantSwell,'LOS loss did not cancel fuse')
visible=true;c.fuse=0;c.fuseDir=-1;c.fuseReceived=750
CreeperEntity.update(c,750);assert(not c.wantSwell,'Zero fuse should require 3m again')

-- Ground movement: reject ledges/steep slopes, keep completed handles while another is pending.
local floorZ,normal,valid,hit=0,point(0,0,1),true,true
CreeperTargeting.ray=function(a,b) return valid,hit,point(b.x,b.y,floorZ),normal,0 end
dofile('client/movement.lua')
c={pos=point(),origin=point(),heading=0,entity=5,walkPhase=0,walkAmount=0,destination=point(0,10,0),wanderUntil=999999}
assert(CreeperMovement.floor(c,point(0,1,0)))
floorZ=1;assert(not CreeperMovement.floor(c,point(0,1,0)))
floorZ=-2;assert(not CreeperMovement.floor(c,point(0,1,0)))
floorZ=0;normal=point(0,0,0.1);assert(not CreeperMovement.floor(c,point(0,1,0)))
normal=point(0,0,1)
local handleCount,probeStates=0,{}
function StartShapeTestCapsule() handleCount=handleCount+1;probeStates[handleCount]={2,false};return handleCount end
function GetShapeTestResult(handle)
    local state=probeStates[handle];assert(state,'Completed handle polled again')
    if state[1]~=1 then probeStates[handle]=nil end
    return state[1],state[2],point(),point(0,0,1),0
end
CreeperMovement.update(c,0);assert(#c.probes==2)
local endPos=M.coords(c.moveEnd);probeStates[2]={1,false}
CreeperMovement.update(c,10);near(M.distance(c.pos,point()),0)
probeStates[2]={2,false};CreeperMovement.update(c,20)
near(M.distance(c.pos,endPos),0)
CreeperMovement.update(c,50);local from=M.coords(c.pos)
probeStates[handleCount]={2,true};CreeperMovement.update(c,60)
near(M.distance(c.pos,from),0);assert(c.steerUntil)
c.wantSwell=true;CreeperMovement.update(c,500);assert(c.walkAmount==0)

-- Mesh bounds, UVs, six cuboids, outward winding, alternating legs, and swell.
local triangles={}
function DrawTexturedPoly(...) triangles[#triangles+1]={...} end
function CreateRuntimeTxd() return 1 end
function CreateRuntimeTextureFromImage() return 1 end
dofile('client/renderer.lua');CreeperRenderer.init()
c={pos=point(),heading=0,fuseRatio=0,walkPhase=0,walkAmount=0}
local mesh=CreeperRenderer.mesh(c,0)
assert(#mesh==36)
local minZ,maxZ=math.huge,-math.huge
for _, face in ipairs(mesh) do
    for _,v in ipairs(face.vertices) do minZ=math.min(minZ,v.z);maxZ=math.max(maxZ,v.z) end
    for _,uv in ipairs(face.uv) do assert(uv[1]>=0 and uv[1]<=1 and uv[2]>=0 and uv[2]<=1) end
end
near(minZ,0);near(maxZ,1.625)
local face=mesh[4];local ab,ac=M.sub(face.vertices[2],face.vertices[1]),M.sub(face.vertices[3],face.vertices[1])
assert(ab.z*ac.x-ab.x*ac.z>0,'Head face points inward')
CreeperRenderer.draw(c,0);assert(#triangles==72)
c.walkAmount=0.6;local animated=CreeperRenderer.mesh(c,0)
assert(M.distance(animated[13].vertices[1],mesh[13].vertices[1])>0.01,'Legs not animated')
c.fuseRatio=1;c.walkAmount=0;local swollen=CreeperRenderer.mesh(c,0)
assert(swollen[1].vertices[1].z>mesh[1].vertices[1].z,'No swelling')

-- Actual client coordinator boot, replicas, interpolation, defuse audio and resource cleanup.
threads={};events={}
local entities,deleted,stopped,explosions=100,{},0,0
function GetHashKey() return 1 end
function RegisterCommand() end
function IsModelInCdimage() return true end
function IsModelValid() return true end
function RequestModel() end
function HasModelLoaded() return true end
function PlayerId() return 1 end
function PlayerPedId() return 1 end
function GetPlayerServerId(player) return player end
function IsPedShooting() return false end
function IsPedPerformingMeleeAction() return false end
function GetGameplayCamCoord() return point() end
function GetGameplayCamRot() return point() end
function CreateObjectNoOffset() entities=entities+1;return entities end
function SetEntityAsMissionEntity() end
function SetEntityVisible() end
function SetEntityAlpha() end
function SetEntityCollision() end
function FreezeEntityPosition() end
function SetEntityInvincible() end
function SetEntityCoordsNoOffset() end
function SetEntityHeading() end
function DeleteEntity(entity) deleted[#deleted+1]=entity end
function GetCurrentResourceName() return 'fivem-creeper' end
function SendNUIMessage() end
function SetModelAsNoLongerNeeded() end
CreeperAudio={play=function() end,listener=function() end,stopFuse=function() stopped=stopped+1 end}
dofile('client/main.lua')
local loop=coroutine.create(threads[1]);local ok,error=coroutine.resume(loop);assert(ok,error)
local replica={id='remote',owner=2,pos=point(),origin=point(),heading=350,hp=100,fuse=0,fuseDir=-1,
               walkPhase=0,walkAmount=0,headYaw=0,headPitch=0}
handlers['fivem-creeper:creeper'](replica);assert(CreeperWorld.creepers.remote.entity==101)
replica.pos=point(2,0,0);replica.heading=10;replica.walkPhase=1
handlers['fivem-creeper:state']({replica})
clock=clock+50;ok,error=coroutine.resume(loop);assert(ok,error)
near(CreeperWorld.creepers.remote.pos.x,1);near(CreeperWorld.creepers.remote.heading,0)
near(CreeperWorld.creepers.remote.walkPhase,0.5)
handlers['fivem-creeper:snapshot']({});assert(not next(CreeperWorld.creepers) and #deleted==1)
handlers.onResourceStop('fivem-creeper');assert(stopped>0)

-- Exactly one client emits the VFX explosion, with native damage/audible flags disabled.
function GetEntityCoords() return point(100,100,0) end
function GetGamePool() return {} end
Citizen={InvokeNative=function(hash,...)
    local args={...};assert(hash==0xE3AD2BDBAEE269AC and #args==9 and args[9]==true and args[6]==false)
    explosions=explosions+1
end}
dofile('client/explosion.lua')
CreeperExplosion.detonate(point(),2);assert(explosions==0)
CreeperExplosion.detonate(point(),1);assert(explosions==1)
-- Splash is bounded and cover-aware; never apply another player's damage locally.
local positions={[1]=point(1,0,0),[2]=point(2,0,0),[3]=point(1,0,0),[10]=point(4,0,0),[20]=point(3,0,0),[21]=point(3,0,0),[22]=point(20,0,0)}
local hits,objectHealth,engineHealth={},{},nil
function GetEntityCoords(entity) return positions[entity] end
function IsEntityAPed(entity) return entity==1 or entity==2 or entity==3 end
function IsPedAPlayer(entity) return entity==1 or entity==3 end
function IsEntityAVehicle(entity) return entity==10 end
function IsEntityAnObject(entity) return entity>=20 end
function GetGamePool(pool) return pool=='CPed' and {1,2,3} or (pool=='CVehicle' and {10} or {20,21,22}) end
function NetworkGetEntityIsNetworked() return true end
function NetworkHasControlOfEntity() return true end
function ApplyDamageToPed(entity,amount) hits[entity]=amount end
function GetVehicleEngineHealth() return 1000 end
function GetVehicleBodyHealth() return 1000 end
function SetVehicleEngineHealth(_,health) engineHealth=health end
function SetVehicleBodyHealth() end
function GetEntityHealth() return 100 end
function SetEntityHealth(entity,health) objectHealth[entity]=health end
CreeperWorld.creepers.anchor={entity=21}
CreeperTargeting.ray=function(_,ending) return true,ending.x==2,ending,point(0,0,1),ending.x==2 and 55 or 0 end
CreeperExplosion.detonate(point(0,0,0.8),2)
assert(hits[1]==100 and not hits[2] and not hits[3],'Cover or player ownership check failed')
assert(engineHealth and engineHealth<1000 and objectHealth[20]<100)
assert(not objectHealth[21] and not objectHealth[22],'Anchor or distant prop damaged')
print('PASS: fuse/defuse, server ownership, bucket isolation, stale input, damage/death, ground probes, mesh, replication and single explosion')

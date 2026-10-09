local M=DragonMath
local function point(x,y,z) return {x=x or 0,y=y or 0,z=z or 0} end
local function close(a,b) assert(math.abs(a-b)<.00001,tostring(a)..' != '..tostring(b)) end
assert(not M.valid(point(0/0)) and not M.valid(point(math.huge)))
assert(M.hit(true) and M.hit(1) and not M.hit(false) and not M.hit(0))
local axes={point(1,0,0),point(0,1,0),point(0,0,1)}
local box={center=point(),axes=axes,half={1,2,3}}
close(M.segmentBox(point(0,-10),point(0,10),box),.4)
assert(not M.segmentBox(point(2,-10),point(2,10),box))
assert(M.boxOverlap(box,{center=point(1.9),axes=axes,half={1,1,1}}))
assert(not M.boxOverlap(box,{center=point(2.1),axes=axes,half={1,1,1}}))
assert(not M.boxOverlap(box,{center=point(0,0,5),axes=axes,half={1,1,1}}))
local rotated={center=point(2,0,0),axes={point(.707,.707),point(-.707,.707),point(0,0,1)},half={1,1,1}}
assert(M.boxOverlap(box,rotated),'Rotated vehicle collision failed')

-- Actual hierarchical render geometry, UV bounds, outward winding and animated hitboxes.
local triangles={}
function DrawTexturedPoly(...) triangles[#triangles+1]={...} end
function CreateRuntimeTxd() return 1 end
function CreateRuntimeTextureFromImage() return 1 end
dofile('client/renderer.lua');DragonRenderer.init()
local g={id='mesh',pos=point(),heading=0,flapPhase=0,poseTime=0,pitch=0,bank=0}
local mesh,boxes=DragonRenderer.geometry(g,0,true)
assert(#boxes==65 and #mesh==374,'Incorrect dragon geometry')
local nextFace=1
for _,b in ipairs(boxes) do
    local n=b.half[2]==.06 and 2 or 6
    for f=nextFace,nextFace+n-1 do
        local face=mesh[f]
        for _,uv in ipairs(face.uv) do assert(uv[1]>=0 and uv[1]<=1 and uv[2]>=0 and uv[2]<=1,'UV outside original atlas') end
        if n==6 then
            local a,c,d=face.vertices[1],face.vertices[2],face.vertices[3]
            assert(M.dot(M.cross(M.sub(c,a),M.sub(d,a)),M.sub(a,b.center))>0,'Inward face: '..b.part)
        end
    end
    nextFace=nextFace+n
end
DragonRenderer.draw(g,0);assert(#triangles>748)
local animated=DragonRenderer.boxes(g,400)
local wingChanged,tailChanged=false,false
for i,b in ipairs(boxes) do
    if b.part=='left_wing_tip' and M.distance(b.center,animated[i].center)>.1 then wingChanged=true end
    if b.part=='tail11' and M.distance(b.center,animated[i].center)>.01 then tailChanged=true end
end
assert(wingChanged and tailChanged,'Wing or tail did not animate')
local mouth=DragonRenderer.mouth(g,0);assert(mouth.y>8 and mouth.y<13,'Projectile mouth origin incorrect')
print('PASS: exact cuboid counts, atlas UVs, outward faces, articulated wings/tail and matching hitboxes')

local clock,handlers,events,threads=0,{},{},{}
local players,buckets={'1','2','3'},{[1]=0,[2]=0,[3]=1}
local coords={[1]=point(),[2]=point(),[3]=point(),[50]=point(0,1,30)}
local entities={[1]=true,[2]=true,[3]=true,[50]=true}
local vehicleOwner,vehicleBucket=2,0
function GetGameTimer() return clock end
function RegisterNetEvent(name,fn) handlers[name]=fn end
function AddEventHandler(name,fn) handlers[name]=fn end
function CreateThread(fn) threads[#threads+1]=fn end
function Wait() coroutine.yield() end
function GetPlayers() return players end
function GetPlayerPed(src) return src end
function GetEntityCoords(e) return coords[e] or point() end
function GetPlayerRoutingBucket(src) return buckets[src] end
function GetPlayerName(src) return 'player'..src end
function IsPlayerAceAllowed() return true end
function DoesEntityExist(entity) return entities[entity] or false end
function GetEntityType(entity) return entity==50 and 2 or 1 end
function GetEntityModel() return 100 end
function GetEntityRoutingBucket() return vehicleBucket end
function NetworkGetEntityOwner() return vehicleOwner end
function NetworkGetEntityFromNetworkId(id) return id==55 and 50 or 0 end
function TriggerClientEvent(name,target,...) events[#events+1]={name=name,target=target,args={...}} end
function TriggerServerEvent(name,...) events[#events+1]={name=name,args={...}} end
local function invoke(name,src,...) source=src;assert(handlers['fivem-enderdragon:'..name],name)(...) end
local function last(name)
    for i=#events,1,-1 do if events[i].name=='fivem-enderdragon:'..name then return events[i] end end
end
local function total(name)
    local n=0;for _,e in ipairs(events) do if e.name=='fivem-enderdragon:'..name then n=n+1 end end;return n
end
dofile('server/main.lua')
local server=coroutine.create(threads[1])
local function tick(ms)
    clock=clock+(ms or 250);local ok,err=coroutine.resume(server);assert(ok,err)
end
tick(0)
invoke('spawn',1,point(0,0,30),0)
local dragon=last('dragon').args[1];local gid=dragon.id
assert(gid and dragon.hp==1200)
for _,e in ipairs(events) do assert(e.target~=3,'Cross-bucket spawn leaked') end
invoke('update',2,{{id=gid,pos=point(1,0,30),heading=0}},{})
invoke('requestSnapshot',2);assert(last('snapshot').args[1][1].pos.x==0,'Non-owner moved dragon')
clock=100;invoke('update',1,{{id=gid,pos=point(80,0,30),heading=0}},{})
clock=1200;invoke('requestSnapshot',2);assert(last('snapshot').args[1][1].pos.x==0,'Teleport accepted')
invoke('warn',2,gid);assert(not last('sound'),'Non-owner warning accepted')
invoke('warn',1,gid);assert(last('sound').args[1]=='warn')
invoke('shoot',1,gid,point(0,10,30),point(0,1,0));assert(not last('projectile'),'Charge fired early')
clock=2100;invoke('shoot',1,gid,point(0,10,30),point(0,1,0))
local pid=last('projectile').args[1].id
assert(pid and last('projectile').args[1].owner==1)
invoke('shoot',1,gid,point(0,10,30),point(0,1,0));assert(total('projectile')==2,'Duplicate projectile')
invoke('impact',2,pid,point(0,10,30));assert(not last('cloud'),'Non-owner impact accepted')
invoke('impact',1,pid,point(0,11,30));assert(last('cloud') and last('impactFx'))
local impacts=total('impactFx');invoke('impact',1,pid,point(0,11,30));assert(total('impactFx')==impacts,'Impact consumed twice')
clock=3300;invoke('requestSnapshot',2);assert(#last('snapshot').args[3]==1,'Late join missing active breath')

-- Networked contact routed to the vehicle owner, one request token, bucket/proximity validation.
invoke('vehicleContact',2,gid,55);assert(not last('explodeVehicle'),'Non-owner contact accepted')
invoke('vehicleContact',1,gid,55)
local request=last('explodeVehicle');assert(request.target==2 and request.args[1]==55)
local token=request.args[3];local reports=total('explodeVehicle')
invoke('vehicleContact',1,gid,55);assert(total('explodeVehicle')==reports,'Duplicate vehicle contact dispatched')
-- Ownership can migrate while collision handling is in flight; retry follows current owner.
vehicleOwner=1;tick(750);assert(last('explodeVehicle').target==1 and last('explodeVehicle').args[3]==token)
invoke('vehicleExploded',3,token);tick(750);assert(total('explodeVehicle')>reports,'Wrong player acknowledged explosion')
invoke('vehicleExploded',1,token);reports=total('explodeVehicle');tick(750);assert(total('explodeVehicle')==reports,'Acknowledged explosion retried')
clock=15000;invoke('update',1,{{id=gid,pos=point(0,0,30),heading=0}},{})
vehicleBucket=1;invoke('vehicleContact',1,gid,55);assert(total('explodeVehicle')==reports,'Cross-bucket vehicle accepted')
vehicleBucket=0;coords[50]=point(100,0,30);invoke('vehicleContact',1,gid,55);assert(total('explodeVehicle')==reports,'Distant vehicle accepted')
coords[50]=point(0,1,30)
invoke('damage',3,gid,'bullet',true);assert(last('dragon').args[1].hp==1200,'Cross-bucket damage accepted')
invoke('damage',2,gid,'bullet',true);assert(last('dragon').args[1].hp==1172,'Headshot multiplier missing')
invoke('damage',2,gid,'bullet',true);assert(last('dragon').args[1].hp==1172,'Damage throttle bypassed')
for i=1,17 do clock=clock+150;invoke('damage',2,gid,'melee',true) end
assert(last('dragon').args[1].hp==0 and last('dragon').args[1].deathRemainingMs,'Death sequence did not start')
reports=total('explodeVehicle');invoke('vehicleContact',1,gid,55);assert(total('explodeVehicle')==reports,'Dead dragon detonated car')
tick(Config.DeathDurationMs);assert(last('removeDragon').args[1]==gid)
print('PASS: server charge/cooldown, ownership, buckets, duplicate consumption, vehicle routing/migration and death')

-- Actual owner fireball holds pending sweeps; booleans and invalidated trace handles are respected.
local probeSerial,probes=0,{}
function StartShapeTestSweptSphere(...)
    probeSerial=probeSerial+1;probes[probeSerial]={status=1,hit=false,point=point()};return probeSerial
end
function GetShapeTestResult(handle)
    local p=assert(probes[handle],'Completed trace queried twice')
    if p.status~=1 then probes[handle]=nil end
    return p.status,p.hit,p.point,point(0,0,1),p.entity or 0
end
function RequestCollisionAtCoord() end
function GetGroundZFor_3dCoord() return true,0 end
dofile('client/fireball.lua')
local p={id='test',pos=point(0,0,10),direction=point(0,1,0),entity=88,born=clock}
DragonFireball.update(p,.05,clock)
local handle=p.probe;DragonFireball.update(p,.05,clock+50);close(p.pos.y,0)
probes[handle].status=2;DragonFireball.update(p,.05,clock+100);close(p.pos.y,.7)
probes[p.probe]={status=2,hit=true,point=point(0,1,10)}
DragonFireball.update(p,.05,clock+150);assert(p.ending and last('impact').args[1]=='test')
local impactCount=total('impact');DragonFireball.update(p,.05,clock+200);assert(total('impact')==impactCount)
print('PASS: moving entity fireball, unresolved sweeps, visible hits and exactly one impact request')

-- Real flight movement circles, enters a swoop, respects ground/world collision and recovers.
DragonTargeting={aim=function() return point(0,30,0) end}
dofile('client/movement.lua')
local flyer={id='f',pos=point(0,0,30),origin=point(0,0,30),heading=0,born=clock,entity=99,target=2}
DragonMovement.update(flyer,.05,clock);assert(flyer.moveProbe and flyer.flightMode=='circle')
local previous=M.coords(flyer.pos);handle=flyer.moveProbe
DragonMovement.update(flyer,.05,clock+50);close(M.distance(previous,flyer.pos),0)
probes[handle].status=2;DragonMovement.update(flyer,.05,clock+100);assert(M.distance(previous,flyer.pos)>0)
probes[flyer.moveProbe].status=2;DragonMovement.update(flyer,.05,clock+5000);assert(flyer.flightMode=='swoop')
probes[flyer.moveProbe]={status=2,hit=true,point=point()}
DragonMovement.update(flyer,.05,clock+5050);assert(flyer.flightMode=='recover','Blocked flight failed to recover')

-- Vehicle contact from a wing, including intermediate animation, with no phantom distant contact.
local carPosition,hasControl,networked=point(),true,true
entities[50]=true
function GetModelDimensions() return point(-1,-2,-.5),point(1,2,.5) end
function GetEntityMatrix() return point(0,1,0),point(1,0,0),point(0,0,1),carPosition end
function GetEntityCoords(e) return e==50 and carPosition or point() end
function GetGamePool(pool) return pool=='CVehicle' and {50} or {} end
function IsEntityAVehicle(e) return e==50 end
function IsEntityDead() return false end
function NetworkGetEntityIsNetworked() return networked end
function NetworkHasControlOfEntity() return hasControl end
function NetworkGetNetworkIdFromEntity() return 55 end
function NetworkDoesEntityExistWithNetworkId() return true end
function GetPlayerServerId(player) return player end
function PlayerId() return 1 end
function PlayerPedId() return 1 end
function NetworkRequestControlOfEntity() end
function SetEntityInvincible() end
function SetEntityProofs() end
function SetVehicleCanBreak() end
function SetVehicleEngineHealth() end
function SetVehiclePetrolTankHealth() end
local explosions=0
function NetworkExplodeVehicle(e,a,b,c) assert(e==50 and a==true and b==false and c==false);explosions=explosions+1 end
function ExplodeVehicle() explosions=explosions+1 end
dofile('client/vehicles.lua')
g={id='contact',pos=point(),heading=0,flapPhase=0,poseTime=clock,pitch=0,bank=0}
for _,b in ipairs(DragonRenderer.boxes(g,clock)) do if b.part=='left_wing_tip' then carPosition=M.coords(b.center);break end end
assert(M.distance(g.pos,carPosition)>4,'Wing contact test accidentally uses the body')
local contactBefore=total('vehicleContact');DragonVehicles.scan(g,clock)
assert(total('vehicleContact')==contactBefore+1,'Animated wing failed to contact vehicle')
clock=clock+100;DragonVehicles.scan(g,clock);assert(total('vehicleContact')==contactBefore+1,'Repeated contact report')
DragonVehicles.enqueue(55,100,'vtest');hasControl=false;DragonVehicles.update(clock);assert(explosions==0,'Non-controller exploded vehicle')
hasControl=true;DragonVehicles.update(clock+100);assert(explosions==1)
DragonVehicles.enqueue(55,100,'vtest');DragonVehicles.update(clock+200);assert(explosions==1,'Duplicate vehicle explosion')
DragonVehicles.cleanup();carPosition=point(35,0,0);g.nextVehicleScan=0;DragonVehicles.scan(g,clock+300)
assert(total('vehicleContact')==contactBefore+1,'Nearby non-contact vehicle exploded')
networked=false;carPosition=point();g.nextVehicleScan=0;DragonVehicles.scan(g,clock+400);assert(explosions==2,'Local vehicle failed to explode')
print('PASS: body/wing SAT contact, vehicle control, remote acknowledgement, deduplication and local explosions')

-- Run actual target selection and attack state machine with native LOS probes.
local targetPositions={[1]=point(200,0,0),[2]=point(20,40,0),[3]=point(0,20,0)}
local blocked=false
function GetEntityCoords(e) return targetPositions[e] or point() end
function GetGamePool(pool) return pool=='CPed' and {1,2,3} or {} end
function IsPedAPlayer(e) return e==1 or e==2 end
function IsPedInAnyVehicle() return false end
function StartExpensiveSynchronousShapeTestLosProbe(ax,ay,az,bx,by,bz)
    probeSerial=probeSerial+1;probes[probeSerial]={status=2,hit=blocked and bx==20,point=point(bx,by,bz),entity=999}
    return probeSerial
end
dofile('client/targeting.lua')
local hunter={id='hunter',pos=point(0,0,10),origin=point(0,0,10),heading=0,entity=99,born=clock,
    nextAmbient=clock+99999,nextScan=0,pitch=0,bank=0,flapPhase=0,poseTime=clock}
assert(DragonTargeting.find(hunter)==2,'Visible player preference missing')
blocked=true;assert(DragonTargeting.find(hunter)==3,'LOS-blocked player was targeted')
local movementModule,vehicleModule=DragonMovement,DragonVehicles
DragonMovement={update=function() end};DragonVehicles={scan=function() end}
DragonAudio={cancel=function() end}
dofile('client/dragon.lua')
local shootBefore=total('shoot');DragonEntity.update(hunter,.05,clock)
assert(hunter.target==3 and hunter.charging,'Visible NPC did not trigger warning')
DragonEntity.update(hunter,.05,clock+Config.ChargeMs-1);assert(total('shoot')==shootBefore,'Client charge fired early')
DragonEntity.update(hunter,.05,clock+Config.ChargeMs);assert(total('shoot')==shootBefore+1,'Client did not fire')
assert(not hunter.charging and hunter.nextAttack==clock+Config.ChargeMs+Config.AttackCooldownMs)
DragonEntity.update(hunter,.05,clock+Config.ChargeMs+100);assert(total('shoot')==shootBefore+1,'Client cooldown ignored')
blocked=false;hunter.target=2;hunter.nextScan=clock+999999;hunter.nextAttack=0
DragonEntity.update(hunter,.05,clock+1000);assert(hunter.charging)
blocked=true;DragonEntity.update(hunter,.05,clock+1000+Config.ChargeMs)
assert(total('shoot')==shootBefore+1 and not hunter.charging,'Launch LOS not rechecked')
DragonMovement,DragonVehicles=movementModule,vehicleModule
print('PASS: real targeting, visible player preference, NPC fallback, charge timing, cooldown and launch LOS')

-- Client coordinator actually boots and renders a replica, interpolates poses and cleans all anchors.
threads={};local deleted=0;local entitySerial=100
function GetHashKey() return 1 end
function RegisterCommand() end
function IsModelInCdimage() return true end
function IsModelValid() return true end
function RequestModel() end
function HasModelLoaded() return true end
function GetGameplayCamCoord() return point() end
function GetGameplayCamRot() return point() end
function IsPedShooting() return false end
function IsPedPerformingMeleeAction() return false end
function CreateObjectNoOffset() entitySerial=entitySerial+1;entities[entitySerial]=true;return entitySerial end
function SetEntityAsMissionEntity() end
function SetEntityVisible() end
function SetEntityAlpha() end
function SetEntityCollision() end
function FreezeEntityPosition() end
function SetEntityCoordsNoOffset() end
function SetEntityHeading() end
function DeleteEntity(e) deleted=deleted+1;entities[e]=nil end
function GetCurrentResourceName() return 'fivem-enderdragon' end
function SendNUIMessage() end
function SetModelAsNoLongerNeeded() end
function DrawLightWithRange() end
DragonAudio={play=function() end,cancel=function() end,listener=function() end}
DragonEntity={playerCombat=function() end,update=function() end}
dofile('client/main.lua')
local loop=coroutine.create(threads[1]);local ok,err=coroutine.resume(loop);assert(ok,err)
local replica={id='remote',owner=2,pos=point(),origin=point(),heading=350,hp=100,pitch=0,bank=0,flapPhase=0}
handlers['fivem-enderdragon:dragon'](replica);assert(DragonWorld.dragons.remote.entity==101)
replica.pos=point(2,0,0);replica.heading=10;replica.bank=10
handlers['fivem-enderdragon:state']({replica},{})
clock=clock+50;ok,err=coroutine.resume(loop);assert(ok,err)
close(DragonWorld.dragons.remote.pos.x,1);close(DragonWorld.dragons.remote.heading,0);close(DragonWorld.dragons.remote.bank,5)
handlers['fivem-enderdragon:snapshot']({},{},{});assert(not next(DragonWorld.dragons) and deleted==1)
handlers.onResourceStop('fivem-enderdragon')

-- Lingering breath damages only our player / controlled NPCs; cover and range remain effective.
local positions={[1]=point(1,0,0),[2]=point(2,0,0),[3]=point(1,0,0),[4]=point(20,0,0)}
function GetEntityCoords(e) return positions[e] or point() end
function GetGamePool(pool) return pool=='CPed' and {1,2,3,4} or {} end
function IsEntityAPed(e) return e<5 end
function IsPedAPlayer(e) return e==1 or e==3 end
function NetworkGetEntityIsNetworked() return true end
function NetworkHasControlOfEntity() return true end
local hurt={}
function ApplyDamageToPed(e,damage) hurt[e]=(hurt[e] or 0)+damage end
DragonTargeting.ray=function(_,ending) return true,ending.x==2,ending,ending.x==2 and 99 or 0 end
DragonFireball.cloud({id='cloud',pos=point(),remainingMs=1000})
DragonFireball.clouds(clock,false);assert(hurt[1]==9 and not hurt[2] and not hurt[3] and not hurt[4])
DragonFireball.clouds(clock+100,false);assert(hurt[1]==9,'Breath tick fired early')
DragonFireball.clouds(clock+500,false);assert(hurt[1]==18)
DragonFireball.clouds(clock+1100,false);assert(not next(DragonWorld.clouds))
local fx=0
Citizen={InvokeNative=function(hash,...)
    local a={...};assert(hash==0xE3AD2BDBAEE269AC and #a==9 and a[9]==true);fx=fx+1
end}
DragonFireball.impact(point(),2);assert(fx==0)
DragonFireball.impact(point(),1);assert(fx==1)
print('PASS: actual client boot, replica interpolation, cleanup, cover-aware breath ticks and one impact FX owner')

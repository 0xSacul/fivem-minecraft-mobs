CreeperExplosion = {}
local E, M = CreeperExplosion, CreeperMath
local function damage(entity,position)
    if M.distance(M.coords(GetEntityCoords(entity)),position) > Config.Explosion.Radius+1 then return end
    local aim = M.add(M.coords(GetEntityCoords(entity)),{x=0,y=0,z=IsEntityAPed(entity) and 0.8 or 0.4})
    local distance = M.distance(aim,position)
    if distance >= Config.Explosion.Radius then return end
    local valid,hit,_,_,blocker = CreeperTargeting.ray(position,aim,0)
    if not valid or (hit and blocker ~= entity) then return end
    local amount = math.floor(Config.Explosion.Damage*(1-distance/Config.Explosion.Radius))
    if amount <= 0 then return end
    if IsEntityAPed(entity) then ApplyDamageToPed(entity,amount,false)
    elseif IsEntityAVehicle(entity) then
        SetVehicleEngineHealth(entity,GetVehicleEngineHealth(entity)-amount*8)
        SetVehicleBodyHealth(entity,GetVehicleBodyHealth(entity)-amount*4)
    elseif IsEntityAnObject(entity) then SetEntityHealth(entity,math.max(0,GetEntityHealth(entity)-amount)) end
end
function E.detonate(position,owner)
    if owner == GetPlayerServerId(PlayerId()) then
        -- VFX only, original Minecraft explosion audio plays separately. Preserve ninth noDamage argument.
        Citizen.InvokeNative(0xE3AD2BDBAEE269AC,position.x,position.y,position.z,
                             Config.Explosion.Type,0.0,false,false,Config.Explosion.CameraShake,true)
    end
    local ped = PlayerPedId()
    if not IsEntityDead(ped) then damage(ped,position) end
    local anchors = {}
    for _, c in pairs(CreeperWorld.creepers) do anchors[c.entity]=true end
    for _, pool in ipairs({'CPed','CVehicle','CObject'}) do
        for _, entity in ipairs(GetGamePool(pool)) do
            if entity ~= ped and not anchors[entity] and not IsEntityDead(entity)
               and not (IsEntityAPed(entity) and IsPedAPlayer(entity))
               and (not NetworkGetEntityIsNetworked(entity) or NetworkHasControlOfEntity(entity)) then damage(entity,position) end
        end
    end
end

DragonRenderer = {}
local R,M=DragonRenderer,DragonMath
local unpack=table.unpack or unpack
local dict='minecraft_enderdragon_runtime'
local poly=DrawTexturedPoly or DrawSpritePoly
local faces={
    {{6,5,1,2},'top',255},{{3,4,8,7},'bottom',195},{{1,5,8,4},'left',225},
    {{2,1,4,3},'front',255},{{6,2,3,7},'right',235},{{5,6,7,8},'back',215}
}
function R.init()
    local txd=CreateRuntimeTxd(dict)
    for _,name in ipairs({'dragon','dragon_hurt','dragon_eyes','dragon_exploding','dragon_fireball'}) do
        assert(CreateRuntimeTextureFromImage(txd,name,'assets/runtime/'..name..'.png'),'Dragon texture failed: '..name)
    end
end
local function triangle(a,b,c,texture,ua,ub,uc,tint,alpha)
    local call=poly or function(...) Citizen.InvokeNative(0x29280002282F1928,...) end
    call(a.x,a.y,a.z,b.x,b.y,b.z,c.x,c.y,c.z,tint,tint,tint,alpha or 255,dict,texture,
        ua[1],ua[2],1.0,ub[1],ub[2],1.0,uc[1],uc[2],1.0)
end
local function drawQuad(face,texture,alpha)
    local v,u=face.vertices,face.uv
    triangle(v[1],v[2],v[3],texture,u[1],u[2],u[3],face.tint,alpha)
    triangle(v[1],v[3],v[4],texture,u[1],u[3],u[4],face.tint,alpha)
end
function R.phase(g,now) return (g.flapPhase or 0)+((now-(g.poseTime or now))/1000)*Config.Flight.FlapsPerSecond*math.pi*2 end
-- Exact builder hierarchy; posing is procedural and remains separate from gameplay.
function R.pose(g,now)
    local phase=R.phase(g,now)
    local overrides={}
    local turn=math.rad(g.turn or 0)*0.5
    local headYaw=math.rad(g.headYaw or 0)
    local current={x=0,y=20,z=-12}
    for i=0,4 do
        local angle=headYaw*(i+1)/5+turn*0.2
        local rotation={0.035*math.sin(phase+i*.45),angle,0}
        overrides['neck'..i]={pivot={current.x,current.y,current.z},rotation=rotation}
        current=M.add(current,M.rotate({x=0,y=0,z=-10},rotation))
    end
    overrides.head={pivot={current.x,current.y,current.z},rotation={math.rad(g.headPitch or 0),headYaw,0}}
    overrides.jaw={rotation={(g.charging and .5 or .12)+(.08*math.sin(phase)) ,0,0}}
    current={x=0,y=10,z=60}
    for i=0,11 do
        local rotation={.045*math.sin(phase*.7+i*.35),-turn*(i+1)/12+.10*math.sin(phase*.6-i*.32),0}
        overrides['tail'..i]={pivot={current.x,current.y,current.z},rotation=rotation}
        current=M.add(current,M.rotate({x=0,y=0,z=10},rotation))
    end
    -- Original wing motion coefficients, mirrored at the shoulders and elbows.
    local pitch=.125-.2*math.cos(phase)
    local roll=-(math.sin(phase)+.125)*.8
    local tip=(math.sin(phase+2)+.5)*.75
    overrides.left_wing={rotation={pitch,-.25,-roll}}
    overrides.right_wing={rotation={pitch,.25,roll}}
    overrides.left_wing_tip={rotation={0,0,-tip}}
    overrides.right_wing_tip={rotation={0,0,tip}}
    local bob=.06*math.sin(phase)
    for _,side in ipairs({'left','right'}) do
        overrides[side..'_front_leg']={rotation={1.3+bob,0,0}}
        overrides[side..'_hind_leg']={rotation={1+bob,0,0}}
    end
    return overrides
end
-- Return world vertices and matching OBBs for rendering, shooting and vehicle contact.
function R.geometry(g,now,wantFaces)
    local pose=R.pose(g,now)
    local result,boxes={},{}
    local rootRotation={-math.rad(g.pitch or 0),0,math.rad(g.bank or 0)}
    local cosH,sinH=math.cos(math.rad(g.heading)),math.sin(math.rad(g.heading))
    local function world(v)
        v=M.rotate(M.sub(v,{x=0,y=16,z=24}),rootRotation)
        local x,y,z=v.x*Config.ModelScale,-v.z*Config.ModelScale,-v.y*Config.ModelScale
        return {x=g.pos.x+x*cosH-y*sinH,y=g.pos.y+x*sinH+y*cosH,z=g.pos.z+z}
    end
    local function visit(part,parent)
        local override=pose[part.name] or {}
        local pivot,rotation=override.pivot or part.pivot,override.rotation or part.rotation
        local function transform(v)
            v=M.rotate(v,rotation)
            return parent(M.add(v,{x=pivot[1],y=pivot[2],z=pivot[3]}))
        end
        for _,cube in ipairs(part.cubes) do
            local x,y,z,dx,dy,dz=unpack(cube.box)
            local function vertex(a,b,c) return world(transform({x=a,y=b,z=c})) end
            local center=vertex(x+dx/2,y+dy/2,z+dz/2)
            local axes={M.normalize(M.sub(vertex(x+dx/2+1,y+dy/2,z+dz/2),center)),
                M.normalize(M.sub(vertex(x+dx/2,y+dy/2+1,z+dz/2),center)),
                M.normalize(M.sub(vertex(x+dx/2,y+dy/2,z+dz/2+1),center))}
            boxes[#boxes+1]={center=center,axes=axes,half={dx*Config.ModelScale/2,math.max(.06,dy*Config.ModelScale/2),dz*Config.ModelScale/2},part=part.name}
            if wantFaces then
                -- Java mirrored cubes swap X endpoints before constructing polygons.
                local x1,x2=x,x+dx
                if cube.mirror then x1,x2=x2,x1 end
                local v={vertex(x1,y,z),vertex(x2,y,z),vertex(x2,y+dy,z),vertex(x1,y+dy,z),
                    vertex(x1,y,z+dz),vertex(x2,y,z+dz),vertex(x2,y+dy,z+dz),vertex(x1,y+dy,z+dz)}
                local rect={top={dz,0,dz+dx,dz},bottom={dz+dx,dz,dz+dx+dx,0},left={0,dz,dz,dz+dy},
                    front={dz,dz,dz+dx,dz+dy},right={dz+dx,dz,dz+dx+dz,dz+dy},back={dz+dx+dz,dz,dz+dx+dz+dx,dz+dy}}
                for _,face in ipairs(faces) do
                    if dy~=0 or face[2]=='top' then
                        local t,order=rect[face[2]],face[1]
                        local u,w=cube.uv[1],cube.uv[2]
                        local uv={{(u+t[3])/256,(w+t[2])/256},{(u+t[1])/256,(w+t[2])/256},
                            {(u+t[1])/256,(w+t[4])/256},{(u+t[3])/256,(w+t[4])/256}}
                        local vertices={v[order[4]],v[order[3]],v[order[2]],v[order[1]]}
                        uv={uv[4],uv[3],uv[2],uv[1]}
                        if cube.mirror then vertices={vertices[4],vertices[3],vertices[2],vertices[1]};uv={uv[4],uv[3],uv[2],uv[1]} end
                        result[#result+1]={vertices=vertices,uv=uv,tint=face[3],part=part.name}
                        if dy==0 then
                            -- The wing uses a single atlas patch. Reuse it for the underside;
                            -- the cube-net opposite face falls in the atlas's transparent area.
                            result[#result+1]={vertices={vertices[4],vertices[3],vertices[2],vertices[1]},
                                uv={uv[4],uv[3],uv[2],uv[1]},tint=face[3],part=part.name}
                        end
                    end
                end
            end
        end
        for _,child in ipairs(part.children) do visit(child,transform) end
    end
    visit(DragonModel.root,function(v) return v end)
    return result,boxes
end
function R.mesh(g,now) local mesh=R.geometry(g,now,true);return mesh end
function R.boxes(g,now) local _,boxes=R.geometry(g,now,false);return boxes end
function R.mouth(g,now)
    for _,box in ipairs(R.boxes(g,now)) do
        if box.part=='head' then return M.sub(box.center,M.mul(box.axes[3],box.half[3]+.3)) end
    end
    return M.add(g.pos,M.mul(M.forward(g.heading),8))
end
function R.draw(g,now)
    local dying=g.deathAt~=nil
    local alpha=dying and math.floor(255*M.clamp(1-(now-g.deathAt)/Config.DeathDurationMs,0,1)) or 255
    local texture=dying and 'dragon_exploding' or (now<(g.hurtUntil or 0) and 'dragon_hurt' or 'dragon')
    for _,face in ipairs(R.mesh(g,now)) do
        drawQuad(face,texture,alpha)
        if face.part=='head' and not dying then
            -- Offset the original transparent eye layer slightly to avoid depth fighting.
            local normal=M.normalize(M.cross(M.sub(face.vertices[2],face.vertices[1]),M.sub(face.vertices[3],face.vertices[1])))
            local eye={vertices={},uv=face.uv,tint=255}
            for i,v in ipairs(face.vertices) do eye.vertices[i]=M.add(v,M.mul(normal,.006)) end
            drawQuad(eye,'dragon_eyes')
        end
    end
end
function R.sprite(position,size,texture,alpha)
    local cam=GetGameplayCamRot(2)
    local yaw=math.rad(cam.z)
    local right={x=math.cos(yaw),y=math.sin(yaw),z=0}
    local up=M.cross(right,M.cameraDirection(cam))
    local v={}
    for i,c in ipairs({{-1,1},{1,1},{1,-1},{-1,-1}}) do v[i]=M.add(position,M.add(M.mul(right,size*c[1]/2),M.mul(up,size*c[2]/2))) end
    local face={vertices=v,uv={{0,0},{1,0},{1,1},{0,1}},tint=255}
    drawQuad(face,texture,alpha)
    drawQuad({vertices={v[4],v[3],v[2],v[1]},uv={face.uv[4],face.uv[3],face.uv[2],face.uv[1]},tint=255},texture,alpha)
end
function R.fireball(p) R.sprite(p.pos,Config.Fireball.SpriteSize,'dragon_fireball',255);DrawLightWithRange(p.pos.x,p.pos.y,p.pos.z,160,40,210,5,1) end
function R.debug(g,now)
    local edges={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
    for _,box in ipairs(R.boxes(g,now)) do
        local vertices={}
        for i,s in ipairs({{-1,-1,-1},{1,-1,-1},{1,1,-1},{-1,1,-1},{-1,-1,1},{1,-1,1},{1,1,1},{-1,1,1}}) do
            local v=box.center
            for axis=1,3 do v=M.add(v,M.mul(box.axes[axis],box.half[axis]*s[axis])) end
            vertices[i]=v
        end
        for _,edge in ipairs(edges) do
            local a,b=vertices[edge[1]],vertices[edge[2]]
            DrawLine(a.x,a.y,a.z,b.x,b.y,b.z,255,150,45,180)
        end
    end
end

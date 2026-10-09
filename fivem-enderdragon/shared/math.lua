DragonMath = {}
local M = DragonMath
function M.coords(v) return { x=v.x, y=v.y, z=v.z } end
function M.add(a,b) return {x=a.x+b.x,y=a.y+b.y,z=a.z+b.z} end
function M.sub(a,b) return {x=a.x-b.x,y=a.y-b.y,z=a.z-b.z} end
function M.mul(a,t) return {x=a.x*t,y=a.y*t,z=a.z*t} end
function M.dot(a,b) return a.x*b.x+a.y*b.y+a.z*b.z end
function M.cross(a,b) return {x=a.y*b.z-a.z*b.y,y=a.z*b.x-a.x*b.z,z=a.x*b.y-a.y*b.x} end
function M.length(a) return math.sqrt(M.dot(a,a)) end
function M.distance(a,b) return M.length(M.sub(a,b)) end
function M.normalize(a) local n=M.length(a);if n<1e-8 then return {x=0,y=0,z=0} end;return M.mul(a,1/n) end
function M.lerp(a,b,t) return M.add(a,M.mul(M.sub(b,a),t)) end
function M.clamp(v,a,b) return math.max(a,math.min(b,v)) end
function M.finite(v) return type(v)=='number' and v==v and math.abs(v)<1000000 end
function M.valid(v) return type(v)=='table' and M.finite(v.x) and M.finite(v.y) and M.finite(v.z) end
function M.hit(v) return v==true or v==1 end
function M.heading(a,b) local d=M.sub(b,a);return math.deg(math.atan(-d.x,d.y))%360 end
function M.angleDelta(a,b) return (b-a+180)%360-180 end
function M.forward(h) h=math.rad(h);return {x=-math.sin(h),y=math.cos(h),z=0} end
function M.cameraDirection(r)
    local p,h=math.rad(r.x),math.rad(r.z)
    return {x=-math.sin(h)*math.cos(p),y=math.cos(h)*math.cos(p),z=math.sin(p)}
end
-- Minecraft ModelPart rotation order: Z * Y * X, applied to column vectors.
function M.rotate(v,r)
    local x,y,z=v.x,v.y,v.z
    y,z=y*math.cos(r[1])-z*math.sin(r[1]),y*math.sin(r[1])+z*math.cos(r[1])
    x,z=x*math.cos(r[2])+z*math.sin(r[2]),-x*math.sin(r[2])+z*math.cos(r[2])
    x,y=x*math.cos(r[3])-y*math.sin(r[3]),x*math.sin(r[3])+y*math.cos(r[3])
    return {x=x,y=y,z=z}
end
function M.segmentBox(a,b,box,padding)
    local delta,origin=M.sub(b,a),M.sub(a,box.center)
    local enter,leave=0,1
    for i=1,3 do
        local p,d,h=M.dot(origin,box.axes[i]),M.dot(delta,box.axes[i]),box.half[i]+(padding or 0)
        if math.abs(d)<1e-8 then if p < -h or p > h then return nil end
        else
            local t1,t2=(-h-p)/d,(h-p)/d
            if t1>t2 then t1,t2=t2,t1 end
            enter,leave=math.max(enter,t1),math.min(leave,t2)
            if enter>leave then return nil end
        end
    end
    return enter
end
-- Separating-axis test for two oriented boxes, including flat wing membranes.
function M.boxOverlap(a,b,padding)
    local delta=M.sub(b.center,a.center)
    local axes={a.axes[1],a.axes[2],a.axes[3],b.axes[1],b.axes[2],b.axes[3]}
    for i=1,3 do for j=1,3 do axes[#axes+1]=M.cross(a.axes[i],b.axes[j]) end end
    for _,axis in ipairs(axes) do
        if M.dot(axis,axis)>1e-10 then
            local extent=0
            for i=1,3 do extent=extent+a.half[i]*math.abs(M.dot(a.axes[i],axis))+b.half[i]*math.abs(M.dot(b.axes[i],axis)) end
            if math.abs(M.dot(delta,axis))>extent+(padding or 0)*M.length(axis) then return false end
        end
    end
    return true
end

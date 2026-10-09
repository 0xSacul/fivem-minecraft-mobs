"""OBJ and CPU preview of the actual Lua render mesh; no modelling installation needed."""
import json
import os
from pathlib import Path
import sys
sys.dont_write_bytecode=True
import numpy as np
from PIL import Image
from lua_runtime import Lua
ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'assets/reference'


def mesh(phase):
    lua=Lua()
    try:
        for p in ['shared/config.lua','shared/math.lua','shared/model.lua','client/renderer.lua']:
            lua.load((ROOT/p).read_bytes(),p,True)
        lua.load('''
            local faces=DragonRenderer.mesh({pos={x=0,y=0,z=0},heading=0,flapPhase=PHASE,poseTime=0},0)
            local output={}
            for _,f in ipairs(faces) do
                local vertices,uv={},{}
                for _,v in ipairs(f.vertices) do vertices[#vertices+1]=string.format('[%.9f,%.9f,%.9f]',v.x,v.y,v.z) end
                for _,v in ipairs(f.uv) do uv[#uv+1]=string.format('[%.9f,%.9f]',v[1],v[2]) end
                output[#output+1]='{"part":"'..f.part..'","tint":'..f.tint..',"vertices":['..table.concat(vertices,',')..'],"uv":['..table.concat(uv,',')..']}'
            end
            GeometryJson='['..table.concat(output,',')..']'
        '''.replace('PHASE',str(phase)),'export renderer mesh',True)
        return json.loads(lua.global_string('GeometryJson'))
    finally:lua.close()


def render(faces):
    width,height=1000,720
    image=np.full((height,width,3),[117,131,124],dtype=np.uint8)
    depth=np.full((height,width),np.inf)
    camera=np.array([24.,37.,22.]);target=np.array([0.,-2.,0.])
    forward=target-camera;forward/=np.linalg.norm(forward)
    right=np.cross(forward,[0,0,1]);right/=np.linalg.norm(right);up=np.cross(right,forward)
    texture=np.array(Image.open(ROOT/'assets/textures/dragon.png').convert('RGBA'))
    for face in faces:
        vertices,uv=np.array(face['vertices']),np.array(face['uv'])
        normal=np.cross(vertices[1]-vertices[0],vertices[2]-vertices[0])
        if np.dot(normal,camera-vertices[0])<=0:continue
        delta=vertices-target
        screen=np.column_stack((width/2+delta@right*28,height/2-delta@up*28,(vertices-camera)@forward))
        for ids in [[0,1,2],[0,2,3]]:
            p=screen[ids];coords=uv[ids]
            x0,y0=np.maximum([0,0],np.floor(p[:,:2].min(axis=0))).astype(int)
            x1,y1=np.minimum([width-1,height-1],np.ceil(p[:,:2].max(axis=0))).astype(int)
            if x1<x0 or y1<y0:continue
            yy,xx=np.mgrid[y0:y1+1,x0:x1+1]
            divisor=(p[1,1]-p[2,1])*(p[0,0]-p[2,0])+(p[2,0]-p[1,0])*(p[0,1]-p[2,1])
            if abs(divisor)<1e-8:continue
            a=((p[1,1]-p[2,1])*(xx-p[2,0])+(p[2,0]-p[1,0])*(yy-p[2,1]))/divisor
            b=((p[2,1]-p[0,1])*(xx-p[2,0])+(p[0,0]-p[2,0])*(yy-p[2,1]))/divisor;c=1-a-b
            z=a*p[0,2]+b*p[1,2]+c*p[2,2];region=depth[y0:y1+1,x0:x1+1]
            sample=a[:,:,None]*coords[0]+b[:,:,None]*coords[1]+c[:,:,None]*coords[2]
            tx=np.clip((sample[:,:,0]*texture.shape[1]).astype(int),0,texture.shape[1]-1)
            ty=np.clip((sample[:,:,1]*texture.shape[0]).astype(int),0,texture.shape[0]-1)
            tex=texture[ty,tx]
            visible=(a>=0)&(b>=0)&(c>=0)&(z<region)&(tex[:,:,3]>128)
            image[y0:y1+1,x0:x1+1][visible]=(tex[:,:,:3].astype(np.float32)*face['tint']/255).astype(np.uint8)[visible]
            region[visible]=z[visible]
    return Image.fromarray(image)


def main():
    os.chdir(ROOT);faces=mesh(0)
    details={'source':'Installed 26.3 EnderDragonModel.class createBodyLayer; shared/model.lua',
        'mesh_function':'client/renderer.lua DragonRenderer.mesh','model_scale':.1,
        'neck_segments':5,'tail_segments':12,'texture_atlas':[256,256],
        'preview':'CPU reference render, not a FiveM screenshot','faces':faces}
    (OUTPUT/'geometry.json').write_text(json.dumps(details,indent=2)+'\n')
    obj=['# Actual Lua renderer mesh, posed at phase zero','mtllib dragon.mtl','usemtl dragon']
    for i,f in enumerate(faces):
        obj+=['v '+' '.join(f'{x:.9f}' for x in v) for v in f['vertices']]
        obj+=[f'vt {u:.9f} {1-v:.9f}' for u,v in f['uv']]
        obj+=['f '+' '.join(f'{i*4+j+1}/{i*4+j+1}' for j in range(4))]
    (OUTPUT/'dragon.obj').write_text('\n'.join(obj)+'\n')
    (OUTPUT/'dragon.mtl').write_text('newmtl dragon\nKd 1 1 1\nmap_Kd ../textures/dragon.png\nmap_d ../textures/dragon.png\n')
    render(faces).save(OUTPUT/'geometry-preview.png')
    frames=[render(mesh(i*np.pi/4)) for i in range(8)]
    frames[0].save(OUTPUT/'wing-animation.gif',save_all=True,append_images=frames[1:],duration=180,loop=0)
    print(f'Generated {len(faces)} quads, OBJ, reference image and wing animation from actual Lua mesh.')


if __name__=='__main__':main()

"""OBJ and CPU preview from the actual Lua mesh function; not a GTA model or game screenshot."""
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


def main():
    os.chdir(ROOT)
    lua=Lua()
    try:
        for path in ['shared/config.lua','shared/math.lua','shared/model.lua','client/renderer.lua']:
            lua.load((ROOT/path).read_bytes(),path,True)
        lua.load('''
            local mesh=CreeperRenderer.mesh({pos={x=0,y=0,z=0},heading=0,fuseRatio=0,walkPhase=0,walkAmount=0},0)
            local faces={}
            for _,face in ipairs(mesh) do
                local vertices,uv={},{}
                for _,v in ipairs(face.vertices) do vertices[#vertices+1]=string.format('[%.9f,%.9f,%.9f]',v.x,v.y,v.z) end
                for _,v in ipairs(face.uv) do uv[#uv+1]=string.format('[%.9f,%.9f]',v[1],v[2]) end
                faces[#faces+1]='{"part":"'..face.part..'","tint":'..face.tint..
                    ',"vertices":['..table.concat(vertices,',')..'],"uv":['..table.concat(uv,',')..']}'
            end
            GeometryJson='['..table.concat(faces,',')..']'
        ''','export actual renderer geometry',True)
        faces=json.loads(lua.global_string('GeometryJson'))
    finally: lua.close()
    OUTPUT.mkdir(parents=True,exist_ok=True)
    details={'source':'Local 26.3 CreeperModel.class and ModelPart$Cube.class, reconstructed in shared/model.lua',
             'mesh_function':'client/renderer.lua CreeperRenderer.mesh','height_m':1.625,'model_scale':1/16,
             'parts':6,'leg_animation':'cos(walkAnimationPos * 0.6662 + phase) * 1.4 * walkAnimationSpeed',
             'fuse_ticks':30,'initial_prime_m':3,'continue_prime_m':7,
             'preview':'CPU reference render, not a FiveM screenshot','faces':faces}
    (OUTPUT/'geometry.json').write_text(json.dumps(details,indent=2)+'\n',encoding='utf-8')
    obj=['# Reconstructed from the actual Lua renderer; static neutral pose','mtllib creeper.mtl','usemtl creeper']
    for index,face in enumerate(faces):
        obj += ['v '+' '.join(f'{v:.9f}' for v in vertex) for vertex in face['vertices']]
        obj += [f'vt {u:.9f} {1-v:.9f}' for u,v in face['uv']]
        obj += ['f '+' '.join(f'{index*4+j+1}/{index*4+j+1}' for j in range(4))]
    (OUTPUT/'creeper.obj').write_text('\n'.join(obj)+'\n',encoding='utf-8')
    (OUTPUT/'creeper.mtl').write_text('newmtl creeper\nKd 1 1 1\nKa 1 1 1\nmap_Kd ../textures/creeper.png\n',encoding='utf-8')
    width,height=800,800
    image=np.full((height,width,3),[36,39,37],dtype=np.uint8)
    depth=np.full((height,width),np.inf)
    camera=np.array([2.2,4.8,3.0]);target=np.array([0.,0.,.8])
    forward=target-camera;forward/=np.linalg.norm(forward)
    right=np.cross(forward,[0,0,1]);right/=np.linalg.norm(right);up=np.cross(right,forward)
    texture=np.array(Image.open(ROOT/'assets/textures/creeper.png').convert('RGB'))
    for face in faces:
        vertices,uv=np.array(face['vertices']),np.array(face['uv'])
        normal=np.cross(vertices[1]-vertices[0],vertices[2]-vertices[0])
        if np.dot(normal,camera-vertices[0])<=0: continue
        delta=vertices-target
        screen=np.column_stack((width/2+delta@right*360,height/2-delta@up*360,(vertices-camera)@forward))
        for ids in [[0,1,2],[0,2,3]]:
            p=screen[ids];coords=uv[ids]
            x0,y0=np.maximum([0,0],np.floor(p[:,:2].min(axis=0))).astype(int)
            x1,y1=np.minimum([width-1,height-1],np.ceil(p[:,:2].max(axis=0))).astype(int)
            yy,xx=np.mgrid[y0:y1+1,x0:x1+1]
            divisor=(p[1,1]-p[2,1])*(p[0,0]-p[2,0])+(p[2,0]-p[1,0])*(p[0,1]-p[2,1])
            if abs(divisor)<1e-8: continue
            a=((p[1,1]-p[2,1])*(xx-p[2,0])+(p[2,0]-p[1,0])*(yy-p[2,1]))/divisor
            b=((p[2,1]-p[0,1])*(xx-p[2,0])+(p[0,0]-p[2,0])*(yy-p[2,1]))/divisor;c=1-a-b
            z=a*p[0,2]+b*p[1,2]+c*p[2,2];region=depth[y0:y1+1,x0:x1+1]
            visible=(a>=0)&(b>=0)&(c>=0)&(z<region)
            sample=a[:,:,None]*coords[0]+b[:,:,None]*coords[1]+c[:,:,None]*coords[2]
            tx=np.clip((sample[:,:,0]*texture.shape[1]).astype(int),0,texture.shape[1]-1)
            ty=np.clip((sample[:,:,1]*texture.shape[0]).astype(int),0,texture.shape[0]-1)
            image[y0:y1+1,x0:x1+1][visible]=(texture[ty,tx].astype(np.float32)*face['tint']/255).astype(np.uint8)[visible]
            region[visible]=z[visible]
    Image.fromarray(image).save(OUTPUT/'geometry-preview.png')
    print('Generated Creeper reference OBJ, metadata and CPU preview from the actual Lua renderer.')


if __name__=='__main__': main()

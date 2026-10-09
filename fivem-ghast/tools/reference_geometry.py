"""Export a static OBJ + CPU-rendered reference preview of the procedural Ghast.
Not a GTA drawable export or a FiveM screenshot. Only uses the installed Pillow/numpy.
"""
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/reference'
LENGTHS = [8, 13, 9, 11, 11, 10, 12, 9, 12]


def geometry():
    faces = []
    cubes = [(-8, -8, -8, 16, 16, 16, (0, 0, 0), 0)]
    for i, length in enumerate(LENGTHS):
        xo = (i % 3 - (i // 3) % 2 * 0.5 + 0.25 - 1) * 5
        zo = (i // 3 - 1) * 5
        cubes.append((-1, 0, -1, 2, length, 2, (xo, 7, zo), 0.2 * math.sin(i) + 0.4))
    for x, y, z, dx, dy, dz, pivot, angle in cubes:
        vertices = np.array([(x,y,z),(x+dx,y,z),(x+dx,y+dy,z),(x,y+dy,z),
                             (x,y,z+dz),(x+dx,y,z+dz),(x+dx,y+dy,z+dz),(x,y+dy,z+dz)], dtype=float)
        rotation = np.array([[1,0,0],[0,math.cos(angle),-math.sin(angle)],[0,math.sin(angle),math.cos(angle)]])
        vertices = (vertices @ rotation.T + pivot)[:,[0,2,1]] * [1,-1,-1] * 4.5 / 16
        specs = [([5,4,0,1], (dz,0,dz+dx,dz), 1.0),
                 ([2,3,7,6], (dz+dx,dz,dz+dx+dx,0), .78),
                 ([0,4,7,3], (0,dz,dz,dz+dy), .88),
                 ([1,0,3,2], (dz,dz,dz+dx,dz+dy), 1.0),
                 ([5,1,2,6], (dz+dx,dz,dz+dx+dz,dz+dy), .92),
                 ([4,5,6,7], (dz+dx+dz,dz,dz+dx+dz+dx,dz+dy), .86)]
        for indices, (u0,v0,u1,v1), tint in specs:
            uv = np.array([(u1,v0),(u0,v0),(u0,v1),(u1,v1)], dtype=float) / [64,32]
            faces.append((vertices[indices][::-1], uv[::-1], tint))
    return faces


def main():
    faces = geometry()
    obj = ['# Generated from local 26.3 GhastModel reference; static animation frame at tick 0',
           'mtllib ghast.mtl', 'usemtl ghast']
    for index, (vertices, uv, _) in enumerate(faces):
        obj += ['v ' + ' '.join(f'{v:.6f}' for v in vertex) for vertex in vertices]
        obj += [f'vt {u:.6f} {1-v:.6f}' for u,v in uv]
        obj += ['f ' + ' '.join(f'{index*4+j+1}/{index*4+j+1}' for j in range(4))]
    (OUTPUT / 'ghast.obj').write_text('\n'.join(obj) + '\n', encoding='utf-8')
    (OUTPUT / 'ghast.mtl').write_text('newmtl ghast\nKd 1 1 1\nKa 1 1 1\nmap_Kd ../textures/ghast.png\n', encoding='utf-8')
    # Orthographic texture rasterization used solely for geometry/UV inspection.
    width, height = 800, 800
    image = np.zeros((height,width,3), dtype=np.uint8)
    image[:] = [36,39,37]
    depth = np.full((height,width), np.inf)
    camera = np.array([8.,14.,8.])
    target = np.array([0.,0.,-1.4])
    forward = target-camera; forward /= np.linalg.norm(forward)
    right = np.cross(forward,[0,0,1]); right /= np.linalg.norm(right)
    up = np.cross(right,forward)
    texture = np.array(Image.open(ROOT/'assets/textures/ghast.png').convert('RGB'))
    for vertices, uv, tint in faces:
        normal = np.cross(vertices[1]-vertices[0], vertices[2]-vertices[0])
        if np.dot(normal,camera-vertices[0]) <= 0: continue
        delta = vertices-target
        screen = np.column_stack((width/2+delta@right*80,height/2-delta@up*80,(vertices-camera)@forward))
        for ids in [[0,1,2],[0,2,3]]:
            p = screen[ids]; coords = uv[ids]
            x0,y0 = np.maximum([0,0],np.floor(p[:,:2].min(axis=0))).astype(int)
            x1,y1 = np.minimum([width-1,height-1],np.ceil(p[:,:2].max(axis=0))).astype(int)
            yy,xx = np.mgrid[y0:y1+1,x0:x1+1]
            divisor = (p[1,1]-p[2,1])*(p[0,0]-p[2,0])+(p[2,0]-p[1,0])*(p[0,1]-p[2,1])
            if abs(divisor)<1e-8: continue
            a=((p[1,1]-p[2,1])*(xx-p[2,0])+(p[2,0]-p[1,0])*(yy-p[2,1]))/divisor
            b=((p[2,1]-p[0,1])*(xx-p[2,0])+(p[0,0]-p[2,0])*(yy-p[2,1]))/divisor
            c=1-a-b
            z=a*p[0,2]+b*p[1,2]+c*p[2,2]
            region=depth[y0:y1+1,x0:x1+1]
            visible=(a>=0)&(b>=0)&(c>=0)&(z<region)
            sample=a[:,:,None]*coords[0]+b[:,:,None]*coords[1]+c[:,:,None]*coords[2]
            tx=np.clip((sample[:,:,0]*texture.shape[1]).astype(int),0,texture.shape[1]-1)
            ty=np.clip((sample[:,:,1]*texture.shape[0]).astype(int),0,texture.shape[0]-1)
            image[y0:y1+1,x0:x1+1][visible]=(texture[ty,tx]*tint).astype(np.uint8)[visible]
            region[visible]=z[visible]
    Image.fromarray(image).save(OUTPUT/'geometry-preview.png')
    details = {'source':'GhastModel.class and ModelPart$Cube.class from local Minecraft 26.3 client JAR',
               'body_units':[16,16,16], 'layer_texture_size':[64,32], 'actual_png_size':[128,64],
               'scale':4.5/16, 'body_pivot_y':17.6, 'tentacle_pivot_y':24.6,
               'tentacle_count':9, 'tentacle_lengths':LENGTHS, 'tentacle_size_xz':[2,2],
               'random_seed':1660, 'animation':'xRot = 0.2 * sin(ageInTicks * 0.3 + i) + 0.4',
               'attack_ticks':{'warn':10,'shoot':20,'reset':-40},
               'preview':'CPU reference render, not an in-game screenshot',
               'obj':'Static reference mesh at age 0; not a FiveM drawable, no bones'}
    (OUTPUT/'geometry.json').write_text(json.dumps(details,indent=2)+'\n',encoding='utf-8')
    print('Generated OBJ, material, geometry reference, and CPU preview')


if __name__ == '__main__':
    main()

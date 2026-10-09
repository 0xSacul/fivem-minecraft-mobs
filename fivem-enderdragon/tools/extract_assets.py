"""Copy the required original local inputs; never write to the Minecraft directory."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import zipfile
sys.dont_write_bytecode=True
from classfile import class_reference
from model_reference import geometry, lua_table
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--minecraft',type=Path,default=Path(os.environ['APPDATA'])/'.minecraft')
    parser.add_argument('--version',default='26.3')
    args=parser.parse_args();mc=args.minecraft.resolve()
    jar=mc/'versions'/args.version/(args.version+'.jar')
    metadata=json.loads(jar.with_suffix('.json').read_text())
    index_path=mc/'assets/indexes'/(metadata['assetIndex']['id']+'.json')
    index=json.loads(index_path.read_text())['objects'];records=[]
    def save(destination,content,source,**extra):
        output=ROOT/destination
        assert not output.resolve().is_relative_to(mc), 'Refusing Minecraft write'
        output.parent.mkdir(parents=True,exist_ok=True);output.write_bytes(content)
        records.append({'destination':destination,'source':source,'sha1':hashlib.sha1(content).hexdigest(),'size':len(content),**extra})
    with zipfile.ZipFile(jar) as z:
        for name in ['dragon','dragon_eyes','dragon_exploding','dragon_fireball']:
            entry='assets/minecraft/textures/entity/enderdragon/'+name+'.png'
            content=z.read(entry);source=f'{jar}!/{entry}'
            save('assets/textures/'+name+'.png',content,source)
            image=Image.open(io.BytesIO(content)).convert('RGBA')
            variants={name:image}
            if name=='dragon':
                overlay=Image.new('RGBA',image.size,(255,45,45,255))
                overlay.putalpha(image.getchannel('A'))
                variants['dragon_hurt']=Image.blend(image,overlay,.4)
            for variant,im in variants.items():
                im=im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST)
                b=io.BytesIO();im.save(b,format='PNG')
                save('assets/runtime/'+variant+'.png',b.getvalue(),source,
                     conversion='RGBA PNG; 4x nearest-neighbor upscale'+('; red hurt overlay' if variant=='dragon_hurt' else ''))
        entries=[
            'net/minecraft/client/model/monster/dragon/EnderDragonModel.class',
            'net/minecraft/client/renderer/entity/EnderDragonRenderer.class',
            'net/minecraft/client/model/geom/ModelPart$Cube.class',
            'net/minecraft/client/model/geom/builders/CubeListBuilder.class',
            'net/minecraft/world/entity/projectile/hurtingprojectile/DragonFireball.class',
            'net/minecraft/world/entity/boss/enderdragon/phases/DragonStrafePlayerPhase.class']
        for entry in entries:
            content=z.read(entry);source=f'{jar}!/{entry}';name=entry.rsplit('/',1)[1]
            ref=class_reference(content)
            save('assets/reference/'+name,content,source)
            save('assets/reference/'+name.replace('.class','.bytecode.json'),json.dumps(ref,indent=2).encode(),source,
                 conversion='Resolved constant pool and raw method bytecode; reference only')
            if name=='EnderDragonModel.class':
                model=geometry(ref)
                save('assets/reference/model.json',json.dumps(model,indent=2).encode(),source,
                     conversion='Declarative createBodyLayer builder evaluated without executing Java')
                save('shared/model.lua',('-- Generated from the installed EnderDragonModel.createBodyLayer, including UVs and parent pivots.\nDragonModel='+lua_table(model)+'\n').encode(),source,
                     conversion='Exact builder geometry as a Lua table; procedural poses supplied by client/renderer.lua')
    info=index['minecraft/sounds.json'];path=mc/'assets/objects'/info['hash'][:2]/info['hash']
    data=path.read_bytes();assert hashlib.sha1(data).hexdigest()==info['hash']
    all_events=json.loads(data);events={k:v for k,v in all_events.items() if k.startswith('entity.ender_dragon.')}
    save('assets/reference/sound_events.json',json.dumps(events,indent=2).encode(),str(path),
         source_sha1=info['hash'],logical_path='minecraft/sounds.json',index=str(index_path),conversion='Only Ender Dragon events extracted')
    names=sorted({s if isinstance(s,str) else s['name'] for event in events.values() for s in event['sounds']})
    for name in names:
        key='minecraft/sounds/'+name+'.ogg';info=index[key]
        path=mc/'assets/objects'/info['hash'][:2]/info['hash'];data=path.read_bytes()
        assert hashlib.sha1(data).hexdigest()==info['hash']
        save('assets/sounds/'+name.rsplit('/',1)[1]+'.ogg',data,str(path),logical_path=key,index=str(index_path),conversion='None: original OGG Vorbis')
    provenance={'minecraft_root':str(mc),'version':args.version,'jar':str(jar),
        'jar_sha1':hashlib.sha1(jar.read_bytes()).hexdigest(),'asset_index':str(index_path),
        'asset_index_sha1':hashlib.sha1(index_path.read_bytes()).hexdigest(),'assets':records}
    (ROOT/'assets/provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
    lines=['# Ender Dragon asset sources','',f'Client JAR: `{jar}`',f'JAR SHA-1: `{provenance["jar_sha1"]}`',
        f'Asset index: `{index_path}`',f'Index SHA-1: `{provenance["asset_index_sha1"]}`','',
        'Minecraft was read only. No software was installed. All output hashes are recorded in provenance.json.','']
    for a in records:
        lines += [f'## `{a["destination"]}`','',f'- Source: `{a["source"]}`',f'- Output SHA-1: `{a["sha1"]}`',
                  f'- Conversion: {a.get("conversion","None: copied unchanged")}']
        if 'logical_path' in a: lines += [f'- Asset-index key: `{a["logical_path"]}`']
        lines += ['']
    lines += ['## Runtime geometry','',
        'shared/model.lua follows the original builder exactly: 5 neck and 12 tail segments, head/jaw, body,',
        'two wings with tips and four articulated legs. The atlas is 256x256. Original zero-thickness wing skins',
        'are rendered as two-sided planes. Animation/flight are adaptations; this is not an exported GTA drawable.',
        'reference/dragon.obj, dragon.mtl, geometry.json, geometry-preview.png and wing-animation.gif are generated from the actual',
        'Lua renderer by tools/reference_geometry.py. Their geometry is derived from this source, not copied mesh files.','']
    (ROOT/'assets/SOURCES.md').write_text('\n'.join(lines),encoding='utf-8')
    print(f'Extracted {len(records)} assets/references. Minecraft unchanged.')


if __name__=='__main__':main()

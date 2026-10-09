"""Copy only local Creeper inputs. The Minecraft installation is always opened read-only."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import zipfile
sys.dont_write_bytecode = True
from classfile import class_reference
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--minecraft', type=Path, default=Path(os.environ['APPDATA'])/'.minecraft')
    parser.add_argument('--version', default='26.3')
    args = parser.parse_args()
    mc = args.minecraft.resolve()
    jar = mc/'versions'/args.version/(args.version+'.jar')
    metadata = json.loads(jar.with_suffix('.json').read_text(encoding='utf-8'))
    index_path = mc/'assets/indexes'/(metadata['assetIndex']['id']+'.json')
    index = json.loads(index_path.read_text(encoding='utf-8'))['objects']
    records = []

    def save(destination, content, source, **extra):
        output = ROOT/destination
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(content)
        records.append({'destination':destination, 'source':source,
                        'sha1':hashlib.sha1(content).hexdigest(), 'size':len(content), **extra})

    with zipfile.ZipFile(jar) as archive:
        entry = 'assets/minecraft/textures/entity/creeper/creeper.png'
        original = archive.read(entry)
        source = f'{jar}!/{entry}'
        save('assets/textures/creeper.png', original, source)
        texture = Image.open(io.BytesIO(original)).convert('RGBA')
        variants = {'creeper':texture}
        # Approximate the Java renderer's white overlay with pre-baked textures, avoiding coplanar quads.
        for percent in [50,75,100]:
            white = Image.new('RGBA',texture.size,(255,255,255,255))
            variants[f'creeper_flash{percent}'] = Image.blend(texture,white,percent/100)
        variants['creeper_hurt'] = Image.blend(texture,Image.new('RGBA',texture.size,(255,50,50,255)),0.45)
        for name, image in variants.items():
            image = image.resize((image.width*16,image.height*16), Image.Resampling.NEAREST)
            buffer = io.BytesIO(); image.save(buffer,format='PNG')
            save(f'assets/runtime/{name}.png',buffer.getvalue(),source,
                 conversion=f'RGBA PNG; 16x nearest-neighbor upscale; {name} overlay variant')
        for entry in [
            'net/minecraft/client/model/monster/creeper/CreeperModel.class',
            'net/minecraft/client/renderer/entity/CreeperRenderer.class',
            'net/minecraft/client/model/geom/ModelPart$Cube.class',
            'net/minecraft/world/entity/monster/Creeper.class',
            'net/minecraft/world/entity/ai/goal/SwellGoal.class'
        ]:
            content = archive.read(entry)
            filename = entry.rsplit('/',1)[1]
            source = f'{jar}!/{entry}'
            save('assets/reference/'+filename,content,source)
            save('assets/reference/'+filename.replace('.class','.bytecode.json'),
                 json.dumps(class_reference(content),indent=2).encode(),source,
                 conversion='Resolved class constant pool and raw method bytecode; reference only')

    sound_object = index['minecraft/sounds.json']
    sound_path = mc/'assets/objects'/sound_object['hash'][:2]/sound_object['hash']
    content = sound_path.read_bytes()
    assert hashlib.sha1(content).hexdigest() == sound_object['hash']
    all_events = json.loads(content)
    events = {k:v for k,v in all_events.items() if k.startswith('entity.creeper.') or k=='entity.generic.explode'}
    save('assets/reference/sound_events.json',json.dumps(events,indent=2).encode(),str(sound_path),
         source_sha1=sound_object['hash'],index=str(index_path),logical_path='minecraft/sounds.json',
         conversion='Only Creeper and generic explosion events extracted')
    names = sorted({s if isinstance(s,str) else s['name'] for e in events.values() for s in e['sounds']})
    for name in names:
        key = 'minecraft/sounds/'+name+'.ogg'; info = index[key]
        path = mc/'assets/objects'/info['hash'][:2]/info['hash']
        content = path.read_bytes()
        assert hashlib.sha1(content).hexdigest() == info['hash'],key
        save('assets/sounds/'+name.rsplit('/',1)[1]+'.ogg',content,str(path),
             index=str(index_path),logical_path=key,conversion='None: original OGG Vorbis')
    provenance = {'minecraft_root':str(mc),'version':args.version,'jar':str(jar),
                  'jar_sha1':hashlib.sha1(jar.read_bytes()).hexdigest(),'asset_index':str(index_path),
                  'asset_index_sha1':hashlib.sha1(index_path.read_bytes()).hexdigest(),'assets':records}
    (ROOT/'assets/provenance.json').write_text(json.dumps(provenance,indent=2)+'\n',encoding='utf-8')
    lines = ['# Creeper asset sources','',f'Version: `{args.version}`',f'Client JAR: `{jar}`',
             f'Client SHA-1: `{provenance["jar_sha1"]}`',f'Index: `{index_path}`',
             f'Index SHA-1: `{provenance["asset_index_sha1"]}`','',
             'Every source was read without modifying Minecraft. Output hashes are also in provenance.json.','']
    for asset in records:
        lines += [f'## `{asset["destination"]}`','',f'- Source: `{asset["source"]}`',
                  f'- SHA-1: `{asset["sha1"]}`',f'- Conversion: {asset.get("conversion","None: copied unchanged")}']
        if 'logical_path' in asset: lines += [f'- Index key: `{asset["logical_path"]}`']
        if 'source_sha1' in asset: lines += [f'- Original object SHA-1: `{asset["source_sha1"]}`']
        lines += ['']
    lines += ['## Reconstructed mesh','',
              'reference/creeper.obj, creeper.mtl and geometry-preview.png are generated from shared/model.lua',
              'by tools/reference_geometry.py. The model table follows the copied CreeperModel reference;',
              'UVs follow ModelPart$Cube. These outputs are reconstructed references, not Minecraft mesh files.','']
    (ROOT/'assets/SOURCES.md').write_text('\n'.join(lines),encoding='utf-8')
    print(f'Extracted {len(records)} files; original Minecraft unchanged.')


if __name__ == '__main__':
    main()

"""Read the installed client and copy only Ghast prototype inputs; never writes to Minecraft."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import struct
import zipfile

RESOURCE = Path(__file__).resolve().parents[1]


def class_reference(data):
    """Small class-file reader: records bytecode + resolved constants, not a decompiler."""
    cursor = 8

    def read(fmt):
        nonlocal cursor
        value = struct.unpack_from('>' + fmt, data, cursor)
        cursor += struct.calcsize('>' + fmt)
        return value[0] if len(value) == 1 else value

    pool = {}
    count = read('H')
    index = 1
    while index < count:
        tag = read('B')
        if tag == 1:
            length = read('H')
            value = data[cursor:cursor + length].decode('utf-8', errors='replace')
            cursor += length
        elif tag in (3, 4, 5, 6):
            value = read({3: 'i', 4: 'f', 5: 'q', 6: 'd'}[tag])
        elif tag in (7, 8, 16, 19, 20):
            value = read('H')
        elif tag in (9, 10, 11, 12, 17, 18):
            value = read('HH')
        elif tag == 15:
            value = read('BH')
        else:
            raise ValueError(f'Unknown constant pool tag {tag}')
        pool[index] = (tag, value)
        index += 2 if tag in (5, 6) else 1

    def resolve(index):
        tag, value = pool[index]
        if tag in (7, 8, 16, 19, 20):
            return resolve(value)
        if tag in (9, 10, 11, 12):
            return ' '.join(str(resolve(v)) for v in value)
        return value

    read('HHH')
    for _ in range(read('H')):
        read('H')

    def members():
        nonlocal cursor
        result = []
        for _ in range(read('H')):
            flags, name, descriptor = read('HHH')
            member = {'name': resolve(name), 'descriptor': resolve(descriptor)}
            for _ in range(read('H')):
                attribute = resolve(read('H'))
                length = read('I')
                start = cursor
                if attribute == 'Code':
                    read('HH')
                    code_length = read('I')
                    member['bytecode_hex'] = data[cursor:cursor + code_length].hex(' ')
                cursor = start + length
            result.append(member)
        return result

    members()  # fields
    methods = members()
    return {'constants': {str(k): resolve(k) for k in pool}, 'methods': methods}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--minecraft', type=Path, default=Path(os.environ['APPDATA']) / '.minecraft')
    parser.add_argument('--version', default='26.3')
    args = parser.parse_args()
    root = args.minecraft.resolve()
    jar = root / 'versions' / args.version / f'{args.version}.jar'
    metadata_path = jar.with_suffix('.json')
    metadata = json.loads(metadata_path.read_text(encoding='utf-8'))
    index_path = root / 'assets' / 'indexes' / (metadata['assetIndex']['id'] + '.json')
    index = json.loads(index_path.read_text(encoding='utf-8'))
    entries = []

    def save(relative, content, source, **extra):
        destination = RESOURCE / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)
        entries.append({'destination': relative, 'source': source, 'sha1': hashlib.sha1(content).hexdigest(),
                        'size': len(content), **extra})

    textures = {'ghast.png': 'entity/ghast/ghast.png', 'ghast_shooting.png': 'entity/ghast/ghast_shooting.png',
                'fire_charge.png': 'item/fire_charge.png'}
    from PIL import Image
    with zipfile.ZipFile(jar) as archive:
        for filename, path in textures.items():
            entry = 'assets/minecraft/textures/' + path
            content = archive.read(entry)
            source = f'{jar}!/{entry}'
            save('assets/textures/' + filename, content, source)
            # Nearest-neighbour upscale avoids smoothing 16px/64px pixels in runtime textures.
            image = Image.open(io.BytesIO(content)).convert('RGBA')
            image = image.resize((image.width * 16, image.height * 16), Image.Resampling.NEAREST)
            buffer = io.BytesIO()
            image.save(buffer, format='PNG')
            save('assets/runtime/' + filename, buffer.getvalue(), source,
                 conversion='RGBA PNG, 16x nearest-neighbour upscale; no artwork changes')
        for entry in ['net/minecraft/client/model/monster/ghast/GhastModel.class',
                      'net/minecraft/world/entity/monster/Ghast$GhastShootFireballGoal.class',
                      'net/minecraft/client/renderer/entity/GhastRenderer.class',
                      'net/minecraft/client/model/geom/ModelPart$Cube.class',
                      'net/minecraft/client/renderer/entity/ThrownItemRenderer.class',
                      'net/minecraft/world/entity/projectile/hurtingprojectile/Fireball.class',
                      'net/minecraft/util/RandomSource.class',
                      'net/minecraft/world/level/levelgen/LegacyRandomSource.class',
                      'net/minecraft/world/level/levelgen/SingleThreadedRandomSource.class',
                      'assets/minecraft/models/item/fire_charge.json']:
            content = archive.read(entry)
            filename = entry.rsplit('/', 1)[1]
            save('assets/reference/' + filename, content, f'{jar}!/{entry}')
            if filename.endswith('.class'):
                reference = json.dumps(class_reference(content), indent=2).encode()
                save('assets/reference/' + filename.replace('.class', '.bytecode.json'), reference,
                     f'{jar}!/{entry}', conversion='Resolved constant pool and raw method bytecode (reference only)')

    sound_index = index['objects']['minecraft/sounds.json']
    sound_path = root / 'assets' / 'objects' / sound_index['hash'][:2] / sound_index['hash']
    content = sound_path.read_bytes()
    assert hashlib.sha1(content).hexdigest() == sound_index['hash']
    sounds = json.loads(content)
    events = {k: v for k, v in sounds.items() if k in (
        'entity.ghast.ambient', 'entity.ghast.hurt', 'entity.ghast.death',
        'entity.ghast.warn', 'entity.ghast.shoot', 'item.firecharge.use')}
    save('assets/reference/sound_events.json', json.dumps(events, indent=2).encode(), str(sound_path),
         index=str(index_path), logical_path='minecraft/sounds.json', source_sha1=sound_index['hash'],
         conversion='Only the six relevant sound events extracted from sounds.json')
    names = sorted({s if isinstance(s, str) else s['name'] for e in events.values() for s in e['sounds']})
    for name in names:
        logical = f'minecraft/sounds/{name}.ogg'
        asset = index['objects'][logical]
        source = root / 'assets' / 'objects' / asset['hash'][:2] / asset['hash']
        content = source.read_bytes()
        assert hashlib.sha1(content).hexdigest() == asset['hash'], logical
        save('assets/sounds/' + name.rsplit('/', 1)[1] + '.ogg', content, str(source),
             index=str(index_path), logical_path=logical, conversion='None: original OGG Vorbis is supported by NUI')

    provenance = {'minecraft_root': str(root), 'version': args.version, 'jar': str(jar),
                  'jar_sha1': hashlib.sha1(jar.read_bytes()).hexdigest(),
                  'asset_index': str(index_path), 'asset_index_sha1': hashlib.sha1(index_path.read_bytes()).hexdigest(),
                  'assets': entries}
    (RESOURCE / 'assets' / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n', encoding='utf-8')
    lines = ['# Local Minecraft asset sources', '',
             'All original assets were read from this installation without modifying it.', '',
             f'- Version: `{args.version}`', f'- Client JAR: `{jar}`',
             f'- Client JAR SHA-1: `{provenance["jar_sha1"]}`',
             f'- Asset index: `{index_path}`', f'- Index SHA-1: `{provenance["asset_index_sha1"]}`', '',
             'Each entry below records its exact source. `provenance.json` also records output hashes and sizes.', '']
    for asset in entries:
        lines += [f'## `{asset["destination"]}`', '', f'- Source: `{asset["source"]}`',
                  f'- Output SHA-1: `{asset["sha1"]}`']
        if 'logical_path' in asset: lines += [f'- Index key: `{asset["logical_path"]}`']
        if 'source_sha1' in asset: lines += [f'- Original object SHA-1: `{asset["source_sha1"]}`']
        lines += [f'- Conversion: {asset.get("conversion", "None: copied unchanged")}', '']
    lines += ['## Derived geometry', '',
              '`reference/ghast.obj`, `ghast.mtl`, `geometry.json`, and `geometry-preview.png` are generated by',
              '`tools/reference_geometry.py` from the copied GhastModel and ModelPart$Cube references and the',
              'original Ghast texture. They are our procedural reconstruction, not model files shipped in Minecraft.', '']
    (RESOURCE / 'assets' / 'SOURCES.md').write_text('\n'.join(lines), encoding='utf-8')
    print(f'Extracted {len(entries)} files into {RESOURCE}; Minecraft opened read-only.')


if __name__ == '__main__':
    main()

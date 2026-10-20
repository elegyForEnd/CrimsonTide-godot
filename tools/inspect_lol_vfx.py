"""Read local LoL base-skin VFX configuration; never export game artwork.

Fallback for WAD/PROP formats unsupported by REA. Install CDTB and Python
dependencies in build/reference-tools (see docs/lol-vfx-study.md).
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
import sys
import types

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'build/reference-tools/python'),
                str(ROOT / 'build/reference-tools/CDTB')]
import zstandard
import xxhash

# CDTB tools only needs pyzstd.decompress for this read-only analysis.
sys.modules.setdefault('pyzstd', types.SimpleNamespace(
    decompress=lambda data: zstandard.ZstdDecompressor().decompress(data)))
from cdtb import binfile as bf

NAMES = '''VfxSystemDefinitionData VfxEmitterDefinitionData particleName
particlePath emitterName emitterLinger emitterLifetime particleLifetime
birthRate birthVelocity birthAcceleration birthRotationalVelocity
birthScale color scale velocity acceleration drag texture blendMode
isLocalOrientation isDirectionOriented bindWeight birthColor
softParticleParams rateByVelocity timeBeforeFirstEmission
uniformScale primitive particleLinger material renderPhaseOverride
VfxPrimitiveBeam VfxPrimitiveRay VfxPrimitiveArbitraryQuad
VfxPrimitiveCameraQuad VfxPrimitiveMesh VfxPrimitiveAttachedMesh
ValueFloat ValueVector3 ValueColor constantValue dynamics
VfxAnimatedFloatVariableData VfxAnimatedVector3fVariableData
VfxAnimatedColorVariableData times values probabilityTables
simpleEmitterDefinitionData complexEmitterDefinitionData
orientation particleBirthRotationalVelocity isUniformScale
textureMult erosionDefinition paletteDefinition uvMode
VfxFloatOverLifeMaterialDriver VfxSineMaterialDriver'''.split()
for name in ('hashfile_binentries', 'hashfile_binhashes',
             'hashfile_binhashes_xxh3', 'hashfile_binfields',
             'hashfile_bintypes', 'hashfile_binpaths'):
    getattr(bf, name).hashes = {bf.compute_binhash(s): s for s in NAMES}


def inspect(wad: Path, champion: str):
    path = f'data/characters/{champion.lower()}/skins/skin0.bin'
    members = []
    with wad.open('rb') as stream:
        magic, major, minor = struct.unpack('<2sBB', stream.read(4))
        if magic != b'RW' or major != 3:
            raise ValueError('Expected WAD 3.x')
        stream.seek(268)
        count, = struct.unpack('<I', stream.read(4))
        table = stream.read(count * 32)
        entries = {e[0]: e for e in struct.iter_unpack('<QIIIBBHQ', table)}
        pending, seen, systems, unresolved = [path], set(), [], []
        while pending and len(seen) < 32:
            member = pending.pop(0).lower()
            if member in seen:
                continue
            seen.add(member)
            entry = entries.get(xxhash.xxh64_intdigest(member.encode('utf-8')))
            if entry is None:
                unresolved.append(member)
                continue
            _, offset, packed, size, flags, *_ = entry
            stream.seek(offset)
            data = stream.read(packed)
            if flags & 15 == 3:
                data = zstandard.ZstdDecompressor().decompress(data)
            elif flags & 15 != 0:
                raise ValueError(f'Unsupported compression {flags & 15}')
            if len(data) != size:
                raise ValueError('Uncompressed size mismatch')
            parsed = bf.BinFile(io.BytesIO(data))
            members.append({'path': member, 'sha256': hashlib.sha256(data).hexdigest(),
                            'offset': offset, 'bytes': size, 'compressed_bytes': packed})
            systems.extend(e for e in parsed.entries if e.type == 'VfxSystemDefinitionData')
            pending.extend(parsed.linked_files or [])
    samples = []
    emitter_count = 0
    for system in systems:
        name = system.getv('particleName', '')
        emitters = system.getv('complexEmitterDefinitionData', [])
        emitter_count += len(emitters)
        if not any(k in str(name).lower() for k in ('_q_', '_r_', '_e_', '_basic', '_w_')):
            continue
        serialized = []
        for emitter in emitters[:16]:
            keep = {str(field.name): field.to_serializable()[1]
                    for field in emitter.fields if str(field.name) in NAMES}
            serialized.append(keep)
        samples.append({'name': str(name), 'path_hash': str(system.path),
                        'emitter_count': len(emitters), 'emitters': serialized})
    return {'authority': 'local artifact parsed with CDTB, not REA evidence',
            'wad': str(wad), 'wad_version': [major, minor], 'wad_entries': count,
            'members': members, 'unresolved_links': unresolved,
            'pending_links': pending, 'system_count': len(systems),
            'emitter_count': emitter_count, 'samples': samples,
            'limitations': ['Base skin only; not runtime timing or native shader code.',
                            'Unknown field hashes preserved by omission; bounded to 16 emitters per sample.']}


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('install', type=Path)
    ap.add_argument('--champions', nargs='+', default=['Lux', 'Ashe', 'Yasuo'])
    ap.add_argument('--out', type=Path, default=ROOT / 'build/lol-vfx-study/local-vfx.json')
    args = ap.parse_args()
    results = [inspect(args.install / 'Game/DATA/FINAL/Champions' / f'{c}.wad.client', c)
               for c in args.champions]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding='utf-8')
    print(json.dumps([{'wad': Path(r['wad']).name, 'members': len(r['members']),
                       'systems': r['system_count'], 'emitters': r['emitter_count'],
                       'unresolved_links': len(r['unresolved_links']),
                       'pending_links': len(r['pending_links'])}
                      for r in results], ensure_ascii=False))

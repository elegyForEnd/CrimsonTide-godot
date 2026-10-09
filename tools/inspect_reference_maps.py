"""Read-only inspection of a local MPQ map library; emits metadata, never game assets.

Dependencies: mpyq and dclimplode (install in output/map-research-deps).
Usage: python tools/inspect_reference_maps.py "F:/game/..."
"""
from pathlib import Path
import argparse, bz2, collections, csv, hashlib, io, json, struct, sys, zlib

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'output/map-research-deps'))
import mpyq
import dclimplode


def decrypt(archive, data, key):
    seed = 0xEEEEEEEE
    result = bytearray(data)
    for off in range(0, len(data) - 3, 4):
        seed = (seed + archive.encryption_table[0x400 + (key & 255)]) & 0xffffffff
        value = struct.unpack_from('<I', data, off)[0] ^ ((key + seed) & 0xffffffff)
        struct.pack_into('<I', result, off, value)
        key = (((~key << 21) + 0x11111111) | (key >> 11)) & 0xffffffff
        seed = (value + seed + (seed << 5) + 3) & 0xffffffff
    return bytes(result)


def read(archive, name):
    name = name.replace('/', '\\')
    entry = archive.get_hash_table_entry(name)
    if entry is None:
        return None
    block = archive.block_table[entry.block_table_index]
    archive.file.seek(block.offset + archive.header['offset'])
    data = archive.file.read(block.archived_size)
    key = archive._hash(name.replace('/', '\\').split('\\')[-1], 'TABLE')
    if block.flags & mpyq.MPQ_FILE_FIX_KEY:
        key = ((key + block.offset) ^ block.size) & 0xffffffff
    encrypted = bool(block.flags & mpyq.MPQ_FILE_ENCRYPTED)

    def unpack(part, expected):
        if len(part) >= expected:
            return part
        if block.flags & mpyq.MPQ_FILE_IMPLODE:
            return dclimplode.decompressobj().decompress(part)
        if block.flags & mpyq.MPQ_FILE_COMPRESS:
            mask, part = part[0], part[1:]
            if mask & 16:
                part = bz2.decompress(part)
            if mask & 8:
                part = dclimplode.decompressobj().decompress(part)
            if mask & 2:
                part = zlib.decompress(part)
            if mask & ~26:
                raise ValueError(f'unsupported compression {mask}')
        return part

    if block.flags & mpyq.MPQ_FILE_SINGLE_UNIT:
        return unpack(decrypt(archive, data, key) if encrypted else data, block.size)
    size = 512 << archive.header['sector_size_shift']
    count = (block.size + size - 1) // size
    if not block.flags & (mpyq.MPQ_FILE_COMPRESS | mpyq.MPQ_FILE_IMPLODE):
        return b''.join(decrypt(archive, data[i*size:(i+1)*size], (key+i)&0xffffffff)
                        if encrypted else data[i*size:(i+1)*size] for i in range(count))[:block.size]
    table_len = 4 * (count + 1 + bool(block.flags & mpyq.MPQ_FILE_SECTOR_CRC))
    table = decrypt(archive, data[:table_len], (key-1)&0xffffffff) if encrypted else data[:table_len]
    offsets = struct.unpack('<' + 'I'*(table_len//4), table)
    pieces = []
    for i in range(count):
        sector = data[offsets[i]:offsets[i+1]]
        if encrypted:
            sector = decrypt(archive, sector, (key+i)&0xffffffff)
        pieces.append(unpack(sector, min(size, block.size-i*size)))
    result = b''.join(pieces)
    assert len(result) == block.size, (name, len(result), block.size)
    return result


class Reader:
    def __init__(self, data): self.data, self.pos = data, 0
    def i(self):
        v = struct.unpack_from('<i', self.data, self.pos)[0]; self.pos += 4; return v
    def string(self):
        end = self.data.index(0, self.pos); v = self.data[self.pos:end].decode('latin1'); self.pos = end+1; return v


def ds1(data):
    r = Reader(data)
    version, w, h = r.i(), r.i()+1, r.i()+1
    act = r.i()+1 if version >= 8 else 1
    sub = r.i() if version >= 10 else 0
    files = [r.string() for _ in range(r.i())] if version >= 3 else []
    if 9 <= version <= 13: r.pos += 8
    walls = r.i() if version >= 4 else 1
    floors = r.i() if version >= 16 else 1
    schema = (['wall0','floor0','orientation0','substitution','shadow'] if version < 4 else
              [v for i in range(walls) for v in (f'wall{i}',f'orientation{i}')] +
              [f'floor{i}' for i in range(floors)] + ['shadow'] + (['substitution'] if sub in (1,2) else []))
    layers = {}
    for name in schema:
        values = struct.unpack_from('<'+'I'*(w*h), data, r.pos); r.pos += w*h*4
        layers[name] = {'nonzero':sum(v != 0 for v in values), 'unique':len(set(values)),
                        'values':values}
    objects = []
    if version >= 2:
        for _ in range(r.i()):
            obj = dict(zip(('type','id','x','y'),[r.i() for _ in range(4)]))
            obj['flags'] = r.i() if version >= 6 else 0
            objects.append(obj)
    return {'version':version,'width':w,'height':h,'act':act,'files':files,
            'layers':{k:{a:b for a,b in v.items() if a!='values'} for k,v in layers.items()},
            'objects':objects,'_grids':layers,'sha256':hashlib.sha256(data).hexdigest()}


def dt1(data):
    major, minor = struct.unpack_from('<II',data)
    count, start = struct.unpack_from('<II',data,268)
    tiles = []
    for i in range(count):
        off = start + i*96
        height,width = struct.unpack_from('<ii',data,off+8)
        kind,style,sequence,rarity = struct.unpack_from('<IIII',data,off+20)
        flags = list(data[off+40:off+65])
        tiles.append({'height':height,'width':width,'type':kind,'style':style,'sequence':sequence,
                      'rarity':rarity,'subtile_flags':flags})
    return {'version':f'{major}.{minor}','tiles':count,'types':dict(collections.Counter(t['type'] for t in tiles)),
            'sizes':dict(collections.Counter(f"{t['width']}x{t['height']}" for t in tiles)),
            'tiles_with_subtile_flags':sum(any(t['subtile_flags']) for t in tiles), 'sample':tiles[:8]}


def main():
    p = argparse.ArgumentParser(); p.add_argument('game'); args = p.parse_args()
    archives = [(name,mpyq.MPQArchive(str(Path(args.game)/name),listfile=False))
                for name in ('Patch_D2.mpq','d2exp.mpq','d2data.mpq')]
    def resolve(name):
        for archive_name, archive in archives:
            result = read(archive, name)
            if result is not None: return archive_name,result
        raise FileNotFoundError(name)
    report = {'root':args.game,'archives':{},'tables':{},'maps':{},'tilesets':{},'errors':[]}
    for name,a in archives:
        listing = read(a,'(listfile)')
        names = listing.decode('latin1').splitlines() if listing else []
        report['archives'][name] = {'header':{k:v for k,v in a.header.items() if not isinstance(v,bytes)},
            'ds1_count':sum(x.lower().endswith('.ds1') for x in names),
            'dt1_count':sum(x.lower().endswith('.dt1') for x in names),
            'ds1_names':[x for x in names if x.lower().endswith('.ds1')],
            'dt1_names':[x for x in names if x.lower().endswith('.dt1')]}
    for name in ('levels','lvlprest','lvltypes','lvlmaze','lvlsub','objects'):
        src,data = resolve('data/global/excel/'+name+'.txt')
        rows = list(csv.DictReader(io.StringIO(data.decode('latin1')),delimiter='\t'))
        report['tables'][name] = {'archive':src,'rows':len(rows),'columns':list(rows[0]),
            'sample':rows[:8] if name!='objects' else rows[:3]}
        if name=='levels':
            report['tables'][name]['selected']=[r for r in rows if any(s in r.get('Name','').lower() for s in ('town','cave','catacomb','wilderness'))]
        if name=='lvlprest':
            selected = [r for r in rows if any(k in r.get('Name','').lower() for k in ('town','graveyard','den of evil'))]
            report['tables'][name]['landmarks'] = selected
    maps = sorted({x.lower() for a in report['archives'].values() for x in a['ds1_names']
                   if '\\act1\\town\\' in x.lower() or 'gravey' in x.lower() or 'bivouac' in x.lower()})
    for row in report['tables']['lvlprest']['landmarks']:
        for col in ('File1','File2','File3','File4'):
            if row.get(col,'0')!='0': maps.append('data\\global\\tiles\\'+row[col].replace('/','\\'))
    maps = list(dict.fromkeys(x.lower() for x in maps))
    # Explicit outdoor modules in addition to camps, discovered through listfile.
    extra = [x for a in report['archives'].values() for x in a['ds1_names']
             if '\\act1\\outdoors\\' in x.lower() and any(k in x.lower() for k in ('border','river','bridge','fence'))][:12]
    for name in maps+extra:
        try:
            src,data = resolve(name); value = ds1(data); value.pop('_grids')
            report['maps'][name] = {'archive':src,**value}
        except Exception as e: report['errors'].append(f'{name}: {e}')
    tiles = [x for a in report['archives'].values() for x in a['dt1_names']
             if '\\act1\\' in x.lower() and any(k in x.lower() for k in ('town','floor','grass','wall','fence','river'))][:16]
    for name in tiles:
        try:
            src,data = resolve(name); report['tilesets'][name] = {'archive':src,**dt1(data)}
        except Exception as e: report['errors'].append(f'{name}: {e}')
    out = ROOT/'output/reference-map-inspection.json'
    out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps({'output':str(out),'archives':{k:{a:b for a,b in v.items() if a.endswith('count')} for k,v in report['archives'].items()},
                      'tables':{k:v['rows'] for k,v in report['tables'].items()},'maps':len(report['maps']),
                      'tilesets':len(report['tilesets']),'errors':report['errors']},ensure_ascii=False))


if __name__=='__main__': main()

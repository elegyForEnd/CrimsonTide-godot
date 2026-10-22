"""Decode selected local LoL textures for visual study only, under ignored build/.

TEX/DDS layout verified against CDTB TexConverter and LeagueToolkit's TEX spec.
This script never writes to the game installation or project runtime assets.
"""
import hashlib
import io
import json
from pathlib import Path
import struct
from PIL import Image, ImageDraw, ImageFont
from inspect_lol_vfx import xxhash, zstandard

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/lol-vfx-study/reference-textures'
SELECTION = {
    'Yasuo': ['Yasuo_Basic_attack_trail', 'Yasuo_W_wind_wispy', 'Yasuo_Q_smoke',
              'Yasuo_Base_Q_wind_hit_tar', 'Yasuo_base_Q_blood_tar', 'Yasuo_Q_sword'],
    'Ashe': ['common_frost_cloud_01', 'Ashe_Base_E_WispySmoke01', 'Irelia_Skin06_shards'],
    'Lux': ['Lux_Base_R_Flash', 'Sphere_E_01', 'Lux_Base_E_Mote'],
}


def texture(data):
    if data[:4] == b'DDS ':
        return Image.open(io.BytesIO(data)).convert('RGBA')
    if data[:4] != b'TEX\0':
        raise ValueError(f'Unexpected image signature {data[:4]!r}')
    width, height = struct.unpack_from('<HH', data, 4)
    fmt, mips = data[9], data[11]
    formats = {10: (b'DXT1', 8), 12: (b'DXT5', 16), 13: (b'DX10', 16),
               14: (b'DX10', 16)}
    if fmt == 20:
        pixel_format = struct.pack('<II4x5I', 32, 0x41, 32, 0xff0000, 0xff00, 0xff, 0xff000000)
        size = width*height*4
    else:
        code, block = formats[fmt]
        pixel_format = struct.pack('<II4s20x', 32, 4, code)
        size = ((width+3)//4)*((height+3)//4)*block
    pixels = data[-size:] if mips else data[12:]
    header = struct.pack('<4s4I56x32sI16x', b'DDS ', 124, 0x1007, height, width, pixel_format, 0x1000)
    if fmt in [13, 14]:
        header += struct.pack('<II4xII', 99 if fmt == 13 else 84, 3, 1, 1)
    return Image.open(io.BytesIO(header+pixels)).convert('RGBA')


def extract(install):
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for champion, names in SELECTION.items():
        wad = install / 'Game/DATA/FINAL/Champions' / f'{champion}.wad.client'
        with wad.open('rb') as f:
            magic, major, minor = struct.unpack('<2sBB', f.read(4))
            assert magic == b'RW' and major == 3
            f.seek(268)
            count, = struct.unpack('<I', f.read(4))
            entries = {e[0]: e for e in struct.iter_unpack('<QIIIBBHQ', f.read(32*count))}
            toc_path = f'data/final/champions/{champion}.wad.subchunktoc'.lower()
            toc_entry = entries[xxhash.xxh64_intdigest(toc_path.encode())]
            f.seek(toc_entry[1])
            toc = f.read(toc_entry[2])
            if toc_entry[4] & 15 == 3:
                toc = zstandard.ZstdDecompressor().decompress(toc)
            else:
                assert toc_entry[4] & 15 == 0
            for name in names:
                member = f'assets/characters/{champion}/skins/base/particles/{name}.tex'.lower()
                entry = entries.get(xxhash.xxh64_intdigest(member.encode()))
                if entry is None:
                    print('NOT FOUND', member)
                    continue
                _, offset, packed, size, flags, *_ = entry
                f.seek(offset)
                data = f.read(packed)
                if flags & 15 == 3:
                    data = zstandard.ZstdDecompressor().decompress(data)
                elif flags & 15 == 4:
                    first = entry[6] + (entry[5] << 16)
                    chunks, position = [], 0
                    for chunk_index in range(first, first+(flags >> 4)):
                        compressed, decoded, digest = struct.unpack_from('<IIQ', toc, chunk_index*16)
                        block = data[position:position+compressed]
                        assert len(block) == compressed and xxhash.xxh3_64_intdigest(block) == digest
                        chunk = block if compressed == decoded else zstandard.ZstdDecompressor().decompress(block)
                        assert len(chunk) == decoded
                        chunks.append(chunk)
                        position += compressed
                    assert position == len(data)
                    data = b''.join(chunks)
                elif flags & 15 != 0:
                    print('SKIP compression', flags & 15, member)
                    continue
                assert len(data) == size
                image = texture(data)
                target = OUT / f'{champion}-{name}.png'
                image.save(target)
                records.append({'champion': champion, 'member': member, 'wad': str(wad),
                                'offset': offset, 'compressed_bytes': packed,
                                'sha256': hashlib.sha256(data).hexdigest(),
                                'size': list(image.size), 'file': str(target),
                                'alpha_extrema': image.getchannel('A').getextrema()})
    (OUT / 'provenance.json').write_text(json.dumps(records, indent=2), encoding='utf-8')
    return records


def sheet(records):
    # RGB over black is useful for additive particles; alpha is shown separately.
    cols, cw, ch = 3, 460, 350
    canvas = Image.new('RGB', (cols*cw, ((len(records)+cols-1)//cols)*ch), '#17212b')
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 14)
    for i, record in enumerate(records):
        x, y = (i % cols)*cw, (i//cols)*ch
        image = Image.open(record['file']).convert('RGBA')
        rgb = image.convert('RGB')
        rgb.thumbnail((288, 274))
        canvas.paste(rgb, (x+(292-rgb.width)//2, y+12+(274-rgb.height)//2))
        alpha = image.getchannel('A').convert('RGB')
        alpha.thumbnail((150, 260))
        canvas.paste(alpha, (x+300+(150-alpha.width)//2, y+12+(260-alpha.height)//2))
        draw.text((x+8, y+290), record['champion']+' / '+Path(record['member']).stem, font=font, fill='#e5edf4')
        draw.text((x+8, y+313), f"{record['size'][0]}×{record['size'][1]}  左：原始RGB  右：Alpha", font=font, fill='#9bafc2')
    canvas.save(OUT / 'lol-original-textures.jpg', quality=95)


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('install', type=Path)
    records = extract(ap.parse_args().install)
    sheet(records)
    print(f'Decoded {len(records)} reference textures: {OUT}')

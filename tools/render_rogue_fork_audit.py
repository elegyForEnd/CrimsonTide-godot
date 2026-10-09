import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
out = root / 'build/fork-audit'
entries = json.loads((out / 'geometry.json').read_text(encoding='utf-8'))
for kind in dict.fromkeys(e['key'].split('-', 1)[1] for e in entries):
    selected = [e for e in entries if e['key'].endswith('-' + kind)]
    sheet = Image.new('RGB', (600, 480 * len(selected)))
    for row, entry in enumerate(selected):
        source = root / entry['texture'].replace('res://', '')
        pic = Image.open(source).convert('RGB').resize((2000, 667))
        draw = ImageDraw.Draw(pic)
        points = [(x * 2000, y * 667) for x, y in entry['outline']]
        draw.line(points + points[:1], fill='#ffdd44', width=3)
        for hole in entry.get('holes', []):
            points = [(x * 2000, y * 667) for x, y in hole]
            draw.line(points + points[:1], fill='#ff7755', width=3)
        for x, y in entry['exits']:
            x, y = x * 2000, y * 667
            draw.ellipse((x-6, y-6, x+6, y+6), fill='#55ddff')
        crop = pic.crop((1400, 100, 2000, 580))
        ImageDraw.Draw(crop).text((6, 6), entry['key'], fill='white', stroke_width=2, stroke_fill='black')
        crop.save(out / (entry['key'] + '.png'))
        sheet.paste(crop, (0, row * 480))
    sheet.save(out / (kind + '.png'))
cards = ''.join(f'<article><h2>{e["key"]}</h2><a href="{e["key"]}.png"><img src="{e["key"]}.png" loading="lazy" alt="{e["key"]}"></a><small>{Path(e["texture"]).name}</small></article>' for e in entries)
page = '<!doctype html><html lang="zh-CN"><meta charset="UTF-8"><title>闯关分叉边界检查</title><style>body{background:#141820;color:#eee;font-family:system-ui;margin:24px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:20px}article{background:#202631;padding:12px}h2{margin:0 0 8px;font-size:18px}img{width:100%;display:block}small{display:block;margin-top:8px;color:#aab3c2}p{line-height:1.7}</style><h1>闯关分叉边界检查 · 75 张实际贴图</h1><p>黄色：可走地面外沿；橙色：内部不可走区域；蓝点：出口。点击图片查看原尺寸。</p><main>'+cards+'</main></html>'
(out / 'index.html').write_text(page, encoding='utf-8')
print('Rendered 75 current forks in 15 sheets and index.html')

"""Compare reference-only art with native materials, geometry and battle footage."""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'art/weapon-vfx-reference-v6'
OUT = ROOT / 'build/vfx-v6'

def build():
    OUT.mkdir(parents=True, exist_ok=True)
    briefs = json.loads((BASE/'briefs.json').read_text(encoding='utf-8'))
    cards, links, coverage = [], [], []
    for brief in briefs:
        weapon = brief['id']
        label = f'{weapon} {html.escape(brief["name"])}'
        links.append(f'<a href="#w{weapon}">{label}</a>')
        final = BASE/f'finished/weapon-{weapon}.png'
        plate = BASE/f'plates/weapon-{weapon}.png'
        reference = final if final.exists() else plate
        reference_url = '../../'+reference.relative_to(ROOT).as_posix()
        reference_html = f'<div class="reference {"sheet" if reference == plate else ""}"><img loading="lazy" src="{reference_url}" alt="{label} 美术参考"></div>' if reference.exists() else '<p>参考图制作中。</p>'
        actual_file = OUT/f'weapon-{weapon}.png'
        actual = f'<a href="weapon-{weapon}.png"><img class="actual" loading="lazy" src="weapon-{weapon}.png" alt="{label} 引擎实际输出"></a>' if actual_file.exists() else '<p>引擎捕获待更新。</p>'
        videos = []
        for action, title in [('normal','普攻'),('heavy','蓄力重击'),('art','战技')]:
            if (OUT/f'battle/{weapon}-{action}.mp4').exists():
                videos.append(f'<figure><video muted loop controls preload="none" src="battle/{weapon}-{action}.mp4"></video><figcaption>闯关实机 · {title}</figcaption></figure>')
        cards.append(f'<article id="w{weapon}" data-label="{label} {brief["family"]}"><h2>{label}</h2><div class="reference-label">美术方向参考</div>'+reference_html+'<p>引擎制作：逐把轨迹、切面、材质流动与独立粒子。上 / 中 / 下为普攻 / 重击 / 战技，各行 20 / 70 / 150 / 350 ms。</p>'+actual+'<div class="videos">'+''.join(videos)+'</div></article>')
        coverage.append({'weapon':weapon,'name':brief['name'],'reference':reference.relative_to(ROOT).as_posix() if reference.exists() else None,'native_capture':actual_file.exists()})
    style = '''body{margin:0;background:#0d141d;color:#e0e9f2;font:16px/1.65 system-ui}header,main{max-width:1440px;margin:auto;padding:24px}header{border-bottom:1px solid #34485b}h1{font-size:28px;margin-bottom:8px}h2{font-size:23px}p{color:#adbfce}a{color:#91cce3}nav{display:flex;flex-wrap:wrap;gap:6px}nav a{padding:4px 8px;background:#172737;border-radius:5px;font-size:13px;text-decoration:none}input{background:#172737;color:white;border:1px solid #4b687d;border-radius:5px;padding:10px;margin-bottom:20px;width:300px}article{padding:20px;margin-bottom:26px;background:#14212e;border:1px solid #2b4152;border-radius:9px;scroll-margin:15px}article[hidden]{display:none}.reference-label{color:#9ab4c7;font-size:13px}.reference{max-width:900px;margin:12px auto;background:#0c1721;overflow:hidden}.reference img{width:100%;max-height:490px;object-fit:contain;display:block}.reference.sheet{aspect-ratio:4/1}.reference.sheet img{max-height:none}.actual{width:100%;display:block}.videos{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}figure{margin:12px 0 0}figcaption{font-size:13px;text-align:center;color:#a8c1d1}video{width:100%;border-radius:5px}@media(max-width:850px){.videos{grid-template-columns:1fr}header,main{padding:12px}}'''
    script = '''document.querySelector('#filter').addEventListener('input',e=>{const q=e.target.value.toLowerCase();for(const a of document.querySelectorAll('article'))a.hidden=!a.dataset.label.toLowerCase().includes(q)});'''
    ref_count = sum(item['reference'] is not None for item in coverage)
    capture_count = sum(item['native_capture'] for item in coverage)
    document = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>武器 VFX · 参考与引擎制作</title><style>'+style+'</style><header><h1>武器 VFX · 参考与引擎制作</h1><p>参考 '+str(ref_count)+' / 52 · 引擎逐把捕获 '+str(capture_count)+' / 52。参考图只用于设计；游戏中的效果由动态曲面、材质、实体弹体和粒子生成。</p><input id="filter" placeholder="搜索武器名、编号或类别"><nav>'+''.join(links)+'</nav></header><main>'+''.join(cards)+'</main><script>'+script+'</script></html>'
    (OUT/'index.html').write_text(document, encoding='utf-8')
    (OUT/'design-coverage.json').write_text(json.dumps(coverage, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'{OUT / "index.html"}: {ref_count}/52 references, {capture_count}/52 native captures')

if __name__ == '__main__':
    build()

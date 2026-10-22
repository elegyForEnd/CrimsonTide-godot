"""Publish only the two review samples, with original references and real combat clips."""
import html
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/vfx-samples'
SOURCE = ROOT / 'build/vfx-v6'
ACTIONS = [('normal', '普攻'), ('heavy', '蓄力重击'), ('art', '战技')]


def build():
    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        raise RuntimeError('ffmpeg is required')
    records = json.loads((SOURCE / 'battle-capture.json').read_text(encoding='utf-8'))
    records = [r for r in records if int(r['weapon']) in (600, 615)]
    if len(records) != 6 or any(r['real_hits'] < 1 for r in records):
        raise RuntimeError('The six sample clips must each contain real enemy contact')
    (OUT / 'battle').mkdir(parents=True, exist_ok=True)
    for record in records:
        key = f"{int(record['weapon'])}-{record['action']}"
        subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
                        '-framerate', '30', '-i', str(SOURCE / f'battle-frames/{key}-%03d.png'),
                        '-frames:v', str(int(record['frames'])), '-an', '-c:v', 'libx264',
                        '-threads', '2', '-crf', '17', '-pix_fmt', 'yuv420p',
                        '-movflags', '+faststart', str(OUT / f'battle/{key}.mp4')], check=True)
    cards = []
    for weapon, name in [(600, '绯红单手剑'), (615, '熔炉巨锤')]:
        sequence = OUT / f'battle/sequence-{weapon}.txt'
        sequence.write_text(''.join(f"file '{weapon}-{a}.mp4'\n" for a, _ in ACTIONS), encoding='utf-8')
        subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-f', 'concat',
                        '-safe', '0', '-i', str(sequence), '-c', 'copy', '-movflags', '+faststart',
                        str(OUT / f'sample-{weapon}.mp4')], check=True)
        videos = ''.join(
            f'<figure><video controls loop muted playsinline preload="metadata" poster="{weapon}-{a}.png" src="battle/{weapon}-{a}.mp4"></video><figcaption>{label} · <button data-rate="1">原速</button> <button data-rate="0.5">半速</button></figcaption></figure>'
            for a, label in ACTIONS)
        notes = ('出刀加速，真实命中后刀面停顿 40–60 ms 再收势；缩短拖尾，增加目标切口、轻微压缩和短促定向镜头反馈。'
                 if weapon == 600 else '爆发对齐伤害判定，真实命中后停顿 55–80 ms；落点立即压亮，熔火快速塌落，碎岩随后抛散，镜头短促冲击后回正。')
        compare = ''
        if (OUT / f'before-weight/sample-{weapon}.mp4').exists():
            compare = f'<h3>力量感调整 · 前后原速对照</h3><div class="compare"><figure><video controls muted playsinline preload="metadata" src="before-weight/sample-{weapon}.mp4"></video><figcaption>调整前</figcaption></figure><figure><video controls muted playsinline preload="metadata" src="sample-{weapon}.mp4"></video><figcaption>当前版本</figcaption></figure></div><button class="sync">从头同时播放</button>'
        cards.append(f'<article><h2>{html.escape(name)}</h2><p>{notes}</p>'
                     f'<h3>原始参考 · 上方动作关键帧</h3><div class="reference"><img src="../../art/weapon-vfx-reference-v6/plates/weapon-{weapon}.png" alt="原始参考上方关键帧"></div>'
                     f'<h3>当前引擎样例 · 普攻 / 重击 / 战技</h3><img class="actual" src="weapon-{weapon}.png" alt="实际渲染">'
                     '<h3>真实战斗录像 · 含起手、命中和消散</h3><div class="videos">'+videos+'</div>'+compare+'</article>')
    style = '''*{box-sizing:border-box}body{margin:0;background:#10141c;color:#e6e7ec;font:16px/1.7 system-ui}main{max-width:1320px;margin:auto;padding:28px}h1{font-size:28px}h2{font-size:23px}h3{font-size:16px;color:#c2c6d2}p{color:#b1b9c8}article{margin:32px 0;padding:22px;background:#191f2b;border:1px solid #343b4a;border-radius:10px}.reference{aspect-ratio:4/1;overflow:hidden;background:#090d13}.reference img{width:100%;display:block}.actual{width:100%;display:block}.videos{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}figure{margin:0}video{width:100%;display:block}figcaption{font-size:14px;margin-top:8px}button{background:#323c50;color:#f3f4f7;border:1px solid #65728b;border-radius:4px;padding:3px 8px;cursor:pointer}@media(max-width:800px){main{padding:12px}article{padding:12px}.videos{grid-template-columns:1fr}}'''
    style += '.compare{display:grid;grid-template-columns:1fr 1fr;gap:12px}.sync{margin-top:12px}@media(max-width:800px){.compare{grid-template-columns:1fr}}'
    script = '''document.querySelectorAll('button[data-rate]').forEach(b=>b.onclick=()=>{b.closest('figure').querySelector('video').playbackRate=Number(b.dataset.rate)});document.querySelectorAll('.sync').forEach(b=>b.onclick=()=>b.previousElementSibling.querySelectorAll('video').forEach(v=>{v.currentTime=0;v.playbackRate=1;v.play()}));'''
    doc = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>两把武器 · 样例验收</title><style>'+style+'</style><main><h1>单手剑与巨锤 · 两把样例</h1><p>本轮只打磨这两把的普攻、重击和战技。原图仅为美术参考，实机由网格和材质制作。参考与实机仍有造型、绘画质感的差别，页面供直接对照；其余武器尚未按此标准验收。</p>'+''.join(cards)+'</main><script>'+script+'</script></html>'
    (OUT / 'index.html').write_text(doc, encoding='utf-8')
    (OUT / 'capture-report.json').write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Built two-sample review and six real-contact clips:', OUT)


if __name__ == '__main__':
    build()

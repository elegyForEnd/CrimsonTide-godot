"""Prepare a dedicated real-combat capture and build the user's review page."""
import json
import shutil
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/weapon-606-reference'

def prepare_capture():
    source=(ROOT/'tools/record_weapon_hybrid_battle.gd').read_text(encoding='utf-8')
    source=source.replace('res://build/vfx-hybrid/','res://output/weapon-606-reference/')
    source=source.replace('hybrid-v7-painted-bold-smoke-4','606-storyboard-path-frost-2')
    source=source.replace('range(600,648)+[17,18,19,20]','[606]')
    source=source.replace('180 if Catalog.weapon_family(weapon) in [0,3] else 85','85 if action=="normal" else 170')
    line='image.save_jpg(OUT+'
    snapshot='if frame in [0,3,6,9,12,15,18,21,24,30] or (action=="heavy" and frame-release_frame in [0,2,4,6,9,12]): image.save_png(OUT+"posters/%s-frame-%02d.png" % [action,frame])\n\t\t\t\t'
    source=source.replace(line,snapshot+line)
    (ROOT/'tools/record_weapon_606_reference.gd').write_text(source,encoding='utf-8')

def build():
    OUT.mkdir(exist_ok=True,parents=True)
    shutil.copyfile(ROOT/'art/weapon-606-action-v1/components.jpg',OUT/'components.jpg')
    shutil.copyfile(ROOT/'output/weapon-606-action-reference/full-action-v1.png',OUT/'storyboard.png')
    shutil.copyfile(ROOT/'output/texiaocankao/exec-ac059584-d5ad-4e22-9dfd-91c5e86a6bf6.png',OUT/'reference.png')
    sections=[]
    records=json.loads((OUT/'battle-capture.json').read_text(encoding='utf-8'))
    for action,title in [('normal','普通攻击'),('heavy','蓄力重击'),('art','战技 · 冰晶贯穿')]:
        row=next(r for r in records if r['action']==action)
        if row['real_hits']<1 or row['damage']<=0 or row['revision']!='606-storyboard-path-frost-2': raise ValueError('Capture must contain current-revision real combat hits')
        sections.append(f'<section><h2>{title}</h2><video controls loop muted playsinline preload="metadata" poster="posters/606-{action}.png" src="close/606-{action}.mp4"></video><p><a href="battle/606-{action}.mp4">完整战场录像</a> · 实际命中 {row["real_hits"]} 次</p><details><summary>查看关键帧</summary><div class="frames">'+''.join(f'<a href="posters/{p.name}"><img src="posters/{p.name}" loading="lazy"><small>{p.stem}</small></a>' for p in sorted((OUT/'posters').glob(f'{action}-frame-*.png')) )+'</div></details></section>')
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>星霜佩剑 · 第一把验收</title><style>body{margin:0;background:#101923;color:#e5edf5;font:16px/1.6 system-ui}main{max-width:1100px;margin:auto;padding:28px}h1{font-size:28px}h2{font-size:22px}p{color:#a9bfce}section{padding:20px;background:#192635;border:1px solid #34495e;border-radius:10px;margin:22px 0}img,video{width:100%;display:block;border-radius:5px}a{color:#a8d9f4}button{padding:8px 14px;margin:8px;color:#e5edf5;background:#2e4d68;border:1px solid #668cab;border-radius:5px;cursor:pointer}.frames{display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-top:16px}summary{cursor:pointer}small{color:#93b0c7}</style><main><h1>星霜佩剑 · 第一把验收</h1><p>根据指定冰晶参考重新制作。下方视频来自实际闯关战斗，包含合法命中；未标记为验收通过。等你确认这一把后，再制作其他武器。</p><div><button onclick="document.querySelectorAll('video').forEach(v=>v.playbackRate=1)">原速</button><button onclick="document.querySelectorAll('video').forEach(v=>v.playbackRate=.5)">半速</button></div><section><h2>你的参考图</h2><img src="reference.png"></section>'''+''.join(sections)+'''<section><h2>本次制作的六张独立素材</h2><img src="components.jpg"><p>晶面、定向碎裂、冷粉、地面霜裂、单块冰晶、聚能凝冰。</p></section></main></html>'''
    page=page.replace('根据指定冰晶参考重新制作。','按六阶段完整动作分镜制作：聚冰、刺出、命中、碎裂、拖尾和冷雾收净。拖尾记录真实出刀轨迹，烟雾粒子各自漂移和扩散。')
    page=page.replace('<section><h2>你的参考图</h2><img src="reference.png"></section>','<section><h2>完整动作依据</h2><img src="storyboard.png"></section><details><summary>原始参考</summary><img src="reference.png"></details>')
    page=page.replace('六张独立素材','七张独立素材').replace('单块冰晶、聚能凝冰。','单块冰晶、聚能凝冰、独立拖尾纹理。')
    page=page.replace('.mp4"','.mp4?v=path-frost-2"')
    (OUT/'index.html').write_text(page,encoding='utf-8')
    encoder=shutil.which('ffmpeg') or 'D:/develop/ffmpeg-2024-11-21-git-f298507323-full_build/bin/ffmpeg.exe'
    args=[encoder,'-hide_banner','-loglevel','error','-y']
    for action in ['normal','heavy','art']: args+=['-i',str(OUT/'close'/f'606-{action}.mp4')]
    args+=['-filter_complex','[0:v][1:v][2:v]concat=n=3:v=1:a=0[v]','-map','[v]','-an','-c:v','libx264','-threads','2','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'preview.mp4')]
    subprocess.run(args,check=True)
    print(OUT/'index.html')

if __name__=='__main__':
    import sys
    if '--prepare' in sys.argv: prepare_capture()
    else: build()

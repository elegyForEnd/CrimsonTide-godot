"""Build a five-weapon reference/real-combat review bundle, never a mock video."""
import hashlib
import html
import json
import shutil
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/weapon-batch-01'
IDS=[607,608,612,614,617]
REVISION='batch01-three-stage-60fps-9'
ACTIONS=[('normal','普攻'),('heavy','重击'),('art','战技')]
SEQUENCES={607:'突进刺击 → 折向上斩 → 雷刃收尾',608:'破封突刺 → 交叉裁切 → 纸带裁决',612:'挑斩 → 跃进追斩 → 落地震裂',614:'低位旋斩 → 推进土脊 → 前方崩裂',617:'上挑 → 腾空追斩 → 巨弧天罚'}

def build():
    specification=json.loads((ROOT/'art/weapon-batch-01/production.json').read_text(encoding='utf-8'))
    specs={r['id']:r for r in specification['weapons']}
    captures=json.loads((OUT/'battle-capture.json').read_text(encoding='utf-8'))
    records={(int(r['weapon']),r['action']):r for r in captures if r['revision']==REVISION and r['real_hits']>0 and r['damage']>0}
    if len(records)!=15: raise ValueError(f'Need 15 current real-hit clips; found {len(records)}')
    for weapon in IDS:
        r=records[(weapon,'art')]
        if r['real_hits']<3 or r['sequence_steps']!=[0,1,2] or r['displacement']<35:
            raise ValueError(f'Missing real three-stage movement: {weapon}')
    for name in ['references','sources']: (OUT/name).mkdir(exist_ok=True,parents=True)
    cards=[]; coverage=[]
    for weapon in IDS:
        spec=specs[weapon]
        reference=Path(spec['reference'])
        shutil.copyfile(reference,OUT/f'references/{weapon}-full.png')
        detail=ROOT/'art/weapon-batch-01/617/user-reference-detail.png'
        shutil.copyfile(detail if weapon==617 else reference,OUT/f'references/{weapon}.png')
        shapes=json.loads((ROOT/f'assets/combat/weapon-batch-01/{weapon}/shapes.json').read_text(encoding='utf-8'))['clips']
        sources={}
        for action,_ in ACTIONS:
            row=shapes[action]
            source=ROOT/row['file'].removeprefix('res://')
            if hashlib.sha256(source.read_bytes()).hexdigest()!=row['sha256']: raise ValueError('Original artwork changed')
            shutil.copyfile(source,OUT/f'sources/{weapon}-{action}.png')
            sources[action]={'file':f'sources/{weapon}-{action}.png','single_peak':row.get('single_peak',False)}
            for view in ['battle','close']:
                if not (OUT/view/f'{weapon}-{action}.mp4').is_file(): raise ValueError('Missing video')
        labels=''.join(f'<button data-action="{action}" class="{"selected" if action=="art" else ""}">{label}</button>' for action,label in ACTIONS)
        cards.append(f'''<article id="w{weapon}" data-weapon="{weapon}" data-action="art" data-view="close"><h2>{html.escape(spec['name'])}<small>{weapon}</small></h2><div class="actions">{labels}</div>
<div class="pair"><figure><figcaption>参考画面</figcaption><a href="references/{weapon}-full.png" target="_blank"><img class="media" src="references/{weapon}.png" alt="参考"></a></figure><figure><figcaption>真实战斗录像</figcaption><video class="media" controls loop muted playsinline preload="none" poster="posters/{weapon}-art.png" src="close/{weapon}-art.mp4?v=4"></video></figure></div>
<div class="controls"><button data-speed="1" class="selected">原速</button><button data-speed="0.5">半速</button><button data-speed="0.25">四分之一速</button><button data-view="close" class="selected">近景</button><button data-view="battle">完整战场</button></div>
<p>{SEQUENCES[weapon]}。战技连续三次真实攻击；收尾按最新反馈缩小约 24%，前两段缩小约 5%。人物沿用原精灵图，突进与腾空由真实位置驱动。</p>
<details><summary>新动作设计依据（每行：普攻、重击、战技三段）</summary><a href="storyboards/batch01-sequences-v2.png" target="_blank"><img src="storyboards/batch01-sequences-v2.png" loading="lazy"></a></details>
<details><summary>本次采用的动作主形</summary><p class="source-note"></p><a class="source-link" href="sources/{weapon}-art.png" target="_blank"><img class="source-image" src="sources/{weapon}-art.png" loading="lazy"></a></details>
<details><summary>分层与接触检查图</summary><a href="review/weapon-{weapon}.png" target="_blank"><img src="review/weapon-{weapon}.png" loading="lazy"></a></details></article>''')
        coverage.append({'weapon':weapon,'name':spec['name'],'sources':sources,'actions':{a:records[(weapon,a)] for a,_ in ACTIONS}})
    style='''*{box-sizing:border-box}body{margin:0;background:#0e1620;color:#e7eff7;font:16px/1.65 system-ui}main{max-width:1260px;margin:auto;padding:24px}h1{font-size:28px;margin:0}h2{font-size:23px;margin:0 0 12px}small{font-size:14px;color:#90a9bf;margin-left:12px}p{color:#a8bbce}nav{display:flex;flex-wrap:wrap;gap:8px;margin:18px 0}a{color:#a6d8fa}nav a,button{border:1px solid #45647e;border-radius:5px;padding:7px 12px;background:#1c3044;color:#deedfa;text-decoration:none;cursor:pointer}button.selected{background:#355d7f;border-color:#a5c9e3}button{margin:0 7px 8px 0}article{background:#152332;border:1px solid #30465c;border-radius:10px;padding:20px;margin:24px 0;scroll-margin:16px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}figcaption{color:#a8bfd4;font-size:14px;margin-bottom:6px}.media{display:block;width:100%;height:335px;background:#0a111a;object-fit:contain;border-radius:5px}.controls{margin-top:14px}details{border-top:1px solid #2a4055;margin-top:12px;padding-top:12px}summary{cursor:pointer;color:#b4d0e8}details img{display:block;width:100%;margin-top:14px}.source-image{max-height:1000px;object-fit:contain;background:#101c29}header{border-bottom:1px solid #2a4055;padding-bottom:12px}.intro{max-width:900px}@media(max-width:800px){main{padding:12px}.pair{grid-template-columns:1fr}.media{height:auto;max-height:520px}article{padding:14px}}'''
    payload=json.dumps({str(r['weapon']):r['sources'] for r in coverage},ensure_ascii=False)
    script='''const sources=SOURCE_DATA;document.querySelectorAll('article').forEach(card=>{const v=card.querySelector('video');let speed=1;function source(){const playing=!v.paused;v.src=card.dataset.view+'/'+card.dataset.weapon+'-'+card.dataset.action+'.mp4?v=4';v.poster='posters/'+card.dataset.weapon+'-'+card.dataset.action+'.png';v.playbackRate=speed;if(playing)v.play();const s=sources[card.dataset.weapon][card.dataset.action];card.querySelector('.source-image').src=s.file;card.querySelector('.source-link').href=s.file;card.querySelector('.source-note').textContent=s.single_peak?'实际形状主图：运动由连续展开、断尾和侵蚀控制。':'独立动作阶段图：共用画布与锚点，按连续运动展开，阶段信息控制密度和消散。'}card.querySelectorAll('[data-action]').forEach(b=>b.onclick=()=>{card.dataset.action=b.dataset.action;card.querySelectorAll('[data-action]').forEach(x=>x.classList.toggle('selected',x===b));source()});card.querySelectorAll('[data-speed]').forEach(b=>b.onclick=()=>{speed=Number(b.dataset.speed);v.playbackRate=speed;card.querySelectorAll('[data-speed]').forEach(x=>x.classList.toggle('selected',x===b))});card.querySelectorAll('[data-view]').forEach(b=>b.onclick=()=>{card.dataset.view=b.dataset.view;card.querySelectorAll('[data-view]').forEach(x=>x.classList.toggle('selected',x===b));source()});source()});'''.replace('SOURCE_DATA',payload)
    nav=''.join(f'<a href="#w{i}">{html.escape(specs[i]["name"])}</a>' for i in IDS)
    page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>五把武器 · 实际形状修订预览</title><style>{style}</style><main><header><h1>五把武器 · 实际形状修订预览</h1><p class="intro">主形改为按参考绘制的实际形状，普攻、重击、战技各有独立造型。修正前摇到峰值的交接、拖尾断开，以及命中与烟尘的主次。人物沿用原精灵图。录像为 60 帧，支持原速、半速和四分之一速。本批等待验收，再继续下一批。</p><nav>{nav}</nav></header>{''.join(cards)}<p><a href="preview.mp4">五把战技实机串联视频</a> · <a href="coverage.json">录制与素材记录</a></p></main><script>{script}</script></html>'''
    page=page.replace('?v=4','?v=9')
    page=page.replace('五把武器 · 实际形状修订预览','五把武器 · 三段战技与普攻修订')
    page=page.replace('主形改为按参考绘制的实际形状，普攻、重击、战技各有独立造型。修正前摇到峰值的交接、拖尾断开，以及命中与烟尘的主次。人物沿用原精灵图。录像为 60 帧，支持原速、半速和四分之一速。本批等待验收，再继续下一批。','普攻新增五张特色主图，重击保留蓄力单次爆发，战技改为带实际位移的三段招式，并新增五张收尾主图。按最新反馈，收尾尺寸已收小约 24%。人物仍使用原精灵图。十五段实机录像均为 60 帧，支持慢放；先验收本批。')
    (OUT/'index.html').write_text(page,encoding='utf-8')
    (OUT/'coverage.json').write_text(json.dumps({'revision':REVISION,'weapons':5,'real_hit_clips':15,'entries':coverage},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    encoder=shutil.which('ffmpeg') or 'D:/develop/ffmpeg-2024-11-21-git-f298507323-full_build/bin/ffmpeg.exe'
    command=[encoder,'-hide_banner','-loglevel','error','-y']
    for weapon in IDS: command+=['-i',str(OUT/f'close/{weapon}-art.mp4')]
    command+=['-filter_complex',''.join(f'[{i}:v]' for i in range(5))+'concat=n=5:v=1:a=0[v]','-map','[v]','-an','-c:v','libx264','-threads','2','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'preview.mp4')]
    subprocess.run(command,check=True)
    specification['status']='revision_ready_for_user_acceptance'
    specification['character']='original sprites retained; replacement drafts canceled and excluded'
    for entry in specification['weapons']: entry['status']='awaiting_user_acceptance'
    (ROOT/'art/weapon-batch-01/production.json').write_text(json.dumps(specification,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Review bundle: 5 weapons, 15 real-hit clips, 15 independently authored action sources')

if __name__=='__main__': build()

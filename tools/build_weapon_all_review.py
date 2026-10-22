"""Reference, source provenance and real-combat playback for all remaining weapons."""
import argparse
import hashlib
import html
import json
import shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/weapon-all-v2'
REVISION='all-v2-reference-4'
ACTIONS=[('normal','普攻'),('heavy','重击'),('art','三段战技')]

def build(require_complete=False):
    production=json.loads((ROOT/'art/weapon-all-v2/production.json').read_text(encoding='utf-8'))
    captures=json.loads((OUT/'battle-capture.json').read_text(encoding='utf-8')) if (OUT/'battle-capture.json').exists() else []
    records={(int(r['weapon']),r['action']):r for r in captures if (r['revision']==REVISION or (int(r['weapon'])<624 and r['revision']=='all-v2-reference-1') or (624<=int(r['weapon'])<636 and r['revision'] in ['all-v2-reference-2','all-v2-reference-3'])) and r['real_hits']>0 and r['damage']>0}
    for folder in ['references','sources']: (OUT/folder).mkdir(exist_ok=True,parents=True)
    cards=[]; ready=[]; pending=[]
    for spec in production['weapons']:
        weapon=spec['id']
        complete=all((weapon,action) in records for action,_ in ACTIONS)
        name=html.escape(spec['name'])
        if not complete:
            pending.append(weapon)
            cards.append(f'<article class="pending" data-family="{spec["family"]}"><h2>{name}<small>{weapon} · 第 {spec["batch"]} 批</small></h2><p>制作与实机检查中。</p></article>')
            continue
        for action,_ in ACTIONS:
            r=records[(weapon,action)]
            if r['fps']!=60 or r['frames']!=144: raise ValueError('Invalid capture format')
            if action=='art' and r['sequence_steps']!=[0,1,2]: raise ValueError('Missing three phases')
            for view in ['battle','close']:
                if not (OUT/view/f'{weapon}-{action}.mp4').exists(): raise ValueError('Missing clip')
        source=ROOT/spec['atlas']
        if hashlib.sha256(source.read_bytes()).hexdigest()!=spec['sha256']: raise ValueError('Original source changed')
        shutil.copyfile(source,OUT/f'sources/{weapon}.png')
        shutil.copyfile(spec['reference'],OUT/f'references/{weapon}.png')
        board=Path(spec['storyboard']).name
        buttons=''.join(f'<button data-action="{a}" class="{"selected" if a=="art" else ""}">{label}</button>' for a,label in ACTIONS)
        cards.append(f'''<article id="w{weapon}" data-weapon="{weapon}" data-family="{spec['family']}" data-action="art" data-view="close"><h2>{name}<small>{weapon} · 第 {spec['batch']} 批</small></h2><div>{buttons}</div><div class="pair"><figure><figcaption>原始材质与风格参考</figcaption><a href="references/{weapon}.png" target="_blank"><img class="media" src="references/{weapon}.png" loading="lazy"></a></figure><figure><figcaption>真实战斗录像 · 60 帧</figcaption><video class="media" controls muted loop playsinline preload="none" poster="posters/{weapon}-art.png" src="close/{weapon}-art.mp4?v=1"></video></figure></div><div class="controls"><button data-speed="1" class="selected">原速</button><button data-speed=".5">半速</button><button data-speed=".25">四分之一速</button><button data-view="close" class="selected">近景</button><button data-view="battle">完整战场</button></div><p>普攻、重击、战技采用独立主形。战技按顺序释放三段，保留真实位移、命中、拖尾和烟尘。人物使用原精灵图。</p><details><summary>完整动作设计（对应本武器所在行）</summary><a href="storyboards/{board}" target="_blank"><img src="storyboards/{board}" loading="lazy"></a></details><details><summary>当前使用的透明素材图集</summary><p>前两行：普攻、重击、战技收尾、命中；中间两行：蓄力、碎片、烟雾、残留拖尾。枪弓与法杖另有一行独立弹体。素材按实测透明间隔采样，保留生成原图像素。</p><a href="sources/{weapon}.png" target="_blank"><img class="atlas" src="sources/{weapon}.png" loading="lazy"></a></details></article>''')
        ready.append(weapon)
        spec['status']='recorded_pending_user_review'
    if require_complete and pending: raise ValueError(f'Incomplete weapons: {pending}')
    style='''*{box-sizing:border-box}body{margin:0;background:#101923;color:#e6eff7;font:16px/1.6 system-ui}main{max-width:1280px;margin:auto;padding:24px}h1{font-size:27px}h2{font-size:22px;margin:0 0 12px}small{font-size:13px;color:#93adc4;margin-left:12px}a{color:#b5dcff}p,figcaption{color:#afc0d0}article{padding:20px;margin:22px 0;background:#162637;border:1px solid #344e68;border-radius:9px}article.pending{opacity:.6}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}.media{width:100%;height:380px;object-fit:contain;background:#0a1119}button{padding:7px 12px;background:#203b53;border:1px solid #537089;color:#e8f2fc;border-radius:4px;margin:0 8px 8px 0;cursor:pointer}button.selected{background:#406b8e}.controls{margin-top:12px}details{border-top:1px solid #30485d;margin-top:12px;padding-top:12px}summary{cursor:pointer}details img{width:100%;margin-top:12px}.atlas{max-height:1400px;object-fit:contain;background:#0d1720}.nav{display:flex;flex-wrap:wrap;gap:10px;margin:18px 0}.nav a{padding:5px 10px;border:1px solid #415e77;border-radius:4px}@media(max-width:800px){main{padding:12px}.pair{grid-template-columns:1fr}.media{height:auto;max-height:600px}}'''
    script='''document.querySelectorAll('article[data-weapon]').forEach(card=>{const v=card.querySelector('video');let speed=1;function source(){const playing=!v.paused;v.src=card.dataset.view+'/'+card.dataset.weapon+'-'+card.dataset.action+'.mp4?v=1';v.poster='posters/'+card.dataset.weapon+'-'+card.dataset.action+'.png';v.playbackRate=speed;if(playing)v.play()}card.querySelectorAll('[data-action]').forEach(b=>b.onclick=()=>{card.dataset.action=b.dataset.action;card.querySelectorAll('[data-action]').forEach(x=>x.classList.toggle('selected',x===b));source()});card.querySelectorAll('[data-speed]').forEach(b=>b.onclick=()=>{speed=Number(b.dataset.speed);v.playbackRate=speed;card.querySelectorAll('[data-speed]').forEach(x=>x.classList.toggle('selected',x===b))});card.querySelectorAll('[data-view]').forEach(b=>b.onclick=()=>{card.dataset.view=b.dataset.view;card.querySelectorAll('[data-view]').forEach(x=>x.classList.toggle('selected',x===b));source()})});document.querySelectorAll('[data-filter]').forEach(b=>b.onclick=()=>{document.querySelectorAll('article').forEach(c=>c.hidden=b.dataset.filter!=='all'&&c.dataset.family!==b.dataset.filter)});'''
    nav=''.join(f'<a href="#w{s["id"]}">{html.escape(s["name"])}</a>' for s in production['weapons'] if s['id'] in ready)
    page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>全部武器 · 新参考特效制作</title><style>{style}</style><main><h1>全部武器 · 新参考特效制作</h1><p>其余 42 把：当前 {len(ready)} 把已有三种动作的实机录像，{len(pending)} 把仍在制作检查。按最新反馈控制尺寸，普攻突出特色，重击集中爆发，战技采用三段节奏。人物保持原精灵图。</p><p><a href="../weapon-batch-01/">第一批五把（尺寸再次缩小版）</a> · <a href="../weapon-606-reference/">已完成的星霜佩剑</a> · <a href="coverage.json">制作与录制记录</a></p><div><button data-filter="all">全部</button><button data-filter="1">单手刃</button><button data-filter="2">重武器</button><button data-filter="0">枪弓</button><button data-filter="3">法杖</button></div><nav class="nav">{nav}</nav>{''.join(cards)}</main><script>{script}</script></html>'''
    page=page.replace('?v=1','?v=4')
    if not pending:
        page=page.replace('其余 42 把：当前 42 把已有三种动作的实机录像，0 把仍在制作检查。','其余 42 把已接入，并完成普攻、重击、战技共 126 段实机录像。连同第一批五把与星霜佩剑，覆盖 48 把正式武器。')
    page=page.replace('<main>','<main>'+'<aside style="padding:18px;background:#453923;color:#fff">这是此前三段编排的存档录像。<a href="../weapon-revision-v3/index.html">打开当前节奏与尺寸修订版</a></aside>',1)
    (OUT/'index.html').write_text(page,encoding='utf-8')
    (OUT/'coverage.json').write_text(json.dumps({'revision':REVISION,'ready':ready,'pending':pending,'real_hit_clips':len(records),'records':list(records.values())},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (ROOT/'art/weapon-all-v2/production.json').write_text(json.dumps(production,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Review: {len(ready)}/42 weapons with {len(records)} real-hit clips; pending {pending}')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--require-complete',action='store_true');args=p.parse_args()
    build(args.require_complete)

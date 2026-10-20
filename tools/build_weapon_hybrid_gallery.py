"""Publish actual final-revision captures, with source artwork visible for review."""
import argparse
import html
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/vfx-hybrid'
ASSETS=ROOT/'assets/combat/weapon-hybrid-v7'
ACTIONS=[('normal','普攻'),('heavy','蓄力重击'),('art','战技')]

def resource_url(path):
    return '../../'+path.removeprefix('res://')

def build(allow_incomplete=False):
    revision=re.search(r'const REVISION="([^"]+)"',(ROOT/'tools/record_weapon_hybrid_battle.gd').read_text(encoding='utf-8')).group(1)
    briefs=json.loads((ROOT/'art/weapon-vfx-reference-v6/briefs.json').read_text(encoding='utf-8'))
    records=json.loads((OUT/'battle-capture.json').read_text(encoding='utf-8'))
    current={(int(r['weapon']),r['action']):r for r in records if r.get('revision')==revision and r['real_hits']>0}
    inventory={int(r['weapon']):r for r in json.loads((OUT/'inventory.json').read_text(encoding='utf-8'))}
    reviews={int(r['weapon']):r for r in json.loads((OUT/'review.json').read_text(encoding='utf-8')) if r.get('revision')==revision}
    cards=[]; links=[]; coverage=[]
    families={'blade':'轻刃','great':'重刃','ranged':'枪弓弩','magic':'法杖'}
    for brief in briefs:
        weapon=brief['id']; name=html.escape(brief['name']); row=inventory[weapon]
        actions={a:(weapon,a) in current and (OUT/f'battle/{weapon}-{a}.mp4').exists() and (OUT/f'close/{weapon}-{a}.mp4').exists() for a,_ in ACTIONS}
        coverage.append({'weapon':weapon,'name':brief['name'],'actions':actions,'review':weapon in reviews,'material':row['material'],'identity_texture':row['surface'],'painted_texture':row['paint']})
        links.append(f'<a href="#w{weapon}" data-jump="{weapon}">{name}</a>')
        ready=[a for a,_ in ACTIONS if actions[a]]
        chosen='art' if actions['art'] else ready[0] if ready else None
        buttons=''.join(f'<button class="action {"selected" if a==chosen else ""}" data-action="{a}" {"disabled" if not actions[a] else ""}>{label}</button>' for a,label in ACTIONS)
        video=(f'<video controls loop muted playsinline preload="none" src="close/{weapon}-{chosen}.mp4" poster="posters/{weapon}-{chosen}.png"></video>' if chosen else '<p>当前版本正在录制。</p>')
        reference=ROOT/f'art/weapon-vfx-reference-v6/finished/weapon-{weapon}.png'
        if not reference.exists(): reference=ROOT/f'art/weapon-vfx-reference-v6/plates/weapon-{weapon}.png'
        sheet='/plates/' in reference.as_posix()
        reference_html=f'<div class="reference {"sheet" if sheet else ""}"><img loading="lazy" src="../../{reference.relative_to(ROOT).as_posix()}" alt="{name}原参考"></div>'
        sources=[('战技刀光' if weapon==600 else '彩色主材质',row['paint']),('战技晶片' if weapon==600 else '独立轮廓素材',row['surface'])]
        if row['payloads']: sources.append(('实际弹体贴图',row['payloads'].get('normal',next(iter(row['payloads'].values())))))
        if row.get('impact'): sources.append(('命中素材',row['impact']))
        source_html=''.join(f'<figure><a href="{resource_url(path)}"><img loading="lazy" src="{resource_url(path)}" alt="{label}"></a><figcaption>{label}</figcaption></figure>' for label,path in sources)
        review_html=f'<details><summary>三种招式的引擎检查画面</summary><a href="review/weapon-{weapon}.png"><img loading="lazy" src="review/weapon-{weapon}.png" alt="引擎逐招捕获"></a><p>这是单独检查释放、接触层的测试场景；上方录像来自实际闯关战斗。</p></details>' if weapon in reviews else ''
        cards.append(f'<article id="w{weapon}" data-weapon="{weapon}" data-label="{name} {weapon} {row["material"]}" data-family="{brief["family"]}" data-current="{chosen or "art"}"><h2>{name}<small>{weapon} · {families[brief["family"]]}</small></h2><div class="actions">{buttons}</div>{video}<div class="playback"><button class="view selected" data-view="close">近景</button><button class="view" data-view="battle">完整范围</button><button class="speed" data-speed="1">原速</button><button class="speed" data-speed="0.5">半速</button></div><p>近景仅裁切同一段录像，完整范围保留原画面。包含起手、释放、真实命中、拖尾和消散。</p><details><summary>查看实际使用的贴图</summary><div class="sources">{source_html}</div></details><details><summary>参考图</summary>{reference_html}</details>{review_html}</article>')
    complete=sum(all(r['actions'].values()) for r in coverage)
    clip_count=sum(sum(r['actions'].values()) for r in coverage)
    review_count=sum(r['review'] for r in coverage)
    if not allow_incomplete and (complete!=52 or clip_count!=156 or review_count!=52):
        raise RuntimeError(f'Final revision incomplete: {complete}/52 weapons; {clip_count}/156 clips; {review_count}/52 reviews')
    style='''*{box-sizing:border-box}body{margin:0;background:#0d1119;color:#e9edf5;font:16px/1.7 system-ui}header,main{max-width:1120px;margin:auto;padding:24px}header{border-bottom:1px solid #34445b}h1{font-size:28px;margin:0 0 8px}h2{font-size:23px;margin:0 0 14px}h2 small{display:block;font-size:13px;color:#a3b5c9}p{color:#aab9ca}a{color:#98cfee}nav{display:flex;flex-wrap:wrap;gap:6px;max-height:150px;overflow:auto;margin-top:16px}nav a{font-size:13px;padding:3px 9px;background:#202c3d;border-radius:4px;text-decoration:none}input,select{padding:9px;border:1px solid #45617d;border-radius:5px;color:#edf4ff;background:#192536;margin-right:8px}article{padding:22px;margin-bottom:28px;background:#152030;border:1px solid #32465f;border-radius:10px;scroll-margin:20px}article[hidden]{display:none}button{background:#22344b;border:1px solid #4b6683;color:#e0efff;border-radius:5px;padding:8px 14px;cursor:pointer;margin-right:7px;margin-bottom:9px}button.selected{background:#35618b;border-color:#9ac6ed}button:disabled{opacity:.35;cursor:default}video{width:100%;display:block;max-height:700px;background:#0b131f;border-radius:6px}.playback{margin-top:14px}.actions{margin-bottom:7px}details{border-top:1px solid #31435b;margin-top:12px;padding-top:12px}summary{cursor:pointer;color:#b7cfe5}details img{width:100%;display:block;margin-top:14px}.reference{overflow:hidden;background:#0b1420}.reference.sheet{aspect-ratio:4/1}.sources{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}figure{margin:0}.sources img{height:140px;object-fit:contain;background:#0b1420}figcaption{font-size:13px;color:#a6b9ce;text-align:center}.progress{color:#c6e0f6;font-size:15px}@media(max-width:700px){header,main{padding:12px}article{padding:13px}.sources{grid-template-columns:1fr}button{padding:7px 10px}input{max-width:180px}}'''
    script='''function filter(){const q=document.querySelector('#query').value.toLowerCase(),f=document.querySelector('#family').value;document.querySelectorAll('article').forEach(a=>a.hidden=!(a.dataset.label.toLowerCase().includes(q)&&(!f||a.dataset.family===f)))}document.querySelector('#query').oninput=filter;document.querySelector('#family').onchange=filter;document.querySelectorAll('[data-jump]').forEach(a=>a.onclick=()=>{document.querySelector('#query').value='';document.querySelector('#family').value='';filter()});document.querySelectorAll('article').forEach(a=>{a.dataset.view='close';let v=a.querySelector('video');if(!v)return;function source(){const t=v.currentTime,playing=!v.paused;v.src=a.dataset.view+'/'+a.dataset.weapon+'-'+a.dataset.current+'.mp4';v.poster='posters/'+a.dataset.weapon+'-'+a.dataset.current+'.png';v.onloadedmetadata=()=>{v.currentTime=Math.min(t,v.duration||0);if(playing)v.play()}}a.querySelectorAll('[data-action]').forEach(b=>b.onclick=()=>{a.dataset.current=b.dataset.action;a.querySelectorAll('[data-action]').forEach(x=>x.classList.toggle('selected',x===b));source()});a.querySelectorAll('[data-view]').forEach(b=>b.onclick=()=>{a.dataset.view=b.dataset.view;a.querySelectorAll('[data-view]').forEach(x=>x.classList.toggle('selected',x===b));source()});a.querySelectorAll('[data-speed]').forEach(b=>b.onclick=()=>v.playbackRate=Number(b.dataset.speed))});'''
    state='当前版本已录制' if complete==52 else '当前版本录制中'
    document=f'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>武器特效 · 实机对照</title><style>{style}</style><header><h1>武器特效 · 实机对照</h1><p class="progress">{state}：{complete} / 52 种武器，{clip_count} / 156 段动作。</p><p>彩色贴图作为主视觉，结合独立运动轨迹、弹体、命中爆发、拖尾和烟尘。修正闯关透明合成后，贴图与辉光不再被重复衰减。伤害与攻击范围保持原逻辑。</p><input id="query" placeholder="搜索武器名、编号、材质"><select id="family"><option value="">全部类型</option>'+''.join(f'<option value="{k}">{v}</option>' for k,v in families.items())+'</select><nav>'+''.join(links)+'</nav></header><main>'+''.join(cards)+f'<p><a href="coverage.json">动作覆盖记录</a> · <a href="../../assets/combat/weapon-hybrid-v7/README.md">素材与提示词</a></p></main><script>'+script+'</script></html>'
    (OUT/'index.html').write_text(document,encoding='utf-8')
    (OUT/'coverage.json').write_text(json.dumps({'revision':revision,'weapons':complete,'clips':clip_count,'reviews':review_count,'entries':coverage},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{state}: {complete}/52 weapons, {clip_count}/156 clips, {review_count}/52 reviews')

def showcase():
    ffmpeg=shutil.which('ffmpeg')
    if not ffmpeg: raise RuntimeError('ffmpeg required')
    selections=[(613,'art'),(615,'art'),(619,'art'),(628,'heavy'),(637,'art'),(646,'normal')]
    args=[ffmpeg,'-hide_banner','-loglevel','error','-y']
    for weapon,action in selections: args+=['-i',str(OUT/f'close/{weapon}-{action}.mp4')]
    graph=';'.join(f'[{i}:v]scale=900:650:force_original_aspect_ratio=decrease,pad=900:650:(ow-iw)/2:(oh-ih)/2,setsar=1[v{i}]' for i in range(len(selections)))
    graph+=';'+''.join(f'[v{i}]' for i in range(len(selections)))+f'concat=n={len(selections)}:v=1:a=0[out]'
    args+=['-filter_complex',graph,'-map','[out]','-an','-c:v','libx264','-threads','2','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/'showcase.mp4')]
    subprocess.run(args,check=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--allow-incomplete',action='store_true'); parser.add_argument('--showcase',action='store_true'); args=parser.parse_args()
    build(args.allow_incomplete)
    if args.showcase: showcase()

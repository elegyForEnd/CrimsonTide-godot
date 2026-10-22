"""Review of the current cast rhythms, restrained staffs and textured ground."""
import json, html, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/weapon-revision-v3'
def build():
    OUT.mkdir(parents=True,exist_ok=True)
    specs=json.loads((ROOT/'resources/weapon_choreography_v2.json').read_text(encoding='utf-8'))
    catalog=json.loads((ROOT/'resources/rogue_build_content.json').read_text(encoding='utf-8'))['weapons']
    captures=json.loads((OUT/'battle-capture.json').read_text(encoding='utf-8')) if (OUT/'battle-capture.json').exists() else []
    records={(int(r['weapon']),r['action']):r for r in captures if r.get('revision')=='varied-arts-ground-3'}
    cards=[]
    for key,spec in specs.items():
        weapon=int(key); item=catalog[weapon-600]; steps=spec['steps']
        clips=[]
        for action,label in [('art','战技'),('heavy','重击')]:
            r=records.get((weapon,action))
            if not r: continue
            if r['real_hits']<=0: raise ValueError(f'No real hit: {weapon}/{action}')
            if action=='art' and r['sequence_steps']!=list(range(len(steps))): raise ValueError(f'Wrong cast rhythm: {weapon}')
            clips.append(f'<figure><figcaption>{label} · {r["real_hits"]} 次实机命中</figcaption><video controls muted loop playsinline preload="none" poster="posters/{weapon}-{action}.png" src="close/{weapon}-{action}.mp4?v=3"></video></figure>')
        rhythm=''.join(f'<span style="flex:{s[0]}">{s[0]:.2f}s<br>释放 {i+1}</span>' for i,s in enumerate(steps))
        cards.append(f'<article data-family="{item["family"]}"><h2>{html.escape(item["name"])} <small>{weapon}</small></h2><h3>{html.escape(spec["name"])}</h3><p>{html.escape(spec["desc"])}</p><div class="rhythm">{rhythm}</div><div class="clips">{"".join(clips)}</div></article>')
    ground=ROOT/'assets/combat/ground-rupture-v3/earth.png'
    summary={'revision':'varied-arts-ground-3','weapons':47,'release_counts':sorted(set(len(x['steps']) for x in specs.values())), 'real_hit_clips':len(records),'ground_sha256':hashlib.sha256(ground.read_bytes()).hexdigest(),'records':list(records.values())}
    (OUT/'coverage.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>武器特效·节奏与尺寸修订</title><style>body{margin:0;background:#10131a;color:#ddd;font:16px/1.6 system-ui}main{max-width:1200px;margin:auto;padding:28px}h1,h2{color:#fff}h2 small{font-size:14px;color:#9aa}article{border:1px solid #394050;border-radius:14px;padding:20px;margin:22px 0;background:#1b202b}h3{color:#e3c791}.rhythm{display:flex;gap:5px}.rhythm span{background:#37314b;border-bottom:3px solid #b99ae5;padding:7px;font-size:13px;text-align:center}.clips{display:flex;flex-wrap:wrap;gap:12px}figure{margin:15px 0;flex:1;min-width:320px}video,img{max-width:100%;width:100%;border-radius:9px}a{color:#c5b7ff}button{padding:8px 13px;margin:6px;background:#343b4c;color:#fff;border:0;border-radius:5px}header{position:sticky;top:0;background:#10131aee;z-index:1;padding:5px}</style><main><h1>武器特效 · 节奏与尺寸修订</h1><p>47 把武器逐把编排，采用一次至五次释放的不同节奏；星霜佩剑沿用原有独立动作。法杖重击长度与爆炸半径缩小约 35%，战技长度控制在 320–430、爆炸半径控制在 45–82。所有战技仍只扣一次法力、触发一次冷却。</p><p>下列录像均来自本轮实机录制；其余卡片展示已接入的动作节奏。录像可用下方按钮统一慢放。</p><header><button data-filter="all">全部</button><button data-filter="3">法杖</button><button data-filter="2">重武器</button><button data-filter="1">单手刃</button><button data-filter="0">枪弓</button><button data-speed="1">原速</button><button data-speed=".5">半速</button><button data-speed=".25">四分之一速</button></header><h2>地裂实机残留</h2><img src="614-ground-detail.png"><p>裂缝沿出招路径展开，包含暗色土石断面、碎石和局部亮边，随烟尘逐渐消退。</p>'''+''.join(cards)+'''</main><script>document.querySelectorAll('[data-filter]').forEach(b=>b.onclick=()=>document.querySelectorAll('article').forEach(c=>c.hidden=b.dataset.filter!=='all'&&c.dataset.family!==b.dataset.filter));document.querySelectorAll('[data-speed]').forEach(b=>b.onclick=()=>document.querySelectorAll('video').forEach(v=>v.playbackRate=Number(b.dataset.speed)));</script></html>'''
    (OUT/'index.html').write_text(page,encoding='utf-8')
    print(f'Current review: {len(specs)} cast designs, {len(records)} verified real-hit clips')
if __name__=='__main__': build()

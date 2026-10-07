"""Build review artifacts from unmodified production PNGs and Godot captures."""
import json
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/bosses/imagegen/actions'
specs=json.loads((BASE/'atlas-3x3-v5.json').read_text())['assets']
bodies=json.loads((BASE/'body-atlas-3x3-v5.json').read_text())['assets']
page='''<!DOCTYPE html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Boss 状态图集</title>
<style>body{margin:0;background:#141c27;color:#e5edf5;font:16px system-ui}header{padding:24px 32px;position:sticky;top:0;background:#141c27ee;z-index:2}h1{font-size:25px;margin:0 0 8px}select,button{background:#263445;color:inherit;border:1px solid #4c657e;border-radius:7px;padding:8px 12px;margin:7px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(310px,1fr));gap:18px;padding:20px 32px}article{background:#1b2634;border:1px solid #33455a;border-radius:12px;overflow:hidden}canvas{width:100%;display:block}article h2{font-size:17px;padding:0 16px}article p{padding:0 16px;color:#a8bacb;font-size:13px}a{color:#85cafa}</style>
<header><h1>Boss 多状态图集</h1><div>每个特效独立 3×3 · 蓄势 → 释放 → 持续 → 消散</div><select id="boss"><option value="all">全部 Boss</option></select><select id="state"><option value="all">完整序列</option><option value="prepare">蓄势</option><option value="contact">释放</option><option value="sustain">持续</option><option value="recover">消散</option></select><button id="pause">暂停</button></header><main id="grid"></main>
<script>const specs=DATA;const cards=[];for(const key of [...new Set(Object.values(specs).map(s=>s.identity))]){const o=document.createElement('option');o.value=key;o.textContent=key;boss.append(o)}
for(const [key,s] of Object.entries(specs)){const card=document.createElement('article');card.innerHTML='<h2>'+s.identity+' / '+s.role+'</h2><canvas width="450" height="350"></canvas><p>3×3 · 9 帧 · <a href="'+s.file+'">查看原始图集</a></p>';grid.append(card);const image=new Image();image.src=s.file;cards.push({card,s,image,ctx:card.querySelector('canvas').getContext('2d')})}
let running=true,t=0,last=0;pause.onclick=()=>{running=!running;pause.textContent=running?'暂停':'播放'};boss.onchange=()=>cards.forEach(c=>c.card.hidden=boss.value!=='all'&&boss.value!==c.s.identity);
function draw(now){if(running)t+=(now-last||0)/1000;last=now;for(const c of cards){if(c.card.hidden||!c.image.complete)continue;const frames=state.value==='all'?c.s.frames.map((_,i)=>i):c.s.states[state.value]||c.s.frames.map((_,i)=>i);const index=frames[Math.floor(t*7)%frames.length],f=c.s.frames[index],r=f.region,p=f.pivot;const scale=230/Math.max(c.s.height,c.s.reach);c.ctx.fillStyle='#1b2634';c.ctx.fillRect(0,0,450,350);const horizontal=['flow','field','projectile','directional','blade'].includes(c.s.style);const x=horizontal?85:225,y=horizontal?175:290;c.ctx.drawImage(c.image,r[0],r[1],r[2],r[3],x-p[0]*scale,y-p[1]*scale,r[2]*scale,r[3]*scale);c.ctx.fillStyle='#9daec0';c.ctx.fillText('帧 '+index,18,24)}requestAnimationFrame(draw)}requestAnimationFrame(draw)</script></html>'''
(BASE/'preview.html').write_text(page.replace('DATA',json.dumps({**specs,**bodies})),encoding='utf-8')
captures=ROOT/'build/boss-all-states-v5'
dest=ROOT/'build/boss-3x3-review'; dest.mkdir(parents=True,exist_ok=True)
keys=sorted({p.name.rsplit('-',2)[0] for p in captures.glob('*-contact.png')})
for key in keys:
    files=sorted(captures.glob(key+'-*-contact.png'))
    # Prefix matching must not mix a reused encounter table with its base identity.
    files=[p for p in files if p.name.rsplit('-',2)[0]==key]
    if not files: continue
    columns=4; rows=(len(files)+columns-1)//columns
    sheet=Image.new('RGB',(1600,rows*270),'#131b25'); draw=ImageDraw.Draw(sheet)
    for n,path in enumerate(files):
        im=Image.open(path); im.thumbnail((400,250)); x=n%4*400; y=n//4*270
        sheet.paste(im,(x,y+20)); draw.text((x+14,y+4),path.stem,fill='white')
    sheet.save(dest/(key+'.png'))
# A native-image animation preview: no repainting of the source artwork.
show=['knight_slash_v3','queen_sabres_v3','dragon_wings_v3','furnace_chain_v3','grove_roots_v3','abyss_jaw_snap_v3']
frames=[]
for index in range(9):
    sheet=Image.new('RGB',(1200,760),'#171f2b'); draw=ImageDraw.Draw(sheet)
    for n,key in enumerate(show):
        s=specs[key]; f=s['frames'][index]; r=f['region']; p=f['pivot']
        im=Image.open(BASE/s['file']); crop=im.crop((r[0],r[1],r[0]+r[2],r[1]+r[3])); scale=240/max(s['height'],s['reach'])
        crop=crop.resize((max(1,round(crop.width*scale)),max(1,round(crop.height*scale))),Image.Resampling.LANCZOS)
        x=n%3*400; y=n//3*380; horizontal=s['style'] in ['flow','field','directional','projectile','blade']
        ox,oy=(65,195) if horizontal else (200,325)
        sheet.paste(crop,(x+round(ox-p[0]*scale),y+round(oy-p[1]*scale)),crop)
        draw.text((x+20,y+20),key+' / frame '+str(index),fill='white')
    frames.append(sheet)
frames[0].save(dest/'states-3x3.gif',save_all=True,append_images=frames[1:],duration=[180,180,90,90,110,110,110,150,190],loop=0)
print('75 atlas clips in interactive gallery; contact pages for',len(keys),'encounter tables; 3x3 animation GIF')

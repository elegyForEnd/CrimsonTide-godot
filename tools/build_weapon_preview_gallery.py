"""Encode native-rendered weapon previews and build an offline viewing gallery."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json
import subprocess
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/vfx-3d/all'
FFMPEG = shutil.which('ffmpeg')
DESIGNS = dict(enumerate([
    '黏滞血膜弯切与血牙', '细轴贯刺与喙尖', '收拢回卷的绸刃', '错向双刃与倒刺',
    '细薄月弧与银屑', '上挑烛焰与灯芯', '斜切冰片与断裂刃面', '锯折电刃与延迟电弧',
    '断续封蜡切面', '错位双刃与镜片', '震颤铜刃与铃芒', '硬折黑曜楔面',
    '日钢下劈与放射光刺', '起伏水幕与浪尖', '岩脊斜砍与分叉地裂', '锤头砸落与熔渣裂地',
    '宽斧斜弧与骨冰片', '雷骸对角斩与折电', '垂直斩首血幕', '星石坠击与地面喷发',
    '宽壁切面与炭壳掀起', '长戟突进与风旗折叠', '向内回勾的魂丝', '重钢王冠斩与冠齿',
    '步枪短促气冲与窄弹芯', '长羽弯尾与羽刃弹体', '分叉弩口与倒刺箭芯', '钝口热焰与螺旋烛尾',
    '反弯弓尾与分束冰针', '短芯折电与跳动电枝', '厚重黑曜矛芯', '错位双枪口与双镜片',
    '轻羽反卷与倾斜羽片', '长轴贯穿与分瓣弹托', '震颤铜翼与铃芒', '上扬信号焰与日芒',
    '星屑弯曲聚合与星芒弹体', '熔石下坠与尖长热尾', '细轴分束的冰针', '跳折雷枝与折线电芯',
    '翻转月牙与弧形弹体', '棱片收束与分瓣光矛', '错向羽片与扇形飞羽', '非对称内吸旋涡',
    '暗壳长轴突刺', '折页刃面与飞行契页', '多层游魂布带与旋转魂丝', '高拱祈愿折带与钟芒'
], start=600))


def run(args):
    subprocess.run([FFMPEG, '-hide_banner', '-loglevel', 'error', '-y', *args],
                   check=True, cwd=ROOT)


def encode_page(page):
    folder = OUT / f'page-{page:02d}'
    target = OUT / f'page-{page:02d}.mp4'
    run(['-framerate', '50', '-i', str(folder / '%03d.png'), '-frames:v', '175',
         '-c:v', 'libx264', '-threads', '2', '-crf', '18', '-pix_fmt', 'yuv420p',
         '-movflags', '+faststart', str(target)])
    return page


def encode_weapon(item):
    page, slot, weapon = item['page'], item['slot'], item['weapon']
    crop = f'crop=480:340:{slot % 4 * 480}:{54 + slot // 4 * 350}'
    run(['-i', str(OUT / f'page-{page:02d}.mp4'), '-vf', crop, '-an',
         '-c:v', 'libx264', '-threads', '1', '-crf', '17', '-pix_fmt', 'yuv420p',
         '-movflags', '+faststart', str(OUT / f'weapon-{weapon}.mp4')])
    run(['-i', str(OUT / f'page-{page:02d}' / 'poster.png'), '-vf', crop,
         '-frames:v', '1', str(OUT / f'weapon-{weapon}.jpg')])
    return weapon


HTML = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>全部武器 · 三维特效预览</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#0c121c;color:#dae7ef;font:16px system-ui,"Microsoft YaHei",sans-serif}
header{position:sticky;top:0;z-index:2;background:#101b29f5;padding:18px 5vw;border-bottom:1px solid #334355}
h1{font-size:23px;margin:0 0 8px}p{color:#9ab0bf;margin:8px 0;line-height:1.7}
.controls{display:flex;gap:10px;flex-wrap:wrap;align-items:center}input,button,select{font:inherit;color:inherit;background:#1b2b3e;border:1px solid #455a70;border-radius:8px;padding:9px 14px}
button{cursor:pointer}button.active{background:#235b78;border-color:#6fcddd}input{min-width:240px;flex:1}
main{padding:22px 5vw}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(290px,1fr));gap:18px}
article{background:#111e2b;border:1px solid #2b3e50;border-radius:12px;overflow:hidden;cursor:pointer}article:hover{border-color:#7ac6d9}
article img{width:100%;display:block;aspect-ratio:480/340;object-fit:contain}article h2{font-size:17px;padding:0 16px;margin:12px 0}article p{padding:0 16px 12px;font-size:13px}
.count{font-size:14px;margin:12px 0;color:#9ab0bf}dialog{border:1px solid #58758c;border-radius:14px;background:#101b28;color:#e4edf2;width:min(1000px,95vw);padding:20px}dialog::backdrop{background:#000c}
dialog video{width:100%;max-height:64vh;display:block;background:#08111b}dialog h2{margin:0 0 12px;font-size:21px}.times{display:flex;flex-wrap:wrap;gap:8px;margin:14px 0}a{color:#8bdcf0}
.close{float:right}#groups{display:flex;gap:12px;flex-wrap:wrap;margin:15px 0}#groups a{padding:8px 12px;background:#1a2c3e;border-radius:7px}
</style><header><h1>全部武器 · 三维 VFX 动态预览</h1>
<p>48 把肉鸽武器 + 21 个剧情/临时武器入口。每段依次展示：普攻 → 聚能 → 满蓄力 → 松手重击 → 战技。</p>
<div class="controls"><button class="active" data-filter="rogue">肉鸽 48 把</button><button data-filter="story">剧情 / 临时 21 把</button><button data-filter="all">全部 69 个入口</button><input id="search" placeholder="输入武器名称或编号"><button id="playgroups">查看分组总览</button><button id="smoketoggle">9 张新烟雾原图</button><button id="bladetoggle">3 张刀光原图</button></div></header>
<main><p>每把武器使用独立的主体 RGBA 原图，配合各自动作与飞行尾迹。点击卡片可放大播放。<a href="blade-texture-layers.png" target="_blank">贴图分层对照</a> · <a href="weapon-surface-atlas-0.png" target="_blank">原图总览 1</a> · <a href="weapon-surface-atlas-1.png" target="_blank">原图总览 2</a>。画面由游戏实际空间特效渲染；每把武器按招式范围取景。</p><div id="groups" hidden></div><div id="smokes" class="grid" hidden></div><div id="count" class="count"></div><div id="grid" class="grid"></div></main>
<dialog id="viewer"><button class="close" id="close">关闭 ×</button><h2 id="title"></h2><video id="video" controls loop playsinline></video><div class="times"><button data-time="0">普攻</button><button data-time=".9">开始蓄力</button><button data-time="1.3">满蓄力保持</button><button data-time="1.6">松手重击</button><button data-time="2.5">战技</button></div><p>可暂停逐帧观察；左右方向键切换武器。<a id="download" download>下载此武器视频</a></p></dialog>
<script>
const weapons=__DATA__;let filter='rogue',current=0,visible=[];
const grid=document.getElementById('grid'),viewer=document.getElementById('viewer'),video=document.getElementById('video');
function render(){const q=document.getElementById('search').value.trim().toLowerCase();visible=weapons.filter(w=>(filter==='all'||(filter==='rogue'?w.weapon>=600:w.weapon<600))&&(`${w.weapon} ${w.name}`.toLowerCase().includes(q)));grid.replaceChildren();document.getElementById('count').textContent=`共 ${visible.length} 把 · 每把包含三类释放与完整蓄力过程`;for(const w of visible){const card=document.createElement('article');card.tabIndex=0;const img=document.createElement('img');img.src=`weapon-${w.weapon}.jpg?v=weapon-v5-polish-v7`;img.alt=w.name;img.loading='lazy';const name=document.createElement('h2');name.textContent=`${w.weapon} · ${w.name}`;const caption=document.createElement('p');caption.textContent=(w.design||'剧情武器 · 独立动作')+' · 点击播放三类招式';card.append(img,name,caption);card.onclick=()=>open(w);card.onkeydown=e=>{if(e.key==='Enter')open(w)};grid.append(card)}}
function open(w){current=visible.indexOf(w);document.getElementById('title').textContent=`${w.weapon} · ${w.name}`;video.src=`weapon-${w.weapon}.mp4?v=weapon-v5-polish-v7`;video.poster=`weapon-${w.weapon}.jpg?v=weapon-v5-polish-v7`;document.getElementById('download').href=video.src;if(!viewer.open)viewer.showModal();video.play().catch(()=>{})}
document.querySelectorAll('[data-filter]').forEach(b=>b.onclick=()=>{filter=b.dataset.filter;document.querySelectorAll('[data-filter]').forEach(x=>x.classList.toggle('active',x===b));render()});document.getElementById('search').oninput=render;document.getElementById('close').onclick=()=>viewer.close();viewer.onclose=()=>video.pause();document.querySelectorAll('[data-time]').forEach(b=>b.onclick=()=>{video.currentTime=Number(b.dataset.time);video.play().catch(()=>{})});document.onkeydown=e=>{if(viewer.open&&['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();open(visible[(current+(e.key==='ArrowRight'?1:-1)+visible.length)%visible.length])}};
const smokes=document.getElementById('smokes');for(const [key,label] of Object.entries({wind:'风丝',dust:'扬尘',cold:'冷雾',heat:'热烟',blood:'血雾',soul:'魂丝',void:'虚空内吸',ion:'离子残雾',incense:'轻烟'})){const card=document.createElement('article');const img=document.createElement('img');img.src=`smoke-${key}.png`;img.alt=label;img.loading='lazy';const title=document.createElement('h2');title.textContent=label;card.append(img,title);smokes.append(card)}smokes.style.display='none';document.getElementById('smoketoggle').onclick=()=>{smokes.hidden=!smokes.hidden;smokes.style.display=smokes.hidden?'none':'grid'};
const groups=document.getElementById('groups');for(let p=0;p<9;p++){const a=document.createElement('a');a.href=`page-${String(p).padStart(2,'0')}.mp4?v=weapon-v5-polish-v7`;a.textContent=p<6?`肉鸽总览 ${p+1} / 6`:`剧情总览 ${p-5} / 3`;a.target='_blank';groups.append(a)}document.getElementById('playgroups').onclick=()=>{groups.hidden=!groups.hidden;groups.style.display=groups.hidden?'none':'flex'};groups.style.display='none';render();
const blades=document.createElement('div');blades.className='grid';blades.hidden=true;blades.style.display='none';document.querySelector('main').prepend(blades);for(const w of weapons.filter(w=>w.weapon>=600||w.weapon>=17&&w.weapon<=20)){const card=document.createElement('article');const img=document.createElement('img');img.src=`surface-${w.weapon}.png`;img.alt=w.name;img.loading='lazy';const title=document.createElement('h2');title.textContent=`${w.weapon} · ${w.name}`;const link=document.createElement('a');link.href=img.src;link.target='_blank';link.append(img);card.append(link,title);blades.append(card)}document.getElementById('bladetoggle').onclick=()=>{blades.hidden=!blades.hidden;blades.style.display=blades.hidden?'none':'grid'};
</script></html>'''


def main():
    if not FFMPEG:
        raise SystemExit('ffmpeg is required')
    shutil.copyfile(ROOT / 'build/vfx-3d/blade-texture-layers.png', OUT / 'blade-texture-layers.png')
    for page in range(2):
        shutil.copyfile(ROOT / f'build/vfx-3d/weapon-surface-atlas-{page}.png', OUT / f'weapon-surface-atlas-{page}.png')
    for key in ['wind','dust','cold','heat','blood','soul','void','ion','incense']:
        shutil.copyfile(ROOT / f'assets/combat/imagegen-mechanics/smoke-v3/density_{key}_v3.png', OUT / f'smoke-{key}.png')
    for weapon in list(range(600,648))+list(range(17,21)):
        shutil.copyfile(ROOT / f'assets/combat/imagegen-mechanics/weapon-v5/weapon_{weapon}_surface_v5.png', OUT / f'surface-{weapon}.png')
    data = json.loads((OUT / 'coverage.json').read_text(encoding='utf-8'))
    for item in data:
        item['design'] = DESIGNS.get(item['weapon'], '剧情武器 · 独立动作')
    assert len(data) == 69 and len({w['weapon'] for w in data}) == 69
    for page in range(9):
        folder = OUT / f'page-{page:02d}'
        assert all((folder / f'{i:03d}.png').is_file() for i in range(175)), page
    with ThreadPoolExecutor(max_workers=3) as pool:
        for page in pool.map(encode_page, range(9)):
            print(f'Encoded group {page}', flush=True)
    with ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(encode_weapon, data))
    html=HTML.replace('3 张刀光原图','52 张专属原图').replace('__DATA__', json.dumps(data, ensure_ascii=False))
    (OUT / 'index.html').write_text(html, encoding='utf-8')
    print(f'GALLERY COMPLETE: {len(results)} individual videos, 9 group videos, 69 posters', flush=True)


if __name__ == '__main__':
    main()

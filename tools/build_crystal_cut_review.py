"""Review one native-engine art trial against the user's unchanged reference."""
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/vfx-crystal'


def build():
    records = json.loads((OUT / 'capture.json').read_text(encoding='utf-8'))
    if len(records) != 1 or records[0]['real_hits'] < 1:
        raise RuntimeError('The single art trial must have confirmed real enemy contact')
    record = records[0]
    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        raise RuntimeError('ffmpeg is required')
    subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-framerate',
                    str(int(record['fps'])), '-i', str(OUT / 'frames/600-art-%03d.png'),
                    '-frames:v', str(int(record['frames'])), '-an', '-c:v', 'libx264',
                    '-threads', '2', '-crf', '16', '-pix_fmt', 'yuv420p',
                    '-movflags', '+faststart', str(OUT / 'trial.mp4')], check=True)
    subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(OUT / 'trial.mp4'),
                    '-vf', 'crop=450:260:130:30,scale=900:520:flags=lanczos',
                    '-an', '-c:v', 'libx264', '-threads', '2', '-crf', '16',
                    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(OUT / 'detail.mp4')], check=True)
    # Preserve a native, unretouched capture as the poster.
    shutil.copyfile(OUT / 'frames/600-art-024.png', OUT / 'actual.png')
    doc = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>晶刃战技 · 单招试作</title><style>
*{box-sizing:border-box}body{margin:0;background:#11141c;color:#eee8f0;font:16px/1.7 system-ui}main{max-width:1120px;margin:auto;padding:24px}h1{font-size:27px}h2{font-size:19px;margin-top:26px}p{color:#bcb5c5}.panel{padding:20px;background:#1b1d29;border:1px solid #3b3246;border-radius:10px;margin:22px 0}img,video{display:block;width:100%;height:auto;border-radius:5px}button{background:#403044;color:#ffe7f2;border:1px solid #86627e;border-radius:5px;padding:8px 14px;cursor:pointer;margin:10px 8px 0 0}.phases{overflow:auto}.phases img{min-width:1100px}small{color:#bcb5c5}a{color:#eeb6d5}
</style><main><h1>单手剑 · 晶刃战技试作</h1>
<p>只试作武器 600 的战技。角色、场景与目标来自实际闯关场景；伤害、范围和击退沿用原逻辑。按你的选择，本版使用依据参考图重新制作的透明刀光和晶片贴图，结合动态网格、独立碎片、命中闪光和地面反光。</p>
<section class="panel"><h2>你提供的参考图</h2><img src="reference.png" alt="用户原始参考图"></section>
<section class="panel"><h2>当前实机 · 完整起手、命中与消散</h2><video id="actual" controls loop muted playsinline preload="metadata" poster="actual.png" src="trial.mp4"></video>
<button data-rate="1" data-video="actual">原速</button><button data-rate="0.5" data-video="actual">半速</button><button id="seek">查看命中帧</button>
<p>贴图保留绘画细节；游戏控制弯曲轨迹、命中点、停顿、飞散和消散。这仍是单招试作，与原始参考的造型和环境融合仍有差别。</p></section>
<section class="panel"><h2>亮度与厚度调整 · 同一招式原速对照</h2><div style="display:grid;grid-template-columns:1fr 1fr;gap:12px"><figure style="margin:0"><video id="before" controls muted playsinline preload="metadata" src="before-density.mp4"></video><figcaption>调整前：偏淡的贴图混合版</figcaption></figure><figure style="margin:0"><video id="after" controls muted playsinline preload="metadata" src="trial.mp4"></video><figcaption>当前：刀面加实、亮刃与接触辉光增强</figcaption></figure></div><button id="compare">同时从头播放</button><p><a href="before-textures.mp4">更早的程序材质版本</a></p></section>
<section class="panel"><h2>放大观察 · 同一录像裁切，未增加特效</h2><video id="detail" controls loop muted playsinline preload="metadata" src="detail.mp4"></video><button data-rate="1" data-video="detail">原速</button><button data-rate="0.5" data-video="detail">半速</button></section>
<section class="panel"><h2>引擎分时捕获</h2><div class="phases"><img src="phases.png" alt="55、100、180、300 毫秒的实际引擎捕获"></div><small>此图使用独立测试场景观察网格层次；上方视频是有敌人与实际伤害判定的闯关录制。测试通过只说明行为约束成立，不代表视觉达到参考图。</small></section>
<p>游戏中装备绯红单手剑，右键释放战技即可使用本次试作；普攻、重击与其他武器保持此前实现。<a href="capture.json">真实命中记录</a></p>
</main><script>document.querySelectorAll('[data-rate]').forEach(b=>b.onclick=()=>document.getElementById(b.dataset.video).playbackRate=Number(b.dataset.rate));document.querySelector('#seek').onclick=()=>{let v=document.querySelector('#actual');v.pause();v.currentTime=.40;};document.querySelector('#compare').onclick=()=>['before','after'].forEach(id=>{let v=document.getElementById(id);v.currentTime=0;v.playbackRate=1;v.play()});</script></html>'''
    (OUT / 'index.html').write_text(doc, encoding='utf-8')
    print('Built one-art trial, native poster, full-speed video and magnified detail:', OUT)


if __name__ == '__main__':
    build()

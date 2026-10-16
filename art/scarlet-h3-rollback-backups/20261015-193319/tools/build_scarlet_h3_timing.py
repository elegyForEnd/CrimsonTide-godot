"""Compute legal H3 timeline windows with 39-frame carried context."""
from pathlib import Path
import csv
import json
import math
import zipfile

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/scarlet-video-prompts'
DOC=ROOT/'docs/rpg/SCARLET-H3-TIMING.md'

def main():
    data=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    text='''# MiniMax H3：时长与重叠的实际设置

依据本机 TimelineDirector 的 `js/segment_windows.mjs`、`minimax_h3_finite_segments.py` 核对，2026-10-15。

## 先分清三种时间

- 剧情文档的秒数是最终剪辑预算；上一版 `timeline.csv` 是剪辑表，不能直接作为 H3 生成区间。
- 导演台每段范围为 `[startFrame,endFrame)`，实际生成帧数是 endFrame−startFrame，必须满足 **5＋17×n**，fps 保持 24。
- 原工作流相邻段重叠 39 帧＝1.625 秒。后一段起点＝上一段终点−39；合并输出会自动删除后一段开头的 39 帧。成片帧数＝各段生成帧数相加−39×(段数−1)。重叠不是额外播放一次的转场。

例如两段均为 175 帧（7.291667 秒）：第一段 0—175，第二段 136—311，重叠 39 帧，合并总长 311/24＝12.958333 秒，并非 14.583333 秒。

## 按你当前导演台怎么设

1. 保持 CreateVideo 为 24 fps，清空原 MV 素材和歌曲。每支 CIN 单独开一份，段数按本表。
2. 先创建所需段数，再逐段选择 GEN1、GEN2……。按下面详细表的起点、终点或长度调整生成窗口。界面会把长度吸附到合法帧数，修改前段还会推动后段；完成后复核所有帧值。优先以帧值为准，秒数保留六位。
3. `generation_seconds` 对应当前选中段的完整长度，包含接续上下文，不是整支片长。前端选中段时会同步其时间选区；检查它显示本表该段秒数。分段模式下后端实际逐段使用每个窗口的帧长。
4. 下面“39 帧接续方案”已算好生成窗口，无需再手工给后一段加 1.625 秒。合并视频也无需再剪掉 1.625 秒。只有拿各段原始视频到外部自行拼接时，才逐段裁去后一段的开头 39 帧。
5. **现在使用 v2 重写后的 TXT，不再自行加前缀。**每段已经分别写好上一段的具体末尾状态、局部 0—1.625 秒的带入画面、新内容的建立／动作／最后 39 帧收势。新内容从第 39 帧才开始；第一段没有前片重叠，直接从第 0 帧开始。TXT 中的时间是本段局部时间，下面表格的起止点是整片时间，不能混用。

## 哪些应该用重叠

v2 的同场运镜明确保持连续；换场、手部特写和记录回放明确在重叠结束后硬切，前 39 帧仍然属于上一镜。模型可能把指定硬切误做成渐变变形，此时单独重做该新镜头并外部剪接。独立生成时不能直接粘含前片的 v2 全文：只取新内容动作、去掉 carried context 并把新内容从 0 秒计时。下表给出独立生成时至少覆盖原剪辑预算的合法长度。

| 原镜头预算 | 独立生成帧数 | 导演台生成秒数 | 剪辑保留 |
|---:|---:|---:|---:|
'''
    for seconds in range(3,11):
        frames=5+17*math.ceil((seconds*24-5)/17)
        text+=f'| {seconds} 秒 | {frames} | {frames/24:.6f} | {seconds} 秒 |\n'
    text+='\n19 张 CG 循环同理：每张独立生成 **124 帧＝5.166667 秒**，无跨片重叠。以完整生成周期检查首尾，必要时衔接修复后重定时为 5 秒，不盲裁尾部破坏周期。\n\n## 保留原工作流 39 帧重叠：各影片总览\n\nv2 TXT 与本表逐段对应。按累计剧情预算向上对齐合法帧长，总长可能比预算多不足 0.709 秒，最终统一裁片尾或微调停顿。不是已生成的视频时长实测。\n\n| 影片 | 剧情预算 | 段数 | 合并帧数 | 合并秒数 | 每段生成秒数（依次） |\n|---|---:|---:|---:|---:|---|\n'
    details='';rows=[];plans=[]
    for f in data['cinematics']:
        prev=0;windows=[]
        for i,s in enumerate(f['segments']):
            end=5+17*math.ceil((s['end']*24-5)/17)
            overlap=39 if i else 0
            start=prev-overlap if i else 0
            length=end-start
            assert (length-5)%17==0 and length>overlap
            assert start>=0 and end>prev
            item=dict(shot=i+1,startFrame=start,endFrame=end,lengthFrames=length,
                      overlapFrames=overlap,generation_seconds=length/24,
                      net_new_seconds=(length-overlap)/24)
            assert item==dict(shot=i+1,**s['h3_window'])
            windows.append(item)
            rows.append([f['id'],i+1,start,end,length,overlap,f'{start/24:.6f}',f'{end/24:.6f}',f'{length/24:.6f}',f'{(length-overlap)/24:.6f}'])
            prev=end
        assert sum(w['lengthFrames']-w['overlapFrames'] for w in windows)==prev
        plans.append(dict(id=f['id'],budget=f['duration'],outputFrames=prev,outputSeconds=prev/24,windows=windows))
        durations=' / '.join(f'{w["generation_seconds"]:.3f}' for w in windows)
        text+=f'| {f["id"]} | {f["duration"]} 秒 | {len(windows)} | {prev} | {prev/24:.6f} | {durations} |\n'
        details+=f'\n### {f["id"]} {f["title"]}\n\n| 段 | 起帧 | 终帧（不含） | 生成帧数 | 起点秒 | 终点秒 | 生成秒数 | 净新增秒数 |\n|---:|---:|---:|---:|---:|---:|---:|---:|\n'
        for w in windows:
            details+=f'| {w["shot"]} | {w["startFrame"]} | {w["endFrame"]} | {w["lengthFrames"]} | {w["startFrame"]/24:.6f} | {w["endFrame"]/24:.6f} | {w["generation_seconds"]:.6f} | {w["net_new_seconds"]:.6f} |\n'
    text+='\n## 逐段设置表\n\nGEN1 的起点为 0；其余段重叠都是 39 帧。\n'+details
    text+='\n本表只计算合法几何与时长，未执行 GPU 生成。`h3-overlap39.json` 是设置参考数据，不是导演台完整导入预设。\n'
    DOC.write_text(text,encoding='utf-8')
    (OUT/'H3-时长与重叠设置.md').write_text(text,encoding='utf-8')
    (OUT/'h3-overlap39.json').write_text(json.dumps(dict(fps=24,overlapFrames=39,films=plans),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    with (OUT/'h3-overlap39.csv').open('w',encoding='utf-8-sig',newline='') as h:
        writer=csv.writer(h);writer.writerow(['cinematic','segment','startFrame','endFrameExclusive','lengthFrames','overlapFrames','startSeconds','endSeconds','generationSeconds','netNewSeconds']);writer.writerows(rows)
    with zipfile.ZipFile(ROOT/'output/Scarlet-H3-Prompts-v2.zip','w',compression=zipfile.ZIP_DEFLATED) as z:
        for p in sorted(OUT.rglob('*')):
            if p.is_file() and not p.name.startswith('.'):
                z.write(p,'Scarlet-H3-Prompts/'+p.relative_to(OUT).as_posix())
        z.write(ROOT/'docs/rpg/SCARLET-H3-DIRECTOR-PROMPTS.md','Scarlet-H3-Prompts/完整逐镜提示词.md')
    print(f'Validated {len(plans)} films, {len(rows)} legal windows. {DOC}')

if __name__=='__main__':main()

"""Analyze alpha and emit atlas rectangles; images are never altered by this tool."""
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'assets/rogue/build'
records=json.loads((folder/'generation-record.json').read_text(encoding='utf-8'))
regions={}
report=[]
for plan in records:
    if 'ids' not in plan: continue
    path=folder/plan['final_file']
    im=Image.open(path)
    assert im.mode=='RGBA',str(path)+' must have alpha'
    alpha=im.getchannel('A')
    w,h=im.size
    assert len(plan['ids'])==plan['columns']*plan['rows']
    for i,id in enumerate(plan['ids']):
        assert id not in regions,id
        left=round((i%plan['columns'])*w/plan['columns'])
        right=round((i%plan['columns']+1)*w/plan['columns'])
        top=round((i//plan['columns'])*h/plan['rows'])
        bottom=round((i//plan['columns']+1)*h/plan['rows'])
        # This reads alpha bounds only. Runtime AtlasTexture references the original PNG.
        cell=alpha.crop((left,top,right,bottom))
        bounds=cell.point(lambda a:255 if a>=24 else 0).getbbox()
        assert bounds and (bounds[2]-bounds[0])*(bounds[3]-bounds[1])>100,id+' is empty'
        x0,y0,x1,y1=bounds
        x0=max(0,x0-3);y0=max(0,y0-3);x1=min(right-left,x1+3);y1=min(bottom-top,y1+3)
        regions[id]={'file':'res://assets/rogue/build/'+plan['final_file'],'region':[left+x0,top+y0,x1-x0,y1-y0],'cell':[left,top,right-left,bottom-top]}
    zeros=alpha.histogram()[0]/(w*h)
    assert zeros>.1,'Atlas transparency is missing: '+str(path)
    report.append({'file':plan['final_file'],'size':[w,h],'icons':len(plan['ids']),'fully_transparent_fraction':round(zeros,4)})
assert len(regions)==252,len(regions)
(folder/'atlas-manifest.json').write_text(json.dumps({'version':1,'regions':regions},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(folder/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Validated252 ID-specific regions,13 RGBA atlases; original PNGs preserved.')

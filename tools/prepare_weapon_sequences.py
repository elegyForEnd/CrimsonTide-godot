"""Register unchanged generated peaks, with hand/contact anchors from inspection."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SOURCES=ROOT/'art/weapon-batch-01/sequence-sources-v2.json'
# Coordinates refer to the entire untouched canvas, never independent alpha crops.
ANCHORS={
 (607,'basic'):([.26,.55],[.905,.55],1,'blade'),
 (608,'basic'):([.30,.55],[.88,.55],1,'blade'),
 (612,'basic'):([.23,.72],[.80,.77],0,'blade'),
 (614,'basic'):([.13,.64],[.85,.77],2,'ground_wave'),
 (617,'basic'):([.20,.59],[.85,.76],0,'blade'),
 (607,'finisher'):([.20,.70],[.81,.85],0,'blade'),
 (608,'finisher'):([.05,.49],[.91,.56],1,'blade'),
 (612,'finisher'):([.22,.65],[.88,.88],0,'blade'),
 (614,'finisher'):([.05,.80],[.90,.80],2,'ground_wave'),
 (617,'finisher'):([.20,.72],[.82,.87],0,'blade'),
}

def prepare():
    manifests={}
    for r in json.loads(SOURCES.read_text(encoding='utf-8')):
        weapon,kind=r['weapon'],r['kind']
        path=ROOT/r['file'].removeprefix('res://')
        digest=hashlib.sha256(path.read_bytes()).hexdigest()
        if digest!=hashlib.sha256(Path(r['original']).read_bytes()).hexdigest():
            raise ValueError('Original pixels changed')
        with Image.open(path) as image:
            if image.mode!='RGBA' or image.getchannel('A').getextrema()[0]!=0:
                raise ValueError('True alpha required')
            w,h=image.size
        pivot,contact,mode,placement=ANCHORS[(weapon,kind)]
        row={**r,'single_peak':True,'sha256':digest,'size':[w,h],
             'canvas_aspect':w/h,'frame_rects':[[0,0,1,1]]*4,
             'frame_bounds':[[0,1]]*4,'pivot':pivot,'contact':contact,
             'reveal_mode':mode,'placement':placement}
        manifest=manifests.setdefault(weapon,json.loads((ROOT/f'assets/combat/weapon-batch-01/{weapon}/shapes.json').read_text(encoding='utf-8')))
        if kind=='basic': manifest['clips']['normal']=row
        else:
            manifest['clips']['art']=row
            manifest['clips']['finisher']=row
    for weapon,manifest in manifests.items():
        manifest['revision']='batch01-three-stage-v2'
        (ROOT/f'assets/combat/weapon-batch-01/{weapon}/shapes.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('10 new original RGBA sources verified; five basics + five finishers registered')

if __name__=='__main__': prepare()

"""Export artist-edited grid heights; preserve stable grid XY and shoreline data."""
import bpy,pathlib,json
ROOT=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/story-environment/opening-terrain.blend'))
for obj in bpy.data.objects:
    if 'stage' not in obj: continue
    width=int(obj['width']); depth=int(obj['depth']); spacing=float(obj['spacing'])
    assert len(obj.data.vertices)==width*depth,'Keep grid topology when sculpting'
    for i,v in enumerate(obj.data.vertices):
        assert abs(v.co.x-(i%width)*spacing*.01)<.001 and abs(v.co.y+(i//width)*spacing*.01)<.001,'Sculpt height only; XY defines gameplay sampling'
    payload={'spacing':spacing,'width':width,'depth':depth,'heights':[round(v.co.z*100,3) for v in obj.data.vertices],'shorelines':json.loads(obj['shorelines'])}
    (ROOT/f'resources/story-terrain-{obj["stage"]}.json').write_text(json.dumps(payload,separators=(',',':')),encoding='utf-8')

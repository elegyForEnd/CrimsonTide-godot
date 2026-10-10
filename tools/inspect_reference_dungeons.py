"""Read-only dungeon/tower metadata audit. Never exports source art into the game."""
from pathlib import Path
import collections,csv,hashlib,io,json
from inspect_reference_regions import resolve,archives,GAME
from inspect_reference_maps import read,ds1
from inspect_d2r_scenes import Storage
ROOT=Path(__file__).resolve().parents[1]

def main():
    tables={name:list(csv.DictReader(io.StringIO(resolve('data/global/excel/'+name+'.txt').decode('latin1')),delimiter='\t')) for name in ['levels','lvlmaze','lvlprest']}
    categories=['caves','crypt','catacomb','barracks','monastry']
    level_hints=['cave','crypt','tower','catacomb','jail','monastery']
    report={'legacy_root':str(GAME),'remaster_root':'F:/game/D2R','legacy_tables':{},'legacy_templates':{},'hd_templates':{},'errors':[]}
    for name,rows in tables.items():
        report['legacy_tables'][name]=[r for r in rows if any(c in r.get('Name','').lower() for c in level_hints)]
    names=[]
    for archive in archives:
        listing=read(archive,'(listfile)')
        if listing: names.extend(listing.decode('latin1').splitlines())
    selected=[]
    for category in categories:
        candidates=sorted({n.lower() for n in names if n.lower().endswith('.ds1') and f'\\act1\\{category}\\' in n.lower()})
        selected.extend(candidates[:6])
    for name in selected:
        try:
            d=ds1(resolve(name)); grids=d.pop('_grids')
            d['orientation_counts']={k:dict(collections.Counter(v['values'])) for k,v in grids.items() if k.startswith('orientation')}
            report['legacy_templates'][name]=d
        except Exception as exc: report['errors'].append(name+': '+str(exc))
    storage=Storage(); storage.tree(storage.read_key(bytes.fromhex('db906148ec59f5d1f89ac240dd6bd12f')))
    chosen=[]
    for category in categories:
        candidates=sorted(n for n in storage.files if '/hd/env/preset/act1/'+category+'/' in n.lower() and n.lower().endswith('.json'))
        # Include normal junctions, themed rooms and explicit vertical transitions.
        chosen.extend(candidates[:4])
        for hint in ['theme','down','up','spec']:
            chosen.extend([n for n in candidates if hint in Path(n).stem][:2])
    out=ROOT/'output/dungeon-reference'; out.mkdir(exist_ok=True)
    for name in dict.fromkeys(chosen):
        try:
            raw=storage.read(name); scene=json.loads(raw); types=collections.Counter(); models=set(); heights=[]; samples={}
            def walk(v):
                if isinstance(v,dict):
                    kind=v.get('type')
                    if isinstance(kind,str):
                        types[kind]+=1
                        if kind=='TransformDefinitionComponent': heights.append(v.get('position',{}).get('y',0))
                        if kind in ['ModelDefinitionComponent','WallTransparencyComponent','PhysicsBoxDefinition','TerrainStampDefinitionComponent'] and kind not in samples: samples[kind]=v
                    for x in v.values():
                        if isinstance(x,str) and x.lower().endswith('.model'): models.add(x)
                        walk(x)
                elif isinstance(v,list):
                    for x in v: walk(x)
            walk(scene)
            report['hd_templates'][name]={'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'entities':len(scene.get('entities',[])),'components':dict(types),'model_dependencies':sorted(models),'local_y_range':[min(heights),max(heights)] if heights else [],'nonzero_local_y':sum(abs(y)>.001 for y in heights),'component_samples':samples}
            (out/(Path(name).stem+'.json')).write_bytes(raw)
        except Exception as exc: report['errors'].append(name+': '+str(exc))
    target=ROOT/'docs/rpg/reference-dungeon-inspection.json'; target.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps({'legacy':len(report['legacy_templates']),'hd':len(report['hd_templates']),'errors':report['errors'],'levels':[(r.get('Name'),r.get('Id'),r.get('SizeX'),r.get('SizeY')) for r in report['legacy_tables']['levels']]},ensure_ascii=False))
    for name,d in report['hd_templates'].items(): print(Path(name).stem,'entities',d['entities'],'y',d['local_y_range'],'models',len(d['model_dependencies']))
if __name__=='__main__': main()

"""Read local legacy campaign adjacency, warp and placement metadata."""
from pathlib import Path
import collections, csv, io, json
from inspect_reference_maps import mpyq, read, ds1
ROOT=Path(__file__).resolve().parents[1]
GAME=Path('F:/game/Diablo II 1.13C原版懒人包')
archives=[mpyq.MPQArchive(str(GAME/n),listfile=False) for n in ('Patch_D2.mpq','d2exp.mpq','d2data.mpq')]
def resolve(name):
    for archive in archives:
        data=read(archive,name)
        if data is not None:return data
    raise FileNotFoundError(name)
def main():
    tables={}
    for name in ('levels','lvlwarp','lvlprest','objects'):
        data=resolve(f'data/global/excel/{name}.txt')
        tables[name]=list(csv.DictReader(io.StringIO(data.decode('latin1')),delimiter='\t'))
    graph=[]
    for r in tables['levels']:
        if not r.get('Id','').isdigit():continue
        graph.append({'id':int(r['Id']),'name':r['Name'],'size':[r.get('SizeX'),r.get('SizeY')],
                      'type':r.get('DrlgType'),'level_type':r.get('LevelType'),'waypoint':r.get('Waypoint'),
                      'links':[{'slot':i,'destination':r.get(f'Vis{i}'),'warp':r.get(f'Warp{i}')} for i in range(8) if r.get(f'Vis{i}','0') not in ('','0')]})
    samples={}
    for name in ['act1/town/towns1.ds1','act1/town/townstrans.ds1','act1/graveyard/gravey.ds1','act2/town/lutn.ds1','act3/docktown/docktown3.ds1','act1/catacomb/catedown.ds1','act1/catacomb/catewup.ds1']:
        try:
            value=ds1(resolve('data/global/tiles/'+name));grids=value.pop('_grids')
            value['orientation_counts']={k:dict(collections.Counter(v['values'])) for k,v in grids.items() if k.startswith('orientation')}
            samples[name]=value
        except Exception as e:samples[name]={'error':str(e)}
    report={'root':str(GAME),'tables':{k:len(v) for k,v in tables.items()},'regions':graph,'warp_definitions':tables['lvlwarp'],'samples':samples,
            'note':'TXT config and DS1 samples; not a disassembly or validation of patched runtime BIN generation.'}
    (ROOT/'docs/rpg/reference-region-inspection.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps({'regions':len(graph),'warps':len(tables['lvlwarp']),'samples':len(samples),'errors':[k for k,v in samples.items() if 'error' in v]},ensure_ascii=False))
if __name__=='__main__':main()

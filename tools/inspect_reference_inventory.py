"""Read local inventory dimensions / item metadata; never copy reference artwork."""
from pathlib import Path
import csv,io,json,hashlib
from inspect_reference_regions import resolve
from inspect_d2r_scenes import Storage
ROOT=Path(__file__).resolve().parents[1]
def main():
    report={'legacy_root':'F:/game/Diablo II 1.13C原版懒人包','remaster_root':'F:/game/D2R','legacy':{},'remaster':{},'errors':[]}
    for name in ['inventory','weapons','armor','misc']:
        raw=resolve('data/global/excel/'+name+'.txt')
        rows=list(csv.DictReader(io.StringIO(raw.decode('latin1')),delimiter='\t'))
        cols=['name','Name','code','invwidth','invheight','stackable','minstack','maxstack','cost','GridX','GridY','gridBoxWidth','gridBoxHeight']
        report['legacy'][name]={'sha256':hashlib.sha256(raw).hexdigest(),'rows':len(rows),'columns':list(rows[0]),'examples':[{k:r[k] for k in cols if k in r} for r in rows[:24]]}
    s=Storage();s.tree(s.read_key(bytes.fromhex('db906148ec59f5d1f89ac240dd6bd12f')))
    for name in ['inventory','weapons','armor','misc']:
        matches=[n for n in s.files if n.lower().endswith('/excel/'+name+'.txt')]
        for path in matches[:1]:
            try:
                raw=s.read(path);rows=list(csv.DictReader(io.StringIO(raw.decode('utf-8-sig')),delimiter='\t'))
                cols=['name','Name','code','invwidth','invheight','stackable','cost','GridX','GridY']
                report['remaster'][name]={'path':path,'sha256':hashlib.sha256(raw).hexdigest(),'rows':len(rows),'examples':[{k:r[k] for k in cols if k in r} for r in rows[:16]]}
            except Exception as exc:report['errors'].append(path+': '+str(exc))
    target=ROOT/'docs/rpg/reference-inventory-inspection.json';target.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps({'legacy':list(report['legacy']),'remaster':list(report['remaster']),'errors':report['errors']},ensure_ascii=False))
if __name__=='__main__':main()

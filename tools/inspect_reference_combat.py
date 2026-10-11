"""Read local missile/skill and remastered VFX metadata, never copy game artwork."""
from pathlib import Path
import csv, io, json, hashlib, collections
from inspect_reference_regions import resolve
from inspect_d2r_scenes import Storage
ROOT = Path(__file__).resolve().parents[1]

def main():
    report = {'legacy_root': 'F:/game/Diablo II 1.13C原版懒人包', 'remaster_root': 'F:/game/D2R',
              'legacy': {}, 'remaster': {}, 'errors': [],
              'limit': 'Resource metadata only; not renderer disassembly or a claim of exact internal runtime behavior.'}
    for table in ('missiles', 'skills', 'skilldesc'):
        raw = resolve('data/global/excel/' + table + '.txt')
        rows = list(csv.DictReader(io.StringIO(raw.decode('latin1')), delimiter='\t'))
        names = ('Name', 'skill', 'Skill', 'Id', 'CelFile', 'AnimLen', 'AnimSpeed', 'LoopAnim', 'Trans',
                 'Light', 'LightR', 'LightG', 'LightB', 'Vel', 'MaxVel', 'Range', 'Size', 'HitShift',
                 'CollideType', 'CltDoFunc', 'CltHitFunc', 'cltstfunc', 'cltdofunc', 'cltmissile',
                 'cltmissilea', 'cltmissileb', 'cltmissilec', 'HitSubMissile1', 'HitSubMissile2',
                 'CltSubMissile1', 'CltSubMissile2', 'CltSubMissile3')
        chosen = [r for r in rows if any(x in str(r).lower() for x in
                  ('fireball', 'frostnova', 'icebolt', 'lightning', 'nova', 'meteor', 'teeth', 'frozenorb', 'blizzard'))]
        report['legacy'][table] = {'rows': len(rows), 'sha256': hashlib.sha256(raw).hexdigest(),
                                  'columns': list(rows[0]), 'examples': [{k: r[k] for k in names if k in r} for r in chosen[:28]]}
    storage = Storage()
    storage.tree(storage.read_key(bytes.fromhex('db906148ec59f5d1f89ac240dd6bd12f')))
    names = [n for n in storage.files if '/hd/' in n.lower() and
             any(x in n.lower() for x in ('/vfx/', '/missiles/', '/particles/', '/skills/'))]
    report['remaster']['candidate_count'] = len(names)
    report['remaster']['extensions'] = dict(collections.Counter(Path(n).suffix.lower() for n in names))
    report['remaster']['path_examples'] = names[:90]
    configs = [n for n in names if n.endswith('.json')]
    selected = []
    for token in ('fireball', 'icebolt', 'lightning', 'meteor', 'frost', 'nova'):
        selected += [n for n in configs if token in n.lower()][:2]
    if not selected: selected = configs[:8]
    samples = {}
    for path in dict.fromkeys(selected):
        try:
            raw = storage.read(path); value = json.loads(raw)
            counts = collections.Counter(); fields = collections.Counter(); references = set()
            def walk(node):
                if isinstance(node, dict):
                    for k, v in node.items():
                        fields[k] += 1
                        if k.lower() in ('type', 'componenttype') and isinstance(v, str): counts[v] += 1
                        walk(v)
                elif isinstance(node, list):
                    for v in node: walk(v)
                elif isinstance(node, str) and any(x in node.lower() for x in ('.texture', '.particle', '.model', '.material')):
                    references.add(node)
            walk(value)
            samples[path] = {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
                             'types': dict(counts), 'field_counts': dict(fields.most_common(36)),
                             'references': sorted(references)[:24]}
        except Exception as exc: report['errors'].append(path + ': ' + str(exc))
    report['remaster']['samples'] = samples
    target = ROOT / 'docs/rpg/reference-combat-inspection.json'
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps({'tables': {k: v['rows'] for k, v in report['legacy'].items()},
                      'remaster_candidates': len(names), 'samples': len(samples), 'errors': report['errors']}, ensure_ascii=False))
if __name__ == '__main__': main()

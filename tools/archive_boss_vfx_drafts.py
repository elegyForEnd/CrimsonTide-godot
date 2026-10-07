"""Preserve this task's unused candidates outside runtime resources."""
import json
import shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/bosses/imagegen/actions'
DEST=ROOT/'output/boss-effect-drafts'
# This workspace's assets directory is a verified junction into the shared
# project asset root; check that resolved source root and the output root.
assert BASE.resolve().is_relative_to((ROOT/'assets').resolve()) and DEST.resolve().is_relative_to(ROOT.resolve())
selected={s['file'] for name in ['atlas-3x3-v5.json','body-atlas-3x3-v5.json'] for s in json.loads((BASE/name).read_text())['assets'].values()}
candidates=set(BASE.glob('*_v3.png'))|set(BASE.glob('*-states-square-v4.png'))|{p for p in BASE.glob('*3x3-v5*.png') if p.name not in selected}
DEST.mkdir(parents=True,exist_ok=True); (DEST/'.gdignore').touch()
moved=[]
for path in sorted(candidates):
    assert path.resolve().parent==BASE.resolve()
    target=DEST/path.name
    if target.exists(): continue
    shutil.move(str(path),str(target)); moved.append(path.name)
    settings=path.with_suffix('.png.import')
    if settings.exists(): shutil.move(str(settings),str(DEST/settings.name))
(DEST/'archive-index.json').write_text(json.dumps({'reason':'unused generation candidates; original production artwork preserved','files':moved},indent=2)+'\n',encoding='utf-8')
print('Preserved',len(moved),'unused candidates in output/boss-effect-drafts; selected 3x3 atlases remain in runtime assets')

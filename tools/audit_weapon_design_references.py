"""Record reference provenance and ensure it is outside the runtime asset tree."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'art/weapon-vfx-reference-v6'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def audit():
    assert (BASE/'.gdignore').exists()
    briefs = json.loads((BASE/'briefs.json').read_text(encoding='utf-8'))
    records_path = BASE/'generation-records.json'
    generation = json.loads(records_path.read_text(encoding='utf-8'))
    records = {r['id']:r for r in generation['records']}
    originals = Path.home()/'.codex/generated_images/01a153ef-40a0-7ae1-9a96-9eac5c3934c3'
    original_hashes = {}
    if originals.exists():
        original_hashes = {digest(path):str(path) for path in originals.glob('*.png')}
    updated = []
    for brief in briefs:
        weapon = brief['id']
        final = BASE/f'finished/weapon-{weapon}.png'
        path = final if final.exists() else BASE/f'plates/weapon-{weapon}.png'
        assert path.exists(), f'Missing reference {weapon}'
        sha = digest(path)
        record = records.get(weapon, {'id':weapon,'generator':'built-in ImageGen; earlier design plate'})
        record.update(file=path.relative_to(BASE).as_posix(), sha256=sha, runtime_asset=False)
        if sha in original_hashes:
            record['original'] = original_hashes[sha]
        prompt = BASE/f'prompts/finished/weapon-{weapon}.txt' if final.exists() else BASE/f'prompts/weapon-{weapon}.txt'
        record['prompt_file'] = prompt.relative_to(BASE).as_posix() if prompt.exists() else None
        if not prompt.exists():
            record['prompt_note'] = 'Earlier prototype prompt was not retained; per-weapon direction is in briefs.json.'
        updated.append(record)
    generation['records'] = updated
    records_path.write_text(json.dumps(generation,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    forbidden = ['weapon-vfx-reference-v6','assets/combat/weapon-vfx-v6','weapon_authored_vfx.gd','weapon_vfx_designs.gd']
    for folder in ['scripts','resources']:
        for path in (ROOT/folder).rglob('*'):
            if path.suffix not in ['.gd','.gdshader']: continue
            source = path.read_text(encoding='utf-8')
            for token in forbidden: assert token not in source, f'{path}: runtime reference leak {token}'
    shader = (ROOT/'resources/weapon_sculpted_material.gdshader').read_text(encoding='utf-8')
    assert 'sampler2D' not in shader
    assert len(updated)==52 and len({r['id'] for r in updated})==52
    print(f'52 reference identities; {sum(r.get("original") is not None for r in updated)} matched original files; zero reference-image runtime dependencies')

if __name__ == '__main__':
    audit()

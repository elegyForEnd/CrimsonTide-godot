"""Validate the compiled story graph and actual art bindings, without Godot."""
from pathlib import Path
from collections import Counter
import json

ROOT=Path(__file__).resolve().parents[1]
content=json.loads((ROOT/'resources/scarlet/campaign.json').read_text(encoding='utf-8'))
source=json.loads((ROOT/'art/scarlet-screenplay/screenplay.json').read_text(encoding='utf-8'))
manifest=json.loads((ROOT/'assets/story/vn-full-v3/manifest.json').read_text(encoding='utf-8'))
physical=json.loads((ROOT/'resources/scarlet/fieldwork.json').read_text(encoding='utf-8'))
checks=0
def check(ok,why):
    global checks
    checks+=1
    assert ok,why

check(content['revision']=='scarlet-screenplay-2','new revision required')
check(len(content['quests'])==46 and len(content['main_order'])==40,'task coverage')
check(not {'opening','rescue-choice','finisher','leave-escape'} & content['scenes'].keys(),'retired scenes must not ship')
check(set(content['cinematics'])==set(source['films']),'film version coverage')
poses=Counter(); clothes=Counter(); used_ids=set(); films=set()
for scene in content['scenes'].values():
    check(bool(scene['pages']),scene['id'])
    if scene.get('film'): films.add(scene['film'])
    for page in scene['pages']:
        if page.get('id'): used_ids.add(page['id'])
        actor=page.get('actor','')
        check(not page['text'].startswith('@|'),'directions cannot be spoken')
        if actor in manifest['heroes']:
            pose=page.get('pose','front'); costume=page.get('costume','regular'); expression=page.get('expression','neutral')
            path=manifest['heroes'][actor]['portraits'][costume][pose][expression]
            check((ROOT/path.removeprefix('res://')).is_file(),path)
            poses[pose]+=1; clothes[costume]+=1
        if page.get('cg'):
            check(any((ROOT/f"assets/story/{folder}/{page['cg']}.png").is_file() for folder in ['cg-scarlet-v1','cg-scarlet-v2']),page['cg'])
    for choice in scene.get('choices',[]):
        if choice.get('reply'): check(choice['reply'] in content['scenes'],choice['reply'])
for scene in source['scenes']:
    for line in scene['lines']:
        if line['type']!='direction': check(line['id'] in used_ids,'missing authored line: '+line['id'])
for q in content['quests'].values():
    for node in q['nodes']:
        check(node['zone'] in content['zones'],node['id'])
        if node['kind']=='scene': check(node['scene'] in content['scenes'],node['scene'])
        if node['kind']=='branch_scene':
            check(node['yes'] in content['scenes'] and node['no'] in content['scenes'],node['id'])
        if node['kind']=='cinematic': films.add(node['cinematic'])
        if node['kind'] in ['mechanism','clue']:
            check(node['id'] in physical and len(physical[node['id']]['parts'])==3,node['id'])
films.add('CIN-12') # explicit chapter transport
check(films==set(content['cinematics']),'every reserved film has an actual trigger')
check(all(film['path'] is None for film in content['cinematics'].values()),'animation slots must remain empty')
check(set(poses)=={'front','turn','crossed'} and poses['turn']>poses['front'],'side-facing blocking required')
check(set(clothes)=={'regular','home','travel'},'all authored costume families used')
report=dict(checks=checks,failures=0,scenes=len(content['scenes']),tasks=len(content['quests']),physical=len(physical),poses=dict(poses),costumes=dict(clothes),reserved_films=len(films))
(ROOT/'output/scarlet-screenplay-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))

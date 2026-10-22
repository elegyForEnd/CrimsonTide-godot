"""Adapt the real combat recorder for the full new reference production."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
s=(ROOT/'tools/record_weapon_batch01.gd').read_text(encoding='utf-8')
s=s.replace('res://output/weapon-batch-01/','res://output/weapon-all-v2/')
s=s.replace('batch01-three-stage-60fps-9','all-v2-reference-4')
s=s.replace('var selected: Array=[607,608,612,614,617]','var selected: Array=[600,601,602,603,604]')
s=s.replace('p.p=capture_origin(s)','p.p=capture_origin(s,330.0 if Catalog.weapon_family(weapon) in [0,3] else 170.0)')
s=s.replace('var capture_distance := 85.0 if action=="normal" else minf(170.0,float(capture_move.reach)*.78)',
    'var capture_distance := minf(330.0,float(Catalog.weapon(weapon).reach)*.65) if action=="normal" and Catalog.weapon_family(weapon) in [0,3] else minf(330.0,float(capture_move.reach)*.65) if Catalog.weapon_family(weapon) in [0,3] else 85.0 if action=="normal" else minf(170.0,float(capture_move.reach)*.78)')
s=s.replace('func capture_origin(s) -> Vector2:','func capture_origin(s,distance: float=170) -> Vector2:')
s=s.replace('var valid: bool=s.ruins.clear_line(at,at+Vector2(420,0))',
    'var valid: bool=s.ruins.clear_line(at,at+Vector2(maxf(420,distance),0)) and not s.ruins.blocked(at+Vector2(distance,0),25)')
(ROOT/'tools/record_weapon_all_v2.gd').write_text(s,encoding='utf-8')
print('Prepared full-production real combat recorder')

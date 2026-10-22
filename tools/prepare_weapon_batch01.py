"""Measure untouched originals and prepare the five-weapon real-combat capture."""
import hashlib
import json
from pathlib import Path
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]
IDS=[607,608,612,614,617]
LAYERS=['surface','charge','impact','mist','ground','shard','trail']

def measure():
    total=0
    for weapon in IDS:
        base=ROOT/f'assets/combat/weapon-batch-01/{weapon}'
        art=ROOT/f'art/weapon-batch-01/{weapon}'
        rows={}
        sheet=Image.new('RGB',(1200,1200),'#17232e'); draw=ImageDraw.Draw(sheet)
        for i,layer in enumerate(LAYERS):
            path=base/f'{layer}-v4.png'
            if not path.exists(): path=base/f'{layer}-v3.png'
            if not path.exists(): path=base/f'{layer}-v2.png'
            if not path.exists(): path=base/f'{layer}.png'
            if not path.exists(): raise ValueError(f'Missing {weapon}/{layer}')
            row=json.loads((art/f'{path.stem}.json').read_text(encoding='utf-8'))
            with Image.open(path) as image:
                if image.mode!='RGBA': raise ValueError(f'{weapon}/{layer} is not RGBA')
                alpha=image.getchannel('A')
                bounds=alpha.point(lambda a:255 if a>=16 else 0).getbbox()
                if not bounds or alpha.getextrema()[0]!=0: raise ValueError(f'{weapon}/{layer}: missing transparency')
                x0,y0,x1,y1=bounds; w,h=image.size
                digest=hashlib.sha256(path.read_bytes()).hexdigest()
                if hashlib.sha256(Path(row['original']).read_bytes()).hexdigest()!=digest: raise ValueError('Original pixels changed')
                rows[layer]={**row,'sha256':digest,'size':[w,h],'uv':[x0/w,y0/h,(x1-x0)/w,(y1-y0)/h],'aspect':(x1-x0)/(y1-y0)}
                thumb=image.copy(); thumb.thumbnail((570,255))
                x,y=(i%2)*600,(i//2)*300
                sheet.paste(thumb,(x+(600-thumb.width)//2,y+30+(255-thumb.height)//2),thumb)
                draw.text((x+15,y+8),f'{weapon} / {layer}',fill='white')
            total+=1
        (base/'manifest.json').write_text(json.dumps({'weapon':weapon,'batch':1,'status':'awaiting_user_acceptance','layers':rows},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        sheet.save(art/'components.jpg')
        for path in base.glob('*.png.import'):
            old=path.read_text(encoding='utf-8'); new=old.replace('mipmaps/generate=false','mipmaps/generate=true')
            if old!=new: path.write_text(new,encoding='utf-8')
    print(f'{len(IDS)} weapons, {total} isolated originals measured and verified')

def capture():
    source=(ROOT/'tools/record_weapon_606_reference.gd').read_text(encoding='utf-8')
    source=source.replace('res://output/weapon-606-reference/','res://output/weapon-batch-01/')
    source=source.replace('606-storyboard-path-frost-2','batch01-three-stage-60fps-9')
    source=source.replace('var selected: Array=[606]','var selected: Array=[607,608,612,614,617]')
    source=source.replace('s.spawn_enemy(p.p+Vector2(85 if action=="normal" else 170,0),0)',
        'var capture_move: Dictionary=Hold.profile(weapon) if action=="heavy" else WeaponArts.of(weapon)\n\t\t\tvar capture_distance := 85.0 if action=="normal" else minf(170.0,float(capture_move.reach)*.78)\n\t\t\ts.spawn_enemy(p.p+Vector2(capture_distance,0),0)')
    source=source.replace('var at: float','var at: float')
    source=source.replace('*30)+1','*60)+1').replace('for frame in 72:','for frame in 144:').replace('1.0/30.0','1.0/60.0')
    source=source.replace('"30"','"60"').replace('"72"','"144"').replace('"frames":72,"fps":30','"frames":144,"fps":60')
    source=source.replace('[0,3,6,9,12,15,18,21,24,30]','[0,6,12,18,24,30,36,42,48,60]').replace('[0,2,4,6,9,12]','[0,4,8,12,18,24]')
    source=source.replace('weight+=minf(effect.age/maxf(.01,peak_time),1.0)*pow(1-clampf((effect.age-peak_time)/maxf(.01,effect.tail_time),0,1),1.2)',
        'if effect.authored!=null and effect.authored.actual_shape!=null:\n\t\t\t\t\t\t\tvar shape_phase := float(effect.authored.actual_shape.material.get_shader_parameter("phase"))\n\t\t\t\t\t\t\tweight+=exp(-absf(shape_phase-1.0)*1.8)\n\t\t\t\t\t\telse:\n\t\t\t\t\t\t\tweight+=minf(effect.age/maxf(.01,peak_time),1.0)*pow(1-clampf((effect.age-peak_time)/maxf(.01,effect.tail_time),0,1),1.2)')
    source=source.replace('p.erase("weapon_hold");','p.erase("build_art_sequence"); p.erase("weapon_hold");')
    source=source.replace('p.p=Vector2(700,690)','p.p=capture_origin(s)')
    source=source.replace('p.mana=10000;','p.mana=p.max_mana;')
    source=source.replace('field.combat.reset(); s.bullets.clear(); s.enemies.clear(); hits.clear()',
        'field.camera_x=p.p.x-580; field.camera_y=p.p.y-610\n\t\t\tfield.combat.reset(); s.bullets.clear(); s.enemies.clear(); hits.clear()\n\t\t\tvar starting_point: Vector2=p.p\n\t\t\tvar max_lift := 0.0\n\t\t\tvar strike_steps: Array=[]\n\t\t\tvar phase_trace: Array=[]')
    source=source.replace('var dt := 1.0/60.0','var dt := 1.0/60.0')
    source=source.replace('Actions.tick(s,p,dt); Actions.tail(s,p,dt)',
        'Actions.tick(s,p,dt); Actions.tail(s,p,dt)\n\t\t\t\tmax_lift=maxf(max_lift,float(p.height))\n\t\t\t\tif p.has("build_art_sequence") and not strike_steps.has(int(p.build_art_sequence.step)):\n\t\t\t\t\tstrike_steps.append(int(p.build_art_sequence.step))\n\t\t\t\tif frame%3==0: phase_trace.append({"frame":frame,"p":[p.p.x,p.p.y],"height":p.height,"step":int(p.get("build_art_sequence",{}).get("step",-1))})')
    source=source.replace('var crop := Rect2i(0,300,1440,600) if Catalog.weapon_family(weapon) in [0,3] else Rect2i(300,400,900,450)','var crop := Rect2i(0,0,1440,900)')
    source=source.replace('"crop=650:500:360:0" if Catalog.weapon_family(weapon) in [0,3] else "crop=650:440:80:0"','"crop=1100:760:240:80"')
    source=source.replace('weight+=exp(-absf(shape_phase-1.0)*1.8)', 'weight+=exp(-absf(shape_phase-1.0)*1.8)*(3.0 if bool(effect.data.get("sequence_final",false)) else 1.0)')
    source=source.replace('"poster_frame":peak_frame}', '"poster_frame":peak_frame,"displacement":p.p.distance_to(starting_point),"max_height":max_lift,"sequence_steps":strike_steps,"phase_trace":phase_trace}')
    source+='''\nfunc capture_origin(s) -> Vector2:
\tfor y in range(600,951,20):
\t\tfor x in range(500,1101,20):
\t\t\tvar at := Vector2(x,y)
\t\t\tvar valid: bool=s.ruins.clear_line(at,at+Vector2(420,0))
\t\t\tfor offset in range(0,191,4): valid=valid and not s.ruins.blocked(at+Vector2(offset,0),25)
\t\t\tif valid: return at
\tpush_error("No clear real map runway for capture")
\treturn Vector2(700,690)
'''
    (ROOT/'tools/record_weapon_batch01.gd').write_text(source,encoding='utf-8')
    print('Prepared 15 real-combat clips for the five selected weapons')

if __name__=='__main__':
    import sys
    if '--capture' in sys.argv: capture()
    else: measure()

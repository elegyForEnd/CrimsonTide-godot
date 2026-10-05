"""Compile the reviewed build tables to immutable runtime data (no prose parsing in combat)."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
text = (ROOT / 'ROGUE-BUILD-SYSTEM-DESIGN.md').read_text(encoding='utf-8-sig')
rows = {}
for line in text.splitlines():
    cells = [c.strip() for c in line.strip().strip('|').split('|')]
    if cells and re.fullmatch(r'(?:W|E|T|I|WC)\d{3}', cells[0]):
        rows.setdefault(cells[0], cells)
grades = {}
for line in text.split('### 18.5')[1].splitlines():
    c = [x.strip() for x in line.strip().strip('|').split('|')]
    if c and re.fullmatch(r'W\d{3}', c[0]):
        grades[c[0]] = dict(zip(['strength', 'dexterity', 'intelligence', 'arcane'], [x.replace('—', '-') for x in c[2:6]]))
templates = {
 'A1':[36,0,0,0,.03,0], 'A2':[22,18,0,.04,0,0], 'A3':[28,10,0,0,.02,0], 'A4':[18,24,0,.03,0,0],
 'F1':[0,16,0,.08,0,0], 'F2':[12,20,0,.04,0,0], 'F3':[16,10,0,0,.02,0], 'F4':[0,12,0,.03,0,.06],
 'B1':[12,0,16,.03,0,0], 'B2':[20,0,12,0,.02,0], 'B3':[0,16,14,.03,0,0], 'B4':[14,0,20,0,0,0]}
weapons = []
spells = ['bullet'] * 12 + ['star','meteor','needle','chain','moon','prism','scatter','vortex','eclipse','moon','vortex','star']
for n in range(1,49):
    c = rows[f'W{n:03d}']
    nums = [float(x) for x in c[2].split('/')]
    family = 1 if n <=12 else 2 if n<=24 else 0 if n<=36 else 3
    # Staff tables have a final MP column.
    d,t,w,reach = nums[:4]
    art_name,art_values = c[4].rsplit(' ',1)
    multiplier,mana,cd = [float(x) for x in art_values.split('/')]
    kind = 'circle' if '环' in art_name or '圆' in art_name else 'beam' if '线' in art_name else 'volley' if family==0 or '散' in art_name else 'burst' if family==3 else 'cone' if family==2 else 'thrust'
    spell = 'arrow' if family==0 and n in [26,27,29,33,35] else spells[n-25] if family in [0,3] else ''
    art_spell = 'scatter' if '散' in art_name else 'star' if kind=='volley' and family==3 else spell or 'star'
    if family==0 and '贯' in art_name: kind='volley'
    if n==2: pattern='thrust'
    elif n in [3,15,16,20]: pattern='spin'
    elif family==2: pattern='cleave'
    else: pattern=''
    weapons.append(dict(id=c[0],name=c[1],family=family,damage=d,rate=t,windup=w,reach=reach,knock=45 if family==2 else 18,
        mana_cost=nums[4] if len(nums)>4 else 0,scaling=grades[c[0]],desc=c[3],pattern=pattern,spell=spell or 'star',speed=1050 if spell=='arrow' or n==39 else 430 if spell in ['meteor','vortex'] else 700 if family==3 else 900,
        art=dict(name=art_name,kind=kind,damage=multiplier,mana=mana,cooldown=cd,reach=650 if family==0 or kind=='beam' else 130 if family==1 and kind=='circle' else 180 if family==1 else 170 if family==2 and kind=='circle' else 220 if family==2 else 500,
                 radius=100,width=35 if family==1 else 30,count=1 if '贯' in art_name else 3 if family==0 else 5 if '散' in art_name else 1,
                 pierce=3 if family==0 and '贯' in art_name else 1,spell=art_spell,
                 desc={'circle':'环斩周围敌人。','thrust':'沿瞄准方向突刺。','cone':'震击前方扇面。','beam':'贯穿前方直线。','volley':'发射灵能弹；同目标全部命中仍共用总伤害预算。','burst':'在瞄准落点产生法术爆发。'}[kind])))
gear=[]
for n in range(1,73):
    c=rows[f'E{n:03d}']
    gear.append(dict(id=c[0],name=c[1],slot=(n-1)//24,template=c[2],text=c[3],**dict(zip(['hp','mana','speed','damage','defense','crit'],templates[c[2]]))))
talents=[]
for n in range(1,97):
    c=rows[f'T{n:03d}']; kind,rank=c[2].split('/')
    talents.append(dict(id=c[0],name=c[1],school=(n-1)//8,category=kind,max_rank=int(rank),cost=3 if kind=='K' else 1,text=c[3]))
engravings=[dict(id=rows[f'I{n:03d}'][0],name=rows[f'I{n:03d}'][1],tag=rows[f'I{n:03d}'][2],text=rows[f'I{n:03d}'][3]) for n in range(1,25)]
cores=[dict(id=rows[f'WC{n:03d}'][0],name=rows[f'WC{n:03d}'][1],family=[1,2,0,3][(n-1)//3],text=rows[f'WC{n:03d}'][2],desc=rows[f'WC{n:03d}'][3]) for n in range(1,13)]
data=dict(version=3,weapons=weapons,gear=gear,talents=talents,engravings=engravings,cores=cores)
assert sum(map(len,[weapons,gear,talents,engravings,cores]))==252
out=ROOT/'resources/rogue_build_content.json'
out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Compiled 252 entries:', out)

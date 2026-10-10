"""Draw the actual authored walkable footprints for design review (not concept art)."""
from pathlib import Path
import json,math
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
DATA=json.loads((ROOT/'resources/story-exploration.json').read_text(encoding='utf8'))['dungeons']
FONT='C:/Windows/Fonts/msyh.ttc'
def draw(keys,path,columns):
 cellw,cellh=480,560
 image=Image.new('RGB',(columns*cellw,math.ceil(len(keys)/columns)*cellh),(18,23,29)); draw=ImageDraw.Draw(image)
 title=ImageFont.truetype(FONT,21); small=ImageFont.truetype(FONT,16)
 colours={'water':(32,78,98),'earth':(45,70,47),'rock':(54,58,67),'pit':(10,14,19)}
 for n,key in enumerate(keys):
  d=DATA[key]; x=(n%columns)*cellw; y=(n//columns)*cellh
  scale=min((cellw-70)/d['extent'][0],(cellh-120)/d['extent'][1])
  left=x+(cellw-d['extent'][0]*scale)/2; top=y+72
  p=lambda q:(left+q[0]*scale,top+q[1]*scale)
  draw.text((x+20,y+12),key+' '+d['name'],font=title,fill=(238,222,189))
  draw.text((x+20,y+43),d['layout_family']+f" · {len(d['chambers'])}处空间",font=small,fill=(148,174,190))
  draw.polygon([p(q) for q in d['boundary']],fill=(137,146,140))
  for hole in d['voids']: draw.polygon([p(q) for q in hole],fill=colours[d['void_surface']])
  for i,q in enumerate(d['boundary']):
   colour={'wall':(235,228,211),'broken':(154,116,87),'rail':(67,166,197),'rock':(99,108,117),'roots':(71,97,66),'colonnade':(192,170,128),'none':(80,104,83)}[d['edge_styles'][0][i]]
   draw.line([p(q),p(d['boundary'][(i+1)%len(d['boundary'])])],fill=colour,width=2)
  for q in d['chests']:
   px,py=p(q); draw.rectangle((px-3,py-3,px+3,py+3),fill=(231,186,57))
  px,py=p(d['spawn']); draw.ellipse((px-5,py-5,px+5,py+5),fill=(74,215,121))
  px,py=p(d['waypoint']); draw.ellipse((px-4,py-4,px+4,py+4),fill=(75,170,242))
  draw.text((x+20,y+cellh-31),'实际可走轮廓 / 水域与岩体留空 / 绿点入口',font=small,fill=(148,174,190))
 image.save(path)
draw(['1:8','1:7','1:9','3:5','4:6','5:7'],ROOT/'docs/rpg/dungeon-identities-comparison.png',3)
draw(list(DATA),ROOT/'docs/rpg/dungeon-identities-atlas.png',5)
print('AUTHORED_FOOTPRINT_ATLAS_READY')

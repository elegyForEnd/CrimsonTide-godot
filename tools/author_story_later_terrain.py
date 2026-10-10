"""Author regional terrain samples; Godot visuals and movement read these alike."""
from pathlib import Path
import json,math
ROOT=Path(__file__).resolve().parents[1]
dest=ROOT/'resources/story-later-terrain.json'
if dest.exists(): raise RuntimeError('Terrain exists; edit the samples instead of overwriting.')
content=json.loads((ROOT/'resources/story_content.json').read_text(encoding='utf8'))
data={}
for a in range(2,7):
 for s,m in enumerate(content['acts'][a-1]['maps'],1):
  if m['layout'] in ['hall','library','crypt','cathedral','mine','chapel','castle']: continue
  heights=[]
  for j in range(97):
   for i in range(97):
    x=i*50; y=j*50
    edge=min(x,y,4800-x,4800-y)
    fade=max(0,min(1,edge/400))
    if a==2: h=17*math.sin(x/320)*math.sin(y/700)-12*math.exp(-((x-950)/210)**2)
    elif a==3: h=150*math.exp(-((x-850)/850)**2-((y-2900)/1100)**2)+55*math.sin(x/850+y/1200)
    elif a==4: h=50*math.sin(y/780)*math.cos(x/1100)+35*math.exp(-((x-3650)/700)**2-((y-3600)/800)**2)
    elif a==5: h=28*math.sin(x/340+y/700)+55*math.exp(-((x-1100)/550)**2-((y-2700)/1300)**2)
    else: h=100*math.exp(-((x-850)/700)**2-((y-3300)/800)**2)+35*math.cos(x/550)*math.sin(y/850)
    heights.append(round(h*fade,2))
  data[f'{a}:{s}']={'spacing':50,'width':97,'depth':97,'heights':heights,'shorelines':[]}
dest.write_text(json.dumps(data,separators=(',',':')),encoding='utf8')
print('AUTHORED_TERRAIN_REGIONS',len(data))

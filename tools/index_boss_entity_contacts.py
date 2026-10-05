"""Read alpha contact landmarks; never modify generated source images."""
from pathlib import Path
import numpy as np
from PIL import Image
root = Path(__file__).resolve().parents[1]
names = ['ground_vent','bell_clapper','royal_sabre','rock_wall','gravestone','standing_mirror','black_sword','royal_crown']
lines = ['extends RefCounted', '# Contact landmarks indexed from unchanged ImageGen PNGs.', 'const DATA := {']
for name in names:
    image = Image.open(root / f'assets/bosses/imagegen/readable/{name}.png').convert('RGBA')
    alpha = np.asarray(image)[:,:,3]
    width, height = image.size
    mask = alpha[:,int(width*.25):int(width*.75)] >= 180
    ys,xs = np.where(mask)
    y = float(np.quantile(ys,.998))
    band = (ys >= y-6) & (ys <= y+2)
    x = float(np.median(xs[band]))+int(width*.25)
    if name in ['ground_vent','rock_wall','gravestone','standing_mirror','royal_crown']: x=width*.5
    lines.append(f'    "{name}": Vector2({x/width-.5:.6f},{y/height-.5:.6f}),')
    print(name, image.size, 'alpha',int(alpha.min()),int(alpha.max()), 'contact',round(x),round(y))
lines.append('}')
(root / 'scripts/boss_entity_contacts.gd').write_text('\n'.join(lines)+'\n',encoding='utf-8')

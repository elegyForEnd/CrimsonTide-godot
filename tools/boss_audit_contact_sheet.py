from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
cases = [('bell',0),('thorn',1),('queen',0),('knight',0),('hidden',2),('mirror',0),('ember',2),('moon',3),('earth',1),('storm',3),('abyss',1),('dragon',2)]
for stage in [0,1,2]:
    board = Image.new('RGB',(1600,1050),'#131b28')
    draw = ImageDraw.Draw(board)
    for i,(key,move) in enumerate(cases):
        path = root / f'build/extraction-boss-audit/{key}-{move}-{stage:02d}.png'
        frame = Image.open(path).convert('RGB').crop((260,120,1010,690))
        frame.thumbnail((395,300))
        at = (i%4*400,i//4*350+28)
        board.paste(frame,at)
        draw.text((at[0]+6,at[1]-20),f'{key} / move {move} / stage {stage}',fill='white')
    board.save(root / f'build/extraction-audit-{stage}.jpg',quality=93)

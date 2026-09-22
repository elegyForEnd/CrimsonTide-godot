"""Prepare the generated terrain and landmark atlas; no network or credentials."""
from pathlib import Path
from PIL import Image
import numpy as np
out=Path('assets/world'); out.mkdir(exist_ok=True)
im=Image.open('output/imagegen/world-materials.png').convert('RGB')
for i in range(6):
    tile=im.crop((i%3*512,i//3*512,i%3*512+512,i//3*512+512))
    # Mirror tiling guarantees edge continuity without modifying painted details.
    from PIL import ImageOps
    seamless=Image.new('RGB',(1024,1024))
    seamless.paste(tile,(0,0)); seamless.paste(ImageOps.mirror(tile),(512,0))
    seamless.paste(ImageOps.flip(tile),(0,512)); seamless.paste(ImageOps.flip(ImageOps.mirror(tile)),(512,512))
    seamless.resize((768,768),Image.Resampling.LANCZOS).save(out/f'terrain-{i}.png')
im=Image.open('output/imagegen/world-landmarks.png').convert('RGBA')
a=np.array(im); rgb=a[:,:,:3].astype(float)
strength=rgb[:,:,1]-np.maximum(rgb[:,:,0],rgb[:,:,2])
a[:,:,3]=(np.clip(1-(strength-15)/70,0,1)*255).astype('uint8')
a[:,:,1]=np.minimum(a[:,:,1],np.minimum(255,np.maximum(rgb[:,:,0],rgb[:,:,2])+12))
im=Image.fromarray(a)
for i in range(8):
    cell=im.crop((i%4*384,i//4*512,i%4*384+384,i//4*512+512))
    cell=cell.crop(cell.getbbox()); cell.thumbnail((384,480),Image.Resampling.LANCZOS)
    cell.save(out/f'landmark-{i}.png')
print('Prepared six seamless materials and eight transparent landmarks')
# Preserve the large central fortress as a separate transparent landmark.
im=Image.open('output/imagegen/world-fortress.png').convert('RGBA')
a=np.array(im); rgb=a[:,:,:3].astype(float)
strength=rgb[:,:,1]-np.maximum(rgb[:,:,0],rgb[:,:,2])
a[:,:,3]=(np.clip(1-(strength-15)/70,0,1)*255).astype('uint8')
a[:,:,1]=np.minimum(a[:,:,1],np.minimum(255,np.maximum(rgb[:,:,0],rgb[:,:,2])+12))
im=Image.fromarray(a); im=im.crop(im.getbbox()); im.thumbnail((1100,850),Image.Resampling.LANCZOS)
im.save(out/'landmark-8.png')

"""Remove chroma green and pack stable, foot-aligned 4x3 animation atlases."""
from pathlib import Path
from PIL import Image, ImageDraw
import argparse
import numpy as np
from scipy import ndimage

parser=argparse.ArgumentParser()
parser.add_argument('--names',nargs='+',default=['crystal-hare','moonbell-spirit','rose-armiger','redmoon-fox'])
names=parser.parse_args().names
for name in names:
    im=Image.open(Path('output/imagegen')/(name+'.png')).convert('RGBA')
    a=np.array(im)
    rgb=a[:,:,:3].astype(float)
    strength=rgb[:,:,1]-np.maximum(rgb[:,:,0],rgb[:,:,2])
    alpha=np.clip(1-(strength-12)/65,0,1)
    a[:,:,3]=(a[:,:,3]*alpha).astype('uint8')
    a[:,:,1]=np.minimum(a[:,:,1],np.minimum(255,np.maximum(rgb[:,:,0],rgb[:,:,2])+15))
    clean=Image.fromarray(a)
    w,h=im.size
    # Locate the true empty gutters near nominal row/column boundaries.
    def gutter(nominal, radius, occupied):
        lo=max(0,int(nominal-radius)); hi=min(len(occupied),int(nominal+radius))
        runs=[]; start=None
        for i in range(lo,hi):
            if not occupied[i] and start is None: start=i
            if occupied[i] and start is not None: runs.append((start,i)); start=None
        if start is not None: runs.append((start,hi))
        if not runs: return int(nominal)
        start,end=max(runs,key=lambda r:r[1]-r[0])
        return (start+end)//2
    mask=a[:,:,3]>100
    ys=[0]+[gutter(h*i/3,h/3*.22,mask.any(axis=1)) for i in [1,2]]+[h]
    frames=[]
    for row in range(3):
        row_pixels=a[ys[row]:ys[row+1]].copy()
        labels,count=ndimage.label(row_pixels[:,:,3]>20)
        sizes=np.bincount(labels.ravel()); sizes[0]=0
        main_ids=sorted(np.argsort(sizes)[-4:],key=lambda k:ndimage.center_of_mass(labels==k)[1])
        centers=[np.array(ndimage.center_of_mass(labels==k)) for k in main_ids]
        groups=[[] for _ in range(4)]
        for k in range(1,count+1):
            if sizes[k]<5: continue
            center=np.array(ndimage.center_of_mass(labels==k))
            nearest=min(range(4),key=lambda n:np.linalg.norm(center-centers[n]))
            groups[nearest].append(k)
        for group in groups:
            pixels=row_pixels.copy()
            pixels[:,:,3][~np.isin(labels,group)]=0
            cell=Image.fromarray(pixels)
            frames.append(cell.crop(cell.getbbox()))
    scale=min(218/max(f.width for f in frames),170/max(f.height for f in frames))
    atlas=Image.new('RGBA',(1024,768))
    for i,f in enumerate(frames):
        f=f.resize((round(f.width*scale),round(f.height*scale)),Image.Resampling.LANCZOS)
        atlas.alpha_composite(f,((i%4)*256+(256-f.width)//2,(i//4)*256+174-f.height))
    atlas.save(Path('assets/enemies')/(name+'.png'))
    print(name,'source',im.size,'scale',round(scale,3))
preview=Image.new('RGB',(1024,768),'#242b40')
for i,name in enumerate(names):
    sheet=Image.open(Path('assets/enemies')/(name+'.png'))
    for col,index in enumerate([0,5,6,10]):
        crop=sheet.crop(((index%4)*256,(index//4)*256,(index%4+1)*256,(index//4+1)*256))
        crop=crop.resize((256,192))
        preview.paste(crop,(col*256,i*192),crop)
preview.save('output/imagegen/'+ ('knight-preview.jpg' if names==['banished-knight'] else 'enemy-preview.jpg'))


"""Read generated atlas alpha and write crop metadata; pixels are not modified.
Run before Godot tools/prepare_boss_art.gd to pack the approved generated poses.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy import ndimage

manifest={}
for name in ['bell-hierophant','thorn-huntsman','blood-queen']:
    path=Path('output/imagegen/bosses')/(name+'-sheet-final.png')
    a=np.array(Image.open(path))
    h,w=a.shape[:2]
    mask=a[:,:,3]>64
    boundaries=[0]
    for n in [1,2]:
        lo,hi=int(h*n/3-h/18),int(h*n/3+h/18)
        occupied=mask[lo:hi].any(axis=1)
        labels,count=ndimage.label(~occupied)
        runs=ndimage.find_objects(labels)
        run=max(runs,key=lambda r:r[0].stop-r[0].start)
        boundaries.append(lo+(run[0].start+run[0].stop)//2)
    boundaries.append(h)
    boxes=[]
    for row in range(3):
        y0,y1=boundaries[row:row+2]
        labels,count=ndimage.label(mask[y0:y1])
        sizes=np.bincount(labels.ravel()); sizes[0]=0
        main=sorted(np.argsort(sizes)[-4:],key=lambda k:ndimage.center_of_mass(labels==k)[1])
        assert min(sizes[i] for i in main)>3000,(name,row,'missing body')
        centres=[ndimage.center_of_mass(labels==i)[1] for i in main]
        groups=[[] for _ in range(4)]
        for i,box in enumerate(ndimage.find_objects(labels),1):
            if sizes[i]<20: continue
            x=(box[1].start+box[1].stop)/2
            nearest=min(range(4),key=lambda k:abs(x-centres[k]))
            groups[nearest].append(box)
        for group in groups:
            x0=min(b[1].start for b in group)-2
            x1=max(b[1].stop for b in group)+2
            top=min(b[0].start for b in group)-2+y0
            bottom=max(b[0].stop for b in group)+2+y0
            boxes.append([max(0,x0),max(0,top),min(w,x1)-max(0,x0),min(h,bottom)-max(0,top)])
    manifest[name]={'source':'res://'+str(path).replace('\\','/'),'boxes':boxes,'packed_height':420}
    print(name,'12 poses, row boundaries',boundaries)
Path('assets/bosses/atlas-layout.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')

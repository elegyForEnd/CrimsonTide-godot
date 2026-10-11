"""Register API edits into stable native-4K body/face layers and full PNG exports.

Raw provider outputs remain unchanged in art/story-portraits/masters.
"""
from pathlib import Path
import argparse
import hashlib
import json
import io

import cv2
import numpy as np
from PIL import Image,ImageDraw,ImageFilter

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/"art/story-portraits"
ASSETS=ROOT/"assets/story/portraits"
cv2.setNumThreads(4)

def save_image(image,path):
    # Short atomic writes avoid publishing a half-written PNG to the importer.
    buffer=io.BytesIO();image.save(buffer,format="PNG",compress_level=6)
    temporary=path.with_suffix(".tmp.png");temporary.write_bytes(buffer.getvalue());temporary.replace(path)


def read(path):
    image=Image.open(path).convert("RGBA")
    if image.size!=(2160,3840): raise ValueError("Expected native 4K: "+str(path))
    return image


def register_face(base, edited, rect, source_eyes, target_eyes):
    source=np.asarray(source_eyes,dtype="float64");target=np.asarray(target_eyes,dtype="float64")
    delta=source[1]-source[0];wanted=target[1]-target[0]
    ratio=complex(*wanted)/complex(*delta)
    linear=np.array([[ratio.real,-ratio.imag],[ratio.imag,ratio.real]])
    translation=target[0]-linear@source[0]
    matrix=np.column_stack([linear,translation]).astype("float32")
    x,y,w,h=rect;local=matrix.copy();local[:,2]-=np.asarray([x,y],dtype="float32")
    aligned=cv2.warpAffine(np.asarray(edited),local,(w,h),flags=cv2.INTER_LANCZOS4,borderMode=cv2.BORDER_CONSTANT)
    patch=Image.fromarray(aligned,"RGBA")
    return patch,{"method":"reviewed-eye-landmarks","source_eyes":source_eyes,"target_eyes":target_eyes,"matrix":matrix.tolist()}

MOUTH_POINTS={"feiyue":(1068,755),"xueli":(1090,609),"yayu":(1092,590)}
MOUTH_SOURCES={"xueli":{"smile":"shy","sad":"angry","determined":"angry","tired":"worried"},"yayu":{"smile":"shy","angry":"determined","tired":"neutral"}}
def feature_mask(rect,eyes,kind,hero):
    x,y,w,h=rect;mask=Image.new("L",(w,h),0);draw=ImageDraw.Draw(mask)
    if kind.startswith("eyes"):
        for ex,ey in eyes:
            draw.ellipse((ex-x-77,ey-y-80,ex-x+77,ey-y+20),fill=255)
            if kind in ["eyes-shy","eyes-joy"]:
                draw.ellipse((ex-x-43,ey-y+20,ex-x+43,ey-y+53),fill=180)
    else:
        mx,my=MOUTH_POINTS[hero];rx=62 if hero=="feiyue" else 53;ry=34
        draw.ellipse((mx-x-rx,my-y-ry,mx-x+rx,my-y+ry),fill=255)
    return np.asarray(mask.filter(ImageFilter.GaussianBlur(4))).astype("float32")/255


def build(partial=False):
    plan=json.loads((ART/"production-plan.json").read_text(encoding="utf-8"))
    ASSETS.mkdir(parents=True,exist_ok=True)
    manifest={"version":1,"canvas":[2160,3840],"quality_requested":"max",
              "quality_note":"Provider logs standard and omits response quality; user approved proceeding with explicit max.",
              "expressions":plan["expressions"],"costumes":plan["costumes"],"heroes":{}}
    report=[]; missing=[]
    eye_data=json.loads((ART/"eye-registration.json").read_text(encoding="utf-8"))["landmarks"]
    for hero in plan["heroes"]:
        config=json.loads((ART/f"{hero}-registration.json").read_text(encoding="utf-8"))
        rect=config["face_rect"];x,y,w,h=rect
        base=read(ART/"masters"/f"{hero}-regular-neutral.png")
        folder=ASSETS/hero;folder.mkdir(exist_ok=True)
        exports=ART/"exports"/hero;exports.mkdir(parents=True,exist_ok=True)
        entry={"bodies":{},"faces":{},"face_rect":rect,"canvas":[2160,3840],"ready":True}
        for costume in plan["costumes"]:
            source=ART/"masters"/f"{hero}-{costume}-neutral.png"
            if not source.exists(): missing.append(str(source));entry["ready"]=False;continue
            body=read(source)
            if costume!="regular":
                base_bottom=int(np.where(np.asarray(base.getchannel("A"))>200)[0].max())
                body_bottom=int(np.where(np.asarray(body.getchannel("A"))>200)[0].max())
                offset=base_bottom-body_bottom
                if abs(offset)>160: raise ValueError("Clothing foot registration needs review: "+str(source))
                registered=Image.new("RGBA",body.size);registered.paste(body,(0,offset));body=registered
                # Lock the entire top/head to the user's approved base. Feather only
                # the neck transition, so expression anchors never depend on clothing.
                src=np.asarray(body).copy(); original=np.asarray(base)
                cutoff=y+h+12; blend=32
                src[:cutoff]=original[:cutoff]
                for row in range(cutoff,min(3840,cutoff+blend)):
                    t=(row-cutoff)/blend
                    src[row]=np.rint(original[row]*(1-t)+src[row]*t).astype("uint8")
                body=Image.fromarray(src,"RGBA")
            target=folder/f"body-{costume}.png"; save_image(body,target)
            save_image(body,exports/f"{costume}-neutral.png")
            entry["bodies"][costume]="res://"+target.relative_to(ROOT).as_posix()
            report.append({"hero":hero,"costume":costume,"expression":"neutral","source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"output":target.relative_to(ROOT).as_posix()})
        edit_mask=Image.open(ART/"masks"/f"{hero}-face-edit.png").getchannel("A").crop((x,y,x+w,y+h))
        weight=255-np.asarray(edit_mask).astype("uint16")
        registered={}
        for expression in plan["expressions"]:
            if expression=="neutral":continue
            source=ART/"masters"/f"{hero}-regular-{expression}.png"
            if source.exists():registered[expression]=register_face(base,read(source),rect,eye_data[hero][expression],eye_data[hero]["neutral"])
        base_face=np.asarray(base.crop((x,y,x+w,y+h))).astype("float32")
        for expression in plan["expressions"]:
            if expression=="neutral":continue
            source=ART/"masters"/f"{hero}-regular-{expression}.png"
            if not source.exists():missing.append(str(source));entry["ready"]=False;continue
            patch,registration=registered[expression]
            # Provider masks sometimes leave the original collar across the edited
            # jaw. Compose only facial features and retain the complete base outline.
            # Reuse a documented, valid generated mouth from the same character.
            mouth_source=MOUTH_SOURCES.get(hero,{}).get(expression,expression)
            mouth_image=base_face if mouth_source=="neutral" else np.asarray(registered[mouth_source][0]).astype("float32")
            eyes_weight=feature_mask(rect,eye_data[hero]["neutral"],"eyes-"+expression,hero)[:,:,None]
            mouth_weight=feature_mask(rect,eye_data[hero]["neutral"],"mouth",hero)[:,:,None]
            data=base_face*(1-eyes_weight)+np.asarray(patch).astype("float32")*eyes_weight
            data=data*(1-mouth_weight)+mouth_image*mouth_weight
            union=np.maximum(eyes_weight[:,:,0],mouth_weight[:,:,0])
            data=np.rint(data).astype("uint8");data[:,:,3]=np.rint(255*union*weight/255).astype("uint8")
            registration["mouth_source"]=mouth_source
            patch=Image.fromarray(data,"RGBA")
            target=folder/f"face-{expression}.png";save_image(patch,target)
            entry["faces"][expression]="res://"+target.relative_to(ROOT).as_posix()
            full=base.copy();full.alpha_composite(patch,(x,y));save_image(full,exports/f"regular-{expression}.png")
            report.append({"hero":hero,"costume":"regular","expression":expression,"source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"output":target.relative_to(ROOT).as_posix(),"registration":registration})
        manifest["heroes"][hero]=entry
    if missing and not partial: raise FileNotFoundError("Incomplete production: "+", ".join(missing))
    (ASSETS/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
    (ART/"layer-build-report.json").write_text(json.dumps({"items":report,"missing":missing},ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({"built":len(report),"missing":len(missing),"ready_heroes":[k for k,v in manifest["heroes"].items() if v["ready"]]},ensure_ascii=False),flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--partial",action="store_true")
    build(parser.parse_args().partial)

"""Package built-in imagegen originals into blank bases and transparent VN features.

No image generation, painting, inpainting or head replacement occurs here.
Operations: crop transparent component atlases, register layers and upscale canvas.
"""
from pathlib import Path
import argparse
import hashlib
import json
import cv2
import numpy as np
from PIL import Image, ImageFont, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/vn-portraits-v2"
ASSETS = ROOT / "assets/story/vn-portraits-v2"
HEROES = ["feiyue", "xueli", "yayu"]
COSTUMES = ["regular", "travel", "ceremony"]
POSES = ["relaxed", "crossed", "clasped"]
EXPRESSIONS = ["neutral", "smile", "joy", "shy", "worried", "sad", "angry", "determined", "surprised", "tired"]
CANVAS = (2160, 3840)


def read(path):
    with Image.open(path) as source:
        image = source.convert("RGBA")
    if image.getchannel("A").getextrema()[0] != 0:
        raise ValueError("Expected real transparent original: " + str(path))
    return image


def write(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp.png")
    image.save(tmp, compress_level=6)
    tmp.replace(path)


def tight(image, threshold=8):
    alpha = np.asarray(image.getchannel("A"))
    yy, xx = np.where(alpha > threshold)
    if not len(xx):
        raise ValueError("Empty feature crop")
    box = (int(xx.min()), int(yy.min()), int(xx.max())+1, int(yy.max())+1)
    cropped=image.crop(box)
    padded=Image.new("RGBA",(cropped.width+4,cropped.height+4))
    padded.alpha_composite(cropped,(2,2))
    return padded, box


def skin_box(image):
    pixels = np.asarray(image)
    h, w = pixels.shape[:2]
    r, g, b = pixels[:int(h*.28), :, :3].astype(int).transpose(2, 0, 1)
    mask = ((r > 180) & (g > 140) & (b > 120) & (r-g > 12) & (g-b > 1)
            & (pixels[:int(h*.28), :, 3] > 200)).astype("uint8")
    _, _, stats, centers = cv2.connectedComponentsWithStats(mask)
    candidates = [(int(st[4]), st) for st, ce in zip(stats[1:], centers[1:])
                  if st[2] > w*.06 and abs(ce[0]-w*.5) < w*.2]
    if not candidates:
        raise ValueError("Blank face needs reviewed registration")
    return list(map(int, max(candidates, key=lambda item:item[0])[1][:4]))


def normalize(image):
    # Keep the original aspect and position; never rewrite a head or facial outline.
    factor = min((CANVAS[0]-160)/image.width, (CANVAS[1]-180)/image.height)
    size = (round(image.width*factor), round(image.height*factor))
    offset = ((CANVAS[0]-size[0])//2, CANVAS[1]-90-size[1])
    body = Image.new("RGBA", CANVAS)
    body.alpha_composite(image.resize(size, Image.Resampling.LANCZOS), offset)
    return body, factor, offset


def split_atlas(hero):
    atlas = read(ART / "masters" / f"{hero}-expressions.png")
    folder = ASSETS / hero / "features"
    features = {}
    # Cells and mouth split are confirmed in the generated atlas contact sheets.
    reviewed = json.loads((ART / "registration.json").read_text()) if (ART / "registration.json").exists() else {}
    config = reviewed.get("atlases", {}).get(hero, {})
    for index, expression in enumerate(EXPRESSIONS):
        col, row = index % 2, index // 2
        x0, x1 = round(atlas.width*col/2), round(atlas.width*(col+1)/2)
        y0, y1 = round(atlas.height*row/5), round(atlas.height*(row+1)/5)
        eye_top,eye_bottom = config["eye_rows"][row]
        mx,my,mw,mh = config["mouths"][index]
        mouth_box = (max(mx-2,0),max(my-2,0),min(mx+mw+2,atlas.width),min(my+mh+2,atlas.height))
        features[expression] = {}
        for kind, box in [("eyes",(x0,eye_top,x1,eye_bottom)), ("mouth",mouth_box)]:
            component, local_box = tight(atlas.crop(box))
            path = folder / f"{kind}-{expression}.png"
            write(component, path)
            features[expression][kind] = {"path":"res://"+path.relative_to(ROOT).as_posix(),
                                          "size":list(component.size), "atlas_crop":list(box),
                                          "alpha_bounds":list(local_box)}
    return features


def build(partial=False):
    ASSETS.mkdir(parents=True, exist_ok=True)
    manual = json.loads((ART/"registration.json").read_text()) if (ART/"registration.json").exists() else {}
    manifest = {"version":2,"canvas":list(CANVAS),"generator":"built-in imagegen",
                "native_4k":False,"review_state":"rejected-facial-art; production incomplete",
                "resampling":"Lanczos; original resolution recorded per base",
                "expressions":EXPRESSIONS,"costumes":COSTUMES,"poses":POSES,"heroes":{}}
    report = {"sources":[],"missing":[],"head_replacement":False,"skin_backplates":False}
    blush_source = ART/"masters/blush.png"
    if blush_source.exists():
        blush = read(blush_source)
        for index, name in enumerate(["natural","shy"]):
            part, _ = tight(blush.crop((0,round(blush.height*index/2),blush.width,round(blush.height*(index+1)/2))))
            write(part, ASSETS/f"blush-{name}.png")
    else: report["missing"].append(str(blush_source))
    for hero in HEROES:
        entry = {"ready":True,"bases":{},"features":{}}
        atlas = ART/"masters"/f"{hero}-expressions.png"
        if atlas.exists(): entry["features"] = split_atlas(hero)
        else: report["missing"].append(str(atlas));entry["ready"]=False
        for costume in COSTUMES:
            entry["bases"][costume] = {}
            for pose in POSES:
                key = f"{hero}-{costume}-{pose}"
                path = ART/"masters"/f"{key}.png"
                retake = ART/"masters"/f"{key}-retake.png"
                if retake.exists():path=retake
                if not path.exists(): report["missing"].append(str(path));entry["ready"]=False;continue
                original = read(path)
                box = manual.get("bases",{}).get(key,{}).get("skin_box",skin_box(original))
                body, scale, offset = normalize(original)
                target = ASSETS/hero/f"base-{costume}-{pose}.png"
                write(body,target)
                x,y,w,h = box
                x,y,w,h = x*scale+offset[0],y*scale+offset[1],w*scale,h*scale
                # Normalized feature frame; all expressions occupy the SAME rect.
                eye_y = {"feiyue":.44,"xueli":.48,"yayu":.51}[hero]
                mouth_y = {"feiyue":.67,"xueli":.78,"yayu":.78}[hero]
                eye_width = w*.92
                eye_height = w*.29
                eyes = [round(x+(w-eye_width)/2),round(y+h*eye_y-eye_height*.72),round(eye_width),round(eye_height)]
                mouth_w,mouth_h=w*.24,w*.15
                mouth = [round(x+(w-mouth_w)/2),round(y+h*mouth_y-mouth_h/2),round(mouth_w),round(mouth_h)]
                cheek = [round(x+w*.05),round(y+h*eye_y+w*.05),round(w*.9),round(w*.15)]
                rects = {"eyes":eyes,"mouth":mouth,"blush":cheek}
                rects.update(manual.get("bases",{}).get(key,{}).get("rects",{}))
                entry["bases"][costume][pose] = {"path":"res://"+target.relative_to(ROOT).as_posix(),"rects":rects,
                                                               "source_size":list(original.size),"source_skin_box":box}
                report["sources"].append({"name":key,"source":path.relative_to(ROOT).as_posix(),"resolution":list(original.size),"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"output":str(target.relative_to(ROOT))})
        manifest["heroes"][hero]=entry
    for hero in manifest["heroes"].values():
        hero["resources_complete"] = hero["ready"] and blush_source.exists()
        hero["ready"] = False  # User rejected the appearance; do not activate in a game.
    if report["missing"] and not partial:
        raise ValueError("Incomplete production: " + "\n".join(report["missing"]))
    (ART/"build-report.json").write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding="utf-8")
    (ASSETS/"manifest.json").write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding="utf-8")
    print("bases",len(report["sources"]),"missing",len(report["missing"]))


def compose(manifest, hero, costume, pose, expression, blank=False, natural_blush=True):
    entry=manifest["heroes"][hero];base=entry["bases"][costume][pose]
    image=read(ROOT/base["path"].removeprefix("res://"))
    if blank: return image
    layers=[]
    if natural_blush:
        layers.append(("blush","res://assets/story/vn-portraits-v2/blush-"+("shy" if expression=="shy" else "natural")+".png"))
    for kind in ["eyes","mouth"]: layers.append((kind,entry["features"][expression][kind]["path"]))
    for kind,path in layers:
        rect=base["rects"][kind];part=read(ROOT/path.removeprefix("res://"))
        part.thumbnail((rect[2],rect[3]),Image.Resampling.LANCZOS)
        # Fit without changing aspect; use common expression-independent anchor.
        at=(rect[0]+(rect[2]-part.width)//2,rect[1]+(rect[3]-part.height)//2)
        if kind=="blush":
            factor=.28 if expression!="shy" else .5
            part.putalpha(part.getchannel("A").point(lambda value:round(value*factor)))
        image.alpha_composite(part,at)
    return image


def gallery():
    manifest=json.loads((ASSETS/"manifest.json").read_text())
    font=ImageFont.truetype("C:/Windows/Fonts/arial.ttf",20)
    for hero in HEROES:
        entry=manifest["heroes"][hero]
        sheet=Image.new("RGB",(1500,2700),(25,22,35));draw=ImageDraw.Draw(sheet)
        for row,costume in enumerate(COSTUMES):
            for col,pose in enumerate(POSES):
                if pose not in entry["bases"][costume]:continue
                image=compose(manifest,hero,costume,pose,"neutral") if entry["features"] else read(ROOT/entry["bases"][costume][pose]["path"].removeprefix("res://"))
                image.thumbnail((490,850),Image.Resampling.LANCZOS)
                sheet.paste(image,(col*500+(500-image.width)//2,row*900+35),image)
                draw.text((col*500+18,row*900+8),costume+" / "+pose,font=font,fill=(225,205,168))
        write(sheet,ROOT/"build"/f"vn-v2-{hero}-bases.png")
        if not entry["features"]:continue
        faces=Image.new("RGB",(2000,900),(32,28,40));draw=ImageDraw.Draw(faces)
        if "relaxed" not in entry["bases"]["regular"]:continue
        base=entry["bases"]["regular"]["relaxed"]
        for index,expression in enumerate(EXPRESSIONS):
            image=compose(manifest,hero,"regular","relaxed",expression)
            ex,ey,ew,eh=base["rects"]["eyes"]
            crop=image.crop((ex-100,ey-100,ex+ew+100,base["rects"]["mouth"][1]+160))
            crop.thumbnail((380,390),Image.Resampling.LANCZOS)
            x,y=index%5*400,index//5*450
            faces.paste(crop,(x+(400-crop.width)//2,y+36),crop);draw.text((x+12,y+8),expression,font=font,fill=(230,214,181))
        write(faces,ROOT/"build"/f"vn-v2-{hero}-faces.png")


def main():
    parser=argparse.ArgumentParser();parser.add_argument("--partial",action="store_true");parser.add_argument("--gallery",action="store_true")
    args=parser.parse_args();build(args.partial)
    if args.gallery:gallery()

if __name__=="__main__":main()

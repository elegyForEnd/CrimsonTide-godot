"""Whole-image-only VN packaging and review galleries. Never splice facial/body pixels."""
from pathlib import Path
import argparse,hashlib,json,time
import numpy as np
from PIL import Image,ImageFont,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/"art/vn-full-v3"
ASSETS=ROOT/"assets/story/vn-full-v3"
HEROES=["feiyue","xueli","yayu"]
COSTUMES=["regular","home","travel"]
POSES=["front","turn","crossed"]
EXPRESSIONS=["neutral","smile","joy","shy","worried","sad","angry","surprised"]
CANVAS=(2160,3840)

def load_jobs():return json.loads((ART/"jobs.json").read_text(encoding="utf-8"))
def write_json_atomic(path,data):
    temporary=path.with_suffix(".tmp.json")
    temporary.write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding="utf-8")
    for attempt in range(10):
        try:temporary.replace(path);return
        except PermissionError:
            if attempt==9:raise
            time.sleep(.05)
def source(job):return ROOT/job["output"]
def read(path):
    with Image.open(path) as image:return image.convert("RGBA")
def write(image,path):
    path.parent.mkdir(parents=True,exist_ok=True)
    tmp=path.with_suffix(".tmp.png");image.save(tmp,compress_level=6);tmp.replace(path)

def fit_whole(image,canvas=CANVAS):
    # One affine resize of the ENTIRE image, plus transparent padding. No body/face
    # separation, feature extraction, head transplant or masked compositing.
    alpha=np.asarray(image.getchannel("A"));yy,xx=np.where(alpha>16)
    if not len(xx):raise ValueError("Empty portrait")
    bounds=(int(xx.min()),int(yy.min()),int(xx.max())+1,int(yy.max())+1)
    factor=min((canvas[0]-160)/(bounds[2]-bounds[0]),(canvas[1]-200)/(bounds[3]-bounds[1]))
    target=image.resize((round(image.width*factor),round(image.height*factor)),Image.Resampling.LANCZOS)
    at=(round((canvas[0]-(bounds[2]-bounds[0])*factor)/2-bounds[0]*factor),round(canvas[1]-100-bounds[3]*factor))
    output=Image.new("RGBA",canvas);output.alpha_composite(target,at)
    return output,{"whole_image_scale":factor,"whole_image_offset":list(at),"source_alpha_bounds":list(bounds)}

def ledger():
    data=load_jobs();produced=0
    for job in data["jobs"]:
        path=source(job);record=path.with_suffix(".json")
        if path.exists() and record.exists():
            job["status"]="generated";job["source_metadata"]=json.loads(record.read_text(encoding="utf-8"));produced+=1
            if "prompt" in job["source_metadata"]:
                job["prompt"]=job["source_metadata"]["prompt"]
                (ART/"prompts"/(job["id"]+".txt")).write_text(job["prompt"],encoding="utf-8")
        else:
            job["status"]="pending";job.pop("source_metadata",None)
    data["generated"]=produced
    write_json_atomic(ART/"jobs.json",data)
    print("whole portraits generated",produced,"/ 216")
    return data

def build(partial=False):
    data=ledger();missing=[]
    manifest={"version":3,"whole_portraits":True,"facial_compositing":False,"canvas":list(CANVAS),
              "generator":"built-in imagegen","resampling":"whole image Lanczos upscale; source resolution retained",
              "costumes":COSTUMES,"poses":POSES,"expressions":EXPRESSIONS,"heroes":{}}
    report=[]
    for hero in HEROES:manifest["heroes"][hero]={"ready":True,"portraits":{c:{p:{} for p in POSES} for c in COSTUMES}}
    for job in data["jobs"]:
        path=source(job);entry=manifest["heroes"][job["hero"]]
        if not path.exists():missing.append(job["id"]);entry["ready"]=False;continue
        image=read(path)
        if image.getchannel("A").getextrema()[0]!=0:raise ValueError("Missing true alpha "+job["id"])
        target=ASSETS/job["hero"]/(job["id"]+".png")
        if not target.exists() or target.stat().st_mtime<path.stat().st_mtime:
            output,transform=fit_whole(image);write(output,target)
        else:
            # Only compute lightweight metadata when the immutable export exists.
            alpha=np.asarray(image.getchannel("A"));yy,xx=np.where(alpha>16)
            transform={"source_alpha_bounds":[int(xx.min()),int(yy.min()),int(xx.max())+1,int(yy.max())+1]}
        entry["portraits"][job["costume"]][job["pose"]][job["expression"]]="res://"+target.relative_to(ROOT).as_posix()
        report.append({"id":job["id"],"source_resolution":list(image.size),"native_4k":image.size==CANVAS,
                       "source_sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"source":job["output"],"export":str(target.relative_to(ROOT)),**transform})
    if missing and not partial:raise ValueError("Missing independent full portraits: "+str(len(missing)))
    manifest["complete"]=not missing
    write_json_atomic(ASSETS/"manifest.json",manifest)
    write_json_atomic(ART/"build-report.json",{"exported":len(report),"missing":missing,"portraits":report,"facial_compositing":False})
    print("4K canvases",len(report),"complete",not missing)

def gallery(masters_only=False):
    jobs=load_jobs()["jobs"];font=ImageFont.truetype("C:/Windows/Fonts/arial.ttf",18)
    for hero in HEROES:
        sheet=Image.new("RGBA",(1500,2700),(26,22,34,255));draw=ImageDraw.Draw(sheet)
        for row,costume in enumerate(COSTUMES):
            for col,pose in enumerate(POSES):
                job=next(j for j in jobs if (j["hero"],j["costume"],j["pose"],j["expression"])==(hero,costume,pose,"neutral"))
                if not source(job).exists() or not source(job).with_suffix(".json").exists():continue
                image=read(source(job));image.thumbnail((485,845),Image.Resampling.LANCZOS)
                sheet.alpha_composite(image,(col*500+(500-image.width)//2,row*900+42))
                draw.text((col*500+14,row*900+10),costume+" / "+pose,font=font,fill=(232,210,174))
        write(sheet.convert("RGB"),ROOT/"build"/("vn-full-"+hero+"-masters.png"))
    if masters_only:return
    # Whole-body rows prove each variation is an independently generated image.
    for hero in HEROES:
        for costume in COSTUMES:
            for pose in POSES:
                sheet=Image.new("RGBA",(2400,1500),(26,22,34,255));draw=ImageDraw.Draw(sheet)
                for index,expression in enumerate(EXPRESSIONS):
                    job=next(j for j in jobs if (j["hero"],j["costume"],j["pose"],j["expression"])==(hero,costume,pose,expression))
                    if not source(job).exists() or not source(job).with_suffix(".json").exists():continue
                    image=read(source(job));image.thumbnail((580,695),Image.Resampling.LANCZOS)
                    x,y=index%4*600,index//4*750
                    sheet.alpha_composite(image,(x+(600-image.width)//2,y+40))
                    draw.text((x+16,y+9),expression,font=font,fill=(232,210,174))
                write(sheet.convert("RGB"),ROOT/"build"/f"vn-full-{hero}-{costume}-{pose}-expressions.png")
                face_sheet=Image.new("RGBA",(2400,1100),(26,22,34,255));face_draw=ImageDraw.Draw(face_sheet)
                for index,expression in enumerate(EXPRESSIONS):
                    job=next(j for j in jobs if (j["hero"],j["costume"],j["pose"],j["expression"])==(hero,costume,pose,expression))
                    if not source(job).exists() or not source(job).with_suffix(".json").exists():continue
                    image=read(source(job))
                    # Inspection crop of the full generated image, never used as art.
                    crop=image.crop((round(image.width*.22),round(image.height*.035),round(image.width*.78),round(image.height*.25)))
                    crop.thumbnail((570,495),Image.Resampling.LANCZOS)
                    x,y=index%4*600,index//4*550
                    face_sheet.alpha_composite(crop,(x+(600-crop.width)//2,y+42))
                    face_draw.text((x+16,y+9),expression,font=font,fill=(232,210,174))
                write(face_sheet.convert("RGB"),ROOT/"build"/f"vn-full-{hero}-{costume}-{pose}-faces.png")

def main():
    parser=argparse.ArgumentParser();parser.add_argument("--ledger",action="store_true");parser.add_argument("--partial",action="store_true");parser.add_argument("--gallery",action="store_true");parser.add_argument("--masters-only",action="store_true");parser.add_argument("--review-only",action="store_true");parser.add_argument("--gallery-only",action="store_true")
    args=parser.parse_args()
    if args.ledger:ledger()
    elif args.masters_only:ledger();gallery(True)
    elif args.review_only:ledger();gallery()
    elif args.gallery_only:gallery()
    else:
        build(args.partial)
        if args.gallery:gallery()
if __name__=="__main__":main()

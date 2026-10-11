"""Composite registered portraits over an opaque review background for visual QA."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
def main():
    art=ROOT/"art/story-portraits"
    plan=json.loads((art/"production-plan.json").read_text(encoding="utf-8"))
    font=ImageFont.truetype(str(ROOT/"assets/NotoSansSC.ttf"),22)
    names={"feiyue":"绯月","xueli":"雪璃","yayu":"鸦羽"}
    all_faces=Image.new("RGB",(2000,2460),"#24333e");all_clothes=Image.new("RGB",(1800,2760),"#24333e")
    for row,hero in enumerate(plan["heroes"]):
        x,y,w,h=json.loads((art/(hero+"-registration.json")).read_text())["face_rect"]
        c=Image.new("RGB",(2000,820),"#24333e");d=ImageDraw.Draw(c)
        for i,(emotion,label) in enumerate(plan["expressions"].items()):
            im=Image.open(art/"exports"/hero/("regular-"+emotion+".png")).convert("RGBA").crop((x-115,y-100,x+w+115,y+h+105))
            im.thumbnail((390,355),Image.Resampling.LANCZOS);col=i%5;r=i//5;c.paste(im,(col*400+(400-im.width)//2,r*410+10),im)
            d.text((col*400+20,r*410+371),names[hero]+" · "+label,font=font,fill="#eadcbd")
        c.save(ROOT/"build"/("portrait-"+hero+"-expressions.png"));all_faces.paste(c,(0,row*820))
        c=Image.new("RGB",(1800,920),"#24333e");d=ImageDraw.Draw(c)
        for i,(costume,label) in enumerate(plan["costumes"].items()):
            im=Image.open(ROOT/"assets/story/portraits"/hero/("body-"+costume+".png")).convert("RGBA")
            im.thumbnail((440,840),Image.Resampling.LANCZOS);c.paste(im,(i*450+(450-im.width)//2,10),im)
            d.text((i*450+18,870),names[hero]+" · "+label,font=font,fill="#eadcbd")
        c.save(ROOT/"build"/("portrait-"+hero+"-costumes.png"));all_clothes.paste(c,(0,row*920))
    all_faces.save(ROOT/"build/portrait-all-expressions.png");all_clothes.save(ROOT/"build/portrait-all-costumes.png")
if __name__=="__main__":main()

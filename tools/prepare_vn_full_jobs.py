"""Create the user's 216 independent full-portrait generation specs. No API requests."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/"art/vn-full-v3"
HEROES={
 "feiyue":{"name":"绯月","identity":"white flowing hair, softly rounded ruby-red eyes, black hair bow with ruby and white flower, purple heart-tipped tail. Keep original delicate face and soft cheek blush.",
 "regular":"exact original white puff sleeves, black/gold gothic layered dress, ruby neck bow, lace socks and black Mary Jane shoes. No lantern, no weapon, empty hands.",
 "home":"modest cozy ivory and burgundy home dress with long soft sleeves, knitted shawl, small ruby ribbon, delicate lace hem and comfortable slippers. Original hair ornaments and tail remain. No armor, weapon or lantern.",
 "travel":"practical beautifully tailored burgundy/black travel coat over a layered skirt, antique gold embroidered shoulder cape, leather belt and satchel, laced travel boots, ruby details. Original hair and tail remain. No weapon, no lantern."},
 "xueli":{"name":"雪璃","identity":"long flowing pale-blue curly hair, softly rounded cyan-blue eyes, silver star ornaments and mint ribbons. Keep original gentle face and faint cheek blush.",
 "regular":"exact original navy ceremonial cleric veil with silver star embroidery, mint bow, navy and white lace dress, tall boots. Her cyan lantern is held low or hangs from her belt when hands are occupied. No katana or tail.",
 "home":"modest cozy pale-aqua linen home dress with navy knitted cardigan, long sleeves, tiny silver star buttons and mint hair ribbon, indoor flat slippers. Replace ceremonial veil with small silver star hair clips; preserve blue curly hairstyle. No lantern, weapon or armor.",
 "travel":"CHANGE THE ENTIRE CLOTHING to a distinct traveling UNIFORM: pale aqua tailored button-up jacket, white high-collar blouse, fitted long navy TROUSERS, silver star buttons, leather utility belt, small satchel and practical ankle boots. NO dress, NO skirt, NO exposed thighs, NO ceremonial veil. Blue curly hair with small silver star clips remains; cyan lantern at belt. Do not retain the original ceremonial cleric gown. The silhouette must clearly differ from the regular and home dresses; no sword or tail."},
 "yayu":{"name":"鸦羽","identity":"deep violet high ponytail with silver ornaments and purple ribbons, softly rendered violet eyes, original delicate serious face with a faint natural cheek tint.",
 "regular":"exact original black fitted armor and gauntlets, purple split overskirt with silver patterns, dark stockings and armored boots. Original sheathed katana at hip. No lantern, tail or new jewelry.",
 "home":"modest soft charcoal and muted violet long-sleeved home dress, comfortable knitted cardigan, small silver clasp and cloth slippers, no armor, weapon or lantern. Preserve violet high ponytail and ribbons.",
 "travel":"CHANGE THE ENTIRE CLOTHING to a distinct traveling UNIFORM: crisp white high-neck blouse, tailored dark-violet military-style tailcoat with silver buttons and short asymmetric shoulder cape, fitted long charcoal TROUSERS with silver braid down the sides, leather satchel, knee-high travel boots. NO armored bodice, NO skirt, NO thigh-high stockings, NO exposed thighs. Violet high ponytail, ribbons and sheathed katana remain. The silhouette must clearly differ from the original armored dress and cozy home gown. No lantern or tail."}
}
POSES={
 "front":"Pose1: naturally relaxed front-facing standing, arms resting at sides, gentle original head inclination. Xueli regular can hold her lantern low. Exactly two arms and hands.",
 "turn":"Pose2: MOSTLY FRONT-FACING, only a gentle 15 to20 degree torso/hip yaw toward viewer's left, both shoulders and almost the entire front bodice remain visible. One hand lightly touching her collar/ribbon at chest, other arm naturally relaxed. Face almost directly toward viewer with a small natural head tilt. Use the supplied VN screenshot only as a reference for this mild body angle, not for character identity or clothing. NOT a strong three-quarter view, NOT profile, NOT back-facing, NOT looking back over the shoulder, NO twisted neck or crossed legs. Exactly two arms and hands.",
 "crossed":"Pose3: MOSTLY FRONT-FACING, only a gentle 10 to15 degree torso yaw toward viewer's right, both shoulders and most front bodice visible. Both arms naturally crossed in front of chest, face almost directly toward viewer with original natural head tilt. Like the supplied VN screenshot's mild angle; no profile or strong three-quarter view, no back-looking head, no twisted neck. Exactly two arms and hands, no third lowered arm. Held objects hang from belt instead."
}
EXPRESSIONS={
 "neutral":"calm natural neutral expression, gently open eyes and a tiny closed mouth, soft restful eyebrows, faint original natural blush",
 "smile":"small gentle closed-mouth smile, subtle warmth in original rounded eyes and faint natural blush, no broad grin",
 "joy":"natural pleased happiness, softly closed smiling crescent eyes and a small cheerful smiling mouth, slightly stronger cheek warmth, preserve the original face proportions, no huge open-mouth cartoon face",
 "shy":"gentle bashful expression, subtly lowered gaze, small shy closed-mouth smile, a little more pink blush, no dramatic eyebrows",
 "worried":"quiet concern, slightly raised inner eyebrows, original eye proportions, tiny uneasy closed mouth, natural subtle emotion",
 "sad":"restrained sadness, softly lowered brows and slight tear sheen, small downturned mouth, no distorted crying face",
 "angry":"restrained displeasure, subtly narrowed eyes and lightly furrowed brows, small firm mouth, not yelling, not exaggerated or scary",
 "surprised":"soft natural surprise, slightly widened eyes with original size/proportions, modest raised brows and a tiny slightly parted mouth, no enormous circular mouth"
}

def prompt(hero,costume,pose,expression,edit=False):
    h=HEROES[hero]
    return ("Use case: identity-preserve. Production Japanese visual novel FULL PORTRAIT, one character only. "
      + ("Image1 is the complete pose/costume portrait to edit. Change ONLY the facial emotion while keeping its complete hair, head outline, head angle, clothing, hands, pose, body, camera, placement and scale as consistent as possible. Output an ENTIRE independently rendered full portrait, not layers or facial components. Image2 is original character identity. " if edit else "Image1 is the ORIGINAL character design, not generic anime styling. If the final reference is a green-haired VN screenshot, use it ONLY for the gentle near-front torso angle; NEVER borrow its face, green hair, school uniform, background or UI. Preserve original facial identity, original softly rounded eyes, small natural mouth, delicate nose, original head/body proportion and soft painterly fine anime linework. ")
      +f"Character: {h['name']} / {hero}. {h['identity']} Outfit: {h[costume]} {POSES[pose]} Expression: {EXPRESSIONS[expression]}. "
      +"Natural high-quality Galgame expression, never plastic glossy eyes, mismatched facial cutouts, generic floating eyes, broad huge mouth, realistic face, flat mask or facial assembly. Full figure from complete hair tip to shoes, centered, transparent margins on all sides. Crisp delicate cloth folds, ornaments and natural anatomically correct hands. Soft consistent diffuse lighting. Real transparent alpha PNG background, no scenery, ground shadows, text, labels, atlas, sheet, collage or extra person. Highest available portrait resolution; preserve actual source resolution metadata.")

def main():
    ART.mkdir(parents=True,exist_ok=True);(ART/"prompts").mkdir(exist_ok=True)
    jobs=[]
    for hero in HEROES:
      for costume in ["regular","home","travel"]:
       for pose in POSES:
        for expression in EXPRESSIONS:
          key=f"{hero}-{costume}-{pose}-{expression}"
          value=prompt(hero,costume,pose,expression,expression!="neutral")
          (ART/"prompts"/(key+".txt")).write_text(value,encoding="utf-8")
          jobs.append({"id":key,"hero":hero,"costume":costume,"pose":pose,"expression":expression,"prompt":value,
                       "status":"pending","output":"art/vn-full-v3/masters/"+key+".png"})
    path=ART/"jobs.json"
    if path.exists():
      previous={j["id"]:j for j in json.loads(path.read_text(encoding="utf-8"))["jobs"]}
      for j in jobs:
       if j["id"] in previous and previous[j["id"]]["status"]!="pending":
        old=previous[j["id"]]
        j["status"]=old["status"]
        if "source_metadata" in old:j["source_metadata"]=old["source_metadata"]
    for j in jobs:
      record=(ROOT/j["output"]).with_suffix(".json")
      if record.exists():
        actual=json.loads(record.read_text(encoding="utf-8"))
        if "prompt" in actual:j["prompt"]=actual["prompt"]
      (ART/"prompts"/(j["id"]+".txt")).write_text(j["prompt"],encoding="utf-8")
    path.write_text(json.dumps({"version":3,"generator":"built-in imagegen","scope":216,"whole_portraits":True,"jobs":jobs},indent=2,ensure_ascii=False),encoding="utf-8")
    print("216 full independent portraits; 27 pose/costume masters then 189 expression edits")
if __name__=="__main__":main()

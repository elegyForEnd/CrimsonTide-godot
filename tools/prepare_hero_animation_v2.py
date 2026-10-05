"""Extract original walking sprites as identity references; no synthesized art."""
from pathlib import Path
from PIL import Image
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/hero-animation-v2/references'
OUT.mkdir(parents=True, exist_ok=True)
for hero in range(3):
    source = Image.open(ROOT / f'assets/combat/movement-{hero}.png').convert('RGBA')
    pose = source.crop((0, 0, 362, 384))
    # Uniform enlargement of the source reference, preserving its proportions.
    pose = pose.resize((724, 768), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (1024, 1024))
    canvas.alpha_composite(pose, (150, 128))
    canvas.save(OUT / f'hero-{hero}-walk.png')
    attacks = Image.open(ROOT / f'assets/combat/attack-clean-{hero}.png').convert('RGBA')
    for row, action in enumerate(('sword', 'heavy', 'staff')):
        weapon_pose = attacks.crop((0, row*362, 362, (row+1)*362))
        weapon_pose = weapon_pose.resize((724, 724), Image.Resampling.LANCZOS)
        weapon_canvas = Image.new('RGBA', (1024, 1024))
        weapon_canvas.alpha_composite(weapon_pose, (150, 150))
        weapon_canvas.save(OUT / f'hero-{hero}-{action}-weapon.png')
print('Extracted three original walking identity references')

IDENTITIES = [
    'Silver-white long hair and single curl, red eyes, black bow with white flower and red ribbons, puffed white sleeves, black gold-trimmed dress with lace hem, white socks and black shoes.',
    'Long pale icy blue hair, teal eyes and ribbons, small black embroidered cap, black silver-trimmed coat, teal scarf, black gloves and boots.',
    'Dark violet high ponytail with purple ribbon and silver hair ornament, violet eyes, black engraved armor, purple-black coat tails and black armored boots.',
]
PHASES = {
    'sword': [
        'Grounded compact ready stance; original crimson sword in right hand, blade diagonally down-right.',
        'Small anticipation: pull sword and right shoulder slightly back, bend knees.',
        'Deepen windup: twist shoulders back, blade high behind right shoulder.',
        'Maximum anticipation: sword held high, torso coiled, rear foot firmly planted.',
        'One strong broad slash toward screen right; front knee bent, sword extended diagonally down-right.',
        'Continue the same slash into low-right follow-through; hair and hem lag behind.',
        'Recover halfway toward ready stance, drawing blade back and straightening torso.',
        'Almost return to opening ready stance; tiny remaining recovery into frame 1.',
    ],
    'heavy': [
        'Grounded wide ready stance, original broad black greatsword with gold filigree held with both hands on its hilt, blade diagonally down-right.',
        'Draw greatsword back slightly, bend both knees and shift weight back.',
        'Raise greatsword overhead with both hands, shoulders twist back.',
        'Largest overhead windup, blade entirely within canvas and rear foot planted.',
        'One committed broad downward-right greatsword strike, strong whole-body follow-through.',
        'Sword continues to low-right finishing position, torso leaning and cloth trailing.',
        'Bring sword up toward ready guard, straighten halfway.',
        'Almost regain opening guard and stance, small remaining recovery into frame 1.',
    ],
    'staff': [
        'Compact standing casting ready stance; original ornate gold-caged cyan crystal staff in right hand, free left hand open.',
        'Draw staff slightly inward, free hand gathers power near chest; no detached effects.',
        'Twist shoulders back, staff drawn toward shoulder, bend knees slightly.',
        'Largest casting anticipation: staff raised beside head, free hand held inward.',
        'One strong forward casting gesture toward screen right with torso and both arms; keep staff gripped.',
        'Continue forward gesture, clothing and hair trail; no projectile or detached effects.',
        'Retract both hands halfway to original casting ready stance.',
        'Almost regain opening casting stance, small remaining recovery into frame 1.',
    ],
    'walk': [
        'In-place walk: near leg extended forward-right, far leg back-left; far arm forward, near arm back.',
        'Walk down phase: near foot planted forward, knees soften, rear heel lifts, opposite arms swing.',
        'Walk passing phase: near leg supports under pelvis, far knee passes forward; arms pass torso.',
        'Walk up phase: far leg extends forward, near heel lifts behind; opposite arms separate.',
        'Opposite contact: far leg forward-right, near leg back-left; near arm forward, far arm back.',
        'Opposite down phase: far foot planted forward, knees soften, near rear heel lifts.',
        'Opposite passing: far leg supports under pelvis, near knee passes forward.',
        'Opposite up phase: near leg extending forward toward opening contact, far heel lifts behind. Connect into frame 1.',
    ],
    'run': [
        'In-place run contact: torso tilted slightly forward, near leg reaching forward-right, far leg extended back-left; opposite bent arms.',
        'Run compression: near foot supports under body, far knee begins driving forward, torso lowers slightly.',
        'Run passing: far knee lifted forward, near leg pushes backward, opposite arms swap.',
        'Run flight: far leg reaches forward, near leg folds behind, both feet briefly airborne.',
        'Opposite run contact: far leg forward-right, near leg behind; bent arms in opposite positions.',
        'Opposite compression: far foot supports, near knee begins driving forward.',
        'Opposite passing: near knee lifted forward, far leg pushes backward.',
        'Opposite flight: near leg reaches toward frame 1 contact, far leg folds behind; seamless return into frame 1.',
    ],
    'dodge': [
        'Compact crouched ready stance, empty hands, preparing one low forward dodge toward screen right.',
        'Lower hips and bend knees deeper, arms draw back for a forward dodge.',
        'Push off rear foot, torso leans forward strongly; head remains upright and recognizable.',
        'Lowest sliding dodge pose, one leg stretched back, one bent under torso; no motion blur.',
        'Continue same low dodge, torso begins lifting slightly, feet tuck back under hips.',
        'Recover to low crouch, hands balance, torso rises halfway.',
        'Return toward compact ready crouch, knees and hair settling.',
        'Almost match opening compact crouch with small remaining recovery into frame 1.',
    ],
}

def prompt(hero, action, index):
    return '\n'.join([
        f'Use case: identity-preserve. Exactly ONE transparent PNG chibi game sprite, {action} frame {index+1} of 8.',
        'Image 1 is the ORIGINAL WALKING sprite, the authoritative identity and style. Preserve its very large round head, short small body and short legs, EXACT original head-to-body ratio, face, hair, costume, delicate outlines, soft painterly anime shading and subdued palette. Do not redesign or make the character taller.',
        f'Identity: {IDENTITIES[hero]}',
        ('Image 2 is the original attack sprite: use ONLY its exact existing weapon design, materials, colors, silhouette, decorations and length relative to the head; character identity and style remain governed by Image 1. If present, Image 3 is the action opening and Image 4 the immediately previous frame.' if action in ('sword','heavy','staff') else 'If present, Image 2 is the action opening and Image 3 the immediately previous frame. Advance chronologically, never repeat.'),
        f'Pose NOW: {PHASES[action][index]}',
        'Equipment: NO weapon or equipment in walk/run/dodge. For attacks copy the ORIGINAL weapon in Image 2 precisely: crimson red blade and ornate gold/dark guard for sword; broad black blade with elaborate gold filigree and gold edges for heavy; blue/cyan crystal in ornate gold cage with cyan ribbons for staff. Do not invent or simplify weapon design. Exactly one weapon; hands close around its hilt/shaft, always behind blade or crystal. Blade never emerges from pommel; no reversed grip.',
        'Fixed camera, screen-right three-quarter view, same head size throughout all actions, character centered about x=520, opening crown near y=260 and lowest sole near y=860 on a 1024 square. Movement is in place: pelvis stays centered, feet cycle relative to ground. Attack rear support foot stays grounded. Keep every weapon tip and hair strand inside with generous margin; do not shrink body to fit weapon.',
        'Genuine alpha transparency, empty background. One subject only. No checkerboard, floor, shadow, text, labels, VFX, motion trails, blur, extra limbs, duplicated body, or sprite sheet. Frame 8 must approach frame 1 for a smooth seam.',
    ])

jobs = []
for hero in range(3):
    for action in PHASES:
        directory = OUT.parent / 'prompts' / f'hero-{hero}' / action
        directory.mkdir(parents=True, exist_ok=True)
        for index in range(8):
            path = directory / f'{index:03d}.txt'
            path.write_text(prompt(hero, action, index), encoding='utf-8')
            jobs.append({'hero': hero, 'action': action, 'frame': index, 'prompt': str(path.relative_to(ROOT)), 'output': f'output/hero-animation-v2/hero-{hero}/{action}/{index:03d}.png'})
(OUT.parent / 'jobs.json').write_text(json.dumps(jobs, ensure_ascii=False, indent=2), encoding='utf-8')
(OUT.parent / 'README.md').write_text('''# 角色动画重做 v2

范围：绯月、雪璃、鸦羽；墓煜不包含。原走路图为唯一画风与人物比例基准。

每个角色：短剑、重剑、法杖、走路、跑步、闪避，每动作 8 张透明 PNG，合计 144 张。
每帧通过内置 imagegen 单独生成，原走路参考始终作为第一输入，动作首帧与上一帧作为后续输入。
走路/跑步按接触、下沉、经过、抬升、反侧接触、反侧下沉、反侧经过、反侧抬升排列。
攻击按准备、小蓄力、深蓄力、最大蓄力、打击、跟随、回收、接近起点排列。
角色 0 和 2 的移动动作不持武器；本轮三个角色移动动作均采用空手，以原走路图为准。

`references/` 为原图裁出的参考；`prompts/` 为全部 144 帧提示词；`jobs.json` 是输出清单。
实际生图尚未全部完成，不能将提示词或参考图当作新动画交付。成图检查画风、帧序、透明度、尺寸和脚部锚点后再接入游戏。
''', encoding='utf-8')
print(f'Prepared {len(jobs)} individual frame prompts')

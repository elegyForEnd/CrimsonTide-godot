# Boss 攻击动画逐帧提示词

每个 Boss 的攻击为 8 张独立 PNG：已确认的首帧加 7 张逐张生成的续帧。
模型：Rolldek `gpt-image-2.5-sunburst` 图片编辑 API；要求输出真正的透明 PNG。
通常 Image 1 是已确认的透明首帧，Image 2 是紧前一帧；每一帧的原始英文提示词如下。
第 8 帧要求接近第 1 帧，以便循环衔接。裂地者生成时临时镜像参考，交付时镜像回原朝向；月海兽第 2 帧额外参考第 3 帧作为中间姿势目标。

| Boss | 独特攻击动作 |
| --- | --- |
| 灰烬晚祷者 (`ashen-vesper`) | 锁链香炉蓄势后横扫，火焰跟随香炉 |
| 钟鸣大祭司 (`bell-hierophant`) | 钟杖从肩侧蓄力并大幅挥出 |
| 血之女王 (`blood-queen`) | 刺剑跨步斩击，六片红色翼刃张开后收拢 |
| 裂地者 (`earthsplitter`) | 环形巨口和前爪带动分节身躯突刺 |
| 冰骨龙 (`frostbone-dragon`) | 四足蓄力、昂首咬击，短促冰息后伏身 |
| 镜织者 (`mirror-weaver`) | 镜刃与悬浮碎镜联动，划出宽阔弧线 |
| 月海兽 (`moon-leviathan`) | 围绕血月收紧盘绕，探首突袭再回卷 |
| 无名之月 (`nameless-moon`) | 手势带动六枚冠刃环绕扫出 |
| 雷鹏 (`storm-roc-v2`) | 双翼下压，带雷光的双爪前探 |
| 荆棘猎王 (`thorn-huntsman`) | 双手持长矛，后脚发力完成长距离突刺 |

## 灰烬晚祷者 (`ashen-vesper`)

### 第 2 帧

```text
Create exactly ONE finished transparent PNG 2D anime game sprite: frame 2 of eight, a SMALL PREPARATORY movement after Image 1. Image 1 is the actual transparent opening pose and the exact identity reference. Preserve the same masked male ash priest, charred red-and-gold vestments, ember halo, two hands on the same ornate long staff, and one chained flaming censer on the right. He has not swung yet: shift his weight toward his back leg, bend both knees a little, turn shoulders slightly left, and draw the raised staff slightly farther behind the head while the hanging censer lags at screen right. Make this only a modest change from the first pose so the later frames have room for a large swing. Preserve the exact face mask, anatomy, costume, weapon, flame and 2D painted linework. Keep whole figure, staff, censer, flame and trailing robes fully within the square canvas, with empty margin on all sides. Background must be actual transparent alpha pixels, exactly like Image 1; never draw or imitate a gray-and-white checkerboard pattern. One boss, one staff, one censer. No scenery, floor, shadow, text, blur, duplicate, extra limbs, detached fireball or sprite sheet.
```

### 第 3 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 3 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 2, the IMMEDIATELY previous chronological pose in this action.
Identity: The same masked male ash priest in charred red-gold vestments, ember halo, and one flaming censer staff. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Deepen the windup by bending or coiling the body farther and drawing the attacking part back. Pull the censer staff behind his shoulder, step and rotate into a heavy forward swing toward screen right. The hanging censer trails then catches up; its small flame stays attached. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 4 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 4 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 3, the IMMEDIATELY previous chronological pose in this action.
Identity: The same masked male ash priest in charred red-gold vestments, ember halo, and one flaming censer staff. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Reach the largest anticipation pose just before the attack, with obvious stored tension. Pull the censer staff behind his shoulder, step and rotate into a heavy forward swing toward screen right. The hanging censer trails then catches up; its small flame stays attached. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 5 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 5 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 4, the IMMEDIATELY previous chronological pose in this action.
Identity: The same masked male ash priest in charred red-gold vestments, ember halo, and one flaming censer staff. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Deliver the biggest, clearest impact or release pose toward screen right. Pull the censer staff behind his shoulder, step and rotate into a heavy forward swing toward screen right. The hanging censer trails then catches up; its small flame stays attached. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 6 帧

```text
Create exactly ONE transparent PNG 2D anime boss sprite: frame 6 of 8, immediately AFTER the large impact in Image 2. Image 1 is the exact approved opening pose and identity reference; Image 2 is frame 5. The masked ash priest and his one long censer staff remain the same. Continue the SAME rightward swing: the flaming hanging censer stays entirely on SCREEN RIGHT of his body, slightly LOWER than in Image 2. His arms extend a little farther right and down; torso follows through and robes lag left. Do NOT swing the censer back across the body or to screen left yet. The staff's plain spiked end remains left, censer end remains right. Both hands stay on the shaft. Keep the full staff, chain, censer, small attached flame, body and robes inside the canvas with transparent margin. Actual alpha transparency, no checkerboard, scenery, text, shadow, extra limbs, duplicate weapons or blur.
```

### 第 7 帧

```text
Create exactly ONE transparent PNG 2D anime boss sprite: frame 7 of 8, recovering after Image 2's rightward follow-through. Image 1 is the approved opening pose and identity reference; Image 2 is frame 6, the immediately previous pose. The same masked ash priest gently lifts his staff from the low-right follow-through toward the original overhead guard. The flaming censer remains on SCREEN RIGHT of his body and moves slightly inward and upward; it does NOT cross to screen left. Torso straightens and trailing robes settle. The staff's plain spiked end stays left, censer end stays right; both hands grip the same shaft. This is recovery, not another strike. Preserve exact design and proportions; keep all parts inside canvas with real transparent alpha and margin. No checkerboard, scenery, text, shadow, extra limbs, duplicate weapons or blur.
```

### 第 8 帧

```text
Create exactly ONE transparent PNG 2D anime boss sprite: final frame 8 of 8. Image 1 is the approved opening pose and must be matched very closely; Image 2 is frame 7, the immediately previous recovery pose. Return the same masked ash priest, two-handed censer staff, ember halo, foot stance and flowing red-gold robes almost exactly to Image 1's starting pose. The staff is held overhead, spiked end at upper LEFT and flaming censer at SCREEN RIGHT, with the small flame attached. Movement from Image 2 is subtle and continuous; frame 8 must connect to Image 1 smoothly. Keep whole figure, weapon, chain and flame inside canvas with real transparent alpha and margins. No checkerboard, scenery, text, shadow, extra limbs, duplicate weapons or blur.
```


## 钟鸣大祭司 (`bell-hierophant`)

### 第 2 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 2 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference.
Identity: The same blindfolded lavender-haired bishop in ivory-violet robes, mitre, bell halo, and one silver crozier. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Make only a small preparatory shift: draw the crozier bell head back across the upper body and brace the rear leg. Do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 3 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 3 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 2, the IMMEDIATELY previous chronological pose in this action.
Identity: The same blindfolded lavender-haired bishop in ivory-violet robes, mitre, bell halo, and one silver crozier. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Deepen the same windup: draw the crozier bell head back across the upper body and brace the rear leg. Clearly progress from the previous pose without releasing the attack. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 4 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 4 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 3, the IMMEDIATELY previous chronological pose in this action.
Identity: The same blindfolded lavender-haired bishop in ivory-violet robes, mitre, bell halo, and one silver crozier. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Reach the largest held anticipation: draw the crozier bell head back across the upper body and brace the rear leg. Store tension for the NEXT frame; do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 5 帧

```text
Create exactly ONE transparent PNG anime game boss sprite: frame 5 of 8, the BIG impact immediately after Image 2's held windup. Image 1 fixes the exact blindfolded lavender-haired bishop, ivory-violet robes, mitre and long silver crozier whose circular head contains FOUR hanging bells. Image 2 is frame 4. She drives the SAME crozier into a broad forceful sweep toward screen right: both hands grip the shaft, torso and planted front leg rotate, and the bell-circle head leads on the RIGHT. The opposite pointed shaft end remains LEFT. Preserve all bells on their original crozier end; do not swap the weapon ends or create extra bells. Draw the entire character and the ENTIRE bell-circle head at a smaller scale, taking at most 75 percent of canvas width, so the rightmost bell is separated from the right edge by at least 10 percent transparent margin. The whole robe and both feet must fit. Actual alpha transparency with no painted checkerboard. No scenery, floor, shadow, text, motion blur, extra limbs, detached weapon or sprite sheet.
```

### 第 6 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 6 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 5, the IMMEDIATELY previous chronological pose in this action.
Identity: The same blindfolded lavender-haired bishop in ivory-violet robes, mitre, bell halo, and one silver crozier. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Move immediately AFTER the hit: keep the bell head on the right as the shaft continues lower and robes lag. This is follow-through, not a second attack or a return to windup. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 7 帧

```text
Generate exactly ONE genuine transparent PNG game sprite: frame 7 of 8, a MIDPOINT recovery pose. Image 1 fixes the blindfolded lavender-haired bishop, white-purple robes, mitre and original silver crozier with four hanging bells. Image 2 is frame 6: the bell-circle head is LOW at screen RIGHT after impact. Now lift the SAME bell-circle head only halfway back: it should be at the UPPER-RIGHT near shoulder height, not yet at the original upper-left. Rotate the staff diagonally upward while the torso begins to rise; hands remain on the same shaft and all four bells remain on the same circular head. This is a modest continuous recovery step from Image 2. Do NOT teleport the bell head from lower-right to upper-left in this frame. Keep entire figure and weapon inside canvas with transparent margin; alpha zero background, no checkerboard, scenery, shadow, text, extra limbs or sprite sheet.
```

### 第 8 帧

```text
Generate exactly ONE genuine transparent PNG game sprite: final frame 8 of 8. Image 1 is the exact approved opening pose of the blindfolded lavender-haired bishop with white-purple robes, mitre and silver crozier. Image 2 is frame 7, where the bell-circle head has risen to the upper-right during recovery. Continue that same rotation to bring the bell-circle head back to the original UPPER-LEFT position, matching Image 1's hands, feet, body, costume and weapon silhouette as closely as possible. Frame 8 must connect smoothly to frame 1. Maintain exactly four bells on the same crozier head and both hands on the shaft. Whole character and weapon inside canvas with transparent margin; real alpha-zero background, no checkerboard, scenery, shadow, text, duplicate limbs or sprite sheet.
```


## 血之女王 (`blood-queen`)

### 第 2 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 2 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference.
Identity: The same silver-haired queen with ruby crown, crimson rapier, and exactly six ruby stained-glass blade wings. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Make only a small preparatory shift: draw the rapier back behind the shoulder and fold the six wings slightly inward. Do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 3 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 3 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 2, the IMMEDIATELY previous chronological pose in this action.
Identity: The same silver-haired queen with ruby crown, crimson rapier, and exactly six ruby stained-glass blade wings. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Deepen the same windup: draw the rapier back behind the shoulder and fold the six wings slightly inward. Clearly progress from the previous pose without releasing the attack. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 4 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 4 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 3, the IMMEDIATELY previous chronological pose in this action.
Identity: The same silver-haired queen with ruby crown, crimson rapier, and exactly six ruby stained-glass blade wings. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Reach the largest held anticipation: draw the rapier back behind the shoulder and fold the six wings slightly inward. Store tension for the NEXT frame; do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 5 帧

```text
Create exactly ONE transparent PNG 2D anime game boss sprite: frame 5 of eight, the single strong impact immediately after Image 2's held windup. Image 1 fixes the exact silver-haired blood queen, red eyes, ruby crown, black-scarlet royal gown, six red stained-glass wings and ONE thin crimson rapier. Image 2 is frame 4. Rotate hips and shoulders into a broad rightward cut, planted front leg, with the rapier BLADE projecting toward screen RIGHT and its hilt in the original hand. Show a large bodily motion, but draw NO slash trail, NO red crescent, NO projectile and NO extra blade. Reduce the whole figure and wing span to occupy at most 70 percent of canvas width; leave 15 percent empty transparent margin on the RIGHT beyond the entire rapier tip, and visible margin around all wings, hair and feet. Full weapon and body must be entirely inside the picture. Actual alpha-zero background, never checkerboard. Preserve the exact face, dress, wing count, rapier design and anime linework. No scenery, floor, shadow, text, motion blur, duplicate character or sprite sheet.
```

### 第 6 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 6 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 5, the IMMEDIATELY previous chronological pose in this action.
Identity: The same silver-haired queen with ruby crown, crimson rapier, and exactly six ruby stained-glass blade wings. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Move immediately AFTER the hit: keep the rapier blade on the right in a low finishing position while wings trail. This is follow-through, not a second attack or a return to windup. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 7 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 7 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 6, the IMMEDIATELY previous chronological pose in this action.
Identity: The same silver-haired queen with ruby crown, crimson rapier, and exactly six ruby stained-glass blade wings. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Begin controlled recovery: draw the rapier back from low-right toward the original guard as wings settle. Move halfway toward Image 1, without a second strike. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 8 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 8 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 7, the IMMEDIATELY previous chronological pose in this action.
Identity: The same silver-haired queen with ruby crown, crimson rapier, and exactly six ruby stained-glass blade wings. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Nearly match Image 1's opening pose, including all body parts, weapon orientation, and silhouette; make the change from Image 2 modest so frame 8 connects smoothly to frame 1. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```


## 裂地者 (`earthsplitter`)

### 第 2 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 2 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference.
Identity: The same giant nonhumanoid armored burrowing centipede with molten amber cracks, circular maw and many digging claws. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Make only a small preparatory shift: retract the circular maw and front claws toward screen right while compressing the segmented body. Do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-LEFT-facing natural creature view as Image 1, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 3 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 3 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 2, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid armored burrowing centipede with molten amber cracks, circular maw and many digging claws. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Deepen the same windup: retract the circular maw and front claws toward screen right while compressing the segmented body. Clearly progress from the previous pose without releasing the attack. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-LEFT-facing natural creature view as Image 1, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 4 帧

```text
Generate exactly ONE real transparent PNG game boss sprite: frame 4 of eight, the FINAL HELD WINDUP, not an impact. Image 1 is the exact approved armored lava centipede reference, mirrored for this drawing pass: round toothed maw faces SCREEN RIGHT, tail curls screen left, segmented dark stone armor has sharp plates and molten amber cracks, several heavy digging claws. Image 2 is frame 3, the immediately previous pose. Compress the segmented body a little more and pull the circular toothed maw back toward screen left, with the claws braced for a coming rightward lunge. Keep EXACTLY the same hard dark armor, jagged plates, glowing cracks, circular maw and claw anatomy as Images 1 and 2. Absolutely no fur, fuzz, soft mammal body, smooth skin, extra limbs, different face, or glow cloud. One creature in fixed side view, full body inside canvas with at least 10 percent transparent empty margin all around. Transparent alpha zero outside the creature; no ground, debris, scenery, checkerboard, text or motion blur.
```

### 第 5 帧

```text
Generate exactly ONE real transparent PNG game boss sprite: frame 5 of eight, the BIG rightward impact. Image 1 is the exact approved armored lava centipede reference, mirrored for this drawing pass: circular toothed maw faces SCREEN RIGHT, tail curls screen left, dark segmented stone armor with sharp plates and molten amber cracks. Image 2 is frame 4, the immediately previous tightly coiled windup. NOW thrust the circular toothed maw and leading digging claws toward SCREEN RIGHT in one strong lunge. Head leads, front segments extend, tail trails; this is one creature, not multiple. Preserve the hard armored material, jagged plates, molten crack pattern, exact circular mouth and claw count. No fur, soft mammal texture, new face or detached rock debris. Draw the ENTIRE centipede at no more than 70 percent canvas width with 15 percent empty transparent margin beyond both maw and tail; no part may touch or cross the image boundary. Actual transparent alpha outside creature, no checkerboard, ground, scenery, shadow, text or giant effect.
```

### 第 6 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 6 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 5, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid armored burrowing centipede with molten amber cracks, circular maw and many digging claws. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Move immediately AFTER the hit: keep the maw on screen right as the front segments finish extending and tail follows. This is follow-through, not a second attack or a return to windup. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 7 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 7 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 6, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid armored burrowing centipede with molten amber cracks, circular maw and many digging claws. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Begin controlled recovery: recoil the front segments from the extended rightward lunge toward the starting coil. Move halfway toward Image 1, without a second strike. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 8 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 8 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 7, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid armored burrowing centipede with molten amber cracks, circular maw and many digging claws. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Nearly match Image 1's opening pose, including all body parts, weapon orientation, and silhouette; make the change from Image 2 modest so frame 8 connects smoothly to frame 1. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```


## 冰骨龙 (`frostbone-dragon`)

### 第 2 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 2 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference.
Identity: The same giant quadrupedal frostbone dragon with exactly four clawed legs, two ragged shoulder wings, long spiked tail and icy blue bone plates. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Make only a small preparatory shift: pull the head and neck back while four legs brace and two shoulder wings lift. Do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 3 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 3 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 2, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant quadrupedal frostbone dragon with exactly four clawed legs, two ragged shoulder wings, long spiked tail and icy blue bone plates. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Deepen the same windup: pull the head and neck back while four legs brace and two shoulder wings lift. Clearly progress from the previous pose without releasing the attack. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 4 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 4 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 3, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant quadrupedal frostbone dragon with exactly four clawed legs, two ragged shoulder wings, long spiked tail and icy blue bone plates. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Reach the largest held anticipation: pull the head and neck back while four legs brace and two shoulder wings lift. Store tension for the NEXT frame; do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 5 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 5 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 4, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant quadrupedal frostbone dragon with exactly four clawed legs, two ragged shoulder wings, long spiked tail and icy blue bone plates. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: NOW deliver the single biggest hit: snap the maw and front claws forward toward screen right in one large bite-strike. Show an unmistakable impact pose. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 6 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 6 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 5, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant quadrupedal frostbone dragon with exactly four clawed legs, two ragged shoulder wings, long spiked tail and icy blue bone plates. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Move immediately AFTER the hit: keep the head on screen right as it lowers from the bite and the two wings trail. This is follow-through, not a second attack or a return to windup. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 7 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 7 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 6, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant quadrupedal frostbone dragon with exactly four clawed legs, two ragged shoulder wings, long spiked tail and icy blue bone plates. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Begin controlled recovery: retract the head and front claws toward the starting four-legged stance. Move halfway toward Image 1, without a second strike. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 8 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 8 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 7, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant quadrupedal frostbone dragon with exactly four clawed legs, two ragged shoulder wings, long spiked tail and icy blue bone plates. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Nearly match Image 1's opening pose, including all body parts, weapon orientation, and silhouette; make the change from Image 2 modest so frame 8 connects smoothly to frame 1. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```


## 镜织者 (`mirror-weaver`)

### 第 2 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 2 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference.
Identity: The same silver-haired female mirror weaver in black lace and cracked silver armor, orbiting mirror shards and one crescent mirror blade. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Make only a small preparatory shift: draw the crescent blade back across the shoulder while the orbiting shards gather closer. Do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 3 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 3 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 2, the IMMEDIATELY previous chronological pose in this action.
Identity: The same silver-haired female mirror weaver in black lace and cracked silver armor, orbiting mirror shards and one crescent mirror blade. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Deepen the same windup: draw the crescent blade back across the shoulder while the orbiting shards gather closer. Clearly progress from the previous pose without releasing the attack. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 4 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 4 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 3, the IMMEDIATELY previous chronological pose in this action.
Identity: The same silver-haired female mirror weaver in black lace and cracked silver armor, orbiting mirror shards and one crescent mirror blade. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Reach the largest held anticipation: draw the crescent blade back across the shoulder while the orbiting shards gather closer. Store tension for the NEXT frame; do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 5 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 5 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 4, the IMMEDIATELY previous chronological pose in this action.
Identity: The same silver-haired female mirror weaver in black lace and cracked silver armor, orbiting mirror shards and one crescent mirror blade. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: NOW deliver the single biggest hit: sweep the crescent mirror blade toward screen right in a large strike with shards arcing behind. Show an unmistakable impact pose. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 6 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 6 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 5, the IMMEDIATELY previous chronological pose in this action.
Identity: The same silver-haired female mirror weaver in black lace and cracked silver armor, orbiting mirror shards and one crescent mirror blade. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Move immediately AFTER the hit: keep the blade on screen right and lower it slightly as shards trail the impact. This is follow-through, not a second attack or a return to windup. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 7 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 7 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 6, the IMMEDIATELY previous chronological pose in this action.
Identity: The same silver-haired female mirror weaver in black lace and cracked silver armor, orbiting mirror shards and one crescent mirror blade. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Begin controlled recovery: draw the blade back from rightward follow-through while shards return to their original orbit. Move halfway toward Image 1, without a second strike. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 8 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 8 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 7, the IMMEDIATELY previous chronological pose in this action.
Identity: The same silver-haired female mirror weaver in black lace and cracked silver armor, orbiting mirror shards and one crescent mirror blade. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Nearly match Image 1's opening pose, including all body parts, weapon orientation, and silhouette; make the change from Image 2 modest so frame 8 connects smoothly to frame 1. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```


## 月海兽 (`moon-leviathan`)

### 第 2 帧

```text
Draw ONE game sprite with a TRUE transparent alpha background, frame 2 of an eight-frame attack loop. Image 1 is the exact approved starting pose. Image 2 is the future frame 3. Draw the IN-BETWEEN pose: the same black-scaled, crimson-finned serpent remains coiled around the one broken blood-red moon, with its ONE ivory-horned tooth-filled head and open maw fully visible at the upper right. Its head lifts only partway from Image 1 toward Image 2, and its body remains a compact C. Preserve its head, mouth, horns, eyes, whiskers, scales, red fins, tail and moon. No extra serpent or missing head. Match the same camera, angle, scale, color and painted anime style. Center the complete creature with clear empty margin on all four sides. The output canvas must have real zero-alpha transparent pixels outside the character. Do not render a visible white-and-gray checkerboard grid or any background; do not flatten the transparent canvas. No scenery, ground, shadow or text.
```

### 第 3 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 3 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 2, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid armored sea serpent coiled around a broken blood-red moon, with horned maw and long scaled body. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Deepen the same windup: tighten the body coil around the blood-red moon and draw the horned head back. Clearly progress from the previous pose without releasing the attack. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 4 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 4 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 3, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid armored sea serpent coiled around a broken blood-red moon, with horned maw and long scaled body. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Reach the largest held anticipation: tighten the body coil around the blood-red moon and draw the horned head back. Store tension for the NEXT frame; do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 5 帧

```text
Generate exactly one transparent PNG game boss sprite, frame 5 of an eight-frame attack. Image 1 is the exact approved opening pose of the same black-scaled, crimson-finned horned sea serpent coiled around one broken blood-red moon. Image 2 is frame 4, its immediately previous tightly drawn-back pose. Continue its motion with a clear, powerful but COMPACT strike: the horned head and open toothed maw lunge a short distance toward screen right while the body still forms a C around the same moon. Preserve the exact dark scale armor, red spined fins, ivory horn structure, one head, one body and one broken moon. This is the single impact frame, not another windup. Place the ENTIRE creature at about 65 percent of the square canvas width, centered, leaving at least 15 percent fully transparent empty space on the right beyond every horn, tongue and whisker and at least 10 percent on the other sides. Do not crop or touch any edge. Genuine alpha transparency; no checkerboard, scenery, ground, shadow, text, extra creature or giant detached effect.
```

### 第 6 帧

```text
Generate exactly one transparent PNG game boss sprite, frame 6 of eight. Image 1 is the approved opening reference of the black-scaled, crimson-finned horned sea serpent coiled around the one broken blood-red moon. Image 2 is frame 5, the immediately previous open-maw impact pose. Continue in the SAME direction with a SMALL follow-through only: keep the open horned head on screen right but lower it slightly, and let the red fins and tail follow. Do not push the head farther right or stretch the body; do not make another strike. Keep the body wrapped in a compact C around the moon. Preserve one continuous body, one head, one moon, dark scales, red spined fins, ivory horn and toothed maw. Compose the ENTIRE creature inside the CENTER 65 percent of the square canvas, with at least 15 percent genuinely transparent margin on BOTH left and right beyond every horn, whisker, tongue and tail tip. No edge touching, no cropping, no detached objects, scenery, floor, shadow, text or checkerboard.
```

### 第 7 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 7 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 6, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid armored sea serpent coiled around a broken blood-red moon, with horned maw and long scaled body. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Begin controlled recovery: recoil the head and body from the extended rightward lunge back around the moon. Move halfway toward Image 1, without a second strike. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 8 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 8 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 7, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid armored sea serpent coiled around a broken blood-red moon, with horned maw and long scaled body. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Nearly match Image 1's opening pose, including all body parts, weapon orientation, and silhouette; make the change from Image 2 modest so frame 8 connects smoothly to frame 1. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```


## 无名之月 (`nameless-moon`)

### 第 2 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 2 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference.
Identity: The same pale silver-haired blood moon queen in a black-scarlet royal gown, red crescent halo and exactly six floating broken crown blades. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Make only a small preparatory shift: draw the commanding arm back and gather the six crown blades close behind her. Do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 3 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 3 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 2, the IMMEDIATELY previous chronological pose in this action.
Identity: The same pale silver-haired blood moon queen in a black-scarlet royal gown, red crescent halo and exactly six floating broken crown blades. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Deepen the same windup: draw the commanding arm back and gather the six crown blades close behind her. Clearly progress from the previous pose without releasing the attack. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 4 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 4 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 3, the IMMEDIATELY previous chronological pose in this action.
Identity: The same pale silver-haired blood moon queen in a black-scarlet royal gown, red crescent halo and exactly six floating broken crown blades. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Reach the largest held anticipation: draw the commanding arm back and gather the six crown blades close behind her. Store tension for the NEXT frame; do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 5 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 5 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 4, the IMMEDIATELY previous chronological pose in this action.
Identity: The same pale silver-haired blood moon queen in a black-scarlet royal gown, red crescent halo and exactly six floating broken crown blades. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: NOW deliver the single biggest hit: sweep the arm toward screen right and send all six attached-orbit crown blades through one broad arc. Show an unmistakable impact pose. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 6 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 6 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 5, the IMMEDIATELY previous chronological pose in this action.
Identity: The same pale silver-haired blood moon queen in a black-scarlet royal gown, red crescent halo and exactly six floating broken crown blades. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Move immediately AFTER the hit: keep the six blades on screen right briefly as the arm finishes its sweep and gown trails. This is follow-through, not a second attack or a return to windup. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 7 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 7 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 6, the IMMEDIATELY previous chronological pose in this action.
Identity: The same pale silver-haired blood moon queen in a black-scarlet royal gown, red crescent halo and exactly six floating broken crown blades. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Begin controlled recovery: draw the arm back and guide the six blades toward their opening positions. Move halfway toward Image 1, without a second strike. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 8 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 8 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 7, the IMMEDIATELY previous chronological pose in this action.
Identity: The same pale silver-haired blood moon queen in a black-scarlet royal gown, red crescent halo and exactly six floating broken crown blades. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Nearly match Image 1's opening pose, including all body parts, weapon orientation, and silhouette; make the change from Image 2 modest so frame 8 connects smoothly to frame 1. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```


## 雷鹏 (`storm-roc-v2`)

### 第 2 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 2 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference.
Identity: The same giant nonhumanoid black-feathered thunder roc with cyan lightning veins, exactly two broad wings, hooked beak and two taloned legs. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Make only a small preparatory shift: raise both wings higher and tuck the two talons while drawing the body back. Do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 3 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 3 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 2, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid black-feathered thunder roc with cyan lightning veins, exactly two broad wings, hooked beak and two taloned legs. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Deepen the same windup: raise both wings higher and tuck the two talons while drawing the body back. Clearly progress from the previous pose without releasing the attack. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 4 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 4 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 3, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid black-feathered thunder roc with cyan lightning veins, exactly two broad wings, hooked beak and two taloned legs. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Reach the largest held anticipation: raise both wings higher and tuck the two talons while drawing the body back. Store tension for the NEXT frame; do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 5 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 5 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 4, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid black-feathered thunder roc with cyan lightning veins, exactly two broad wings, hooked beak and two taloned legs. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: NOW deliver the single biggest hit: strike both talons forward toward screen right with one strong downbeat of two wings. Show an unmistakable impact pose. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 6 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 6 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 5, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid black-feathered thunder roc with cyan lightning veins, exactly two broad wings, hooked beak and two taloned legs. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Move immediately AFTER the hit: keep the talons forward-right as the wings finish the downbeat and feathers trail. This is follow-through, not a second attack or a return to windup. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 7 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 7 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 6, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid black-feathered thunder roc with cyan lightning veins, exactly two broad wings, hooked beak and two taloned legs. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Begin controlled recovery: draw the talons back and raise both wings toward the opening flight pose. Move halfway toward Image 1, without a second strike. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 8 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 8 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 7, the IMMEDIATELY previous chronological pose in this action.
Identity: The same giant nonhumanoid black-feathered thunder roc with cyan lightning veins, exactly two broad wings, hooked beak and two taloned legs. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Nearly match Image 1's opening pose, including all body parts, weapon orientation, and silhouette; make the change from Image 2 modest so frame 8 connects smoothly to frame 1. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```


## 荆棘猎王 (`thorn-huntsman`)

### 第 2 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 2 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference.
Identity: The same masked dark-haired huntsman king with crimson branching antlers, broad white fur mantle, burgundy armor and one long thorn spear. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Make only a small preparatory shift: plant the rear foot and withdraw the thorn spear tip toward screen left behind the shoulder. Do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 3 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 3 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 2, the IMMEDIATELY previous chronological pose in this action.
Identity: The same masked dark-haired huntsman king with crimson branching antlers, broad white fur mantle, burgundy armor and one long thorn spear. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Deepen the same windup: plant the rear foot and withdraw the thorn spear tip toward screen left behind the shoulder. Clearly progress from the previous pose without releasing the attack. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 4 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 4 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 3, the IMMEDIATELY previous chronological pose in this action.
Identity: The same masked dark-haired huntsman king with crimson branching antlers, broad white fur mantle, burgundy armor and one long thorn spear. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Reach the largest held anticipation: plant the rear foot and withdraw the thorn spear tip toward screen left behind the shoulder. Store tension for the NEXT frame; do not strike yet. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 5 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 5 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 4, the IMMEDIATELY previous chronological pose in this action.
Identity: The same masked dark-haired huntsman king with crimson branching antlers, broad white fur mantle, burgundy armor and one long thorn spear. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: NOW deliver the single biggest hit: drive the thorn spear tip in a committed thrust toward screen right. Show an unmistakable impact pose. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 6 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 6 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 5, the IMMEDIATELY previous chronological pose in this action.
Identity: The same masked dark-haired huntsman king with crimson branching antlers, broad white fur mantle, burgundy armor and one long thorn spear. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Move immediately AFTER the hit: keep the spear tip extended screen right as the torso follows into the lunge. This is follow-through, not a second attack or a return to windup. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 7 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 7 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 6, the IMMEDIATELY previous chronological pose in this action.
Identity: The same masked dark-haired huntsman king with crimson branching antlers, broad white fur mantle, burgundy armor and one long thorn spear. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Begin controlled recovery: pull the spear back from the extended thrust toward the opening guard. Move halfway toward Image 1, without a second strike. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```

### 第 8 帧

```text
Create exactly ONE finished 2D anime game sprite: frame 8 of an eight-frame attack sequence. Image 1 is the exact approved opening frame and identity reference. Image 2 is frame 7, the IMMEDIATELY previous chronological pose in this action.
Identity: The same masked dark-haired huntsman king with crimson branching antlers, broad white fur mantle, burgundy armor and one long thorn spear. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework.
Action now: Nearly match Image 1's opening pose, including all body parts, weapon orientation, and silhouette; make the change from Image 2 modest so frame 8 connects smoothly to frame 1. Make this frame visibly progress from the previous pose; do not repeat it.
Invariants: preserve all original weapons, wings, claws, tails and ornaments in their original counts and attachments. Maintain the same screen-right-facing three-quarter or natural creature view, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.
```


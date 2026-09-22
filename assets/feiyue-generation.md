# 绯月立绘替换

## 直杆法杖修正（当前）

使用内置 imagegen 修正杖杆弯折，杖头、握持处及杖尾共用一条笔直轴线。最终提示词：

```text
Precise-object-edit: fix ONLY the bent magic staff in this image. The staff must be a perfectly STRAIGHT rigid cylindrical black metal rod, ruler-straight, with no bend at the hand, no curve, no kink, no change of direction, no segmented crooked shaft. Position staff vertically at x approximately 260 on the 1024-wide canvas: the center of the crimson gemstone crown at top, shaft above the hand, shaft inside the gripping hand, shaft below hand and bottom pointed finial must ALL lie on exactly ONE straight vertical axis. Shift the upper crown and bottom finial sideways as needed to align with the existing gripping hand. Keep elegant gold filigree wrapped around the straight black rod and the same crimson gemstone crescent crown. A continuous straight centerline must pass through the whole prop from crown to bottom. Preserve character, face, hair, dress, tail, body pose, proportions, shoes, placement, dimensions and rendering unchanged. Only tiny finger adjustments to wrap the straight shaft allowed. Preserve actual alpha transparent background, no glow, no backdrop, no shadows, no text. 1024x1536 PNG full figure and complete straight staff visible.
```

## 法杖初版

使用内置 imagegen 编辑上一版立绘，将步枪换为黑金红宝石法杖，保留人物站姿、服装及透明通道。最终提示词：

```text
Use case: precise-object-edit. Edit the provided transparent full-body anime game portrait. Change ONLY the rifle held at viewer's left into a beautiful gothic magic staff. Completely remove all rifle parts, scope, barrel, stock and trigger. Replace with a slender black staff with delicate antique-gold filigree and a crimson gemstone enclosed in a small elegant crescent crown at the upper end, matching her black white burgundy and gold costume. Keep the staff aligned with the former rifle diagonal, lower tip near the same floor location, upper ornamental head above her holding hand, not covering her face. Her same lowered hand naturally wraps the staff shaft, adjusting only the fingers locally as needed. Preserve EXACTLY her face, expression, white hair, red eyes, hair ornaments, clothing, tail, shoes, body proportions, head tilt, standing pose, other hand, composition, scale and anime linework. Single complete character with entire staff visible, same 1024x1536 canvas. Preserve genuine alpha transparency outside character and staff. No background, no glow backdrop, no ground shadow, no text, no other changes.
```

## 初始持枪版本

使用内置 imagegen，以用户提供的三视图为角色设定参考，以 `camp-sentinels.png` 左侧角色为原游戏姿势参考。输出替换 `portrait-0.png`，用于营地立绘。

最终提示词：

```text
Use case: identity-preserve. Asset type: Godot game standalone full-body character portrait, transparent PNG. Input image 1 is the CHARACTER DESIGN reference: white-haired red-eyed anime girl, black hair bow with red gemstone and hanging gold cross, opposite white flower, white puff-sleeve blouse, burgundy chest bow, black laced bodice and bell skirt with gold filigree and white lace hem, white ankle socks, black Mary Jane shoes, thin dark burgundy spade tail. Input image 2 is ONLY the POSE reference: use only the LEFT silver-haired rifle sentinel, ignore center and right characters. Generate the character from image 1 in the same standing pose as the LEFT sentinel in image 2: body slightly turned three-quarter, head facing viewer with slight tilt, weight on one leg and other leg offset forward, arms lowered close to sides, right hand on viewer's left holding a long dark rifle downwards beside the body with muzzle toward floor. Preserve the rifle's placement and body gesture from image 2 while retaining the face, youthful nonsexual proportions, detailed modest costume, shoes, ornaments, hair and tail design from image 1. Do not use the left sentinel's military coat, thigh-high boots or costume. Delicate high quality 2D anime drawing matching image 1. One single character, head to soles fully visible, entire rifle visible, centered portrait 1024x1536 with transparent margin, no clipping. TRUE ALPHA transparent background, no glow, no halo, no backdrop, no black or white rectangle, no checkerboard drawn into pixels, no ground shadow, no text, no extra figures.
```

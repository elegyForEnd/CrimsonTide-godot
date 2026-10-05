本期我们将用AI从零开始制作一款《无职转生》的同人横版动作游戏。整个过程完全在本地部署完成，用到的工具也都是可以本地跑起来的。本期想把整个流程跟大家分享一下，从美术素材生成、动画制作到最终的游戏开发，每一步都会讲到。

# 美术素材：用QwenImage2.1生成角色立绘

首先做的是人物角色的美术资产。我选的主角是《无职转生》里的洛琪希。

这里有个小细节需要注意——找参考图的时候一定要用全身图。因为如果身体下半部分没有展示出来，AI就只能靠脑补来生成，很容易出现和原作设定不一致的情况。另外参考图的尺寸我调整成了1:1，角色左右两侧留了比较多的空闲区域。这是因为后面要用MiniMax H3生成动画，需要给跑步、攻击这些动作预留活动空间，不然动画很容易因为空间不足被截断。

生成图像用的是ComfyUI里的QwenImage2.1图像编辑工作流。提示词方面，我让它生成手持法杖的侧面待机图像，背景用绿幕方便后续抠图。其他参数保持默认，直接生成看一下效果。

![图片](https://mmbiz.qpic.cn/mmbiz_png/ZD3D0EjPn0h75dkibw4mjBFPlske6j72jAP22NQ5b37cHq4TU0ibXn2dNMIJ60dBlFV4NE6nacPgiaEU4Q20HibzRicWX0FMZZcGicJQNxu1V06aA/640?wx_fmt=png&from=appmsg&tp=webp&wxfrom=5&wx_lazy=1#imgIndex=0)

其实这里首次生成的效果就已经能用了，但还有一些关键细节很多人会忽略。比如人物典型特征是否完整——你可能注意到了，在纯侧面图像中洛琪希的双马尾变成了单马尾，这就导致后面用MiniMax H3生成动画时角色就变成了单马尾，和原作设定不符。所以做侧视图的时候尽量别让角色的特征信息丢失。

![图片](https://mmbiz.qpic.cn/sz_mmbiz_png/ZD3D0EjPn0gSMeeBroJib40LOXsqRUFtI4JmDIK4t85Ca3OIkhg8Oibw0zXvmAhxuExdiar91veKv77ico7nuedJjefibBtDfBbOeA2gpWsrQGd4/640?wx_fmt=png&from=appmsg&tp=webp&wxfrom=5&wx_lazy=1#imgIndex=1)

还有一个更细节的问题，是怎么在MiniMax H3里获取更多的可用帧。如果直接用纯侧面图去生成待机动画，AI需要先让角色从侧面变成放松姿势，这个过程会占用几秒钟，真正能用于动画的帧数就少了。很多人可能会想增加总时长来解决，但其实这样视频越长我们对结果的掌控力就越弱，原本要生成待机动画，角色后面可能就跑起来了，甚至镜头角度都变了。

所以我的做法是修改提示词，让它生成一个更接近待机动画首帧的侧面视图，比如增加”可以看到双马尾”“可以看到双手”这类表述，同时用负面提示词避免生成纯侧面视图。这里需要注意的是，使用负面提示词时要把CFG的值设置为一以上。

![图片](https://mmbiz.qpic.cn/mmbiz_png/ZD3D0EjPn0g1ZllAfNiaqnDFs5IVQw6JTM3pFG2p5KEPuegtibGRlibr2K3QXoUUPjVq0icrZ4IQLibymoZ8vj5g5tynsjc68ZDVrg3Zqs71auuA/640?wx_fmt=png&from=appmsg&tp=webp&wxfrom=5&wx_lazy=1#imgIndex=2)

这个环节可能需要多轮抽卡和调整提示词，很多时候你会发现抄别人的提示词效果不佳，这很正常，因为参考图不一样、随机种子也不同。提示词永远只是参考，更重要的是学会根据结果去调整自己的提示词。这也是为什么我每次做视频都愿意讲这么多思路的原因——我是真心希望能教会大家写提示词的核心方法，而不是扔一段提示词就不管了。如果大家认可我的视频和劳动，请一定给我点个关注，这是对我这个只有几千粉丝的小小博主最大的帮助了。

# 动画制作：用MiniMax H3产出角色动画

生成合适的图像后，接下来制作动画。在ComfyUI的视频模板中找到MiniMax H3的图生视频工作流。同样的先看一下提示词。

提示词方面建议直接用英文，往往会更精准一些。不用担心看不懂，视频里给大家准备了完整的中英文对照。

写提示词有几个要点：首先要强调框架，说明这是一个2D平面动漫风格的游戏Sprite动画，始终为侧面且面向屏幕右侧；其次要强调机位，要求固定机位、无运镜；然后根据不同类型的动画来写具体描述。

比如待机动画，希望角色保持静止但有细微的呼吸动作。我们可以看到生成的效果还是蛮不错的。待机动画比起其他动画更依赖参考图，所以参考图一定要像待机动画的首帧一样。

移动动画可以在提示词中强调这是循环动画，并且音效明确只出现脚步声，这样的话后续我们还可以拿来做音效素材。跑步动画可以强调身体前倾腾空感来增加动感和速度。攻击动画需要考虑技能释放的高度，太高或太矮都是不合适的，因此我在提示词中强调了法杖最高抬至胸口。受击动画需要强调画面只有角色和法杖，避免出现一些额外的攻击元素。最后是死亡动画，我们希望倒地后角色仍能处在屏幕之内。

![图片](https://mmbiz.qpic.cn/sz_mmbiz_png/ZD3D0EjPn0hj6aXF4GQmUZ25c7ErauJiazqmes2pficwAe0tXianbyZzM0PeaDeLRVgFI3lzSHickXB03DzWjshxD2dXRAXV4ncV0yHRP9yNFx4/640?wx_fmt=png&from=appmsg&tp=webp&wxfrom=5&wx_lazy=1#imgIndex=3)

敌人的素材制作流程类似，用QwenImage2.1的文生图工作流生成角色图，然后用同样的方法通过MiniMax H3生成动画。这里我就不复述了，大家直接看提示词的效果就行。

# 游戏场景与素材处理

这些都完成后，我们来制作游戏场景。游戏场景实际上也可以用文生图来实现，其核心关键词是”横版卷轴2D动作游戏背景”以及”多层视差滚动结构”，然后再加上环境的相关描述即可。生成的素材如果含有人物，可以利用图像编辑工作流移除一下。

接下来我们再利用本地agent帮我们处理一下美术素材。我们此前生成的动画还是视频格式的，为此我们需要提取成一张一张的透明的PNG图像。我在DSH中使用Qwen-3.8-27B的IQ4量化版，要求其制作一个视频逐帧提取并抠像的脚本，帮助我进行动画帧序列的提取。

完成后我们可以看到提取了非常多的图像，而我们制作角色动画实际上是用不到这么多帧的。那如何选择呢？技巧就是间隔两帧选一张图像，直到找到和所选的第一帧接近的图像为止，这样动画循环起来就非常流畅。我们将动画都挑选出来放到单独的文件夹里，完成后就可以来进行最终的游戏开发了。

![图片](https://mmbiz.qpic.cn/mmbiz_png/ZD3D0EjPn0gHppBMKyK2D9bIdkeibYvfbLrcictwicDxRKqXd2ahFeAXJZGDoxToycNdwq4HqwawdfbI9jffkBGshuVibtDiaDziaOXgkrrzkT3d8/640?wx_fmt=png&from=appmsg&tp=webp&wxfrom=5&wx_lazy=1#imgIndex=4)

# 游戏开发：用Qwen-3.8-27B + VibeCoding完成

首先来看一下这个VibeCoding的提示词是怎么写的。

首先在最开始，我们就明确项目要做什么——我们要做一个横版卷轴动作游戏原型，通过一个单文件HTML5就可以运行，并且明确出所有的角色动画都是依赖的外部的素材，避免AI自行生成而浪费时间。

然后强调出重点要做的就是动画、碰撞、敌人和调试模式。其实这里的潜台词就是告诉AI，其他的方面你可以自行发挥。紧接着我补了一句，希望它能够完全自主，然后一口气把它生成，中间不要问我。这也主要是因为这个项目本身对于Qwen-3.8-27B来说不是很难，它是完全能够一口气生成的，就不折腾分步骤了。

接着我明确了下，这个游戏画布固定为16:9，但是这个地面平台我现在很难明确，因此我希望他把这个地面平台的y轴坐标做成一个可配置的，这样子我就可以在调试模式中很快的去调整。

玩法逻辑这里没什么可讲的，就是很通用的一些控制规则。重点是相机系统这里，限定了一下它不能超出这个画面，避免出现一些穿帮的情况。调试模式这里很重要，重点是能够显示出碰撞盒体，这样有问题有bug我们能直观的看到。包括这里也明确了一下，可以调整平台顶面的一个数值，包括对玩家和敌人的体积进行缩放等。

完事后就是美术素材的清单与绑定规则，这里我们需要明确出有哪些美术素材，避免有遗漏之类的。接着是场景素材的文件夹所在位置，我们也给明确出来。其他的部分就不是很关键了，都是跟一些视觉相关的，比如增加阴影、还有受击的一个红光闪烁之类的。

![图片](https://mmbiz.qpic.cn/mmbiz_jpg/ZD3D0EjPn0hU7U5rUw3t64T6xlWU1icfk5TiaverfwsNfYLRKWDufSNhmadqX7zNgPHoyo9ynAP68DqjoOQKicQ3J8IAY2fVVeWkseZ0krN7hU/640?wx_fmt=jpeg&from=appmsg&tp=webp&wxfrom=5&wx_lazy=1#imgIndex=5)

# 效果展示与调试

我们直接来看一下这个首轮的生成效果。好，能够正常打开。然后平台的高度不太正确，我们在调试模式中来把它调整一下。其次我还发现两个bug，一个是播放动画之后角色就会卡住，另一个是受击的时候会额外播放一个缩小版的动画。这些都是不符合预期的，我们让其修复一下。

这样一来，我们一个基础的游戏框架就算搭建完成了。

# 后续计划

AI美术的高阶玩法还有一堆，滚动视差背景、直接生成UI界面等，后面都会做。这期只是一个开始，后续我会出更多相关内容。如果大家对AI美术感兴趣，请关注我吧。

我是ZZ，期待下期见。

提示词附录：

## **洛琪希图像生成（正向提示词）**

参考<Image1>生成该角色手持法杖的侧面idle待机姿势图像（参考横板卷轴2D游戏角色），戴着<Image1>中的巫师帽，自然放松的待机站姿，纯色绿幕背景，游戏美术素材，人物完整居中，无复杂背景，无人物遮挡，无多余物体。三分之二，侧面视角，非纯侧面，可见双手（一只手自然握住白色骨架造型法杖（法杖和人物等高），另一只手自然垂放在身侧），蓝紫色双马尾长发，双马尾从身体两侧清晰可见，双脚自然分开站立，重心稳定，膝盖微松，肩颈放松，身体姿态不僵硬。

**负向提示词**

纯侧面，单马尾，色彩暗淡，色调单一



### **洛琪希-死亡动画提示词**

2D flat anime game sprite animation, the character always remains in a three-quarter side view facing toward the right side of the screen, never turns toward the camera, never changes facing direction during the fall. Young female mage with blue-purple twin braids, black witch hat, white coat with black and blue details, black frilled skirt, white boots, holding a white skeleton magic staff.

Defeat / death animation. The character starts in a stable standing pose, positioned safely inside the screen with full body, hat, twin braids, coat hem, boots and staff tip all visible. Her legs weaken, knees buckle gently, body slumps forward softly while still facing right, her grip loosens, the staff slips from her hand and falls to the ground beside her within the screen area. She collapses slowly and lightly to the ground in a compact fallen pose, keeping the entire body and all equipment inside the frame at all times. The staff falls alongside her, not away from her, and ends resting on the ground next to her body without leaving the screen. Twin braids fall naturally but do not extend outside the edges, the coat flows down and stays inside, the hat remains on her head or lands very close beside it. She stays completely motionless for the final moment. Subtle faint blue magic particles fade away briefly at the start of the fall, then disappear quickly. No blood, no gore, no wounds.

Fixed camera, no camera movement, no perspective change, pure solid green screen background, clean cel shading, full body always visible, stable character design, stable staff shape, no flicker, no distortion.

Do not turn the character toward the camera. Do not rotate the body while falling. Do not show front view. Do not make the character face left. Do not make the character get up or revive. Do not allow hair, braids, hat, coat, staff or boots to go outside the screen. Do not make the staff fly or roll away from the body. Do not add large explosion, beam, projectile or magic effects. Do not add any scenery, buildings, flowers or grass to the background. Do not produce motion blur, hand deformation, extra fingers or staff shape change.

**核心画面描述：**
2D 平面动漫风格的游戏精灵（Sprite）动画。角色始终保持四分之三侧视图，面向屏幕右侧，**绝不**转向镜头，坠落过程中也**绝不**改变朝向。

**角色设定：**
年轻的蓝紫色双麻花辫女法师，戴着黑色女巫帽，身穿带有黑蓝细节的白色外套、黑色褶边短裙和白靴子，手持一根白色骨架魔法杖。

**动作细节（战败/死亡动画）：**

- 起始：

  角色全身处于屏幕内的稳定站立姿势（帽子、双麻花辫、外套下摆、靴子和法杖尖端都必须完全可见）。

- 过程：

  双腿无力，膝盖轻微弯曲，身体在保持面向右侧的同时柔和地向前瘫软，手部抓握放松，法杖从手中滑落，掉落在她身旁的屏幕区域内。

- 倒地：

  她缓慢且轻盈地倒在地上，呈紧凑的倒地姿势，始终保持全身和所有装备在画面框内。

- 细节：

  法杖随她一同掉落（不会飞远），最终停在她身体旁边；双麻花辫自然垂落但不超出边缘；外套下摆流下并留在画面内；帽子保持在头上或落在旁边极近处。

- 结尾：

  最后一刻保持完全静止。

**特效与风格：**
倒地开始时有微弱的淡蓝色魔法粒子消散，随后迅速消失。**无血腥、无内脏、无伤口。**

**技术与构图要求：**
固定机位，无运镜，无透视变化，纯净的绿幕背景，干净的赛璐珞（Cel Shading）上色风格。全身始终可见，角色设计和法杖形状稳定，无闪烁，无变形。

**负面提示（绝对禁止出现的元素）：**

- 不要让角色转向镜头，倒地时不要旋转身体，不要展示正面，不要让角色面向左侧。
- 不要让角色站起来或复活。
- 头发、辫子、帽子、外套、法杖或靴子不得超出屏幕边缘。
- 法杖不得飞离或滚离身体。
- 不要添加大爆炸、光束、投射物或魔法特效。
- 背景中不要添加任何风景、建筑、花草。
- 不要产生运动模糊、手部变形、多余的手指或法杖形状改变。

###  

### **洛琪希-****待机动画提示词**

2D flat anime game sprite animation, the character always remains in a three-quarter side view facing toward the right side of the screen, never turns toward the camera, never changes facing direction. Young female mage with blue-purple twin braids, black witch hat, white coat with black and blue details, black frilled skirt, white boots, holding a white skeleton magic staff.

Idle / standing wait animation. The character stands completely still in a stable relaxed pose for most of the loop, feet planted firmly, body held naturally, both hands resting lightly on the staff in front of her or at her side. Very subtle breathing motion only: chest and shoulders rise and fall slowly, twin braids sway gently back and forth, coat hem and skirt have tiny natural movement, the hat stays steady on her head. The staff remains completely motionless or moves only minimally with her breathing. No walking, no stepping, no attacking, no casting, no turning, no jumping, no large gestures.

Fixed camera, no camera movement, no perspective change, pure solid green screen background, clean cel shading, full body always visible, stable character design, stable staff shape, no flicker, no distortion.

Do not turn the character toward the camera. Do not change facing direction. Do not rotate the body. Do not show front view. Do not make the character face left. Do not make her walk, run, jump, crouch, attack or cast magic. Do not add any scenery, buildings, flowers or grass to the background. Do not produce motion blur, hand deformation, extra fingers or staff shape change.

**翻译：**

**核心画面描述：**
2D 平面动漫风格的游戏精灵动画。角色始终保持四分之三侧视图，**面向屏幕右侧**，绝不转向镜头，绝不改变朝向。

**角色设定：**
年轻的蓝紫色双麻花辫女法师，戴着黑色女巫帽，身穿带有黑蓝细节的白色外套、黑色褶边短裙和白靴子，手持一根白色骨架魔法杖。

**动作细节（待机/站立等待动画）：**

- 主体状态：

  在循环动画的大部分时间里，角色保持完全静止的稳定放松姿势。双脚稳稳踩地，身体姿态自然，双手轻轻搭在身前的法杖上或放在身体两侧。

- 微动细节（仅呼吸感）：

  只有非常细微的呼吸动作——胸部和肩膀缓慢起伏；双麻花辫轻微地前后摆动；外套下摆和裙子有极其自然的微小晃动；帽子稳稳地戴在头上。

- 法杖状态：

  法杖保持完全静止，或者仅随着她的呼吸有极微小的移动。

- 禁止动作：

  没有走路、踏步、攻击、施法、转身、跳跃或大幅度手势。

**技术与构图要求：**
固定机位，无运镜，无透视变化，纯净的绿幕背景，干净的赛璐珞（Cel Shading）上色风格。全身始终可见，角色设计和法杖形状稳定，无闪烁，无变形。

**负面提示（绝对禁止出现的元素）：**

- 不要让角色转向镜头，不要改变朝向，不要旋转身体，不要展示正面，不要让角色面向左侧。
- 不要让她走路、跑步、跳跃、蹲下、攻击或施法。
- 背景中不要添加任何风景、建筑、花草。
- 不要产生运动模糊、手部变形、多余的手指或法杖形状改变。

###  

### **洛琪希-移动动画提示词**

2D flat anime game sprite animation, the character always remains in a three-quarter side view facing toward the right side of the screen, young female mage with blue-purple twin braids, black witch hat, white coat with black and blue details, black frilled skirt, white boots, holding a white skeleton magic staff. Smooth running cycle toward the right, body slightly leaned forward, legs striding naturally, arms swinging in rhythm, braids and coat flowing behind, staff held steadily. Pure animation with no soundtrack, no background music, no BGM, no ambient music, no melody, no song. Only clear game sound effects for footsteps, walking/running steps and body movement sounds. Fixed camera, no camera movement, pure solid green screen background, clean cel shading, full body always visible, stable character design, no flicker, no distortion.

Do not turn the character toward the camera. Do not change facing direction. Do not rotate the body. Do not show front view. Do not make the character face left. Do not add any scenery, buildings, flowers or grass to the background. Do not produce motion blur, hand deformation, extra fingers or staff shape change. Do not add background music, BGM, soundtrack, melody, song, ambient music or any music. Only footstep sounds are allowed.

**核心画面描述：**
2D 平面动漫风格的游戏精灵（Sprite）动画。角色始终保持四分之三侧视图，**面向屏幕右侧**。

**角色设定：**
年轻的蓝紫色双麻花辫女法师，戴着黑色女巫帽，身穿带有黑蓝细节的白色外套、黑色褶边短裙和白靴子，手持一根白色骨架魔法杖。

**动作细节（平滑移动循环）：**

- **整体动态：**向右侧平滑的移动循环动画。
- **身体姿态：**身体微微前倾，双腿自然迈开，双臂有节奏地摆动。
- **物理飘动：**双麻花辫和外套下摆向后自然飘动，法杖握持稳固。

**音频要求（重点）：**

- **纯动画无配乐：**没有任何背景音乐（BGM）、环境音乐、旋律或歌曲。
- **仅保留音效：**只有清晰的游戏音效，包括脚步声、走路/跑步的步伐声以及身体动作的声音。

**技术与构图要求：**
固定机位，无运镜，纯净的绿幕背景，干净的赛璐珞（Cel Shading）上色风格。全身始终可见，角色设计稳定，无闪烁，无变形。

**负面提示（绝对禁止出现的元素）：**

- 不要让角色转向镜头，不要改变朝向，不要旋转身体，不要展示正面，不要让角色面向左侧。
- 背景中不要添加任何风景、建筑、花草。
- 不要产生运动模糊、手部变形、多余的手指或法杖形状改变。
- **绝对不要添加**背景音乐、BGM、原声带、旋律、歌曲、环境音乐或任何音乐元素。只允许出现脚步声。

###  

### **洛琪希-****跑步动画提示词**

2D flat anime game sprite animation, the character always remains in a three-quarter side view facing toward the right side of the screen, young female mage with blue-purple twin braids, black witch hat, white coat with black and blue details, black frilled skirt, white boots, holding a white skeleton magic staff.

Fast running animation toward the right, not walking, not jogging. The character leans her body noticeably forward at the waist, keeps her head aligned with the forward direction, takes long and powerful strides, right leg and left leg alternate rapidly, one leg pushes off strongly while the other leg swings forward, both feet leave the ground briefly in each stride, there is clear airborne running motion, not a walk cycle. Arms bend at the elbows and swing quickly back and forth in rhythm with the legs, one arm forward while the other is back, the staff is held steadily at the side or slightly behind, braids, coat, skirt and ribbons flow strongly behind her with visible speed momentum. The character maintains continuous forward movement to the right while staying in the same side view, running speed is fast and energetic, weight transfer is clear, knees bend naturally, feet land realistically.

Fixed camera, no camera movement, no perspective change, pure solid green screen background, clean cel shading, full body always visible, stable character design, stable staff shape, no flicker, no distortion.

Audio: no background music, no BGM, no soundtrack, no melody, no song, no ambient music. Do not generate music of any kind. Only generate clear footstep sound effects, running step sounds, and minimal movement sounds synchronized with the animation.

Do not turn the character toward the camera. Do not change facing direction. Do not rotate the body. Do not show front view. Do not make it walk or jog. Do not add any scenery, buildings, flowers or grass to the background. Do not produce motion blur, hand deformation, extra fingers or staff shape change. Do not add background music, BGM, soundtrack, melody, song, ambient music or any music.

**核心画面描述：**
2D 平面动漫风格的游戏精灵（Sprite）动画。角色始终保持四分之三侧视图，**面向屏幕右侧**。

**角色设定：**
年轻的蓝紫色双麻花辫女法师，戴着黑色女巫帽，身穿带有黑蓝细节的白色外套、黑色褶边短裙和白靴子，手持一根白色骨架魔法杖。

**动作细节（快速奔跑动画）：**

- 核心定性：

  向右的**快速奔跑**动画，**绝对不是**走路（Walking）或慢跑（Jogging）。

- 身体姿态：

  角色在腰部明显向前倾斜，头部保持与前进方向一致。

- 腿部动作：

  步伐大而有力，左右腿快速交替；一条腿用力蹬地，另一条腿向前摆动；**每一步都有双脚短暂离地的腾空期**，呈现出明显的腾空奔跑动态，绝非走路循环。

- 手臂与法杖：

  手臂在肘部弯曲，配合腿部节奏快速前后摆动（一前一后）；法杖稳固地握在身侧或稍微靠后的位置。

- 物理飘动：

  双麻花辫、外套、裙子和丝带随着速度感强烈地向后飘动。

- 整体感觉：

  角色保持连续的向右移动，速度感快且充满活力，重心转移清晰，膝盖自然弯曲，双脚落地真实。

**音频要求：**

- 绝对无音乐：

  没有任何背景音乐（BGM）、原声带、旋律、歌曲或环境音乐。不要生成任何形式的音乐。

- 仅保留音效：

  只生成清晰的**脚步声**、跑步的步伐声，以及与动画同步的极少量动作摩擦声。

**技术与构图要求：**
固定机位，无运镜，无透视变化，纯净的绿幕背景，干净的赛璐珞（Cel Shading）上色风格。全身始终可见，角色设计和法杖形状稳定，无闪烁，无变形。

**负面提示（绝对禁止出现的元素）：**

- 不要让角色转向镜头，不要改变朝向，不要旋转身体，不要展示正面。

- 不要让她走路或慢跑

  （必须是快跑）。

- 背景中不要添加任何风景、建筑、花草。

- 不要产生运动模糊、手部变形、多余的手指或法杖形状改变。

- 不要添加背景音乐、BGM、原声带、旋律、歌曲、环境音乐或任何音乐元素。

###  

### **洛琪希-攻击动画提示词**

2D flat anime game sprite animation, the character always remains in a three-quarter side view facing toward the right side of the screen, young female mage with blue-purple twin braids, black witch hat, white coat with black and blue details, black frilled skirt, white boots, holding a white skeleton magic staff.

Short spellcasting attack animation while facing right, no projectile, no beam, no magic bullet flying forward. The character keeps body turned right, plants both feet firmly, does not lean back. The staff starts near the side, then is quickly raised only to chest height or slightly above shoulder height, not above the head, not held high overhead. Both hands control the staff briefly in a forward-downward casting position, then hold the pose steadily. Blue glow and small runes appear quickly at the staff tip, light stays localized around the tip only, particles do not travel far. Fast startup, short delay, practical game attack motion, minimal windup, no long charging sequence.

Fixed camera, no camera movement, no perspective change, pure solid green screen background, clean cel shading, full body always visible, stable character design, stable staff shape, no flicker, no distortion.

Do not turn the character toward the camera. Do not change facing direction. Do not rotate the body. Do not show front view. Do not make the character face left. Do not raise the staff above the head. Do not make the staff point straight up. Do not create projectile, bullet, beam, laser, explosion or long-range magic effect. Do not let light or particles fly off-screen. Do not add any scenery, buildings, flowers or grass to the background. Do not produce motion blur, hand deformation, extra fingers or staff shape change.

**核心画面描述：**
2D 平面动漫风格的游戏精灵（Sprite）动画。角色始终保持四分之三侧视图，**面向屏幕右侧**。

**角色设定：**
年轻的蓝紫色双麻花辫女法师，戴着黑色女巫帽，身穿带有黑蓝细节的白色外套、黑色褶边短裙和白靴子，手持一根白色骨架魔法杖。

**动作细节（短施法攻击动画）：**

- 核心定性：

  面向右侧的短施法攻击动画。**绝对没有**飞行道具、光束或魔法子弹向前飞出。

- 身体姿态：

  角色身体保持向右，双脚稳稳踩地，**身体不向后仰**。

- 法杖动作：

  法杖从身侧开始，快速抬起，但**仅抬至胸口高度或略高于肩膀**（绝不举过头顶，也不高举在头顶正上方）。

- 施法动作：

  双手控制法杖短暂地摆出向前下方的施法姿势，然后稳定保持该姿势。

- 特效表现：

  法杖尖端快速出现蓝色光芒和小型符文，**光线仅局部停留在法杖尖端周围**，粒子不会飞散到远处。

- 整体节奏：

  启动极快，延迟极短，是实用的游戏攻击动作，**几乎没有前摇，没有漫长的蓄力序列**。

**技术与构图要求：**
固定机位，无运镜，无透视变化，纯净的绿幕背景，干净的赛璐珞（Cel Shading）上色风格。全身始终可见，角色设计和法杖形状稳定，无闪烁，无变形。

**负面提示（绝对禁止出现的元素）：**

- 不要让角色转向镜头，不要改变朝向，不要旋转身体，不要展示正面，不要让角色面向左侧。

- 不要将法杖举过头顶

  ，不要让法杖笔直向上指。

- 不要生成

  飞行道具、子弹、光束、激光、爆炸或远程魔法特效。

- 不要让光线或粒子飞出屏幕边缘。

- 背景中不要添加任何风景、建筑、花草。

- 不要产生运动模糊、手部变形、多余的手指或法杖形状改变。

###  

### **洛琪希-受击动画提示词**

Roxy flinch animation. Three-quarter side view, facing right, no turning, no direction change. Her upper body suddenly flinches as if struck by a close-range melee attack from the right front. Shoulders tense upward, head tilts back briefly, hands grip the staff tighter, torso recoils shortly, then she quickly returns to a stable standing pose. Both feet stay planted on the ground. No falling, no knockdown, no flying backward. Only the character and her staff. Pure solid green screen background, fixed camera, clean cel shading, game sprite asset. No background music, no BGM, no soundtrack, no music of any kind. Only one short melee clank sound effect.

**核心画面描述：**
Roxy 的畏缩（受击）动画。保持四分之三侧视图，**面向右侧**，不转身，不改变方向。

**动作细节（受击反应）：**

- 触发情境：

  上半身突然畏缩，仿佛被来自右前方的近距离近战攻击击中。

- 身体反应：

  肩膀紧张地向上耸起，头部短暂向后仰，双手更紧地握住法杖，躯干短暂地向后收缩。

- 恢复动作：

  随后迅速恢复到稳定的站立姿势。

- 下盘状态：

  双脚始终稳稳踩在地面上。**绝对没有**摔倒、击倒或向后飞出的动作。

**画面与音频要求：**

- 画面元素：

  只有角色和她的法杖。纯净的绿幕背景，固定机位，干净的赛璐珞（Cel    Shading）上色风格，作为游戏精灵（Sprite）素材使用。

- 音频限制：

  没有任何背景音乐、BGM、原声带或任何形式的音乐。

- 唯一音效：

  只有一声短促的近战金属撞击声（Melee clank sound    effect）。

##  

## **牛头人-图像生成提示词**

2D flat anime game sprite art, full body shot, three-quarter side view facing right, minotaur warrior enemy, bull head with thick curved horns, muscular bulky humanoid body, dark brown fur, fierce angry expression, wearing tattered leather chest armor, iron bracers and worn loincloth, holding a large double-edged battle axe with both hands, axe blade resting on right shoulder, standing in a steady ready stance, feet shoulder-width apart. Japanese TV anime cel shading style, clean sharp outlines, flat color blocks, bold clear silhouette, high contrast, readable enemy shape for side-scrolling game. Solid pure green screen background, no scenery, full body completely visible, centered composition, game asset ready, no text, no watermark, no UI.

**核心画面描述：**
2D 平面动漫风格的游戏精灵（Sprite）美术图。全身镜头，四分之三侧视图，**面向右侧**。

**角色设定（牛头人战士敌人）：**

- 头部特征：

  牛头，长着粗壮弯曲的角，表情凶猛愤怒。

- 身体特征：

  肌肉发达、体型庞大的人形躯体，深棕色的毛发。

- 装备服饰：

  穿着破旧的皮革胸甲、铁制护腕和磨损的缠腰布。

- 武器与姿态：

  双手握着一把巨大的双刃战斧，斧刃 resting 在右肩上，双脚与肩同宽，呈现出稳定的**准备/待机姿态**。

**美术风格要求：**

- 日式电视动画赛璐珞风格：

  轮廓线干净锐利，平涂色块，剪影大胆清晰，高对比度。

- 游戏功能性：

  角色形状必须清晰易读，适合横版过关游戏（Side-scrolling    game）。

**构图与技术要求：**
纯净的绿幕背景，无风景，全身完全可见，居中构图。作为 готовый的游戏素材（Game asset ready），**无文字、无水印、无 UI 界面**。

### **牛头人-死亡动画提示词**

2D flat anime game sprite animation, the character always remains in a three-quarter side view facing toward the right side of the screen, never turns toward the camera, never changes facing direction during the fall. Minotaur warrior enemy, bull head with thick curved horns, muscular bulky body, dark brown fur, tattered leather chest armor, iron bracers, worn loincloth, holding a large double-edged battle axe.

Defeat / death animation. The minotaur's legs weaken, knees bend, body slumps forward slightly while still facing right, then collapses down to the ground in a heavy but natural way. The axe slips from both hands and falls beside the body, landing on the ground near the right side. The minotaur ends lying on the ground in a stable defeated pose, head toward the left side of the body, legs bent naturally, weapon resting beside him, body motionless for the final moment. Heavy weight, slow fall, clear death pose, no revival movement after falling.

Subtle white hit flash and small impact particles appear briefly at the start, then fade away quickly. No blood, no gore, no dismemberment.

Fixed camera, no camera movement, no perspective change, pure solid green screen background, clean cel shading, full body visible during the fall, stable character design, stable axe shape, no flicker, no distortion.

Do not turn the character toward the camera. Do not rotate the body while falling. Do not show front view. Do not make the character face left. Do not make the character get up or revive. Do not add large explosion, beam, projectile or magic effects. Do not add any scenery, buildings, trees or rocks to the background. Do not produce motion blur, hand deformation, extra fingers or axe shape change.

**核心画面描述：**
2D 平面动漫风格的游戏精灵（Sprite）动画。角色始终保持四分之三侧视图，**面向屏幕右侧**，绝不转向镜头，倒地过程中也绝不改变朝向。

**角色设定：**
牛头人战士敌人，牛头长着粗壮弯曲的角，肌肉发达的庞大躯体，深棕色毛发，穿着破旧的皮革胸甲、铁制护腕和磨损的缠腰布，手持一把巨大的双刃战斧。

**动作细节（战败/死亡动画）：**

- 起始动作：

  牛头人的双腿无力，膝盖弯曲，身体在保持面向右侧的同时略微向前瘫软。

- 倒地过程：

  以一种沉重但自然的方式倒向地面（Heavy weight,    slow fall）。

- 武器掉落：

  战斧从双手滑落，掉落在身体旁边，最终停在身体右侧附近的地面上。

- 最终姿态：

  牛头人最终呈稳定的战败姿势躺在地上，头部朝向身体左侧，双腿自然弯曲，武器静置在身旁。最后一刻身体完全静止，倒地后**没有任何复活动作**。

**特效与风格：**

- 受击反馈：

  动画开始时出现微弱的白色受击闪光和小型冲击粒子，随后迅速消散。

- 画面限制：

  无血腥、无内脏、无肢体断裂

  。

- 技术要求：

  固定机位，无运镜，无透视变化，纯净的绿幕背景，干净的赛璐珞（Cel    Shading）上色风格。倒地过程中全身始终可见，角色设计和战斧形状稳定，无闪烁，无变形。

**负面提示（绝对禁止出现的元素）：**

- 不要让角色转向镜头，倒地时不要旋转身体，不要展示正面，不要让角色面向左侧。
- 不要让角色站起来或复活。
- 不要添加大爆炸、光束、飞行道具或魔法特效。
- 背景中不要添加任何风景、建筑、树木或岩石。
- 不要产生运动模糊、手部变形、多余的手指或战斧形状改变。
- 

### **牛头人移动****动画提示词**

2D flat anime game sprite animation, the character always remains in a three-quarter side view facing toward the right side of the screen, never turns toward the camera, never changes facing direction. Minotaur warrior enemy, bull head with thick curved horns, muscular bulky body, dark brown fur, tattered leather chest armor, iron bracers, worn loincloth, holding a large double-edged battle axe with both hands.

Heavy steady walking cycle toward the right, slow and weighty movement, body bounces slightly up and down with each step, legs take wide solid strides, feet plant firmly on the ground with each step. The axe rests naturally in both hands and sways slightly with the body's rhythm, horns, fur and armor follow the movement naturally. Full smooth walking loop with consistent weight.

Fixed camera, no camera movement, no perspective change, pure solid green screen background, clean cel shading, full body always visible, stable character design, stable axe shape, no flicker, no distortion.

Do not turn the character toward the camera. Do not change facing direction. Do not rotate the body. Do not show front view. Do not make the character face left. Do not make it run or jump. Do not add any scenery, buildings, trees or rocks to the background. Do not produce motion blur, hand deformation, extra fingers or axe shape change.

**核心画面描述：**
2D 平面动漫风格的游戏精灵（Sprite）动画。角色始终保持四分之三侧视图，**面向屏幕右侧**，绝不转向镜头，绝不改变朝向。

**角色设定：**
牛头人战士敌人，牛头长着粗壮弯曲的角，肌肉发达的庞大躯体，深棕色毛发，穿着破旧的皮革胸甲、铁制护腕和磨损的缠腰布，双手握着一把巨大的双刃战斧。

**动作细节（沉重行走循环）：**

- 整体动态：

  向右侧沉重且稳定的行走循环。动作缓慢且充满重量感。

- 身体起伏：

  随着每一步，身体有轻微的上下弹动（体现体重）。

- 步伐特征：

  双腿迈出宽大且扎实的步伐，每一步双脚都稳稳地踩在地面上。

- 武器与物理：

  战斧自然地握在双手中，随着身体节奏轻微晃动；牛角、毛发和盔甲随着动作自然摆动。

- 循环要求：

  完整平滑的行走循环，重量感保持一致。

**技术与构图要求：**
固定机位，无运镜，无透视变化，纯净的绿幕背景，干净的赛璐珞（Cel Shading）上色风格。全身始终可见，角色设计和战斧形状稳定，无闪烁，无变形。

**负面提示（绝对禁止出现的元素）：**

- 不要让角色转向镜头，不要改变朝向，不要旋转身体，不要展示正面，不要让角色面向左侧。

- 不要让他跑步或跳跃

  （必须是稳重的行走）。

- 背景中不要添加任何风景、建筑、树木或岩石。

- 不要产生运动模糊、手部变形、多余的手指或战斧形状改变。

###  

### **牛头人-攻击动画提示词**

2D flat anime game sprite animation, the character always remains in a three-quarter side view facing toward the right side of the screen, never turns toward the camera, never changes facing direction. Minotaur warrior enemy, bull head with thick curved horns, muscular bulky body, dark brown fur, tattered leather chest armor, iron bracers, worn loincloth, holding a large double-edged battle axe with both hands.

Short windup melee axe swing attack toward the right. Character starts in ready stance, briefly pulls the axe back to shoulder height with both hands, then swings the axe forward and downward in a clean arc toward the right, body leans slightly forward with the swing, then returns to ready stance quickly. Fast snappy attack motion, clear hit frame, no long charging, no projectile, no beam, no magic effect. The axe stays solid and intact throughout the swing.

Fixed camera, no camera movement, no perspective change, pure solid green screen background, clean cel shading, full body always visible, stable character design, stable axe shape, no flicker, no distortion.

Do not turn the character toward the camera. Do not change facing direction. Do not rotate the body. Do not show front view. Do not make the character face left. Do not raise the axe above the head. Do not create projectile, beam, explosion or long range effect. Do not add any scenery, buildings, trees or rocks to the background. Do not produce motion blur, hand deformation, extra fingers or axe shape change.

**核心画面描述：**
2D 平面动漫风格的游戏精灵（Sprite）动画。角色始终保持四分之三侧视图，**面向屏幕右侧**，绝不转向镜头，绝不改变朝向。

**角色设定：**
牛头人战士敌人，牛头长着粗壮弯曲的角，肌肉发达的庞大躯体，深棕色毛发，穿着破旧的皮革胸甲、铁制护腕和磨损的缠腰布，双手握着一把巨大的双刃战斧。

**动作细节（近战挥斧攻击）：**

- 攻击方向：

  向右侧进行短前摇的近战挥斧攻击。

- 前摇蓄力：

  角色从准备姿态开始，双手将战斧短暂向后拉至肩膀高度。

- 挥砍动作：

  向右侧以干净的弧线向前下方挥动战斧。

- 身体配合：

  挥砍时身体略微向前倾斜，随后迅速恢复到准备姿态。

- 整体节奏：

  快速且干脆利落的攻击动作，有清晰的**命中帧（Hit frame）**，**没有漫长的蓄力**，没有飞行道具、光束或魔法特效。

- 武器状态：

  战斧在整个挥砍过程中保持坚固完整。

**技术与构图要求：**
固定机位，无运镜，无透视变化，纯净的绿幕背景，干净的赛璐珞（Cel Shading）上色风格。全身始终可见，角色设计和战斧形状稳定，无闪烁，无变形。

**负面提示（绝对禁止出现的元素）：**

- 不要让角色转向镜头，不要改变朝向，不要旋转身体，不要展示正面，不要让角色面向左侧。

- 不要将战斧举过头顶

  （保持攻击动作的紧凑感）。

- 不要生成飞行道具、光束、爆炸或远程特效。

- 背景中不要添加任何风景、建筑、树木或岩石。

- 不要产生运动模糊、手部变形、多余的手指或战斧形状改变。

###  

### **牛头人-受击动画提示词**

2D flat anime game sprite animation, the character always remains in a three-quarter side view facing toward the right side of the screen, never turns toward the camera, never changes facing direction. Minotaur warrior enemy, bull head with thick curved horns, muscular bulky body, dark brown fur, tattered leather chest armor, iron bracers, worn loincloth, holding a large double-edged battle axe with both hands.

Hit reaction animation when taking damage from the right front. Bulky body flinches briefly backward, shoulders tense up, head ducks slightly, both hands grip the axe handle tighter, torso jolts shortly, then bounces back to steady stance quickly. Short stiff hitstun, no falling, no knockdown, no large backward flight, weight stays stable on both feet. Subtle white hit flash and small impact particles appear briefly around the upper body at impact moment, light stays close to the body, no explosion.

Fixed camera, no camera movement, no perspective change, pure solid green screen background, clean cel shading, full body always visible, stable character design, stable axe shape, no flicker, no distortion.

Do not turn the character toward the camera. Do not change facing direction. Do not rotate the body. Do not show front view. Do not make the character face left. Do not make the character fall down, sit down or fly far backward. Do not add large explosion, beam or projectile effects. Do not add any scenery, buildings, trees or rocks to the background. Do not produce motion blur, hand deformation, extra fingers or axe shape change.

**核心画面描述：**
2D 平面动漫风格的游戏精灵（Sprite）动画。角色始终保持四分之三侧视图，**面向屏幕右侧**，绝不转向镜头，绝不改变朝向。

**角色设定：**
牛头人战士敌人，牛头长着粗壮弯曲的角，肌肉发达的庞大躯体，深棕色毛发，穿着破旧的皮革胸甲、铁制护腕和磨损的缠腰布，双手握着一把巨大的双刃战斧。

**动作细节（受击反馈动画）：**

- 触发情境：

  受到来自右前方的伤害时的受击反应。

- 身体反应：

  庞大的身体短暂地向后畏缩，肩膀紧绷，头部略微低下（duck），双手更紧地握住斧柄，躯干短暂地一震。

- 恢复动作：

  随后迅速弹回并恢复到稳定的站立姿态。

- 硬直状态：

  短暂的僵硬受击硬直（Hitstun）。**绝对没有**摔倒、击倒或大幅度的向后飞出，双脚始终稳稳踩地，重心保持稳定。

**特效与风格：**

- 受击特效：

  在受击瞬间，上半身周围短暂出现微弱的白色受击闪光和小型冲击粒子，光线紧贴身体，**无爆炸效果**。

- 技术要求：

  固定机位，无运镜，无透视变化，纯净的绿幕背景，干净的赛璐珞（Cel    Shading）上色风格。全身始终可见，角色设计和战斧形状稳定，无闪烁，无变形。

**负面提示（绝对禁止出现的元素）：**

- 不要让角色转向镜头，不要改变朝向，不要旋转身体，不要展示正面，不要让角色面向左侧。

- 不要让角色摔倒、坐下或向后飞出很远

  。

- 不要添加大爆炸、光束或飞行道具特效。

- 背景中不要添加任何风景、建筑、树木或岩石。

- 不要产生运动模糊、手部变形、多余的手指或战斧形状改变。

##  

##  

## **动画帧提取提示词**

在文件夹“D:\001_Work\05_账户运营\04_视频企划\017_模型评测\09-Image2点1和H3制作同人游戏\01-资产\02-动画帧序列提取\01-源视频”内，有一些绿幕视频，这是我用来制作游戏角色的动画序列帧的原始素材，我现在希望你制作一个脚本，将这些视频素材逐帧提取并抠像，移除画面中的绿幕，变成透明的PNG文件，并存放到“D:\001_Work\05_账户运营\04_视频企划\017_模型评测\09-Image2点1和H3制作同人游戏\01-资产\02-动画帧序列提取\02-动画帧序列”文件夹中，每个视频都单独导出到一个文件夹中，png图像的命名要清晰，使用视频名+序号的组合。边缘可以有一定的羽化效果，避免边缘有绿色的像素。不要删除任何文件。

## **游戏开发提示词**

请生成一个可直接在浏览器运行的单文件HTML5 横版卷轴动作游戏原型。所有角色动画均使用外部序列帧素材，重点实现完整的动画状态机、运动碰撞、敌人AI 和调试模式。

请完全自主一口气生成，中间不要问题，请仔细整理步骤，依次生成。

**1. 基础参数与窗口规范**

游戏画布固定为 16:9 比例，基准尺寸 1280×720，页面居中显示，浏览器无滚动条。

场景背景为单张 21:9 超宽背景图，支持横向卷轴滚动；相机仅水平跟随玩家，垂直方向固定。

地面平台为一条水平连续平面，平台顶面 Y 坐标全局可配置，所有角色脚底与平台顶面对齐，无台阶、无落差。

使用固定时间步长的游戏循环，保证不同帧率下运动速度、动画播放速度一致。

**2. 核心玩法逻辑**

玩家控制：A键和D键控制角色左右水平移动、空格键跳跃、Q键发射冰锥；冰锥从法杖位置沿面朝方向水平发射（调试模式中，可调整冰锥生成位置（即相对玩家角色的位置）），命中敌人造成伤害，飞出屏幕自动销毁。

敌人 AI：在平台上持续朝向玩家水平移动，进入攻击距离后触发近战攻击；敌人前方生成矩形近战命中盒，仅在攻击判定帧生效。

碰撞系统：玩家身体碰撞盒、敌人身体碰撞盒、冰锥碰撞盒、敌人攻击判定盒，全部使用矩形碰撞检测。

相机系统：相机平滑跟随（如果角色向左侧移动导致相机触及到背景图左侧边缘，那么相机就不再继续向左侧移动了，角色向右侧移动到边缘时也是同理），相机移动范围限制在背景图左右边界内，不得超出背景图（也就是说玩家可移动的范围就是仅在背景图的宽度范围内的）。

**3. 调试模式（核心功能，必须完整实现）**

按键盘～键切换调试模式开启 / 关闭，默认关闭

调试模式开启时，画面叠加显示以下可视化内容： 

亮绿色实线绘制平台顶面基准线，旁边标注文字「平台顶面 Y = 数值」；

蓝色半透明矩形绘制玩家身体碰撞盒，标注「玩家碰撞盒」；

浅蓝色半透明矩形绘制每个冰锥的碰撞盒，标注「冰锥」；

红色半透明矩形绘制敌人身体碰撞盒，标注「敌人本体」；

橙红色半透明矩形绘制敌人近战命中盒，标注「敌人攻击判定」；

屏幕左上角显示实时调试数据：玩家 XY 坐标、玩家水平速度、相机 X 坐标、当前冰锥数量、存活敌人数量。

所有调试图形仅作可视化叠加，不影响任何游戏逻辑与碰撞判定

调试模型下可以调整 平台顶面基准线数值，可以缩放玩家和敌人的体积大小，同时最多生成的敌人数量等。

**4. 美术素材清单与绑定规则**

所有角色素材均为透明背景 PNG 序列帧，默认角色朝向为右方向，朝向左侧时代码自动做水平翻转处理。

不同动画的帧数可能不同。

**玩家角色：洛琪希（远程法师）**

动画有：待机、移动、跑步、攻击、受击、死亡。

**敌人角色：牛头人（近战）**

**动画有：待机、移动、攻击、受击、死亡。**

牛头人攻击动画为近战攻击，玩家进入攻击范围后播放一次，攻击判定帧激活前方命中盒；

补充说明：
洛琪希-攻击动画，为远程攻击，会生成冰锥，并向前方发射。

冰锥投射物为Canvas 程序化绘制（浅蓝色尖锥图形），无需外部素材。

受击动画，受到伤害时播放一次；

死亡动画生命值归零时播放一次，播放结束后保持最后一帧静止；

敌人的死亡动画播放完成后，敌人从场景移除。

所以动画素材均在D:\001_Work\05_账户运营\04_视频企划\017_模型评测\09-Image2点1和H3制作同人游戏\01-资产\03-同人游戏Demo\01-动画资产文件夹内。

**场景素材**

主背景图，用途说明：单张 21:9 超宽横版场景，用于横向卷轴滚动，素材在文件"D:\001_Work\05_账户运营\04_视频企划\017_模型评测\09-Image2点1和H3制作同人游戏\01-资产\03-同人游戏Demo\02-美术资产\背景图01.jpg"内。

补充说明：玩家和角色的立足平台的高度，暂时先设置在画面的中间位置（即Y轴的一半），这个平台高度可以在调试模式中通过滑块实时调整(同时显示平台高度的数值)，以便于确认合适的高度。

玩家和敌人受击时不仅播放受击动画，而且在身体上还有红色闪烁，并有轻微击退效果。

**其他素材**

使用程序化的方式，在角色底部生成一个半透明的阴影。
"""Latest 24-film screenplay prompts: short films in one generation, 39-frame joins."""
from pathlib import Path
import csv
import hashlib
import json
import math
import re
import zipfile

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/scarlet-h3-cg-prompts'
DOC=ROOT/'docs/rpg/SCARLET-H3-CG-PROMPTS.md'
WORKFLOW=Path('D:/Program Files/ComfyUI/工作流/MiniMaxH3全功能合一完全体导演台工作流.json')
FPS=24
OVERLAP=39
STYLE=('16:9 横幅，手绘二次元暗黑哥特动画电影，稳定清晰的赛璐璐线稿和精细背景，深海军蓝阴影、旧金金属、克制赤光与青色提灯。'
       '自然有重量的动作，正确的手指握持、脚底接触与视线关系，面孔、身量、服装和道具跨镜一致。'
       '光效不遮盖手部、面孔和因果动作。不出现字幕、可读文字、片名、数字 HUD、水印、标志、分镜格或白底立绘排版。'
       '只生成指定环境与动作音，不生成可辨识对白、旁白、歌声或配乐；正式台词、音乐和必要口型后期另做。')
CHAR={
 'F':('绯月','assets/feiyue.png','银白长发、红瞳、黑红蝴蝶结、红宝石、白袖黑色金纹哥特裙，按参考的原身量与面孔；只有一根深酒红色尾巴，单手赤晶剑。三视图是同一人，不生成三个人。非加冕状态无冠、无彩窗翼。'),
 'X':('雪璃','assets/xueli.png','浅蓝长卷发、蓝瞳、深蓝兜帽、青色飘带与银纹长裙，青光提灯用链握持。不是法杖或火炬，三视图只对应一个人。'),
 'Y':('鸦羽','assets/yayu.png','紫色高马尾、紫瞳、黑紫铠甲与长衣摆，完整长刀和刀鞘各一，不把长刀换成绯月的赤晶剑。三视图只对应一人。'),
 'Q':('旧女王','assets/bosses/blood-queen-portrait.png','银白长发、红瞳、玫瑰发饰、黑白赤金王室礼装、独立长剑，面孔和成年身量区别于绯月。完整形态恰好六片彩窗刃翼、左右各三；冠、翼、伤势必须按本段连续性覆写，卸冠后绝不能重新生成第二顶冠。'),
 'V':('维恩','assets/story/scarlet/npc/vein.png','旧骑士面孔、年龄、发型、铠甲按参考，神情克制，温和表象转为执行公务，不突然邪笑或变怪。'),
 'M':('莱特','assets/story/scarlet/npc/messenger.png','信使外形衣装按参考；受伤后仍有呼吸，肩伤不拍成死亡，不生成血腥伤口。'),
 'D':('埃文医师','assets/story/scarlet/npc/physician-v2.png','灰白束发和胡须、旧棕色医师装按此正式参考，不改成初稿的另一个年轻人。'),
 'S':('瑟芮','assets/story/scarlet/npc/surgeon.png','外科医师面孔和服装按参考，戴手套、动作精确，进入大型手术偶胸舱操作，机械装置与她本人是两样东西。'),
 'A':('莫罗','assets/story/scarlet/npc/admiral.png','黑帆提督面孔、衣装与武器按参考，站控制旗舰甲板，身体有重量，不复制成多个提督。'),
 'C':('玛菈船长','assets/story/scarlet/npc/captain.png','普通木帆船船长面孔衣装按参考，操作缆绳、船舵和信号灯，不使用现代驾驶设备。'),
}
LOCATIONS={
 'throne':'同一破损哥特大教堂，湿黑石地，旧金铅框玫瑰窗，尽头高两级黑石王座，右后方窄侧台，左侧侧廊。赤月之心在王座下方，拘束外节点与主稳流连接清楚分开。',
 'inn':'旧石墙客舍，中央木桌、右侧漏雨木格窗，左后方走廊门，低柜起初靠窗。暖烛与冷雨光分开。',
 'bridge':'深谷红雾上方的旧石桥，中央路面和修过的桥索完整，南端是安全平台与礼拜堂门。桥外断面不作为可踩路。',
 'record':'现时礼拜堂石台、打开的圣物箱与唯一血晶，青色提灯；旧影像是另一间褐灰色诊疗室，固定机位、破边，不读心。',
 'abbey':'修院前庭湿石板、低破墙、拱门通道，三人向右前方安全角突破；这里没有女王、王座或核心。',
 'vein':'夜间营地窄走廊与一张单人书桌，只有油灯、纸笔和山道图；主角都睡着不偷看。',
 'ambush':'下层主路直通落闸山门，右侧比主路高一人的石平台，右后高处矿洞，弩手在门顶和左侧高台。A 有预布侧梯，B 没有；地形左右不能镜像。',
 'palace':'临水行宫接见厅靠窄码头，临水窗能见王船；岸上押送通道向内接医室，王船向外回王城，两方向不同。',
 'theatre':'旧石圆厅，黄铜黑铁大型手术偶，躯干正中透明胸舱，背部两根承重臂及细针索，麻醉槽与外墙局部风阀相连。旁边病房最低保障已经独立。',
 'flood':'港外高地、上游低海堤、下方街巷与浅滩。侧翻旧民船在浅滩，主角修好小船在高地另一侧独立安全泊位。',
 'fleet':'陆侧望台朝外海，黑帆控制船横封海口，两岸锚点间是升降封航链，民船在港内。旗舰甲板有缆弩、炮架与后舵。',
 'sail':'同一中小木帆船，低船首、木舷、单主桅旧帆、后舵。港口出发，驶往王城旧水门完整登陆台。',
 'room':'王城安静记录室，窗外真实复光的城区，桌上回信、三张旧船票、药布和两只杯子。无现代设施。',
 'evac':'王座右后侧台正在开裂，左侧已开退路，安全石柱有预备绳锚，最后通向外墙医护与看守接收处。',
 'dawn':'战后外墙残缺城垛、湿石通道，前方断塔、受损街区和远海，晨光出现但建筑不修复。',
}

PLANS=[]
def seg(seconds,visible,beats,tail):
    assert sum(x[0] for x in beats)==seconds,(seconds,beats)
    return dict(budget=seconds,visible=visible,beats=beats,tail=tail)
def film(cid,keys,loc,state,end,segments,note='',shared=''):
    PLANS.append(dict(id=cid,keys=keys,location=loc,state=state,landing=end,segments=segments,note=note,shared=shared))

film('CIN-00','Q','throne','女王清醒核北岸撤运，再写短召信；不是求死或求妹妹解脱。六翼收拢，冠仍在。',
 '信封缺角蜡印稳定一秒，后期转客舍 ADV。',[
 seg(13,'Q',[(7,'超远景，血月与破损大教堂压在湿城上，镜头缓慢接近，远处稀疏灯火在水面反光。'),(6,'一次明确硬切至窗外缓推，旧金窗框掠边，烛光下女王与桌面形成远处单一剪影，不新增近景角色。')],
     '窗外视角已经接近破窗，女王只是桌后剪影，前景窗框仍在一侧。'),
 seg(13,'Q',[(7,'切室内侧面中景，侍从只露手递撤运表。女王核看地图与船数，划去一处等待准令的墨迹，盖印交回，动作简洁。'),(6,'同场切手部，女王摘单只手套露指节晶纹，把已签公文移到一边，取私人信纸落笔。晶痛只使腕短暂停顿，不使她失控。')],
     '女王稳住手腕在私人信纸写第一行，已签表留桌边，六翼依旧收拢。'),
 seg(14,'Q',[(6,'延续手部书写，女王一次写完几行短句，墨迹不形成要求可读的汉字；不反复划掉妹妹名字、不长时间诉苦。'),(7,'切俯拍，折纸装封、滴蜡、以缺角印戒压纹，再把信推向侍从手边。撤运图仍在一角，信里不出现继位、死亡或王冠的说明。'),(1,'相机停在缺角蜡印，信封与手势稳定，不自行淡黑。')],
     '封好短召信，缺角蜡印清楚，桌面没有第二封展开的秘密说明。')],
 '后期信文：绯月：北岸的水又涨了。旧水门还留着。带上那把剑，回来见我。——姐姐。原求死信退出。')

film('CIN-01','FXYM','inn','追杀来自窗外。莱特开场未受伤，第二箭后才肩伤，始终存活；封存文件尚未展开。绯月、雪璃、鸦羽各自武器不交换。',
 '四人安全构图，莱特有呼吸，回伤者旁 ADV。',[
 seg(13,'FMX',[(5,'室内中景，窗纸上不同高度两道弩影停住。莱特先发现反光，转身推开绯月，镜头横移小幅跟随。'),(3,'切桌面，第一箭从右窗穿入钉在绯月原站位前，轨迹清楚，木屑不遮人。'),(5,'切信使与雪璃，第二箭伤肩侧，雪璃托住背与手臂让他坐靠墙，肩上只有暗痕与少量血迹，胸口仍起伏。')],
     '雪璃扶住墙边莱特，绯月已经站稳在桌前，窗口在右，低柜尚未推到遮挡位。'),
 seg(12,'FXYM',[(4,'切绯月侧后中景，她以单手赤晶剑挡偏一箭，门框又甩进一条弩索。'),(4,'切门侧，鸦羽拔自己的长刀切索，再以肩推低柜挡窗，先切后推，不增加手臂。'),(3,'切略高全景，绯月护窗，鸦羽柜侧收势，雪璃扶莱特，四人位置清楚。'),(1,'保持安全全景，莱特有呼吸，桌上的文件未展开，不淡黑。')],
     '窗口已挡，四人各在明确位置，信使存活，后续由 ADV 压伤读文件。')])

film('CIN-02','FXY','bridge','桥索已由玩家修好、病人已实际转运；本片三人走最后清出的桥段。',
 '全员在完整南平台，礼拜堂门未开。',[
 seg(18,'FXY',[(4,'远景建立完整中央桥面与修补绳结，桥下红雾流动，镜头沿桥轴缓推。'),(8,'同一段生成内硬切侧向跟拍，绯月前、雪璃中、鸦羽后，三人沿完整石面跑过，不踩破边缘。'),(5,'切南平台回望，三人依次收步，鸦羽最后扶稳桥索；镜头略转露出礼拜堂关着的门。'),(1,'三人在安全平台站定，相机停住，不淡黑。')],
     '三人都离开桥面，南平台安全，尚未开箱。')])

film('CIN-03','FXYQD','record','只回放一次固定诊疗记录，女王清醒签整张供药与封存处置书；旧影像不能拍到心思和别处。',
 '影像熄灭回石台三人，绯月收紧手指。',[
 seg(13,'XQD',[(5,'现时血晶近景，雪璃把青灯斜照唯一血晶，里面出现边缘破损的矩形旧影像。'),(8,'硬切进影像，机位完全固定。女王坐诊椅，医师展示晶化手臂、供药单与隔离单，她先核供水和人数再移近整张处置书。画面偏褐灰，轻微档案划痕。')],
     '固定旧诊疗中景，女王与医师仍在原位，处置书在女王手前，印尚未压下。'),
 seg(12,'QDFXY',[(6,'延续同一固定影像机位，医师指处置书下半，女王看清后盖覆盖整张纸的印。纸上不生成可读文字，不切她秘密想法。'),(5,'在影像熄灭后明确切回现时礼拜堂，绯月台边手收紧，雪璃放低灯，鸦羽看向她不催促。'),(1,'现时三人沉默站定，血晶不再播放，旧医师和女王不留在礼拜堂。')],
     '诊疗影像已灭，现时只有三位主角。')],
 '旧影像正式对白与命令字幕后期按 01-07 配，必须知道签批包括供药和限制自由，不只拍一段可被误解的疼痛。')

film('CIN-04','FXY','abbey','居民已接收，主厅 Boss 尚未登场；敌人为前庭演出夜兽，不冒充玩家已经打完赫缄。',
 '前庭安全角站稳，回可整备状态。',[
 seg(12,'YF',[(7,'侧面中全景，鸦羽低重心一步居合切开两只黑色夜兽轮廓，影兽化少量暗粒，无血肉飞散。'),(5,'同方向切绯月接缺口突进，第一下赤晶剑斩击后落脚，刀路与敌人位置可读。')],
     '绯月第一击已收势落脚，鸦羽后侧，通道缺口向右前打开。'),
 seg(13,'FXY',[(4,'绯月第二下分开斩击，把残余影兽逼离通道，先落脚后出剑。'),(5,'较大影兽砸地，雪璃从后侧举灯，青盾在落点前展开，碎石留盾外，绯月与鸦羽退回她能覆盖的范围。'),(3,'影兽退入侧影，护盾散，三人沿同向通道到安全角。'),(1,'站稳，未出现审判官或胜利字样。')],
     '三人安全，前庭暂清，主厅门仍待玩家主动进入。')])

film('CIN-05','V','vein','玩家专知幕间，绯月等三人没有偷看。维恩主动报告路线与分离同行者的条件。',
 '密使走后空椅与未熄灯，后期转次日。',[
 seg(18,'V',[(5,'固定侧面，维恩掩客舍门，温和神色收起，确认走廊无人后到单人书桌。'),(8,'硬切俯拍，维恩在山道图标预定路线与分离位置，核完短笺后亲手签名，不表现被迫求救。墨迹不要求可读字。'),(4,'切门口，密使仅露手套接走纸，维恩退画外，焦点落空椅和灯。'),(1,'相机停，椅子空着，没有主角窥视。')],
     '路线已送，只有玩家知道。')],
 '后期文字：同行者分开看管，拒令按袭驾条款处置。不是用一张“所有知情人全部灭口”把阴谋讲完。')

AMBUSH_OPEN=seg(8,'VFXY',[(4,'山门广角，维恩沿高侧廊离开，背影消失后门顶锁链绷紧，小队在下层主路。'),(4,'闸门落下，高台弩手出现，箭压向两侧但避开绯月；三人伏低，高低平台与矿口方向仍可读。')],
                 '落闸已停，绯月与鸦羽在下层，雪璃在右高台附近；尚未出现分支索与梯的结果。')
film('CIN-06A','FXYV','ambush','已准备线：玩家预布侧梯、改过索，雪璃没有被绑或被俘。',
 '雪璃带伤者进入矿口，绯月鸦羽准备下层接应。',[
 AMBUSH_OPEN,
 seg(14,'FXY',[(8,'续山门原方向，落索被预布侧梯横梁卡住，雪璃举灯护两名伤者沿备用路进入右后矿口，脚实际经过入口。'),(5,'切下层绯月鸦羽侧后，雪璃从上方安全入口举灯标位置，再带人退洞内，两人转向近处下层索。'),(1,'稳住上下空间关系，无捆绑，无自动全员营救完成。')],
     '雪璃已走备路进矿口，下层两人还要玩家接应伤者。')],shared='ambush-opening')
film('CIN-06B','FXYV','ambush','未准备线：没有侧梯，完整猎索隔开雪璃；片中仅隔开，不直接演完俘虏营救。',
 '雪璃在高台护伤者，绯月鸦羽准备切近索。',[
 AMBUSH_OPEN,
 seg(14,'FXY',[(8,'没有预布侧梯，猎索带动隔断，把雪璃和伤者留右侧高台。她举灯挡箭，退向矿道石壁；侧面全景明确不能直接跨断口，不捆绑。'),(5,'切下层，绯月迈向断口又停，鸦羽伸臂拦危险跨越，两人转向可达锚点，刀剑就位但未切完。'),(1,'远处青光仍在，稳定等待交还下层操作。')],
     '雪璃仍在高处，不能把未准备线剪成已安全走侧梯。')],shared='ambush-opening')

film('CIN-07','YQS','palace','鸦羽交易失败欲毁剑，女王先核撤运、拒非血亲替代。晶痛不使她发疯；命封剑留置，禁止用药审讯。',
 '王船回王城，岸内押送带走鸦羽和封存箱，转清晨绯月追踪。',[
 seg(18,'YQS',[(6,'接见厅侧中景，鸦羽反握绯月赤晶剑抵石沿欲毁，女王一手示意，两近卫分先后压前臂、控制剑，剑未断。'),(6,'切女王，取剑时晶化腕短震，她把剑交侍从封存，再用稳手压平未签完的撤运表盖印，鸦羽仍在另一侧被控制。'),(5,'切码头广角，女王登外行王船，瑟芮在岸接凭据与剑箱，押送队带鸦羽向岸内行宫，方向分开。'),(1,'相机停在远去船尾，未上刑或注药。')],
     '女王离开，瑟芮留守，鸦羽非自愿留置。')],
 '本片全部一次生成，内部切镜不是三个生成段。正式对白前置 ADV 已讲清，勿另加解释继位的字幕。')

film('CIN-08','S','theatre','病房已先转出或最低保障已独立；主角尚可反抗，没有被麻醉。',
 '手术偶站稳，镜头退出安全战斗距离。',[
 seg(15,'S',[(5,'瑟芮拉紧手套，走进大型手术偶胸舱，透明舱门逐扣关闭，脸仍可辨，机械臂尚垂。'),(6,'低位全景，两根承重臂依固定关节展开，细针索绷紧，液槽震动，局部风阀出现暗红警戒光，构造不变形增肢。'),(3,'装置离固定架站起，重量压地，镜头后退露完整装置和空地。'),(1,'站定，不先向玩家位置挥击。')],
     '手术偶启动完成，没有完成手术或伤害主角。')],
 '装置正式设定图尚缺；先统一同一版胸舱与承重臂，再量产。人物立绘不能代替机械设计。')

film('CIN-09','FXY','flood','真实承载衰败导致红水越堤，不是女王造假灾难。修好的回程船仍可用，七名幸存者后续由玩家救。',
 '三人到救援入口，未救完七人。',[
 seg(12,'',[(7,'高处远景，上游低堤被赤红夹晶屑的水越过，水按地形进入低街，前景安全高地不被瞬间淹没。'),(5,'切街巷侧面，少量清楚的居民剪影向坡上跑，水在后方而不是从任意方向突然生成。')],
     '居民上坡，低街有水，主角安全泊位仍完整。'),
 seg(13,'FXY',[(4,'岸边近中景，另一条旧民船浅滩侧翻，舱板内有人拍击挥手，船保持可救状态，不突然沉没。'),(8,'切高地三人，绯月收船票，雪璃提灯，鸦羽取备用绳，三人看清求救位置，沿石阶入口转身出发。'),(1,'停在安全入口，修好的回程船仍在另一泊位。')],
     '救援行动刚开始，没有用影片代替逐人接收。')])

film('CIN-10','FXYA','fleet','封锁发生在海口，民船尚不能离开；玩家未调查押运仓。',
 '炮口朝向远处望台，进入传话 ADV。',[
 seg(18,'FXYA',[(6,'望台高度全景，黑帆船由雾中驶入，沿同一航线横列海口，港内民船慢下。'),(6,'切绞盘与水面，缆弩向固定点送粗缆，铁链被拉出水，链前民船停稳，不撞沉。'),(5,'切提督背后甲板，侧面脸露出，镜头沿炮口望向远处三人小轮廓，三位主角不复制到旗舰上。'),(1,'稳定炮口与望台的空间关系，不出现牢仓内部。')],
     '莫罗在船，三人在岸，后续还要调查与交涉。')])

film('CIN-11','FXYC','fleet','莫罗已被制服，两缆弩解除，安全舵向锁定，民船已实际获准分批通过。',
 '三人等最后一船走远，再回可操作甲板。',[
 seg(15,'C',[(6,'已损坏缆弩近景垂下，失张力的封航链缓慢落水，镜头沿真实打开的海口转向第一条民船。'),(9,'切民船侧面跟拍，船长举信号灯，后面不同大小的民船按有间距的航序前进，乘客自然坐立，不排主角阵形。')],
     '首批船已通过，船长信号灯举着，海口没有再合拢。'),
 seg(15,'FXY',[(6,'切控制甲板中景，雪璃举灯回应，绯月放低完整剑，鸦羽收完整长刀，后方固定舵绳结清楚。'),(8,'切三人背后全景，最后民船穿空出的海口，远处首船已小。三人一直等到最后那条过界才稍转身。'),(1,'安全甲板稳住，控制船没有沉，民船不返回原位。')],
     '最后一批民船已经离港，三人尚未自动到码头。')])

film('CIN-12','FXYC','sail','玩家主动选择去王城；三人自由同行，绯月剑柄已卸外饰、契印完整。此时没有最终答应或拒绝。',
 '旧水门完整登陆台，船慢靠岸。',[
 seg(12,'FXYC',[(8,'码头侧面，三人自愿依次上修好的木船，船长解缆，鸦羽接绳头，装备各归本人，无囚笼手铐或押送队。'),(4,'切船上中景，船驶离泊位，三人扶稳木舷与灯链，船身规律起伏，脚不浮空。')],
     '小船已离港，三人同船，风雨在船外，前方仍是海面。'),
 seg(13,'FXYC',[(5,'延续船上同行，绯月居中、雪璃一侧护灯、鸦羽另一侧看航路，短眼神确认后一起望前方。'),(7,'切船首视角，王城与大教堂远现，镜头下移看见旧水门和完整登陆台。船长减速，小船慢靠，不自动开水门。'),(1,'靠岸位置稳定，人物仍自由，没有接受加冕的动作。')],
     '三人在王城外水门登陆前安全位。')])

film('CIN-13','FQ','throne','女王关门要求留剑，绯月尚未回答。女王冠在、六翼完整，雪璃在侧廊、鸦羽查工区，不能先拍三人齐。',
 '绯月左、女王右，相距足够开战，不先完成缴械。',[
 seg(11,'FQ',[(6,'绯月左侧背肩中景，黑地冷反光，她握住自己的赤晶剑望王座，主殿目前只有姐妹二人。'),(5,'切女王略低全景，她从高台缓慢降到地面，鞋尖接地、头发和裙摆稍后落定，六翼尚收在背后。')],
     '女王已落地，冠在，六翼收拢，绯月仍持自己的剑在左侧。'),
 seg(11,'FQ',[(4,'切女王正面中全景，恰好六片独立旧金边赤色彩窗翼由近至远展开，左右各三，片间能数清，不长第七片或羽毛翼。'),(6,'切侧面双人宽景，绯月左前、女王右后，两把不同的剑各自举准备位，镜头退出安全开战距离。'),(1,'稳住，未接冠、未刺心、未先打倒任何一方。')],
     '两人对立，六翼完整，共通战将开始。')])

film('CIN-14','FXQ','throne','共同战第一段已完成，开侧廊接雪璃；鸦羽此时仍查工区，绝不能用三人齐旧版本。',
 '绯月与雪璃站稳，女王转向提灯支点，进入第二段。',[
 seg(14,'FXQ',[(5,'姐妹侧面中景，短身赤晶剑与女王独立长剑交锁，脸分别在左右，两人各退半步解除，不流血致死。'),(5,'切左侧廊，内闩打开，雪璃提灯步入，青光沿门边照到绯月；鸦羽不出现、不偷换为画面外第三影子。'),(3,'切宽景，雪璃到绯月左后站稳，女王隔厅转向灯的方向，主连接仍稳。'),(1,'停在可接战斗的位置，不自动破翼根或杀女王。')],
     '当前厅内三人是绯月、雪璃、旧女王；鸦羽稍后才返厅。')])

film('CIN-15','FXQ','throne','女王启动尚未获回答的强制认证。契印认活体、王座阵，不再使用持剑刺心的旧规则。核心与王冠必须保留。',
 '绯月手腕处于未完成认证的拘束，雪璃支点在，交还解外扣操作。',[
 seg(18,'FXQ',[(5,'宽幅厅景，女王抬稳手，王座外侧阵点逐个亮起，拘束连接向绯月持剑腕延伸。雪璃在稳流支点，鸦羽尚不入镜。'),(7,'切侧面中近景，女王扣住绯月腕，认证线由完整契印接向王座阵，绯月反向抵抗。剑尖始终朝斜下远离两人躯干，绝不朝心口或刺入。'),(5,'切手腕与阵点，认证光停在未闭合状态，雪璃青光撑住近处，让外扣与主连接看起来是两种明确部件。'),(1,'稳定在未接通的清楚状态，冠未移交，核心未破。')],
     '强制认证未完成，玩家仍有解外扣和等接应的操作。')],
 '18 秒整段生成，内部切镜不拆任务。旧“将剑转向女王心脏”的画面从本版删除。')

film('CIN-16C','FXYQ','throne','鸦羽已接完工区返厅，三人断外侧强制节点；主稳流连接保留。这里尚未最终选择 A/R。',
 '女王重伤但清醒且能继续维持控制，三人自由，进入最终选项。',[
 seg(16,'FXYQ',[(6,'侧面中景，返厅鸦羽切开外扣，绯月停止硬扯、手腕脱离认证，雪璃灯支点稳。每人手里只有自己的武器。'),(5,'切王座全景，外侧拘束光熄、六翼失能并垂低，但主稳流仍有受控赤光。冠、赤月之心、剑柄契印三者完整，绝不出现玫瑰窗终结或碎冠。'),(4,'切安全侧台宽景，女王坐下仍清醒，三人站在相同地面，刀剑放低而非向她补刀。'),(1,'稳定停顿，留给片后真实选择，不自动戴冠或破心。')],
     '同一终局检查点，两条路线都可行，没有预播任何结局。')])

film('CIN-17A','FXYQ','throne','仅答应线，玩家已二次确认、民船自由、原件留城外。三人监护移交的操作先成立。全场只有一顶控制王冠，从旧女王转给绯月。',
 '绯月接稳王冠，旧女王尚有最后压潮的微弱呼吸，随后是 A 复光片。',[
 seg(17,'FXYQ',[(6,'姐妹侧面中景，绯月自愿走入已经解除强迫的阵内站位，雪璃一侧监护，鸦羽守开放的门。没有锁腕、推搡或挣扎。'),(6,'切手部，完整契印与阵点逐段接通，绯月将手放在雪璃能看见的位置，女王稳住旧侧节点，连接有先后，不是一阵闪白。'),(5,'切双人中景，旧女王头上的唯一王冠缓慢升离，绯月仍无冠等待下一段，女王六翼只是失能旧残光，不给绯月长出复制品。')],
     '唯一王冠悬在姐妹之间，旧女王已卸冠，绯月站定接受，核心与契印完整。'),
 seg(18,'FXYQ',[(7,'沿同一视线，唯一王冠缓慢落向绯月头顶并停稳。绯月保留自己红黑蝴蝶结、少女身量与面孔，不变成旧女王，不长六翼；旧女王头上始终空着。'),(6,'切侧面宽景，绯月第一次承受连接重量，膝微弯后稳住，雪璃贴近监护手腕，鸦羽守门，旧女王逐步收回一只手。'),(4,'切绯月面部，她有恐惧与疼痛但意识清醒，以呼吸稳住，不是傀儡或胜利大笑。'),(1,'保持接稳瞬间，皇冠只在绯月头上，核心未熄。')],
     'A 线移交完成，仍需下一片表现压潮和旧女王耗尽。')],
 '加冕绯月正式差分／服装尚待制作。当前三视图只锁身份；先统一采用原服装加单顶王冠的试片方案，正式服装须另出设定，不自动套旧女王礼装。')

film('CIN-18A','FXYQ','throne','A 线移交已完成，绯月佩唯一王冠，旧女王卸冠且六翼失能。赤月之心继续运作，城真的恢复，不混入 R 线废墟与断柄。',
 '压潮稳定、旧女王耗尽死亡；回安全哀悼 ADV，不直接跳欢庆。',[
 seg(15,'',[(6,'切城内水道远景，赤红污染水被有秩序地压回受控渠，街区不被摧毁，普通清水与红水渠道分开。'),(5,'切民居与泵边，清水重新到桶，街灯从近到远依次复光，居民慢慢松开紧握桶沿的手，不要求可读字。'),(4,'切港口远景，按既有航序的民船继续走，有人能望向尚在的家，不拍新灾害推翻真实救援成果。')],
     'A 线王城恢复灯、水与受控水道，房屋尚在，恢复不是幻象。'),
 seg(15,'FXYQ',[(6,'明确切回王座侧台，卸冠旧女王手从旧节点慢松开，绯月戴冠靠近，雪璃检查，鸦羽在一旁留出空间。旧女王不生成第二顶冠。'),(5,'切姐妹面部分离的中景，绯月扶住她，旧女王眼神最后看向妹妹，随后头微低、呼吸停止。无血腥，没有突然康复。'),(3,'雪璃检查后慢慢放低手，三人沉默，没有立刻庆祝、微笑或抹掉责任。'),(1,'稳定哀悼构图，冠只在绯月，契印与核心继续完整。')],
     '旧女王死亡、城市压潮有效，A 线身体代价后续在 CG 和 ADV 呈现。')],
 '后期可配：女王“亮了吗？”绯月“亮了。接收点的回条也到了。”此段不要求模型直接生成对白和口型。')

film('CIN-19A','FXY','room','A 线数日后：绯月新女王、手腕第一道晶纹已包扎，姐姐已逝。同伴留在她身边，赤月之心未熄，城市灯火是真实成果。',
 '窗外灯火与桌上三票同在，接受线片尾。',[
 seg(20,'FXY',[(5,'固定记录室桌面近景，三张未用旧船票、一封回信、药布和两杯在暖灯下，不出现可读文字。'),(7,'同一次生成切三人中景，绯月原面孔戴唯一王冠坐桌边，雪璃替她重新包腕，鸦羽把边境回信放近；她们像仍会一起生活的人，不是朝臣跪拜。'),(7,'缓慢拉到窗侧宽景，三人在同室，外面保住的街灯成片亮着。绯月读信，晶纹被布遮大部分，只露一点代价。'),(1,'相机停，安静呼吸与窗外灯火，无旧女王病房、断剑或废墟混入。')],
     '接受并非失败：城市保住，同伴仍在，未来没有无损保证。')],
 '剧情预算恰好 20 秒，本版也只一次生成；合法帧长为 481 帧，约 20.041667 秒。')

film('CIN-17R','FXYQ','throne','仅拒绝线，玩家二次确认后已完成回条、回流、稳流、断主连接、核心破防与共同终结按钮。片初旧女王仍佩冠；三实体在本片按动作先后毁，之后旧女王失冠但仍存活。',
 '核心、王冠、契印均毁，女王仍可救，进入停供和绳索救援。',[
 seg(15,'FXY',[(6,'正面三人稳定全景，雪璃左、绯月中、鸦羽右，青白、赤、紫能量各自分离，不让旧女王混进三人招式画面。'),(5,'切雪璃与鸦羽侧面，青灯稳近场，长刀沿已打开的内扣切出清楚紫色刀路，为绯月留同一目标方向。'),(4,'切绯月，单手赤晶剑踏前交叉斩线，脚落地与挥剑先后可读，面孔和握持手不被闪白遮掉。')],
     '三人的动作朝已暴露核心汇合，核心、冠、契印尚未完成毁灭。'),
 seg(15,'Q',[(5,'只拍高处与核心方向，三色动作线汇成可读玫瑰窗轮廓，亮度收住，不新增第四主角或神明。'),(6,'切赤月之心近景，能量沿已破防裂纹进入，核心逐层裂开，碎片向下远离人物，内部赤光逐渐暗下。'),(4,'切旧女王独立中景，王冠开裂碎落、失能翼片熄光、束缚垂下。她倒在侧台但手仍微动有呼吸，不宣告死亡。')],
     '赤月之心与旧冠已毁，旧女王倒侧台仍活着，绯月的契印尚有残光。'),
 seg(15,'F',[(6,'切绯月手部，她查看已卸外饰的剑柄契印，双手收拢主动用力折断同体连接，只有一次明确折裂，不凭空出现第二把剑。'),(5,'断口固定为斜裂赤晶加半截旧金护手，残光沿裂纹熄去，不能恢复完整剑柄。'),(3,'镜头微移露绯月抬眼望向侧台，另一只手伸向救援绳所在方向，不先救起姐姐。'),(1,'稳定断柄与熄光，回游戏等待停供实况与救援。')],
     'R 线三实体全部毁，不能在后续再加冕或复原武器。')],
 '这是新 CIN-17R，不是共通 CIN-16C。旧版三人破心素材只能在此路由改编使用。')

film('CIN-18R','FXYQ','evac','R 线核心与冠毁，女王无翼力、重伤未死。预备绳锚、卸晶桥、救援带、三人共拉均已由玩家实际完成。',
 '女王交给外墙医护与看守，不复位、不痊愈。',[
 seg(12,'FXYQ',[(5,'安全石柱旁全景，雪璃固定绳扣，鸦羽压住锚点复查，绯月沿已固定路线靠近侧台。动作是已有操作结果，不新增从未备好的装置。'),(7,'侧面中景，绯月为卸冠女王系好肩胸救援带，避开晶化伤臂，卸开的晶桥留在旁边，女王虚弱睁眼配合但不能自己站起。')],
     '女王带已系好，绯月在侧台托她，雪璃鸦羽在安全端准备共同承重。'),
 seg(13,'FXYQ',[(6,'宽幅侧面，雪璃与鸦羽后移重心拉绳，绯月托住女王，逐步把两人拖回稳地。绳索真实绷紧，脚擦石，不用飞跃或新翼代替。'),(6,'切外墙接收，普通医护抬担架、看守随行，三主角松绳留在通道口，女王卸冠、无完整新翼。'),(1,'担架平稳向医护处走，受看守状态清楚，未回王座。')],
     'R 线女王获救但病伤仍在，三人可再去外墙观景点。')])

film('CIN-19R','FXY','dawn','R 线救援接收后玩家主动到观景点。城市已经停供，低区受损，只有三主角在墙上。绯月无冠、携斜裂断柄，鸦羽长刀完整。',
 '稳定外墙同机位淡回操作，仍要走回水门，不自动片尾。',[
 seg(17,'',[(9,'王城废墟远景，赤月之心熄灭后残留光点散去，赤云分开浅金天光，断塔与受损街区保持真实，不自动修复。'),(8,'缓慢沿湿城垛下降和横移，水滴从缺口落下，旧旗轻动，远处被放弃的下城区仍有红水，没有现代城市或复活人群。')],
     '晨光已到湿城垛，王城仍是废墟，镜头朝观景点移动。'),
 seg(18,'FXY',[(7,'切后侧全景，雪璃左、绯月中、鸦羽右看海平线，绯月无冠，斜裂断柄安稳收侧，青灯平静，鸦羽完整长刀放低。'),(7,'同场缓近一点，三人松肩、发梢衣摆随风，只是疲惫安静，不胜利摆拍，不出现第四位女王。'),(3,'相机慢退到可接外墙游戏的宽幅机位，城内灯没有复亮。'),(1,'完全停镜，仍有自然微动，不自行淡黑。')],
     'R 线黎明，代价仍在，玩家还需自己走回水门。')])

SOUNDS={
 'throne':'空厅风、缓慢晶体共鸣、靴底与衣料、动作发生时的金属与石扣；不以连续轰鸣掩盖关键断扣。',
 'inn':'窗外雨、破纸、两次分明弩弦、木击、柜脚擦地与伤者呼吸；不生成可辨识喊话。',
 'bridge':'山风、桥索轻振、三组有间隔脚步、灯链。',
 'record':'现时灯链与低晶鸣；旧影像段为窄带室内底噪、纸与印戒，熄灭后回空室风。',
 'abbey':'清楚刀出鞘与破风、落地、影兽散裂、护盾清鸣，低于人物动作的读解强度。',
 'vein':'门闩、克制脚步、纸笔和油灯。',
 'ambush':'落闸、绷链、弩弦、索撞木与落地脚步，后段跟随所在高低空间。',
 'palace':'铠甲和纸声、克制晶裂、缆绳与水、押送脚步，非欢庆或刑讯音效。',
 'theatre':'锁扣、泵压、齿轮、针索与承重落地，声音按机械动作逐次发生。',
 'flood':'远堤石裂、潮水、跑动脚步与拍舱板，避免连续尖叫。',
 'fleet':'帆索、船壳、绞盘、链节与滴水，信号灯链轻响。',
 'sail':'风浪、帆布、木结构与靠岸轻碰，稳定随船。',
 'room':'微风、纸、布料与杯轻碰，安静室内。',
 'evac':'绳索和环受力、鞋擦石、担架与医护脚步、远处低沉塌石。',
 'dawn':'风从强转弱、远海、水滴和旧旗，无自动煽情音乐。',
}


def aligned_end(frames):
    return 5+17*math.ceil((frames-5)/17)


def windows_for(f):
    elapsed=0;previous=0;result=[]
    budget=sum(s['budget'] for s in f['segments'])
    for i,s in enumerate(f['segments']):
        elapsed+=s['budget']
        end=aligned_end(elapsed*FPS)
        overlap=OVERLAP if i else 0
        start=previous-overlap
        length=end-start
        assert start>=0 and length>overlap and (length-5)%17==0
        result.append(dict(index=i+1,startFrame=start,endFrameExclusive=end,lengthFrames=length,
                           overlapFrames=overlap,generation_seconds=length/FPS,
                           new_frames=end-previous,new_seconds=(end-previous)/FPS,
                           film_tail_trim_frames=(end-budget*FPS) if i==len(f['segments'])-1 else 0))
        previous=end
    assert sum(w['new_frames'] for w in result)==result[-1]['endFrameExclusive']
    return result


def references(f):
    return [dict(slot=i+1,actor=k,name=CHAR[k][0],path=CHAR[k][1]) for i,k in enumerate(f['keys'])]


def prompt_for(f,i,w):
    s=f['segments'][i];incoming=w['overlapFrames'];length=w['lengthFrames']
    shared=bool(f['shared'] and i==0)
    title='山门伏击·共同前段' if shared else f['title']
    state=('维恩离开、山门落下、弩手露面，三人位置先建立；只拍共同开场，未拍任何准备或未准备的结果。'
           if shared else f['state'])
    if f['id']=='CIN-01' and i==1:
        state+=' 本段开头莱特已经肩伤，后续四人全景也保留伤势，不恢复未伤状态。'
    if f['id']=='CIN-17A' and i==1:
        state+=' 本段从唯一王冠悬在姐妹之间开始：旧女王头顶已无冠，绯月此刻尚待落冠，不重复演第一段脱冠。'
    if f['id']=='CIN-17R' and i==1:
        state='仅拒绝线。第一段已形成朝向核心的合力，但核心和旧王冠在本段开头仍在；本段按动作毁核心和王冠，旧女王活着倒侧台，契印留下一段再折。'
    if f['id']=='CIN-17R' and i==2:
        state='仅拒绝线。本段开始赤月之心与旧王冠已经毁，旧女王无冠倒侧台仍存活；不重生冠或核心。这里只处理绯月尚有残光的契印晶核，之后不恢复断柄。'
    refs=references(f)
    reftext=[]
    for r in refs:
        description=CHAR[r['actor']][2]
        if f['id']=='CIN-07' and r['actor']=='Y':
            description+=' 本片鸦羽拿的是借来的绯月赤晶剑，自己的长刀在侧边被控制，不再同时持于手中；借剑不改变她的身份。'
        reftext.append(f'<Picture {r["slot"]}>：{r["name"]}，人物外形参考。{description}')
    visible='、'.join(CHAR[k][0] for k in s['visible']) if s['visible'] else '不出现参考主角，仅场景与无特写普通居民'
    scope=('前 39 帧保留上一段末尾实际出现者，后面新内容才按本段时序出镜。' if incoming else '')
    scope+=f'本段新内容涉及：{visible}；仅按分镜在对应地点出现，不把所有参考人物硬放在同一镜。'
    if f['id']=='CIN-03':scope+=' 现时只有绯月、雪璃、鸦羽；女王与医师只在旧记录中，严禁五人同屋。'
    if f['id']=='CIN-14':scope+=' 鸦羽整片不出现，不能提前三人汇合。'
    location=LOCATIONS[f['location']]
    if f['location']=='ambush':
        detail=('备路具体结构本段不展示，画幅不扫到放梯处。' if shared else
                '本版预布侧梯存在并可通行。' if f['id']=='CIN-06A' else '本版没有侧梯，不能生成可直接跨越的备路。')
        location=location.replace('A 有预布侧梯，B 没有；',detail)
    text=(f'{STYLE}\n\n'+'\n'.join(reftext)+f'\n\nsummary: {title}，本次完整生成 {length/FPS:.6f} 秒。'
          f'\nenvironment: {location}\ncontinuity: {state}'
          '\nretention_analysis: 保留人物身份与画风，不保留三视图排版、白底或立绘原姿势。'
          f'{scope} 伤势、王冠、断裂等状态在动作发生后才改变，不把片尾状态提前画到片头。\n'
          'detailed_description: ')
    if incoming:
        previous=f['segments'][i-1]['tail']
        text+=(f'[Shot 1] 局部 00:00.000—00:01.625 是上一段最后 39 帧的真实连续上下文：{previous}'
               '保留实际末尾人物位置、相机路径、动作速度、光色和声音，不重新演一遍上一段，也不静止复制同一末帧。'
               '新的地点与动作不能提前侵入这 39 帧。\n'
               f'[Shot 2] 从局部 00:01.625 起进入本段新内容，到 {length/FPS:.6f} 秒结束；需要切镜的地方按下面明确切，不新增其他蒙太奇：\n')
    else:
        text+=(f'[Shot 1] 局部 00:00.000—{length/FPS:.6f} 秒，整段一次生成，没有前段重复区。'
               '下面只描述同一次生成中的画面变化和内部切镜，不是多个生成任务：\n')
    content_frames=w['new_frames'];total=s['budget'];beats=s['beats']
    # End-align surplus stays in the last static beat, so cropping final padding
    # leaves a real one-second stable game transition.
    lengths=[]
    if i==len(f['segments'])-1 and beats[-1][0]==1:
        hold=FPS+w['film_tail_trim_frames'];action_frames=content_frames-hold
        elapsed=0;previous=0
        for span,_ in beats[:-1]:
            elapsed+=span;end=round(elapsed/(total-1)*action_frames)
            lengths.append(end-previous);previous=end
        lengths.append(hold)
    else:
        elapsed=0;previous=0
        for span,_ in beats:
            elapsed+=span;end=round(elapsed/total*content_frames)
            lengths.append(end-previous);previous=end
    assert sum(lengths)==content_frames and min(lengths)>0
    cursor=incoming
    for n,((_,action),count) in enumerate(zip(beats,lengths),1):
        end=cursor+count
        text+=f'{cursor/FPS:06.3f}—{end/FPS:06.3f} 秒：{action}\n'
        cursor=end
    assert cursor==length
    text+=f'本段最后状态：{s["tail"]}\n'
    if i==len(f['segments'])-1:text+='片尾相机稳定，不自动淡黑；后期接回游戏，不在生成中加字幕或 UI。\n'
    sound=SOUNDS[f['location']]
    if f['id']=='CIN-18A' and i==0:sound='红水退渠、净水泵重启、清水到桶、港口船声，普通生活恢复，不生成欢呼台词。'
    if incoming:sound='前 1.625 秒沿用上一段实际末尾声音，重复区结束后才换本段空间声。'+sound
    text+=f'overall_soundscape: {sound}\nnon_diegetic_music: 无，音乐与正式对白后期独立混音。\n'
    return text


def loop_prompt(title,motion):
    return (f'<Picture 1> 是“{title}”完整静帧，唯一画面、人物与构图参考。生成一次 124 帧、24 fps、5.166667 秒的固定镜头轻动画，不拆段、不加前片重复区。'
            '保留原手绘画风、构图、人数、面孔、表情、服装、光色、物件数量与手的位置。\n'
            f'detailed_description: {motion} 所有变化幅度很小，眨眼错开。摄影机不推拉、不平移、不切镜；图中可调查的纸、道具与角色手指位置固定。'
            '周期结束尽量回到与开头相同的姿势、亮度、发梢方向，首尾自然衔接；不新增剧情动作、不改写文字。'
            '\noverall_soundscape: 无声。游戏环境与音乐继续播放，不每次循环重复音效。'
            '\n画面没有字幕、水印或新增人物。首尾仍需剪辑核对，不能靠一句循环提示词保证完美无缝。\n')


INTRO='''# 《赤月遗书》最新 CG 动画生成提示词

2026-10-16 · 对应详细演出脚本的 24 个过场版本、答应／拒绝双结局。**小于 20 秒整片只生成一次；恰好 20 秒也保留一次。超过 20 秒通常拆 2 段，40／45 秒拆 3 段。**内部有切镜不等于拆成多个生成任务。

## 怎么用你的导演台

1. 本次只交提示词，不启动生成，不修改原工作流。原文件是带歌手 MV 图片和歌曲的示例，先清旧素材、音频绑定、末段选区，另存一份再使用。
2. 每支 CIN 单独一份时间轴。按下方参考图顺序上传并绑定；`<Picture 1>` 等仅指该支的顺序。三视图锁一个人的外形，不是让画面生成三个人。只复制 TXT 正文到提示词框，参数按表填，不把制作备注也当画面文字。
3. **单段片**：只留一个生成段，起帧为 0，重复帧为 0，长度按表设置。单次提示词内可有两三次明确切镜，无需为每个切镜新建段。
4. **长片**：后段起帧＝前段终帧−39。每段生成秒数已包含前 39 帧＝1.625 秒接续；新动作在局部 1.625 秒后才开始。必须保留实际末尾上下文，不重做上一段动作。
5. 插件的 Merged Frames 已丢弃后段重复开头，**合并成片不要再剪一次 1.625 秒**。只有自行拼接各段原始视频时，才裁后段头部的 39 帧。
6. 本机源码要求生成长度为 `5＋17×n` 帧，24 fps。因此 18 秒片用 447 帧＝18.625 秒一次生成。表中的“裁尾余量”仅来自合法帧长对齐，与重复帧无关；已放在稳定片尾，合并后一次裁掉即可恢复原剪辑预算。
7. 原工作流是 960×544、24 fps，二次放大不等于原生 4K。先审人物、握持与动作，再制作高清母版；需要 3840×2160 交付时后期按比例放大／裁边，勿拉伸脸。提示词写 4K 不会替代节点设置。
8. 本版默认只有环境与动作音。对白和信件字按剧本后配，必要口型另做；若输出夹入人声或配乐，静音该轨重做声音。所有生成状态仍需审片，不能把文本约束当作成功保证。

## 两个结局不能混

- 共通 `CIN-16C` 只断强制节点：核心、王冠、契印都完整，女王活着，绯月未戴冠。
- 答应线 `17A→18A→19A`：自愿移交、城市复光、灯下三人；同一顶冠从姐姐移给妹妹，源头保留，姐姐耗尽死亡。
- 拒绝线 `17R→18R→19R`：三人破心、绳索救姐姐、废墟黎明；绯月无冠，断柄不恢复，姐姐获救但病伤不消失。
- 旧同号 `CIN-17A` 曾是救援片，本版是自愿移交；旧 21 版本／83 镜包不能直接混用。本包按当前 24 版本重新写。
- `CIN-06A` 已准备、`06B` 未准备。两版第一生成段可共用；后段才表现是否有侧梯。`CIN-14` 只有雪璃接入，鸦羽仍查工区。

## 文件

每片一个文件夹：`整段.txt` 表示一次生成；`01.txt`、`02.txt` 等为长片生成段；`README.txt` 有参考图与参数。`timeline.csv` 是实际生成窗口（终帧不含），`manifest.json` 是整理数据，**不是已验证可直接导入的导演台 preset**。

`cg-loops/` 另放 19 张现有 CG 与 7 张待制 CG 的轻动画提示词，每张均一次生成。待制构图必须先有静帧再把它当 `<Picture 1>` 使用，本包没有生成新图片或视频。

## 24 支过场总览

| ID | 片名 | 剪辑预算 | 生成次数 | 各段生成秒数 | 合并后裁尾余量 |
|---|---|---:|---:|---|---:|
'''


def main():
    screenplay_path=ROOT/'art/scarlet-screenplay/screenplay.json'
    screenplay=json.loads(screenplay_path.read_text(encoding='utf-8'))
    source=screenplay['films']
    assert len(PLANS)==24 and {f['id'] for f in PLANS}==set(source)
    workflow_bytes=WORKFLOW.read_bytes()
    wf=json.loads(workflow_bytes.decode('utf-8-sig'))
    planner=next(n for n in wf['nodes'] if n['type']=='MiniMaxH3TimelinePlanner')
    timeline=json.loads(planner['widgets_values'][3])
    assert timeline['fps']==FPS
    original_segments=timeline['segmentConfig']['segments']
    assert all(original_segments[i-1]['endFrame']-s['startFrame']==39 for i,s in enumerate(original_segments) if i)
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').write_text('',encoding='utf-8')
    manifest=dict(version=1,date='2026-10-16',basis='latest-screenplay-24-films',fps=FPS,overlapFrames=OVERLAP,
                  short_rule='budget <= 20 seconds: exactly one generation',films=[],loops=[],
                  screenplay_sha256=hashlib.sha256(screenplay_path.read_bytes()).hexdigest(),
                  workflow_sha256=hashlib.sha256(workflow_bytes).hexdigest(),importable_preset=False)
    rows=[];overview=INTRO;details='';shared_prompts=[]
    for f in PLANS:
        f['title'],budget,status=source[f['id']]
        assert budget==sum(s['budget'] for s in f['segments'])
        assert budget>20 or len(f['segments'])==1,f['id']
        assert len(f['segments'])<=3
        directory=OUT/f['id'];directory.mkdir(exist_ok=True)
        ws=windows_for(f);refs=references(f)
        for r in refs:assert (ROOT/r['path']).is_file(),r
        merged=ws[-1]['endFrameExclusive'];trim=merged-budget*FPS
        overview+=f'| {f["id"]} | {f["title"]} | {budget} 秒 | {len(ws)} | '+ ' / '.join(f'{w["generation_seconds"]:.6f}' for w in ws)+f' | {trim} 帧／{trim/FPS:.6f} 秒 |\n'
        header=(f'{f["id"]} {f["title"]}\n剪辑预算 {budget} 秒；生成 {len(ws)} 次。合并 {merged} 帧，最终裁尾 {trim} 帧至 {budget*FPS} 帧。\n'
                f'连续性：{f["state"]}\n片尾：{f["landing"]}\n')
        details+=f'\n## {f["id"]} {f["title"]}\n\n**{budget} 秒，{len(ws)} 次生成。**\n\n连续性：{f["state"]}\n\n片尾落点：{f["landing"]}\n\n参考图上传顺序：\n\n'
        for r in refs:
            header+=f'<Picture {r["slot"]}>：{r["name"]} → {r["path"]}\n'
            details+=f'- `<Picture {r["slot"]}>`：{r["name"]}，`{r["path"]}`。\n'
        if f['note']:
            header+='制作备注：'+f['note']+'\n'
            details+='\n制作备注：'+f['note']+'\n'
        record={k:v for k,v in f.items() if k not in ('segments','keys')}
        record.update(budget=budget,references=refs,merged_frames=merged,trim_tail_frames=trim,segments=[])
        for i,w in enumerate(ws):
            prompt=prompt_for(f,i,w)
            if f['shared'] and i==0:shared_prompts.append(prompt)
            name='整段.txt' if len(ws)==1 else f'{i+1:02d}.txt'
            target=directory/name;target.write_text(prompt,encoding='utf-8')
            entry=dict(**w,prompt_file=target.relative_to(ROOT).as_posix(),prompt=prompt)
            record['segments'].append(entry)
            header+=(f'{name}：[{w["startFrame"]},{w["endFrameExclusive"]})，生成 {w["lengthFrames"]} 帧／{w["generation_seconds"]:.6f} 秒；'
                     f'接续 {w["overlapFrames"]} 帧，净新增 {w["new_seconds"]:.6f} 秒。\n')
            details+=f'\n### {"整段一次生成" if len(ws)==1 else "生成段 "+str(i+1)}\n\n'
            details+=(f'参数：`[{w["startFrame"]},{w["endFrameExclusive"]})`，{w["lengthFrames"]} 帧，**{w["generation_seconds"]:.6f} 秒**；'
                      f'前段接续 {w["overlapFrames"]} 帧。\n\n```text\n{prompt}```\n')
            rows.append([f['id'],f['title'],budget,len(ws),i+1,w['startFrame'],w['endFrameExclusive'],w['lengthFrames'],
                         w['overlapFrames'],f'{w["generation_seconds"]:.6f}',f'{w["new_seconds"]:.6f}',trim if i==len(ws)-1 else 0,entry['prompt_file']])
        details+=f'\n合并器已去重；全片合并后仅裁尾 **{trim} 帧**（{trim/FPS:.6f} 秒对齐余量），保留 {budget} 秒。这不是再剪接续帧。\n'
        (directory/'README.txt').write_text(header,encoding='utf-8')
        manifest['films'].append(record)
    assert len(shared_prompts)==2 and shared_prompts[0]==shared_prompts[1]
    (OUT/'共用-山门伏击前段.txt').write_text(shared_prompts[0],encoding='utf-8')
    loops_section='\n## 平面 CG 的轻动画（全部一次生成）\n\n先上传本张完整静帧作为唯一 `<Picture 1>`，124 帧／5.166667 秒；无跨片重复区。检查首尾后再修衔接或重定时，不盲裁掉周期尾。新增 7 张必须先制作静帧，本段仅预写动效。\n'
    loopdir=OUT/'cg-loops';loopdir.mkdir(exist_ok=True)
    older=json.loads((ROOT/'art/scarlet-video-prompts/manifest.json').read_text(encoding='utf-8'))
    oldloops={x['id'].upper():x for x in older['loops']}
    for cid,path in sorted(screenplay['existing_cg'].items()):
        old=oldloops.get(cid.upper())
        assert old,(cid,oldloops.keys())
        motion=old['prompt'].split('detailed_description: ',1)[1].split(' 所有动作幅度',1)[0]
        prompt=loop_prompt(old['title'],motion)
        file=loopdir/(cid.lower()+'.txt');file.write_text(prompt,encoding='utf-8')
        item=dict(id=cid,title=old['title'],status='static-image-exists',reference=path,
                  frames=124,generation_seconds=124/FPS,prompt_file=file.relative_to(ROOT).as_posix(),prompt=prompt)
        manifest['loops'].append(item)
        loops_section+=f'\n### {cid} {old["title"]}\n\n已有静帧：`{path}`。\n\n```text\n{prompt}```\n'
    reserved_motion={
     'CG-N01':'等水的人仅微呼吸、错开眨眼，街灯保持原静帧已有明暗状态，水纹小幅往复；不把停灯画面逐渐变成恢复供能的剧情片。',
     'CG-N02':'档案照片、地图、时间条与手绝对固定，只有桌边光线极轻呼吸、少量微尘；照片里的人不突然活过来行动。',
     'CG-N03':'母亲抓住绯月手的位置固定，两人微呼吸和极小眨眼，孩子留原位；不松手、跪拜或自动替绯月答应。',
     'CG-N04':'三本名册、标记与手位置固定，灯光微弱呼吸；字迹不重写，待查不会自动变已接。',
     'CG-A01':'姐妹与唯一王冠维持原静帧位置，仅发梢、呼吸和眼神微动；不自动完成移交或生成第二顶冠。',
     'CG-A02':'第一道晶纹形状固定，不沿全身扩散，雪璃包布的手停原位，绯月微呼吸，脸保持本人。',
     'CG-A03':'灯下三人微呼吸与错开眨眼，窗外灯真实亮着，三票和信固定；不新增已逝女王或拒绝线断柄。',
    }
    for cid,(title,reason) in screenplay['reserved_cg'].items():
        prompt=loop_prompt(title,reserved_motion[cid])
        file=loopdir/(cid.lower()+'-待静帧.txt');file.write_text(prompt,encoding='utf-8')
        manifest['loops'].append(dict(id=cid,title=title,status='static-image-not-produced',reference=None,reason=reason,
                                     frames=124,generation_seconds=124/FPS,prompt_file=file.relative_to(ROOT).as_posix(),prompt=prompt))
        loops_section+=f'\n### {cid} {title}｜静帧待制\n\n先制作本张画面，再把成图上传为 `<Picture 1>`；当前没有可填的现成文件路径。\n\n```text\n{prompt}```\n'
    DOC.write_text(overview+details+loops_section,encoding='utf-8')
    (OUT/'README.md').write_text(overview+'\n完整逐片正文：docs/rpg/SCARLET-H3-CG-PROMPTS.md。\n',encoding='utf-8')
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    with (OUT/'timeline.csv').open('w',encoding='utf-8-sig',newline='') as h:
        writer=csv.writer(h);writer.writerow(['film','title','editSeconds','generationCount','segment','startFrame','endFrameExclusive',
                                              'generatedFrames','overlapFrames','generateSeconds','newSeconds','finalTailTrimFrames','promptFile'])
        writer.writerows(rows)
    short=[f for f in manifest['films'] if f['budget']<20]
    assert len(short)==8 and all(len(f['segments'])==1 and f['segments'][0]['overlapFrames']==0 for f in short)
    assert all(len(f['segments'])==1 for f in manifest['films'] if f['budget']==20)
    assert all((e['lengthFrames']-5)%17==0 for f in manifest['films'] for e in f['segments'])
    assert len(manifest['loops'])==26
    assert hashlib.sha256(WORKFLOW.read_bytes()).hexdigest()==manifest['workflow_sha256']
    report=dict(films=24,short_films_under_20=len(short),single_generation_films=sum(len(f['segments'])==1 for f in manifest['films']),
                total_film_generations=len(rows),unique_film_generations=len(rows)-1,shared_ambush_first_segment=True,
                existing_static_loops=19,reserved_static_loops=7,all_short_films_single=True,overlapFrames=39,
                aligned_lengths=True,original_workflow_unchanged=True,generated_media=False)
    (OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    archive=ROOT/'output/Scarlet-H3-CG-Prompts.zip'
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED) as z:
        z.write(DOC,'Scarlet-H3-CG/完整动画提示词.md')
        for path in sorted(OUT.rglob('*')):
            if path.is_file() and not path.name.startswith('.'):
                z.write(path,'Scarlet-H3-CG/'+path.relative_to(OUT).as_posix())
    with zipfile.ZipFile(archive) as z:assert z.testzip() is None
    print(json.dumps(report,ensure_ascii=False))


if __name__=='__main__':main()

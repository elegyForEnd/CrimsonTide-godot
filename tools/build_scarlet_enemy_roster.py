"""Reproducible enemy design, encounter composition and readable attack timings."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]

def strike(shape, radius, delay, anchor='target', **extra):
    return dict(shape=shape, radius=radius, delay=delay, anchor=anchor, **extra)

def skill(name, hint, *strikes, recovery=.8, element='physical'):
    return dict(name=name, hint=hint, strikes=list(strikes), recovery=recovery, element=element)

def build():
    minions = {}
    def mob(key, name, role, hp, speed, distance, cooldown, height, color, moves, lore, counter, **extra):
        minions[key] = dict(id=key, name=name, role=role, hp=hp, speed=speed, distance=distance,
                            cooldown=cooldown, height=height, color=color, skills=moves,
                            lore=lore, counter=counter, **extra)
    mob('tide_hound','赤晶猎犬','侧翼扑击',.78,145,185,2.7,86,'c56b7e',[
        skill('低身扑咬','侧移离开窄长扑击线',strike('line',110,.85,'forward',reach=225),recovery=1.0)],
        '下层水道的流浪犬被晶砂侵染，仍会回避高处。','看到压低前肢后横向闪避，扑空时反击。',flank=True),
    mob('crystal_husk','淤晶役骸','近身重击',1.38,68,200,3.3,143,'b46c78',[
        skill('沉臂砸击','绕到背后或退出扇区',strike('cone',270,1.2,'self'),recovery=1.15)],
        '被赤潮结晶卡死的旧役用机，不是仍可救援的病人。','起手慢、转身慢；蓄力固定朝向后绕背。'),
    mob('royal_pikeman','封印枪卫','正面防守',1.18,88,245,2.8,151,'c4aa7c',[
        skill('定步突刺','向枪锋两侧移动',strike('line',115,1.0,'forward',reach=245),recovery=.95),
        skill('横枪驱退','退出近身扇区',strike('cone',250,1.1,'self'),recovery=.9)],
        '奉命封住转运与王庭通路的正规军，击退后失去战斗能力。','正面盾姿减伤，绕侧背攻击或趁出手破绽攻击。',guard=.35),
    mob('royal_arbalist','王庭弩手','远程狙击',.82,92,600,3.2,134,'c6b88b',[
        skill('校准弩矢','瞄线固定后横移，靠掩体截断',strike('line',80,1.25,'shot',reach=740),recovery=1.0)],
        '使用王庭制式弩机，为封锁队提供远程火力。','接近后迫使其后撤，直线瞄准会被实体遮挡。',retreat=True),
    mob('archive_scribe','封卷书记员','区域封锁',.85,72,570,3.6,148,'bead84',[
        skill('封卷落印','离开脚下延迟印区',strike('circle',160,1.55),recovery=1.0),
        skill('双页划界','两道落印之间留有空隙',strike('circle',135,1.6,offset=[-185,0]),strike('circle',135,1.95,offset=[185,0]),recovery=1.0)],
        '公共档案庭的封存术士，把行政封条当作战斗禁区。','优先接近打断；落印只锁定起手时的位置。',retreat=True),
    mob('crystal_stalker','霜脊潜猎兽','快速突进',.96,152,230,2.9,107,'b2bae0',[
        skill('折脊猛扑','等伏身后朝侧面闪开',strike('line',140,.95,'forward',reach=290),recovery=1.1),
        skill('晶脊震落','离开兽身周围',strike('circle',230,1.25,'self'),recovery=.95)],
        '废矿的巡兽失去饲养者，矿晶沿旧追踪颈环生长。','扑击前不能追踪转向，扑空后的恢复时间较长。',flank=True),
    mob('suture_puppet','缝索手术偶','牵制与延迟斩',1.05,85,350,3.1,157,'c4a0a5',[
        skill('牵索剪切','绕开针索的窄线',strike('line',130,1.15,'shot',reach=450),recovery=.95),
        skill('胸舱排气','不要停在偶身旁',strike('ring',300,1.4,'self',inner=135),recovery=1.0)],
        '示范厅的机械器具由瑟芮远程牵索，停止后不会伤害病房。','贴近圆环内侧或退到外圈，击中后可打断起手。'),
    mob('anchor_raider','黑帆钩斧兵','中距离逼位',1.12,105,310,2.9,148,'b6ad8e',[
        skill('抛钩封路','向链钩侧面躲开',strike('line',150,1.1,'forward',reach=345),recovery=1.05),
        skill('回身扫斧','退出钩斧扇面',strike('cone',290,1.1,'self'),recovery=.9)],
        '莫罗留下的登船队负责控制舷梯与牵引链。','抛钩时侧移，然后接近其长收招空档。'),

    bosses = {}
    def boss(key, height, color, arena, identity, phases):
        bosses[key] = dict(id=key,height=height,color=color,arena=arena,identity=identity,phases=phases)
    boss('inquisitor',210,'d49c82','1:6 · 修院转运厅','赫缄用交接条款拖住病人，弩台与封锁链是其权力的实体。',[
        [skill('封门锁链','横移离开锁链落点',strike('line',190,1.25,'shot',reach=620)),
         skill('押印处决','离开双重落印',strike('circle',210,1.5),strike('circle',155,1.9,offset=[260,0]))],
        [skill('破戒追斩','绕开正面，等剑落后反击',strike('cone',370,1.1,'self'),recovery=1.1),
         skill('交叉缉拿','两条锁链按先后生效',strike('line',140,1.35,'shot',reach=650,rotation=-.38),strike('line',140,1.9,'shot',reach=650,rotation=.38),recovery=1.15)]])
    boss('judge',218,'d2bd88','2:6 · 公共档案庭','白面法官用三庭隔断分割证人与原件，解除隔断后亲自执剑。',[
        [skill('三庭宣判','印区逐次落下，保留另一侧走道',strike('rect',180,1.4,'arena',at=[420,860],reach=340),strike('rect',180,2.0,'arena',at=[1380,860],reach=340)),
         skill('封缄令','离开脚下落印',strike('circle',230,1.55))],
        [skill('亲持刑剑','向剑锋侧面移动',strike('line',160,1.05,'forward',reach=420),recovery=1.0),
         skill('覆卷追判','先退出印区，再避开刑剑',strike('circle',195,1.3),strike('cone',370,1.95,'self'),recovery=1.15)]])
    boss('vein',212,'b7c1d0','3:6 · 山路旧门','维恩用旧剑路押送绯月；重盾阶段应把他引到断柱再反制。',[
        [skill('旧式起手','不要从剑侧硬拼',strike('cone',350,1.05,'self'),recovery=.9),
         skill('踏前直刺','离开直线剑路',strike('line',135,1.15,'forward',reach=415),recovery=1.1)],
        [skill('重盾压阵','引向断柱，在盾击后使用断柱',strike('line',230,1.45,'forward',reach=365),recovery=1.3),
         skill('反身挑剑','先退出近圈，再绕过剑尖',strike('ring',350,1.2,'self',inner=120),strike('line',130,1.95,'forward',reach=400),recovery=1.2)]])
    boss('surgeon',224,'d3a2b3','4:6 · 示范厅','瑟芮操纵针索与手术偶，只关闭示范厅的局部阀门，不能切断病房保障。',[
        [skill('针索定位','瞄线固定后走开',strike('line',155,1.35,'shot',reach=680)),
         skill('局部麻醉','两片麻醉区依次落下',strike('circle',225,1.75,offset=[-240,0]),strike('circle',225,2.1,offset=[240,0]))],
        [skill('缝合十字','两根针索之间留出躲避时间',strike('line',150,1.4,'shot',reach=670,rotation=-.65),strike('line',150,2.0,'shot',reach=670,rotation=.65),recovery=1.2),
         skill('胸舱排气','贴内圈或退到外侧',strike('ring',440,1.6,'self',inner=190),recovery=1.1)]])
    boss('admiral',236,'b2c9bf','5:6 · 黑帆旗舰','莫罗以重锚与舰舵控制船只，第二阶段锁住舰舵才能阻止断链离港。',[
        [skill('重锚抛投','横向闪过锚链，勿沿链后退',strike('line',215,1.45,'shot',reach=740),recovery=1.15),
         skill('回收链环','进入内圈或撤到锚链外',strike('ring',430,1.65,'self',inner=175),recovery=1.15)],
        [skill('断链摇舷','轮流越过甲板压区',strike('rect',170,1.65,'arena',at=[500,850],reach=420),strike('rect',170,2.25,'arena',at=[1300,850],reach=420),recovery=1.25),
         skill('拒港重斩','远离锚头，再避开扫链',strike('circle',250,1.5),strike('cone',410,2.2,'self'),recovery=1.35)]])
    boss('queen',260,'ef9eb5','6:6 · 王座厅','女王的王剑与六片晶翼表现控制和压制；回答之前始终保留赤月之心、王冠与契印。',[
        [skill('王剑裁线','侧移让开王剑指向',strike('line',170,1.25,'forward',reach=520),recovery=.9),
         skill('止步','退出女王正面的扇区',strike('cone',420,1.35,'self'),recovery=1.0)],
        [skill('六翼封庭','晶翼划线有先后，趁间隔解除翼根护晶',strike('line',150,1.4,'shot',reach=680,rotation=-.6),strike('line',150,1.95,'shot',reach=680),strike('line',150,2.5,'shot',reach=680,rotation=.6),recovery=1.25),
         skill('王庭环界','近圈是空隙，优先打开侧廊',strike('ring',470,1.7,'self',inner=210),recovery=1.1)],
        [skill('认证回流','只解除外侧护架，保留核心',strike('circle',220,1.9),recovery=1.2),
         skill('护架泄压','固定落印之间有安全间隙',strike('circle',190,1.8,offset=[-280,0]),strike('circle',190,2.3,offset=[280,0]),recovery=1.3)]])
    boss('beast',222,'adcbdf','3:3 · 废矿支路','霜脊岩兽围绕矿甲与落石作战，支线可以选择不挑战。',[
        [skill('岩甲冲撞','离开宽直线冲撞区',strike('line',230,1.4,'forward',reach=400),recovery=1.2),
         skill('震地','离开兽身周围',strike('circle',340,1.55,'self'),recovery=1.1)],
        [skill('霜脊落石','离开锁定时所在的位置',strike('circle',210,1.5),strike('circle',180,2.0,offset=[260,0]),recovery=1.3),
         skill('碎甲震环','贴近岩兽或退到外侧',strike('ring',430,1.6,'self',inner=165),recovery=1.2)]])
    boss('warden',235,'c1a478','4:4 · 旧牢房','铁棺看守用盾墙与拖链封路，击退后可接近关押处。',[
        [skill('棺盾压路','避开正面盾击',strike('cone',365,1.35,'self'),recovery=1.15),
         skill('锁链拘束','横移离开拖链',strike('line',195,1.45,'shot',reach=650),recovery=1.15)],
        [skill('闭棺扫链','进入链环内侧再反击',strike('ring',410,1.5,'self',inner=155),recovery=1.1),
         skill('断门重击','避开棺盾落点',strike('circle',245,1.6),recovery=1.25)]])

    rosters = {
        '1':['tide_hound','crystal_husk','royal_pikeman','royal_arbalist'],
        '2':['royal_pikeman','royal_arbalist','archive_scribe','archive_scribe'],
        '3':['crystal_stalker','royal_pikeman','crystal_husk','royal_arbalist'],
        '4':['suture_puppet','suture_puppet','archive_scribe','royal_pikeman'],
        '5':['anchor_raider','royal_arbalist','tide_hound','anchor_raider'],
        '6':['royal_pikeman','archive_scribe','suture_puppet','royal_arbalist'],
    }
    data = dict(revision='rpg-enemies-1',atlas_cells=3,minions=minions,bosses=bosses,rosters=rosters,
                art_root='res://assets/story/rpg-enemies-v1/',animation='three-authored-poses-with-procedural-transitions',
                notes='Human enemies are incapacitated; mandatory enemies remain objective encounters. No new film paths.')
    output=ROOT/'resources/scarlet/enemies.json'
    output.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'RPG enemies: {len(minions)} minions, {len(bosses)} bosses, 6 chapter rosters')
    return data

if __name__ == '__main__': build()

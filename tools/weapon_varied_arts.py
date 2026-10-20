"""Authored cast rhythms: time/share/reach/travel/lift/turn/source/kind/count/radius/side."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def step(t,reach,kind='cone',source='finisher',travel=0,lift=0,turn=0,count=1,radius=75,side=0,share=1):
    return [t,share,reach,travel,lift,turn,source,kind,count,radius,side]
S=step
# No common opener/追击/finisher template. Stationary casts deliberately stay still.
DESIGNS={
600:('绯红·回旋返刃','贴身回旋展开，再折返切过前方。',[S(.32,225,'circle','heavy',travel=30,share=.4),S(.27,255,travel=-20,turn=.28,share=.6)]),
601:('鸦喙·一线穿心','短暂压低重心，沿直线高速穿刺。',[S(.48,290,'thrust',travel=115)]),
602:('绢刃·往返','向外甩出绢刃，再反向回卷。',[S(.35,230,turn=-.3,share=.45),S(.38,245,travel=-25,turn=.3,share=.55)]),
603:('荆棘·交绞','两次快速交叉切割，收束成一次重斩。',[S(.16,215,source='normal',turn=-.32,share=.2),S(.15,215,source='heavy',turn=.32,share=.2),S(.38,265,travel=45,share=.6)]),
604:('残月·跃返','跃进斩出月弧，后撤时再留一道残月。',[S(.42,255,travel=75,lift=42,share=.65),S(.25,240,travel=-45,turn=-.25,share=.35)]),
605:('烛影·掠灭','低身冲过目标，留下骤然熄灭的烛刃。',[S(.36,245,travel=100)]),
607:('鸣电·疾影贯穿','压缩雷光后一次突进贯穿。',[S(.42,285,'thrust',travel=120)]),
608:('断誓·破封裁决','窄幅破封刺击后，停顿展开封蜡裁决。',[S(.22,205,'thrust','normal',travel=35,share=.25),S(.49,265,share=.75)]),
609:('镜刃·错身双映','左右错身，各留一道相反的镜刃。',[S(.28,245,side=45,turn=-.28,share=.5),S(.28,245,side=-80,turn=.28,share=.5)]),
610:('钟鸣·四叠震','一次定身起振，三次短促余震沿前方传开。',[S(.42,195,source='heavy',share=.4),S(.13,220,share=.2),S(.13,245,share=.2),S(.16,270,share=.2)]),
611:('黑曜·断面','蓄势后以完整黑曜断面一击劈落。',[S(.64,265,travel=32)]),
612:('破晓·跃光断岳','直接跃起劈落，再由地面反震推出一道金刃。',[S(.52,290,travel=90,lift=62,share=.75),S(.27,270,share=.25)]),
613:('潮涌·推浪','前冲推起一道厚重潮峰。',[S(.62,285,travel=95,lift=20)]),
614:('裂地·崩山','原地蓄力砸地，向前掀起一道土脊。',[S(.72,285,travel=18)]),
615:('熔炉·锤震','重锤落地后接一次短促的炉渣反冲。',[S(.58,275,travel=30,lift=32,share=.8),S(.18,230,'circle','heavy',share=.2)]),
616:('霜骨·冰脊','跃落一击，沿前方顶出冰脊。',[S(.65,280,travel=65,lift=48)]),
617:('雷骸·凌空天罚','上挑腾空，停顿后落下天罚重刃。',[S(.32,220,source='heavy',travel=30,share=.25),S(.56,300,travel=80,lift=70,share=.75)]),
618:('断罪·铡落','长蓄势后跃进，铡刃一次落下。',[S(.78,290,travel=85,lift=52)]),
619:('星陨·震荡','重击星石，随后三次衰减石浪向外展开。',[S(.48,260,travel=30,lift=36,share=.55),S(.17,275,share=.2),S(.17,285,share=.15),S(.21,290,share=.1)]),
620:('城垣·破壁','向前猛推断壁，缓慢而沉重的一击。',[S(.68,285,travel=70)]),
621:('青岚·横扫返挑','长柄横扫后反手上挑。',[S(.34,270,travel=45,turn=-.3,share=.45),S(.34,285,travel=15,lift=28,turn=.18,share=.55)]),
622:('幽镰·环收','环形勾取后后撤收镰。',[S(.37,250,'circle','heavy',share=.4),S(.42,280,travel=-35,share=.6)]),
623:('王刃·裁断','沉稳迈步后以王刃完整劈落。',[S(.7,285,travel=60,lift=24)]),
624:('寒鸦·点射','短促四连点射，最后一发稍作瞄准。',[S(.22,620,'volley',count=1,share=.2),S(.12,620,'volley',count=1,share=.2),S(.12,620,'volley',count=1,share=.2),S(.3,650,'volley',count=1,share=.4)]),
625:('暮羽·追魂','拉满弓弦，一箭贯穿。',[S(.64,700,'volley',count=1)]),
626:('血棘·双簇','两簇交错的荆棘箭，侧移后补射。',[S(.28,600,'volley',count=3,share=.5),S(.32,620,'volley',count=3,side=35,share=.5)]),
627:('焰鸦·爆响','近距单次扇形齐射，后坐力推人后退。',[S(.38,540,'volley',count=5,travel=-35)]),
628:('霜翎·封线','蓄力一次放出五道冰箭封锁前方。',[S(.62,650,'volley',count=5)]),
629:('鸣电·急雨','五次快速电脉冲，节奏紧凑。',[S(.22,620,'volley',share=.2),S(.1,620,'volley',share=.2),S(.1,620,'volley',share=.2),S(.1,620,'volley',share=.2),S(.16,650,'volley',share=.2)]),
630:('黑曜·破甲','长瞄准后射出一发破甲弹。',[S(.72,740,'volley',travel=-18)]),
631:('镜铳·交映','左右错身交替双枪齐射。',[S(.25,600,'volley',count=2,side=35,share=.5),S(.25,600,'volley',count=2,side=-70,share=.5)]),
632:('风翎·掠射','侧滑时一次放出宽幅羽箭。',[S(.4,630,'volley',count=5,side=65)]),
633:('封印·破甲','定点压缩火药，单发贯穿封印。',[S(.66,720,'volley')]),
634:('鸣钟·回响箭','一发引弦，停顿后两箭回响。',[S(.3,620,'volley',share=.4),S(.4,640,'volley',count=2,share=.6)]),
635:('信标·照路','一次发射三枚扇形信号弹。',[S(.48,580,'volley',count=3)]),
636:('星辉·贯流','短暂聚星后，一束细长星辉贯穿前方。',[S(.56,390,'beam')]),
637:('陨火·坠落','在瞄准位置落下一颗陨石，单次爆裂。',[S(.76,345,'burst',radius=78)]),
638:('霜针·骤雨','两阵快慢相间的冰针齐射。',[S(.3,370,'volley',count=3,share=.35),S(.42,400,'volley',count=5,share=.65)]),
639:('雷枝·连闪','同一区域四次短促递减落雷。',[S(.36,350,'burst',radius=62,share=.4),S(.12,350,'burst',radius=65,share=.25),S(.14,350,'burst',radius=68,share=.2),S(.18,350,'burst',radius=72,share=.15)]),
640:('月华·双弦','两道交错月刃，第二道略作停顿。',[S(.33,365,'beam',turn=-.1,share=.45),S(.4,390,'beam',turn=.1,share=.55)]),
641:('棱镜·聚焦','较长聚焦后一次射出窄幅金色光束。',[S(.72,420,'beam')]),
642:('焰羽·展翼','后撤时一次展开七枚火羽。',[S(.5,375,'volley',count=7,travel=-28)]),
643:('虚空·塌缩','小范围起涡，停顿后向内塌缩。',[S(.34,330,'burst',source='heavy',radius=48,share=.2),S(.53,330,'burst',radius=78,share=.8)]),
644:('蚀月·破界','压缩黑色枪芒，一次窄幅穿透。',[S(.78,430,'beam',travel=-15)]),
645:('血契·开庭','定点展开血契，一次裁决爆发。',[S(.64,335,'burst',radius=82)]),
646:('冥庭·引魂','先聚拢魂片，再于原处收束爆裂。',[S(.4,330,'burst',source='heavy',radius=58,share=.3),S(.46,330,'burst',radius=76,share=.7)]),
647:('祈愿·钟鸣','四次渐强钟鸣，范围缓缓展开。',[S(.36,320,'burst',radius=45,share=.1),S(.18,320,'burst',radius=55,share=.2),S(.2,320,'burst',radius=65,share=.3),S(.28,320,'burst',radius=78,share=.4)])
}
def write():
    out={str(k):dict(name=n,desc=d,steps=s) for k,(n,d,s) in DESIGNS.items()}
    (ROOT/'resources/weapon_choreography_v2.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
if __name__=='__main__': write()

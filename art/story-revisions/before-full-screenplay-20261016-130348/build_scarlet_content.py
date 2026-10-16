"""Authoring source for the independent Scarlet ADV campaign. UTF-8, deterministic."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'resources/scarlet'
OUT.mkdir(parents=True, exist_ok=True)
ACTS = [
 ('姐姐不会寄第二封信','边境客舍',['驿路浅河','换马驿站','村医的小屋','雾桥礼拜堂','囚车与修院侧道','边境修院主厅'],'inquisitor'),
 ('替她说谎的人','白垩避难所',['白垩外街','查封工匠铺','旧审判庭地牢','灰页书库','地下炉渠','焚书礼堂'],'judge'),
 ('替你挡刀的人，也会把你交出去','月晶驿站',['月晶坡地','骨鹿猎道','断星矿坑','流星坠谷','观星信站','山口祭场'],'vein'),
 ('你送我剑的时候，已经想过这一天','蔷薇篱营',['行宫荒园','裁衣工坊','旧卧室长廊','庭院地下医室','手术档案室','外科示范厅'],'surgeon'),
 ('我们本来可以回家','月舟码头',['修船坞','沉舟滩','潮盐工事','海防高坡','逆潮水道','黑帆旗舰'],'admiral'),
 ('姐姐，把剑放下','旧水门营地',['水门登陆台','通风侧廊','失乡庭院','彩窗工区','王座前室','赤月王座'],'queen')]
NAMES = {'F':'绯月','X':'雪璃','Y':'鸦羽','Q':'女王','V':'维恩','D':'埃文医师','C':'玛菈船长','M':'莱特','I':'赫缄','J':'白面法官','S':'瑟芮','A':'莫罗','N':'旁白','W':'工匠','H':'驿夫','B':'村医','T':'旅人'}
ACTORS = {'F':'feiyue','X':'xueli','Y':'yayu','Q':'queen','V':'vein','D':'physician','C':'captain','M':'messenger','I':'inquisitor','J':'judge','S':'surgeon','A':'admiral','W':'craftsman','H':'stablemaster','B':'village-doctor'}
scenes = {}
quests = {}
facts = {}

def scene(sid, title, lines, cg='', choices=None):
    pages=[]
    for raw in lines.strip().splitlines():
        if not raw.strip(): continue
        who, _, text = raw.strip().partition('|')
        bits=who.split(':')
        speaker=bits[0]
        pages.append(dict(speaker=NAMES.get(speaker,speaker),actor=ACTORS.get(speaker,''),text=text,
                          expression=bits[1] if len(bits)>1 else 'neutral',pose=bits[2] if len(bits)>2 else 'front',
                          costume='regular',cg=cg))
    scenes[sid]={'id':sid,'title':title,'pages':pages,'choices':choices or []}
    return sid

def choice(text,key,value,reply='',requires=None):
    return dict(text=text,key=key,value=value,reply=reply,requires=requires or [])

def node(kind,label,**kw):
    return dict(kind=kind,label=label,**kw)

def clue(label,key,text):
    facts[key]=dict(title=label,text=text)
    return node('clue',label,fact=key,text=text)

def puzzle(label,question,options,answer,needs=None):
    return node('deduce',label,question=question,options=options,answer=answer,needs=needs or [])

def fight(label,count=3): return node('fight',label,count=count)
def escort(label,count=1): return node('escort',label,count=count)
def mechanism(label,hero=-1,**kw): return node('mechanism',label,hero=hero,duration=2.4,**kw)
def read(label,sid): return node('scene',label,scene=sid)
def movie(cid,label): return node('cinematic',label,cinematic=cid)
def boss(): return node('boss','推门挑战章节首领')

def quest(qid,title,act,stage,nodes,intro='',outro='',kind='main',requires=None):
    quests[qid]=dict(id=qid,title=title,act=act,stage=stage,kind=kind,nodes=nodes,intro=intro,outro=outro,
                    requires=requires or [],description=nodes[0]['label'],reward={'xp':90+act*35,'coins':35+act*10})

scene('opening','序章 · 她寄来一封遗书', '''
Q|绯月。
N|女王停笔，把写过名字的纸折起来，换了一张。窗外的血月落在她摘下手套的手上。晶纹已经长到了指节。
Q|如果信能送到，你应该已经长大了。
N|“带上我送你的剑。到王城来。亲手杀死我。”她封好信。蜡印缺了一角。
N|清晨之前，边境客舍。雨沿着窗缝往下滴。雪璃把一块干布垫在剑鞘下面。
X:smile:turn|你昨天说要换剑鞘。
F:neutral|今天换。
X:smile|上次的今天，是半个月前。
N|有人敲门。信使浑身湿透，却不肯坐下。他先看绯月，再看剑柄上的红晶。
M|她说，你认得这个。
F:surprised|她还活着？
M|活着。但我劝你——
N|他突然把绯月推开。窗碎了。一支箭钉入桌面，另一支击中他的肩。
X:worried|别拔箭。绯月，压住这里！
Y:angry:crossed|窗外还有第二组。离窗远一点。
F:angry|你是谁？
Y:neutral|你姐姐雇来送你进城的人。
X:angry|那外面也是她雇的？
N|鸦羽将弩索上的王庭扣件放在桌上。她没有否认。
''')
scene('letter-first','遗书', '''
F:sad|“我正被王冠吞噬。只有你手里的剑，能让我解脱。”
X:worried|她要你亲手杀她，却不说为什么不能让别人来。
F:worried|也许她只敢求我。
X:neutral|也许。我们要把另一个可能也留下。
''','cg-01a')
scene('letter-orders','同一枚缺角蜡印', '''
M|不要只看信……我从追兵身上拿了这张。剑……他们在找剑。
Y:neutral|“护送绯月殿下及其佩剑。知情人不得留。”两个命令，同一个印。
X:angry|他替她送信，她的人却要他闭嘴。
F:angry|人还活着。现在先让他活下去。
''','cg-01b',[
choice('我背他，你开路。','opening_reply','carry'),
choice('先告诉我，你知道多少。','opening_reply','ask','opening-ask')])
scene('opening-ask','能问的事，不能等的人','''
F:angry|你接信的时候，就知道会有人追来？
Y:worried|我知道王庭会清路。我不知道他们连自己的信使也杀。
X:angry|回答之后帮我抬他。再拖下去，解释就没用了。
Y:neutral|我开路。到了医棚，你要问多久都可以。
''')
quest('R-P01','一封遗书',1,0,[movie('CIN-00','王座上的信'),read('拆开姐姐的信','opening'),read('读遗书','letter-first'),movie('CIN-01','窗外的第二组弩手'),read('核对追缉令','letter-orders')])
scene('messenger-safe','先让人活下来','''
M|我以为把信送到，就算做完了。
X:worried|你已经送到了。接下来的路，先交给我们。
F:sad|等你好一点，我还想问问她写信时是什么样子。
N|医护接过担架。雪璃松手的时候，掌心还在发抖。
''')
quest('R-P02','先过这扇门',1,0,[mechanism('推开后廊柜子',0),fight('解除后廊弩手威胁',2),escort('把信使担架送进医棚'),read('医护接手','messenger-safe')])
scene('conditions','同行的条件','''
F:neutral|现在，人活着了。轮到你解释。
Y:neutral|委托是把你和剑送到王城。报酬包括压制我旧伤的药。
X:worried|如果委托改了呢？比如不许我们跟着。
Y:worried|原来的条款里，确实有“到了驿站不得停留”。
F:angry|那就改我们的条件。和安全有关的事，先说出来。
Y:neutral|好。我不要求你现在相信我。
X:smile|先去查信使换过的马。药、干布，还有你的新剑鞘。
F:smile|剑鞘等回来。
X:angry|这次我记着。
''')
quest('R-P03','同行的条件',1,0,[read('在医棚外与鸦羽谈条件','conditions'),node('depart','确认从南门出发')])

scene('1-1-in','不许回头的路','''
Y:neutral|搜查队沿大路来了。不能把他们引回医棚。
X:worried|浅河那边可以抹去车辙。先看看他们怎么追踪。
F:angry|她叫我过去，又把来过这里的人都当成证据。
''')
scene('1-1-out','另一条车辙','''
N|空车驶向错误的岔口。搜查队跟了上去。
X:neutral|他们会迟一些发现。我们去换马的驿站。
Y:neutral|不是所有人都能像信使那样逃过第二箭。别沿着他们留下的路直走。
''')
quest('R-1-01','不许回头的路',1,1,[clue('检查王庭靴印','bootprints','三组整齐靴印沿车辙追踪，未走浅河。'),mechanism('将废车推向西岔道'),fight('击退浅河拦路者',3),mechanism('用河水抹去回营标记')],'1-1-in','1-1-out')
scene('1-2-in','换马的人','''
H|没见过信使。昨晚雨大，谁也看不清谁。
F:neutral|那你怎么知道我要问昨晚？
H|……马棚随你们看。我还有生意。
''')
scene('1-2-out','被涂掉的一行','''
F:angry|鞍扣在你的棚里，账上涂掉的却是王庭付的钱。你怕的是谁？
H|审判官的人。他们要我说，信使从没在这里停过。
X:worried|他在这里说了什么？
H|礼拜堂。有人在那里等他，带着一枚血晶。别说是我讲的。
''')
quest('R-1-02','信使换过的马',1,2,[read('问驿夫昨夜的客人','1-2-in'),clue('检查鞍扣','saddle','王庭信使专用扣，内侧新沾浅河泥。'),clue('透光看涂改账页','ledger','被涂去的是王庭预付的换马费，日期为昨夜。'),clue('检查马蹄泥','hoof','浅河灰泥和信使靴底一致。'),puzzle('向驿夫出示矛盾','哪两项直接证明他接待过信使？',['鞍扣与换马账','只凭他紧张','街上有巡兵'],0,['saddle','ledger'])],outro='1-2-out')
scene('1-3-in','村屋门内','''
B|我能让你们住一夜。但药箱被扣在巡查棚里，我这里还有三个发热的孩子。
F:neutral|药拿回来，你能替医棚传话吗？
B|可以。信使的伤也需要干净绷带。
''')
scene('soup','一碗热汤','''
N|药箱放回柜子，窗帘也终于拉上。村医端来三碗汤。
F:smile|这碗给她。鸦羽从进门就没坐下。
Y:surprised|我可以自己拿。
X:smile|那先坐。你的手把汤洒了，明天我不会再分一碗。
N|鸦羽将折好的合同放到桌上，推到两人面前。
Y:worried|所有条款。包括我不愿意让你们看见的。
F:neutral|今晚先喝汤。明早，一条一条读。
N|提灯罩上留着白天的细裂痕。雪璃用布把它包好，靠在床边。
''','cg-02')
quest('R-1-03','今晚谁都没见过我们',1,3,[read('敲村医家的门','1-3-in'),node('route','选择取药路线',choices=[choice('冒充补货，核对封条','medicine_route','trade'),choice('绕后卸下门栓','medicine_route','stealth'),choice('击退巡查护卫','medicine_route','fight')]),clue('取固定药箱','medicine','整箱退热药与绷带，没有被王庭用于武器。'),mechanism('将药箱交还村医'),read('坐下喝一碗汤','soup')])
scene('crystal','看见的那一部分','''
N|记录里，女王的左臂已经晶化。一名医师阻止继续注药，她亲手在处置书上盖印。
X:worried|我们看见她批准了一次处置。还不知道之前发生了什么。
F:sad|她没有失去意识。
Y:neutral|也不是每件事都能推给王冠。先把记录带走。
''')
quest('R-1-04','圣物箱里的伤口',1,4,[mechanism('重新固定雾桥桥索'),movie('CIN-02','三人过雾桥'),puzzle('打开圣物箱','箱盖上的三道标记对应什么顺序？',['月纹、灯槽、晶孔','用剑砸碎箱盖','先把血晶拿出来'],0),mechanism('雪璃调整照明角度',1),clue('取唯一血晶','medical_record','影像仅记录一次医疗处置：女王清醒并批准秘密处置。'),movie('CIN-03','血晶中的医疗记录'),read('讨论证据的限度','crystal')])
scene('prison-cart','囚车','''
B|我没说你们住过这里。
I|殿下会来。你说没说，不影响这个结果。
Y:angry|先截车，开笼。人离开以后，我们才进修院。
F:angry|这一次，不让他们等我们打完。
''')
quest('R-1-05','留在这里会害死他们',1,5,[read('在安全岔口观察囚车','prison-cart'),fight('截停囚车护卫',3),mechanism('拆开笼锁'),escort('护村医和被抓者到浅滩',3),clue('取修院封锁路图','abbey_route','修院侧院可通主厅，传令匣由审判官亲自保管。'),movie('CIN-04','三人突破前庭')])
scene('1-boss-in','血烙审判官','''
I|殿下，传令是真的。保护您，也是陛下的命令。
F:angry|那张命令里，没有他们的位置？
I|他们不该知道自己护送的是什么。
X:angry|我们护送的是一个人。
I|那就试着保住她。连同你们自己。
''')
scene('second-letter','第二封信','''
N|村医把新信递过来。封蜡上的缺角还在。
F:sad|“你不该把她们带上。你总是舍不得丢下捡来的东西。”
X:angry:crossed|把纸翻过来做什么？我已经看完了。
F:angry|她不是那个意思。
X:sad|那她是什么意思？她叫得出我的名字。
Y:neutral|白垩城有给王庭做过剑的工匠。信使指着的，是你的剑。
N|绯月没有再替那句话解释。她把信收进了证物袋，和追缉令放在一起。
''','cg-03')
quest('R-1-06','缺角的蜡印',1,6,[read('推开修院主厅门','1-boss-in'),boss(),clue('保住审判官传令匣','full_orders','完整命令：绯月及其剑不得受损，其余知情者不在保护范围。'),read('返回村医安全站领取第二封信','second-letter')])

scene('vein-meet','旧名字','''
V|小月，低头。
N|骑士替她挡开街口的一箭。他的护手上，还是那道旧划痕。
F:surprised|维恩叔叔？
V|先把街上的人带进去。要问的事，关门之后慢慢说。
X:neutral|右边那个人走不动了。我们一起。
''')
scene('vein-shelter','一个可用的住处','''
V|门锁是真的，后巷也通。工匠铺在旧广场，我替你们写张引见。
F:smile|你还记得她送我的剑。
V|她一直在等你。
Y:neutral|门我检查过了。今晚可以休息。
''')
quest('R-2-01','叫我旧名字的人',2,1,[read('街口与维恩相遇','vein-meet'),fight('与维恩清开街口',3),escort('把受伤路人带进避难所',2),mechanism('打开庇护点内门')],outro='vein-shelter')
scene('sword-exam','姐姐送我的东西','''
W|刃是我磨的，柄里的东西不是我做的。底稿被扣在查封铺。
X:neutral|先做外检。我们不要求你现在拆开。
F:worried|要是拆了以后装不回去呢？
W|那更该先看图。把怕的东西放在外面，才能看清它。
''')
scene('sword-exam-out','暂时不拆','''
W|柄中有第二种晶纹。粗拆会连刃一起碎。要问当年的医师。
F:worried|那先不拆。
X:neutral|我记下封口位置。暂时不拆，不能变成永远不查。
F:neutral|……好。
''')
quest('R-2-02','姐姐送我的东西',2,2,[read('请工匠外检赤晶剑','sword-exam'),clue('读查封条','seal_notice','底稿锁在西柜，模具留在东台；柜钥由值班书记保管。'),mechanism('打开底稿西柜'),clue('对照模具和剑纹','sword_plan','剑柄封印与刃同体，不能粗暴拆除；编号下有被裁去的一栏。'),puzzle('核对外部检验','现在能得出的结论是？',['柄中还有未知结构，需要医师原图','姐姐一定想让我继位','毁剑就能结束血潮'],0,['sword_plan'])],outro='sword-exam-out')
scene('physician','医师与旧伤','''
D|你还是来了。
Y:worried|我当时没能把你送出城。
D|你拒绝处决我。是那一天让我活到今天。
N|医师看见她袖口的晶纹，把原本递给自己的药放到她手边。
D|杀死佩冠者，和结束契约，是两件事。原图在灰页书库。
F:surprised|信里没写这个。
D|信不是手术书。我说的也不是全部证据。去取原图，再问我。
''','cg-04')
quest('R-2-03','还活着的证人',2,3,[clue('读取地牢值班表','guard_roster','换班空档在南门，医师关在没有刑具的观察室。'),node('route','选择救人方法',choices=[choice('借换班空档取钥匙','prison_route','stealth'),choice('解除守卫再开门','prison_route','fight')]),mechanism('打开观察室'),escort('带医师到安全医室'),read('请医师查看鸦羽旧伤','physician')])
scene('refuse-sword','不肯交出的剑','''
X:worried|编号在这里。你的剑不是普通武器，是继位器。
F:angry:crossed|你想让我把剑交给你？然后呢？告诉我别去？
X:angry:crossed|我想让我们查完再去。
F:angry|你根本不认识她。
N|雪璃伸出的手停在半空。她慢慢收回去。
X:sad:turn|对。我不认识她。可我认识现在拿着剑的人。
Y:worried|医师还在等我们。先把人送出去。
''','cg-05')
quest('R-2-04','剑上没有写给你的名字',2,4,[clue('取原图正文','diagram_body','正文写明同源母晶器可以作为契约转移通道。'),clue('查装订切口与页码','diagram_page','第十七页被移入解剖册，切口与正文装订吻合。'),puzzle('叠合解剖页','哪一页能和母晶编号接合？',['十七页：剑柄纵剖','四页：镇痛剂量','封底：签收栏'],0,['diagram_body','diagram_page']),read('雪璃提出暂存武器','refuse-sword')])
scene('apology','先把道歉说完','''
N|排水门合上，蒸汽声终于停了。医师在另一端坐下。
F:sad|刚才那句话，我不是因为懂姐姐才说的。
X:neutral|那是因为什么？
F:sad|因为我怕。怕你把图看明白了，我就再也不能带她回来。
X:worried|你怕，不代表我该受那句话。
F:sad|对不起。图给你。接下来，查完再决定。
X:neutral|我收着。不是替你决定，是让我们都有东西可查。
''',choices=[choice('直接说“对不起”。','apology','direct'),choice('承认自己怕再见不到姐姐。','apology','fear')])
quest('R-2-05','谁都别替我决定',2,5,[mechanism('关闭蒸汽总阀'),mechanism('打开排水门'),escort('护医师与维修者到安全支路',2),read('在安全平台向雪璃道歉','apology')])
scene('judge-in','判决之前','''
J|图纸归档，证人静默。这是王庭裁决。
F:angry|她还没说完，你就要烧掉她能说的话。
J|原图证明王冠需要不断换人。这句话足以让整个王庭失序。
Y:angry|那就让它失序。
''')
scene('judge-out','手术书与护手','''
D|模型可以说明契约会转移。但选择持剑者的条件，这本书还没有写。
F:neutral|我们继续查。不会再用一封信代替答案。
V|明天越山。我来带路。
N|入夜，维恩替绯月系紧护手。动作和她记得的一样。
V|你姐姐一直在等你。
F:sad|我也等了她很久。
''')
quest('R-2-06','判决之前',2,6,[read('进入焚书礼堂','judge-in'),boss(),mechanism('打开侧笼救学徒'),clue('保住王冠手术书','surgery_book','契约可经同源母晶转移，持剑继位条件缺页。'),read('回避难房交书并确认休息','judge-out'),movie('CIN-05','夜里的路线信')])

scene('mountain-in','太顺利的路','''
V|新修的路标。沿着走，下午就能翻山。
X:worried|路标下的泥是新的，高处也有弩架压过的痕迹。
F:neutral|叔叔，等一下。我们想先看看。
V|好。我在山门等你们。
''')
quest('R-3-01','一条太顺利的山路',3,1,[read('与维恩确认山路','mountain-in'),node('route','决定是否勘查伏击高点',choices=[choice('勘查、挪捕猎索并布侧梯','ambush_prepared',True),choice('确认尚未勘查，继续跟随','ambush_prepared',False)]),mechanism('检查山门前的退路',optional_preparation=True),node('confirm','推进到下一段山门')])
scene('ambush-prepared','侧梯还在','''
N|山门落下。预先挪开的捕猎索没有套住三人，侧梯仍通着矿道。
X:angry|我带伤者从侧梯走。到矿口接我，别走弩架下面！
Y:neutral|听见了。绯月，我们掩护下面的人。
''')
scene('ambush-unprepared','山门落下','''
N|铁门把队伍切开。雪璃站在另一侧的高台，守卫已经堵住退路。
F:angry|雪璃！往矿口退！
X:angry|先救你身边的人！我会留下路标！
Y:angry|别冲弩线。切索，从下层过去。
''')
quest('R-3-02','为谁设下的陷阱',3,2,[movie('CIN-06','山门伏击'),node('branch_scene','观察两条不同的退路',key='ambush_prepared',yes='ambush-prepared',no='ambush-unprepared'),mechanism('切断绯月侧捕猎索',0),fight('解除下层弩手',3),escort('护近处伤者到矿口',2)])
scene('support','换你扶住她','''
Y:worried|剩下的人……先数清楚。
X:angry|先伸手。别替我数剩下多少人。
N|鸦羽的膝盖突然失去力气。雪璃接住她，把提灯放到地上。
F:worried|药呢？
Y:sad|快没有了。
X:worried|下次在快没有之前说。不是每次都有人刚好站在这里。
Y:sad|……好。
''','cg-06')
quest('R-3-03','别替我数剩下多少人',3,3,[mechanism('重启矿坑升降架'),mechanism('关闭毒雾排气阀'),fight('解除上井看守',3),escort('找齐雪璃与同行伤者，共同上井',3),read('在上井平台照顾鸦羽','support')])
scene('gauntlet','伸过来的旧护手','''
F:angry|这是你的路线信。箭也是你让他们带来的。
V|我没让他们伤你。
X:angry|你说的是她一个人。
V|她姐姐撑不了多久。小月，跟我走。你不用背所有人的命。
F:sad|你什么时候知道的？
V|收到信的时候。我知道她需要下一位。
N|他伸出手。护手上的旧划痕，让绯月想起一条很久以前的路。
F:angry|那不是来带我回家。是来交货。
''','cg-07',[
choice('质问他收到了什么承诺。','vein_reply','question'),choice('明确拒绝：我不跟你走。','vein_reply','refuse'),choice('不再接那只手。','vein_reply','silence')])
quest('R-3-04','他没有走远',3,4,[clue('对照王庭弩箭','arrow_supply','箭簇属于白垩军库，由维恩签领。'),clue('找到发讯副本','route_letter','维恩提供小队路线，绯月及佩剑优先保护，其余二人可处置。'),puzzle('核对路引与信','这是被迫留下的求救信吗？',['不是：他主动提供了同行者处置条件','是：只因他用旧称呼','尚未见过箭就可以断定'],0,['arrow_supply','route_letter']),read('在安全拱道质问维恩','gauntlet')])
scene('tower','信站前','''
V|我还有一次让这件事停下的机会。只要你愿意。
F:angry|你说停下，是让他们只带走我。
Y:angry|左边切信标，右边接旅人。别让他再替谁签字。
''')
quest('R-3-05','你还肯叫我一声叔叔吗',3,5,[read('信站外拒绝交接','tower'),mechanism('切断左侧发讯信标'),fight('解除塔上守卫',3),mechanism('打开侧梯'),escort('带被扣旅人离开信站',2)])
scene('vein-in','旧骑士最后的工作','''
V|你小时候握不稳剑，是我替你扶的。
F:sad|所以我一直相信，你知道什么时候该放手。
V|你们已经没有下一条路。
Y:angry|那就从你站着的地方过。
''')
scene('vein-defeat','不再替你回答','''
V:sad|爵位、庄园。我想过，把你送回去，我也能回到原来的生活。
F:sad|你记得我的名字。也知道我怕什么。你用的全是这些。
X:neutral|守备会带走他。决定交给证据，不交给他下一句话。
N|回到驿站，三人约好明早拆剑。鸦羽将药瓶收进口袋，最后一个离开灯下。
''')
scene('empty-rack','空着的剑架','''
N|半夜，剑架空了。鸦羽的铺位也空了。桌上只压着一张短笺。
Y|“我拿剑去换一个不用你去的办法。别跟来。”
F:angry|又一个人。又是替我决定。
X:worried|先别把这句话当答案。她带着药，走得不快。
N|绯月把纸折好。这次，她没有把它当成保证。
''','cg-08')
quest('R-3-06','旧骑士最后的工作',3,6,[read('主动走进山口祭场','vein-in'),boss(),read('将维恩交给守备后返驿站','vein-defeat'),read('确认休息，检查半夜的剑架','empty-rack')])
scene('interlude-4','同一夜 · 鸦羽视角','''
N|王船甲板。鸦羽将剑放在两人之间，刀没有离手。
Y:angry|剑在这里。让绯月回去。我可以替她留下。
Q|替她？契印取的是她的血。十年前就定好了。
Y:surprised|你送剑的时候，就想过今天？
Q|你带着她最舍不得的东西来。她会追来的。
Y:angry|那我现在把它毁掉。
N|她抬刀。近卫同时收紧锁索。女王取回剑，袖口下一片晶纹骤然裂亮。
Q|回王城。剑和她，交给瑟芮。
N|此刻只有玩家看见这场交易。远在驿站的绯月尚不知道答案。
''')
scene('garden','两个人的路','''
X:worried|药瓶在花架下面。脚印是自己走的，墙内才有拖痕。
F:sad|她没来得及毁剑。
X:neutral|我们还不知道她想做什么。先找到人。
F:neutral|用备用剑。她和我的剑，都要查清楚再带回去。
''')
quest('R-4-01','她走的是王庭的路',4,1,[read('沿药瓶痕迹入荒园','garden'),clue('辨认黑纱与拖痕','garden_traces','鸦羽自行走到王船接应口，返回行宫时有被拖行的痕迹。'),mechanism('移开排水沟栅栏',0),clue('找到工坊通行暗号','workshop_pass','当晚交接暗号写在药物验收单背面。')])
scene('dress','为你备好的新衣','''
N|衣架上的尺寸被改过。最早的日期，在遗书之前很久。
F:sad|我还以为她写信的时候，才终于想起我。
X:worried|她一直在准备。只是不一定在准备重逢。
F:angry|尺寸是谁量的？
N|没有人回答。绯月把验收牌翻到正面，认真记下每一个数字。
''','cg-09')
quest('R-4-02','合身的新衣',4,2,[clue('查礼服尺寸改动','dress_size','量体记录从十年前开始，最近一次修改早于遗书。'),clue('核对契印模型订单','dress_order','加冕衣与同源剑柄模型共同下单，交付对象为绯月。'),puzzle('开启试衣架机关','应该保留什么作为可复核证据？',['原日期、改动尺寸与同批订单','只拍新礼服外观','烧掉礼服免得仪式继续'],0,['dress_size','dress_order']),read('取内宅钥匙前再看一眼衣架','dress')])
scene('bedroom','十年前的房间','''
N|木马、墙边的刻线、没送出去的信。房间被保存得很仔细，连窗边那道磨痕都还在。
F:sad|这里是真的。
X:worried|嗯。
F:sad|那为什么另一件事也是真的？
N|雪璃没有把她拉走。等绯月自己转过身，两人才一起打开礼服箱底的交接格。
X:neutral|地下医室。鸦羽在那里。
''','cg-10')
quest('R-4-03','别人替你选好的房间',4,3,[read('主动推开旧卧室门','bedroom'),clue('查看箱底交接单','detention','鸦羽被收押在庭院地下医室，血契剑另存手术档案柜。'),node('confirm','收好交接单，先去救鸦羽')])
scene('reunion','我不是来替她问罪的','''
Y:sad|我拿剑去换你的自由。她说不可能，契印早已定了你的血。
F:angry|所以你就一个人去？
Y:sad|我以为只要做成，就不用解释。我做错了。
X:neutral|先把所有话说完。我们不再替谁省去最坏的部分。
Y:sad|她等你，是要你接过王冠。我没有换来任何条件。
F:sad|我不是来替她问罪的。下次，先问问我们愿不愿意和你一起。
Y:sad|好。没有下一张只写“别跟来”的纸。
''',choices=[choice('现在回应她。','yayu_reunion','answer'),choice('先听她把全部经过讲完。','yayu_reunion','listen')])
quest('R-4-04','我不是来替她问罪的',4,4,[mechanism('雪璃先稳定鸦羽伤势',1),puzzle('拆刑具联锁','联锁必须怎样拆？',['先稳伤，再卸承重，最后解腕锁','先拉断手腕锁','先切断所有支撑'],0),mechanism('绯月解除承重刑具',0),mechanism('切断警报线'),read('在安全医室听完鸦羽的经过','reunion')])
scene('hilt','礼物里的契印','''
N|剑柄外饰卸下。契印与剑柄母晶连成一体，验收日期停在十年前。
Y:neutral|用它刺穿女王心脏，契约就沿着剑转给持剑的血亲。
X:worried|提前毁印会让剑碎。我们就失去了切开王冠和母晶的东西。
F:neutral|母晶什么时候能碰到？
X:neutral|继位仪式打开王座的时候。她想让你接位，那也是我们唯一能破源的机会。
F:sad|所以先把它保留到最后。不是因为它是礼物。
''','cg-11')
scene('gift-truth','她送我的时候就知道','''
F:sad:turn|她教我握剑的时候，知道。送我出城的时候，也知道。
N|剑放在两人之间。绯月的手没有再护住它。
F:sad|那我该恨哪一部分？
X:sad|我不知道。
N|雪璃坐下来，没有急着给答案。鸦羽守在门边，把刚拿到的步骤摊平。
F:sad|先让我坐一会儿。
X:worried|好。
''','cg-12')
quest('R-4-05','现在把剑拆开',4,5,[mechanism('回收器械柜中的血契剑'),puzzle('按底稿拆外饰','这次操作的边界是什么？',['暴露契印，不破坏同体母晶','把剑柄彻底折断','立刻用它刺向女王'],0,['sword_plan']),clue('核对十年前验收单','contract_truth','血亲持同源剑刺心会继位；母晶仅在继位仪式开放；王冠、母晶、契印须全部毁掉。'),read('用测试片验证转移结构','hilt'),read('陪绯月坐一会儿','gift-truth')])
scene('surgeon-in','请殿下不要损坏自己','''
S|下一位陛下，外饰拆得很漂亮。请把手放在这里。
F:angry|你十年前也这么叫她？
S|当然。术式成功，她才活到了现在。
Y:angry|你把下一具身体，也叫成功。
S|请不要损坏自己。修复会耽误交付。
''')
scene('home-decision','这次先回家','''
N|装卸水道通了。工匠沿着她们打开的门向外走。
F:neutral|不进王城了。我想回边境。
X:worried|你想清楚了？
F:sad|我现在不想再见她。不是今晚。不是拿着这把剑。
Y:neutral|那去码头。药和合同，我都带着，这次先说在前面。
X:smile|好。一起回去。
''')
quest('R-4-06','请殿下不要损坏自己',4,6,[read('走进外科示范厅','surgeon-in'),movie('CIN-08','手术偶启动'),boss(),clue('取解除步骤','release_steps','仪式开启后：稳住晶潮，切王座内扣，再转刃破母晶，最后毁冠及契印。'),mechanism('打开装卸水道'),read('在安全水道决定回家','home-decision')])

scene('captain','先修回家的船','''
C|三张票。回边境，船是有的，转舵杆断了。
F:neutral|我们修。不要王城方向的。
C|你说得很清楚。修好以后先试航，能回来，我才让人上船。
X:smile|这次终于有人先把退路讲完。
''')
scene('tickets','三张船票与果酱','''
N|试航结束。三张船票压住一小碟果酱，海风里仍有冷雨的味道。
F:smile|回去先找一家不漏雨的旅馆。
X:smile|然后换剑鞘。
F:shy|……你还记得。
Y:neutral|我剩四次药。合同已经没用了，但我想留着，免得以后装作没签过。
X:smile|说得好。剩四次的时候说，够我们一起找第五次。
N|这一餐没有人来敲窗。她们把面包吃完，船仍停在岸边。
''','cg-13')
quest('R-5-01','三张回程票',5,1,[read('向船长购买回边境的船票','captain'),clue('取有编号的备用木料','timber','船长保管的耐水木料，尺寸正好适配转舵杆。'),mechanism('修复转舵杆'),mechanism('完成安全试航'),read('坐下吃点东西','tickets')])
scene('seven','船上多了七个人','''
N|修好的船还在。海堤外，另一艘翻倒的船里有人在敲舱板。
C|先系绳！水会涨，但还来得及一段一段救。
F:angry|七个人。我们把人数带回来，不把他们留在这里。
X:neutral|我照舱门。鸦羽断绳，绯月接人。
''')
quest('R-5-02','船上多了七个人',5,2,[node('confirm','去岸边等登船'),movie('CIN-09','越过海堤的红潮'),read('观察侧翻船的呼救位置','seven'),mechanism('先固定救生绳'),escort('救出侧翻船里的七名幸存者',7),mechanism('核对接收名单并安排分批运送')])
scene('fleet','她派船来接你了','''
A|殿下独自登舰。其余人员另行安置。
F:neutral|安置在哪条船？
A|不必向您解释。
Y:angry|押运仓的门从外面锁。民船也扣在这里。
X:neutral|先看清楚，再回答。
''')
scene('fleet-out','拒绝的根据','''
F:angry|我看过押运仓了。你说的安置，是把她们分开关起来。
A|您没有谈条件的余地。
F:angry|那就不谈。先把民船的闸打开。
C|近岸还能停。远海口被封着，先到高坡去。
''')
quest('R-5-03','她派船来接你了',5,3,[movie('CIN-10','封港舰队'),read('主动查看舰队传话','fleet'),clue('调查同行者押运仓','prison_hold','押运仓分隔拘束，标注同行者另行处置；不是自由转乘。'),node('route','选择开民船闸的方法',choices=[choice('绕后夺闸','harbor_route','stealth'),choice('清开闸前守卫','harbor_route','fight')]),mechanism('打开被扣民船的离港闸')],outro='fleet-out')
scene('return-choice','如果什么都不做','''
D|书里写过：承载者衰败，母晶便会外泄。三处潮痕都在涨，和这里吻合。
F:sad|回边境，潮也会到那里。
Y:worried|想回去没有错。现在知道的，比离开行宫时多。
F:neutral|我想回去。也想那里还在。
X:worried|进王城，不能再照她的意思做。
F:neutral|所以，这次我们把自己的计划说完。
''')
quest('R-5-04','如果什么都不做',5,4,[clue('测低岸潮痕','tide_low','低岸潮痕已越昨夜最高线。'),clue('测中堤潮痕','tide_mid','中堤潮痕增长与承载衰败记录吻合。'),clue('测高坡渗晶','tide_high','高坡出现新晶渗，灾难并非只限当前港区。'),escort('护居民上高地',3),fight('守住高地接收点',3),read('对照书中记录决定去向','return-choice')])
scene('plan','三个人的计划','''
F:neutral|剑切开王冠。母晶露出来以后，我转刃。
X:neutral|我稳住晶潮，让你有时间走近。
Y:neutral|我切内扣。你挣不开手时，先叫我，不要再一个人硬撑。
F:worried|她不肯开仪式呢？
X:neutral|那就先撤。这次连计划失败时怎么走，也写在图上。
N|三人将图摊在同一张桌上。没有谁站在灯光以外。
''','cg-14')
quest('R-5-05','这一次先把计划说完',5,5,[read('主动与两人完整讨论反攻','plan'),puzzle('确认三目标与顺序','必须等到什么时候转刃破母晶？',['仪式打开、稳住晶潮并切内扣后','女王见面时直接刺心','先在码头折断契印'],0,['contract_truth','release_steps']),mechanism('勘查缆弩盲区'),mechanism('布置诱饵船'),mechanism('挂好撤离标志')])
scene('admiral-in','让他们先走','''
A|上船容易。海口在我手里。
C|舵杆是我们修的，闸也是我们开的。船不是你说沉就沉的。
Y:angry|先破缆弩，再接他。民船的方向别挡。
F:angry|让他们先走。
''')
scene('sail','船长按约回来了','''
C|人都在近岸。轮到问你们：去哪？
F:neutral|王城。这次，是我们自己去。
X:smile|先约好回来见面的地方。
C|旧水门。我等到看见你们。
Y:smile|三个人。记好这个数。
''')
quest('R-5-06','让他们先走',5,6,[read('确认登舰行动','admiral-in'),mechanism('解除左舷缆弩'),mechanism('解除右舷缆弩'),boss(),mechanism('锁舵并释放最后一批民船'),movie('CIN-11','让船通过'),read('回码头与船长确认航向','sail')])

scene('watergate','约好回来的地方','''
C|这里。我把船系在这根石柱边。
X:neutral|先开水门，让担架也过得去。
F:neutral|这次的退路，先真的走一遍。
Y:smile|然后才去见她。
''')
quest('R-6-01','约好回来的地方',6,1,[read('在登陆台确认接收地点','watergate'),mechanism('清开水门落石'),mechanism('打开旧水门'),mechanism('放下固定绳梯'),escort('用空担架验证回船通道')])
scene('side-passage','不走红毯','''
Y:neutral|医师画的通风井就在这里。
F:neutral|她让我从正门进去。我们先开另一扇门。
X:smile|救下一个人，后来就多了一条能走的路。
''')
quest('R-6-02','不走她铺好的红毯',6,2,[read('核对医师通风井图','side-passage'),clue('找到通风井内锁','vent_lock','内锁以外部验血盘为诱导，侧壁检修扣可直接绕过。'),puzzle('避开验血机关','根据检修图应从哪里进入？',['不接触验血盘，拆侧壁检修扣','把绯月血滴进正门','摧毁医师的图'],0,['vent_lock']),mechanism('关闭侧廊隔断'),mechanism('从内打开回营门')])
scene('palace-route','你可以不用一个人来','''
Q|我只见妹妹。让她一个人走到红毯尽头。
F:angry|她还在替我们排位置。
X:neutral|正门也好，侧路也好，我们先把安排说清楚。
Y:neutral|说吧。这次我们听着。
''',choices=[choice('当面拒绝，三人从正门同行。','palace_approach','front'),choice('先告诉同伴计划，绯月走正门，两人走侧路。','palace_approach','side')])
quest('R-6-03','你可以不用一个人来',6,3,[read('回应女王只见妹妹的口信','palace-route'),node('approach','实施约定的入城方案'),mechanism('在约定安全点确认三人已到')])
scene('under-throne','王座下面是什么','''
X:neutral|外壳还关着。现在攻击，剑只会折在外面。
Y:neutral|内扣留给我。先固定支点，别碰那条连着冠的索。
F:neutral|我看见了。最后动手的人，也得知道前两个人做了什么。
''')
quest('R-6-04','王座下面是什么',6,4,[read('观察封闭母晶外壳','under-throne'),mechanism('拆外围护架'),mechanism('雪璃固定提灯支点',1),mechanism('鸦羽布置内扣切入口',2),mechanism('测试撤离绳与回营路线')])
scene('two-cups','两只杯子','''
N|桌上放着两只杯子。一只朝向女王，另一只留给妹妹。没有第三只。
Q|你长高了。
F:sad|你十年前就准备好那把剑了。
Q|我送过你那么多东西。你只记得这一件？
F:sad|我每件都记得。所以才会来。
Q|那就帮我。我已经替你们撑了十年。
F:angry|你问过我愿不愿意接下一次十年吗？
Q|如果我问，你会让我死？
F:sad|我会找办法。和别人一起。你连这件事都不肯让我做。
Q|你带她们进来，是要她们替你回答？
F:angry|是因为我不用一个人来。
N|侧廊里，提灯的青光亮起来。
''','cg-15')
quest('R-6-05','你真的想让我杀你吗',6,5,[node('final_gate','检查退路并确认进入终局'),read('王座前，面对姐姐','two-cups'),movie('CIN-13','六翼与妹妹')])
scene('queen-phase2','侧廊的光','''
Q:angry|我说过，不许她们靠近！
X:angry|你说的不是规则。
Y:angry|绯月，别把所有剑都接在自己身上！
F:neutral|我知道。现在是三个人。
''')
scene('queen-phase3','继位仪式','''
N|王座外壳打开。女王抓住绯月持剑的手，将刃尖转向自己。
Q|只要一下。之后，你会明白的。
F:angry|我不会用变成你，来证明我爱过你。
X:angry|我稳场。鸦羽，内扣！
Y:angry|绯月，叫我的名字，然后把剑转过去！
''')
scene('finisher','把你的命还给你','''
F:angry|鸦羽！
Y:angry|扣断了。现在！
X:angry|往前走，我在这里！
N|三人的光在破碎彩窗前汇成一线。母晶裂开，王冠坠落。绯月最后折断剑柄里的契印。
F:sad|姐姐。我把你的命还给你。也把我的留下。
''')
quest('R-6-06','不再有下一位女王',6,6,[boss(),node('final_choice','决定如何面对重伤的女王'),movie('CIN-18','走向外墙，观看废墟黎明')])
scene('rescue-choice','王冠碎后','''
N|王座侧台开裂。女王重伤倒在边缘，已无法自己起身。三人打开过的退路仍在。
X:worried|绳索够，医护也在水门。救她，就意味着她要活着面对调查。
Y:neutral|你不需要在这里原谅她。也不需要替别人原谅。
F:sad|我知道。这一次，决定由我说。
''',choices=[choice('固定绳索，把她拉回来；她会受看守并接受调查。','queen_resolution','rescue'),choice('带同伴撤出，让她留在坍塌的王座。','queen_resolution','leave')])
scene('rescue-escape','沿约好的退路','''
N|绳索固定在预留的石柱上。三人把女王拉离侧台，交给外墙医护。守备随担架一起离开。
F:sad|不要把她送回王座。
X:neutral|不会。现在先去看看外墙。
''')
scene('leave-escape','转身离开','''
N|绯月将同伴拉向已经打开的通道。身后的侧台在灰尘中坍塌。
F:sad|走吧。
Y:worried|我们都在。
N|没有新的命令追来。三人沿着亲手做好的退路，走到外墙。
''')
scene('broken-sword','留在水门的剑','''
N|绯月将折断的剑柄留在水门边。雪璃和鸦羽在几步之外等她。
F:sad|我把信带走。剑就留在这里。
X:worried|我们等你。
F:neutral|不用很久。
''','cg-16b')
scene('captain-return','回到等我们的人那里','''
C|三个人。我记着呢。
Y:smile|这回没让你重数。
M|我的信送完了。你们的呢？
F:neutral|还差一封。先让我学着写，不是照她说的写。
''')
scene('hospital','数日后 · 病房里的提问','''
N|女王躺在病床上，没有王冠。门边站着看守，桌上放着尚未完成的问询记录。
Q|你要去哪？
F:neutral|先去边境。后面还没想好。
Q|你不留下？
F:sad|我来，是想把你带回来。不是把自己留在这里。
N|绯月把水杯放近一点，然后起身。没有人替病房里的人说一句得到原谅的话。
''','cg-16a')
scene('leave-epilogue','数日后 · 出发之前','''
N|雨停了一阵。鸦羽把药装进新袋，雪璃缝好最后一处背带。
X:neutral|船长问，今天走吗？
F:sad|走。我想好了。
Y:smile|那我去搬行李。你这次可以只拿自己的。
''')
scene('letter-back','信的背面','''
N|返程船上，绯月将那封遗书翻到背面。纸是空白的。
X:smile|信还留着吗？
F:neutral|留着。背面还能写。
N|鸦羽递来一支笔，没有替她拟好第一句话。
Y:smile|写去哪？
F:smile|先找一家不漏雨的旅馆。
X:joy|然后？
F:smile|然后再想。
''','cg-17')
quest('R-E01','回到等我们的人那里',6,0,[node('ending_cg','在旧水门边停一会儿'),read('向船长报平安','captain-return'),node('epilogue','选择启航，观看后日谈')])

# Optional stories have their own objective and world facts; no ending gates.
scene('s1','修好之后也别扔','''
F:shy|罩子给我。不是要你换提灯。
X:surprised|你居然看见了。
F:smile|箭擦过去的时候，我就在旁边。
N|新玻璃上留下了一道缝。试灯时，光仍然能照到路的另一头。
''')
quest('S01','修好之后也别扔',1,3,[clue('在村医屋边找旧玻璃','lamp_glass','可以修补提灯的旧玻璃片。'),mechanism('给护罩补玻璃'),mechanism('用雪璃试照暗路',1)],outro='s1',kind='side',requires=['R-1-03'])
scene('s2','不属于委托的报酬','''
D|替代药不能治好旧伤，但能让你少依靠王庭的药。
Y:worried|我不想再拿别人换一次剂量。
X:neutral|那就把配方给我们一人一份。
F:smile|报酬记在一起。这个不写进护送合同。
''')
quest('S02','不属于委托的报酬',2,3,[clue('按药箱标签查替代配方','remedy','以灰叶和温盐代替王庭抑晶剂，可稳定但不治愈。'),puzzle('配稳定剂','怎样使用替代剂？',['低剂量试用并记录反应','一次喝完全部','以为旧伤已经治愈'],0),mechanism('医师指导试制稳定剂')],outro='s2',kind='side',requires=['R-2-03'])
scene('s3','有人等你回去','''
T|我以为出了矿坑，就再也不会有人回来。
F:neutral|有人在驿站等你。名字说给我，我替你带到门口。
Y:smile|这回不是清点剩下多少。是知道带谁回去。
''')
quest('S03','山里有人等你回去',3,3,[mechanism('修好矿坑侧路升降架'),node('optional_boss','封住霜脊岩兽的兽道',boss='beast'),escort('接失散旅人回驿站',2)],outro='s3',kind='side',requires=['R-3-03'])
scene('s4','现在穿也不算晚','''
N|包裹里是一双旧手套，针脚比衣柜里的礼服歪一点。
F:sad|她确实想过我会冷。
X:worried|这件事不需要被另一件事擦掉。
F:neutral|也不能拿来擦掉另一件事。
''',choices=[choice('修补后带走。','keepsake','take'),choice('修补后留在房间。','keepsake','stay')])
quest('S04','现在穿也不算晚',4,3,[clue('展开未送信件的礼物清单','gift_list','一双为绯月缝的旧手套，没有寄出。'),mechanism('修补手套针脚'),read('决定如何保存旧礼物','s4')],kind='side',requires=['R-4-03'])
scene('s5','下一次别逞强','''
C|演练合格。绯月，刚才没让你一个人搬整副担架。
F:shy|我以为能搬。
Y:smile|能搬，和该不该一个人搬，是两件事。
X:joy|这句你也记好。
''')
quest('S05','下一次别逞强',5,1,[mechanism('绯月固定安全演练绳',0),mechanism('雪璃照亮模拟舱口',1),mechanism('鸦羽解除演练索结',2),escort('三人把练习担架抬回岸边')],outro='s5',kind='side',requires=['R-5-01'])
scene('s6','被留下的房间','''
D|名字和人都对上了。这次不是只有一本能交上去的名册。
T|她还会回来吗？
F:neutral|王冠已经不是保护谁的理由。你们可以把发生过的事说出来。
''')
quest('S06','被留下的房间',6,2,[clue('核对拘留室门牌','detention_names','医师名册对应三间未疏散拘留室。'),node('optional_boss','解除牢狱看守·铁棺',boss='warden'),mechanism('打开拘留室联锁'),escort('护仍被困者到旧水门',3)],outro='s6',kind='side',requires=['R-6-02'])

cinematics = {
'CIN-00':('王座上的信','女王封好写给妹妹的遗书，缺角蜡印映着血月。'),
'CIN-01':('窗外的第二组弩手','弩箭穿窗，信使推开绯月负伤；鸦羽挡住窗口，雪璃立即止血。信使仍然活着。'),
'CIN-02':('雾桥上的三个人','绯月跑过前段，雪璃举灯护住桥心，鸦羽在后方收住摇晃的桥索。三人抵达完整的平台。'),
'CIN-03':('医疗记录','血晶只回放一段医疗影像：女王的手臂已经晶化，她清醒地批准了秘密处置。'),
'CIN-04':('三人突破','居民已经安全。鸦羽切开弩索，绯月突破前庭，雪璃护盾接住最后一轮箭雨。'),
'CIN-05':('夜里的路线信','维恩独自在灯下写出小队路线，将“其余二人”标为可处置。这是玩家看见的幕间，不是绯月此刻已知的事实。'),
'CIN-06A':('预布退路的伏击','山门落下，但侧梯仍开着。雪璃主动带伤者退向矿坑，并没有被守卫俘虏。'),
'CIN-06B':('未勘查的伏击','山门从队伍之间落下。雪璃被隔在高台，守卫将她逼向矿道，另两人必须从下层救近处伤者。'),
'CIN-07':('交易失败','近卫压住准备毁剑的鸦羽。女王夺剑后晶化发作，返回王城，将剑和俘虏交给瑟芮。'),
'CIN-08':('手术偶启动','瑟芮进入透明胸舱。承重臂抬起，针索扫过示范台，通风阀亮起警戒灯。'),
'CIN-09':('越过海堤的红潮','红潮越过上游海堤，人群奔向高坡。侧翻船中仍有人呼救，主角修好的回程船没有被毁掉。'),
'CIN-10':('封港舰队','黑帆舰队横在海口，缆弩锁住民船。提督只许绯月一人登舰。'),
'CIN-11':('让船通过','舵已锁定，缆弩已毁。最后一批民船穿过断开的封锁，小队等到难民先走。'),
'CIN-12':('主动驶向王城','三人站在返航的船首。这一次她们已经知道风险，也已经约好旧水门的退路。'),
'CIN-13':('六翼与妹妹','六片彩窗刃翼在女王身后展开。绯月站在地面安全标记内，侧廊提灯的光仍远着。'),
'CIN-14':('双剑与侧廊的光','旧剑路交锁。雪璃与鸦羽从侧廊接入，三人重新站到同一片地面。'),
'CIN-15':('继位仪式','女王抓住妹妹的持剑手，主动打开王座母晶。剑还没有刺进心脏，反制的机会终于出现。'),
'CIN-16':('三人奥义与断剑','稳场、断扣、转刃。母晶与王冠同时崩裂，绯月折断契印。契约不再有下一位承受者。'),
'CIN-17A':('绳索救援','三人用预布绳索把女王拉出坍塌侧台，沿已经打开的水道交给医护与看守。'),
'CIN-17B':('离开王座','三人转身沿退路离开。王座侧台塌落，没有人代替她们宣告宽恕。'),
'CIN-18':('废墟黎明','雪璃在左，绯月在中，鸦羽在右。三人站在外墙，第一次真正看见风暴后的晨光。建筑仍是废墟。')}
bosses = {
 'inquisitor':dict(name='血烙审判官 · 赫缄',phases=['锁链禁区','烙印追击'],hp=1050,lines=['保护殿下。其余人，不在命令以内。','弩台，封住她们的退路！','活捉的限度，到此为止。']),
 'judge':dict(name='王庭裁决官 · 白面法官',phases=['三庭宣判','亲持刑剑'],hp=1250,lines=['证词无需保留。','隔断合拢。判决不容旁听。','我亲自执行。']),
 'vein':dict(name='旧骑士 · 维恩',phases=['旧剑路','重盾反制'],hp=1450,lines=['你的起手，我比你更熟。','别逼我把你绑回去。','叫不叫叔叔，都得从这里过。']),
 'surgeon':dict(name='缀身夫人 · 瑟芮',phases=['针索与麻醉','手术偶胸舱'],hp=1650,lines=['请不要损坏自己。','保持呼吸。不会很久的。','承重臂重启。修复优先。']),
 'admiral':dict(name='黑帆提督 · 莫罗',phases=['重锚封路','断链离港'],hp=1850,lines=['海口在我手里。','把甲板清干净！','断锚。谁也别想从这里走。']),
 'queen':dict(name='血潮女王',phases=['旧剑路','不许她们靠近','把你的命还给你'],hp=2200,lines=['像以前一样，听我的。','不许她们靠近！','只要一下。你会明白的。']),
 'beast':dict(name='霜脊岩兽',phases=['岩甲','落石'],hp=950,lines=['岩甲传来低沉裂响。','兽道正在震动。']),
 'warden':dict(name='牢狱看守 · 铁棺',phases=['重盾封路','锁链拖拽'],hp=1400,lines=['没有放行令。','把他们带回房间。'])}

# Current narrative revision is applied before assigning stable objective IDs and maps.
# Gameplay layout and completed-step identifiers stay compatible with existing saves.
from scarlet_regency_story import apply as apply_regency, LETTER as REGENT_LETTER
apply_regency(scene, scenes, quests, facts, cinematics, bosses, ACTS)

# Per-room authored floorplan, ports and cover. Coordinates are simulation pixels.
zones={}
styles=['road','town','home','chapel','canal','arena']
for a,(title,camp,maps,b) in enumerate(ACTS,1):
    for s,name in enumerate([camp]+maps):
        layout=('camp' if s==0 else ['road','town','prison','library','canal','arena'][s-1])
        if a==3: layout=['camp','road','ravine','mine','ravine','tower','arena'][s]
        if a==4: layout=['camp','garden','workshop','bedroom','prison','archive','theatre'][s]
        if a==5: layout=['camp','dock','wreck','dock','cliff','canal','ship'][s]
        if a==6: layout=['camp','watergate','corridor','garden','workshop','thronehall','throne'][s]
        if a==1 and s in [3,4,6]: layout={3:'home',4:'chapel',6:'chapel'}[s]
        # Positions are story event indices, projected onto the original map.
        # Physical layout, cover, dimensions and scenery belong to story_map.
        zones[f'{a}:{s}']=dict(id=f'{a}:{s}',act=a,stage=s,name=name,layout=layout,
                              points=[[800,1320],[1000,1120],[820,920],[990,700],[820,470],[1050,310],[900,220]],
                              ambient=['5c6b78','6b6372','5c6d87','70566e','487c85','663746'][a-1])

order=[k for k,q in quests.items() if q['kind']=='main']
for i,qid in enumerate(order):
    if i: quests[qid]['requires']=[order[i-1]]
for q in quests.values():
    for i,n in enumerate(q['nodes']):
        n['id']=f"{q['id']}:{i}"
        n['zone']=f"{q['act']}:{q['stage']}"
        n['at']=zones[n['zone']]['points'][min(i,6)]
        # Chapter endings really return to camp; no silent teleport after a boss.
        if q['id'] in ['R-1-06','R-2-06','R-3-06','R-5-06'] and i>=next((j+1 for j,x in enumerate(q['nodes']) if x['kind']=='boss'),99):
            if n['kind']=='scene' or n['kind']=='cinematic': n['zone']=f"{q['act']}:0"; n['at']=[900,880 if i%2 else 620]
        if q['id']=='R-E01': n['at']=[760+i*140,700]
facts.update(royal_letter={'title':'女王的召回信','text':REGENT_LETTER},pursuit_order={'title':'与召信同印的封存令','text':'封存医档，拘押擅传者；武装拒捕可就地处置，绯月及佩剑例外保护。信使带出密档后遭追捕。'})
# The queen writing is CIN-00; the following ADV begins at the inn without
# leaking the queen's portrait into a different location.
# The revised opening is already set in the inn; CIN-00 holds the queen's court.
scenes['letter-first']['facts']=['royal_letter']
scenes['letter-orders']['facts']=['pursuit_order']
background_groups={
 'inn':['opening','opening-ask','conditions','messenger-safe'],
 'village':['soup','second-letter','s1'],
 'city':['vein-shelter','sword-exam','sword-exam-out','physician','refuse-sword','apology','judge-out','s2'],
 'mountain':['vein-defeat','empty-rack','support','s3'],
 'palace':['interlude-4','dress','bedroom','reunion','hilt','gift-truth','surgeon-in','home-decision','s4'],
 'harbor':['captain','tickets','return-choice','plan','sail','captain-return','watergate','hospital','leave-epilogue','letter-back','s5'],
 'throne':['two-cups','queen-phase2','queen-phase3','finisher','rescue-choice']}
for bg,ids in background_groups.items():
    for sid in ids: scenes[sid]['background']=bg
quests['R-P03']['nodes'][-1]['at']=[900,1570]
quests['R-5-01']['nodes'][3]['kind']='trial'
quests['R-1-02']['nodes'][3]['optional']=True
zones['6:7']={**zones['6:1'],'id':'6:7','stage':7,'name':'王城外墙 · 观景台','layout':'cliff'}
quests['R-6-06']['nodes'][-1]['zone']='6:7'
quests['R-6-06']['nodes'][-1]['at']=[900,500]
content=dict(revision='scarlet-1',narrative_revision='regency-compassion-2026-10-16',title='赤月遗书',acts=[dict(id=i+1,title=a[0],camp=a[1],maps=[dict(name=n) for n in a[2]],boss=a[3]) for i,a in enumerate(ACTS)],
             main_order=order,quests=quests,scenes=scenes,facts=facts,zones=zones,bosses=bosses,
             cinematics={k:dict(id=k,title=v[0],summary=v[1],path=None) for k,v in cinematics.items()})
from scarlet_terminology import normalize as normalize_terms
content=normalize_terms(content)
quests=content['quests']; zones=content['zones']
(OUT/'campaign.json').write_text(json.dumps(content,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f"Scarlet: {len(order)} main, {len(quests)-len(order)} side, {len(scenes)} scenes, {sum(len(x['pages']) for x in scenes.values())} pages, {len(zones)} zones")
rows=['# 赤月遗书 · 运行内容索引','', '由 tools/build_scarlet_content.py 生成；2026-10-16 新叙事正文以 tools/scarlet_regency_story.py 为准，运行判定见 SCARLET-IMPLEMENTATION.md。','', '| ID | 任务 | 起始地区 | 可操作节点／演出 |','|---|---|---|---|']
for q in quests.values():
    steps=' → '.join(n['label'] for n in q['nodes'])
    zone_name=zones[str(q['act'])+':'+str(q['stage'])]['name']
    rows.append(f"| {q['id']} | {q['title']} | {zone_name} | {steps} |")
(ROOT/'docs/rpg/SCARLET-CONTENT-INDEX.md').write_text('\n'.join(rows)+'\n',encoding='utf-8')

"""Compile the approved screenplay into playable objectives and ADV directions.

Story text lives in write_scarlet_screenplay.py / screenplay.json. This module
authors the physical work between those scenes; it never imports old dialogue.
"""
from pathlib import Path
import json
import re
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
REVISION = 'crown-and-city-2026-10-16'
ACTORS = {'F':('绯月','feiyue'),'X':('雪璃','xueli'),'Y':('鸦羽','yayu'),
 'Q':('女王','queen'),'M':('莱特','messenger'),'D':('埃文医师','physician'),
 'C':('玛菈船长','captain'),'V':('维恩','vein'),'I':('赫缄','inquisitor'),
 'J':('白面法官','judge'),'S':('瑟芮','surgeon'),'A':('莫罗','admiral'),
 'W':('工匠','craftsman'),'H':('驿夫','stablemaster'),'B':('村医','village-doctor'),
 'N':('旁白',''),'U':('居民',''),'P':('获救的母亲',''),
 'K':('阿宁',''),'G':('卫兵／侍从','')}


def runtime_id(qid):
    return qid if qid.startswith('S') else 'R-'+qid


def apply(content):
    source = json.loads((ROOT/'art/scarlet-screenplay/screenplay.json').read_text(encoding='utf-8'))
    content['revision'] = 'scarlet-screenplay-2'
    content['narrative_revision'] = REVISION
    content['screenplay'] = True
    content['scenes'] = {}
    content['facts'] = {}
    content['quests'] = {}
    content['main_order'] = []
    scenes, facts, quests = content['scenes'], content['facts'], content['quests']
    profiles = {}
    titles = ['等你的人','灯下的名字','你一定会回头','她走过的路','下一班船','回答之前']
    maps = [
      ['官道关卡','村医与巡查棚','村医转诊站','雾桥礼拜堂','囚车前庭','修院转运主厅'],
      ['白垩外街','工匠检验台','审判庭观察室','原件书库','安全排水支路','公共档案庭'],
      ['山路入口','山门下层','矿坑升降井','废讯台与安全拱道','信站侧梯','山口交接场'],
      ['行宫荒园','改尺工坊','旧卧室','地下医室','手术档案台','外科示范厅'],
      ['月舟修船坞','沉舟滩接收棚','近岸闸与账房','海防高坡','公告台与计划桌','黑帆控制旗舰'],
      ['旧水门登陆台','值房与侧廊','王座前室','王座厅外环','工区接应与认证阵','王座安全台']]
    for a in range(1,7):
        act=content['acts'][a-1]; act['title']=titles[a-1]
        act['maps']=[{'name':n} for n in maps[a-1]]
        for stage,name in enumerate([act['camp']]+maps[a-1]):
            content['zones'][f'{a}:{stage}']['name']=name
    content['zones']['6:7']['name']='王城外墙 · 黎明观景点'

    # Costumes change at a location/time transition, never on each sentence.
    home = {'00-02','00-03','00-04','00-05','00-05a','00-05b',
            '01-05','03-12','A-06','A-07','R-08'}
    formal = {'00-01','04-I01','04-I02','04-02','06-04','06-05','06-06',
              '06-06a','06-06b','06-06c','06-07','06-08','06-09','06-10',
              '06-11','06-12','06-13','A-01','A-02','A-03','A-04','A-05','R-01','R-02','R-03','R-04','R-05'}
    # Keep clothes continuous through the inn attack; change only at a safe room.
    CG = {'00-03':'cg-01a','00-05':'cg-01b','01-05':'cg-02','01-12':'cg-03',
      '02-06':'cg-04','02-08':'cg-05','03-06':'cg-06','03-08':'cg-07',
      '03-12':'cg-08','04-02':'cg-09','04-03':'cg-10','04-07':'cg-11',
      '04-09':'cg-12','05-03':'cg-13','05-13':'cg-14','06-05':'cg-15',
      'R-07':'cg-16b','R-08':'cg-16a','R-09':'cg-17','S04-01':'cg-10'}
    CG.update({'04-06':'cg-n02','05-06':'cg-n03','06-09':'cg-n04',
               'A-02':'cg-a01','A-06':'cg-a02','A-07':'cg-a03'})
    for s in source['scenes']:
        sid=s['id']; task=s['task']; act=int(task[0]) if task[0].isdigit() else 1
        if task=='I04': act=4
        if task=='E01': act=6
        if task.startswith('S'): act=int(task[1:])
        bg=['village','city','mountain','palace','harbor','throne'][act-1]
        if sid.startswith('00-'): bg='inn' if sid<='00-06' else 'village'
        if sid=='00-01': bg='throne'
        if sid.startswith('A-'): bg='palace'
        if sid.startswith('R-') and int(sid[2:])>=6: bg='harbor'
        costume='home' if sid in home else 'regular' if sid in formal else 'travel'
        cast=[]
        for code in ['F','X','Y']:
            if re.search(r'(?<![A-Z])'+code+r'(?![A-Z])',s['cast']) or '三人' in s['cast'] or '三主角' in s['cast']:
                cast.append(ACTORS[code][1])
        if sid=='03-12': cast=['feiyue','xueli']
        if sid.startswith('04-I'): cast=[]
        pages=[]; cg=CG.get(sid,'')
        # Expression and pose are two independent directions. Turn is the normal
        # conversational stance; crossed is reserved for challenges/guarding.
        for line in s['lines']:
            if line['type']=='direction': continue
            code=line['actor']; name,actor=ACTORS[code]
            pose=line['pose']; expression=line['expression']
            if code in ['F','X','Y']:
                if pose=='front':
                    pose='crossed' if expression=='angry' else 'turn'
                    if expression in ['surprised','joy'] or (sid in ['A-07','R-09'] and code=='F'): pose='front'
                    blocking={('00-08','Y'):'crossed',('02-08','F'):'crossed',
                              ('02-09','F'):'front',('03-08','F'):'front',
                              ('03-06','Y'):'front',('05-12','F'):'front',
                              ('06-13','F'):'front',('A-01','F'):'front',('R-01','F'):'front'}
                    pose=blocking.get((sid,code),pose)
                if sid=='03-12' and code=='Y': actor='' # letter voice, absent body
            page=dict(id=line['id'],speaker=name,actor=actor,text=line['text'],
                      expression=expression,pose=pose,costume=costume,cg=cg)
            if cg.startswith(('cg-n','cg-a')): page['cg_fit_above_dialogue']=True
            if sid=='06-10': page['portrait_only']=True
            pages.append(page)
        if sid=='00-01':
            # Show the waiting street only for its actual lines; the court
            # dialogue then returns to the throne backdrop without a movie.
            for page in pages[:3]: page['cg']='cg-n01'; page['cg_fit_above_dialogue']=True
        assert pages,sid
        scenes[sid]=dict(id=sid,title=s['title'],pages=pages,choices=[],background=bg,
                        cast=cast,default_costume=costume,default_pose='turn',source_task=task)

    # Branch reply scenes and menus retain a serializable continuation on reload.
    keymap={'C00':'opening_reply','C01':'medicine_route','C02':'apology',
            'C03':'ambush_prepared','C04':'vein_reply','C05':'harbor_route',
            'C06':'queen_question','C07':'resolution','C08':'keepsake'}
    for choice in source['choices']:
        cid=choice['id']; sid=choice['scene']; target_scene=scenes[sid]
        # Put C02 before the answer, and C08 after the physical repair (below).
        if cid=='C02':
            tail=target_scene['pages'][4:]; target_scene['pages']=target_scene['pages'][:4]
        else: tail=[]
        for index,option in enumerate(choice['options']):
            value=option.get('action',option.get('keepsake',option.get('world',str(index))))
            if cid=='C00': value=['carry','ask'][index]
            if cid=='C03': value=[True,False,'later'][index]
            entry=dict(text=option['text'],key=keymap[cid],value=value)
            target=option.get('target','')
            if cid in ['C00','C06'] and target in scenes and not (cid=='C06' and index==3): entry['reply']=target
            if option.get('reply'):
                reply_id=f'{cid}-reply-{index}'; pages=[]
                for code,text in option['reply']:
                    name,actor=ACTORS[code]
                    pages.append(dict(speaker=name,actor=actor,text=text,expression='sad' if cid=='C02' else 'neutral',
                                      pose='turn',costume=target_scene['default_costume'],cg=''))
                scenes[reply_id]={**target_scene,'id':reply_id,'title':choice['prompt'],'pages':pages+tail,'choices':[]}
                entry['reply']=reply_id
            if cid=='C06' and index<3: entry['return_menu']=sid
            if cid=='C03' and index==2: entry['defer']=True
            if cid=='C07': entry['confirmation']=option['consequences']
            target_scene['choices'].append(entry)
        if cid=='C08':
            scenes['C08-menu']={**target_scene,'id':'C08-menu','pages':[dict(speaker='绯月',actor='feiyue',text='针脚补好了。把它放在哪里？',expression='neutral',pose='turn',costume='travel',cg='')]}
            target_scene['choices']=[]

    scenes['cost-review']=dict(id='cost-review',title='再看两份代价',background='throne',cast=['feiyue','xueli','yayu'],default_costume='regular',choices=[],pages=[
      dict(speaker='雪璃',actor='xueli',expression='neutral',pose='turn',costume='regular',text='接过王冠，今夜的血潮会退，城市的水泵与灯还能继续。赤月之心仍在，你会长期承载晶化，没有人能保证年数。姐姐可能在最后一次透支后死去。'),
      dict(speaker='鸦羽',actor='yayu',expression='neutral',pose='turn',costume='regular',text='不接，就要先走完回流、断连接和破心。源头会熄灭，下城和供能也会失去，旧水与病都还要处理。我们有救姐姐的机会，不是治好她的保证。')])
    scenes['06-13']['choices'].append(dict(text='再看两份代价。',reply='cost-review',return_menu='06-13'))

    for docid,sid,title,text,_ in source['documents']:
        facts[docid]={'title':title,'text':text}
    facts['royal_letter']={'title':'女王的短召信','text':'绯月：\n北岸的水又涨了。旧水门还留着。\n带上那把剑，回来见我。\n——姐姐'}
    facts['pursuit_order']={'title':'与召信同印的封存令','text':'封存医档，拘押擅传者；武装拒捕可就地处置。绯月及佩剑例外保护。保留完整签署页。'}
    scenes['00-03']['facts']=['royal_letter']; scenes['00-05']['facts']=['pursuit_order']
    for docid,sid,*_ in source['documents']:
        scenes[sid].setdefault('facts',[]).append(docid)

    # Every material action has its own authored three-step physical interaction.
    def n(kind,label,**kw): return dict(kind=kind,label=label,**kw)
    def talk(sid,**kw): return n('scene',scenes[sid]['title'],scene=sid,**kw)
    def work(label,steps,prop='lock',hero=-1,**kw):
        assert len(steps)==3
        return n('mechanism',label,hero=hero,procedure=steps,prop=prop,**kw)
    def evidence(key,label,text):
        facts[key]=dict(title=label,text=text)
        return n('clue',label,fact=key,text=text,procedure=['观察原件','对照编号与现场','保留原物并记录'],prop='document')
    def escort(label,count=1,**kw): return n('escort',label,count=count,**kw)
    def fight(label,count=3,**kw): return n('fight',label,count=count,**kw)
    def confirm(label,**kw): return n('confirm',label,**kw)
    def film(cid): return n('cinematic',source['films'][cid][0],cinematic=cid)
    def boss(label,**kw): return n('boss',label,**kw)
    def W(label,a,b,c,**kw): return work(label,[a,b,c],**kw)
    def Q(label,question,options,answer=0,**kw): return n('deduce',label,question=question,options=options,answer=answer,needs=[],**kw)
    def at_zone(nodes,zone):
        for item in nodes: item['zone']=zone
        return nodes
    manifests={q['id']:q for q in source['quests']}
    def quest(qid,act,stage,nodes,auto=False,intake=None):
        spec=manifests[qid]; rid=runtime_id(qid); kind='side' if qid.startswith('S') else 'main'
        quest=dict(id=rid,title=spec['title'],act=act,stage=stage,kind=kind,nodes=nodes,
          intro='',outro='',requires=[],description=' → '.join(item['label'] for item in nodes if item['kind'] not in ['scene','cinematic','checkpoint']) or spec['title'],intake=spec,
          auto_accept=auto,intake_scene=intake or '',reward={'xp':90+act*35,'coins':35+act*10})
        quests[rid]=quest
        if kind=='main':
            if content['main_order']: quest['requires']=[content['main_order'][-1]]
            content['main_order'].append(rid)
        for i,item in enumerate(nodes):
            item['id']=f'{rid}:{i}'; item.setdefault('zone',f'{act}:{stage}')
            item.setdefault('at',[800+(i%2)*200,1320-(i%6)*175])
            if item['kind'] not in ['boss','escort','fight']: item.setdefault('chain',item['kind'] in ['scene','cinematic'])
            if item['kind'] in ['mechanism','clue']:
                steps=item.pop('procedure'); prop=item.pop('prop')
                survey=item['kind']=='clue'
                parts=[dict(name=step,instruction=step+'。按住 E 操作，松开可暂歇。',result='已确认：'+step) for step in steps]
                calibration=-1 if survey else 1
                challenge='tension' if prop=='rope' else 'alignment' if prop in ['lamp','workbench'] else 'timing'
                if calibration>=0:
                    parts[1]['instruction']+='在青色区间松开。' if challenge=='tension' else '用 A / D 对准青色区间，再按 E。' if challenge=='alignment' else '指针进入青色区间时按 E。'
                profiles[item['id']]=dict(mode='survey' if survey else 'procedure',prop=prop,parts=parts,
                    subtitle='观察 · 比对 · 留证' if survey else '依序操作 · 稳定受力',
                    hint=' → '.join(steps),calibrate=calibration,challenge=challenge)

    quest('P01',1,0,[talk(x) for x in ['00-01','00-02','00-03','00-04','00-05']],True)
    quest('P02',1,0,[talk('00-06'),W('推开后廊柜子','卸下柜内重物','推柜留出担架宽度','固定柜脚'),
      fight('解除后廊弩线威胁',2),escort('把莱特担架送进医棚'),talk('00-07')],True)
    quest('P03',1,0,[talk('00-08'),n('depart','南门路标 · 确认向村医站出发',at=[900,1570])])
    quest('1-01',1,1,[talk('01-01'),W('分开官车与病人车通路','查看车轮卡位','打开内侧栏杆','确认担架通行宽度'),escort('让最后一辆病人车通过',1),talk('01-02')])
    quest('1-02',1,2,[evidence('medicine_invoice','核对巡查棚封条与村医缺单','017 号药箱，退热药十二瓶、敷料二十四份；核对村医缺单及原箱封口。'),talk('01-03'),
      n('route','执行已经选择的取药办法',key='medicine_route'),
      W('保住完整药箱并交回村医','核药箱封条','护住瓶塞与敷料','村医按原号验收',prop='medical')],intake='intake-medicine')
    scenes['intake-medicine']=dict(id='intake-medicine',title='不能等的药',background='village',cast=['feiyue','xueli'],default_costume='travel',choices=[],pages=[
      dict(speaker='村医',actor='village-doctor',text='017 号箱被留在巡查棚。退热药十二瓶、敷料二十四份，再等下去，床上的人等不起。请照这张缺单查，别砸坏瓶子。'),
      dict(speaker='绯月',actor='feiyue',expression='worried',pose='turn',costume='travel',text='我去核编号。箱子取回以后，先交给你验收。')])
    quest('1-03',1,3,[talk('01-04'),W('分检普通伤与晶化伤','查看皮肤与红水接触','分开清洁敷料','写转诊标识',prop='medical'),
      W('把清水与患者送上转诊路','检查水桶无红色沉积','封好清水桶','交接转诊车',prop='cart'),talk('01-05',chain=False)])
    quest('1-04',1,4,[talk('01-06'),W('修好桥索让担架通过','验桥头挂点','拉紧主索','固定两侧护绳',prop='rope',hero=2),
      escort('护病人过雾桥',2),film('CIN-02'),W('解开灯角与箱盖记录','雪璃对准灯角','依编号打开箱盖','保留整张签署页',prop='lamp',hero=1),talk('01-07')])
    quest('1-05',1,5,[talk('01-08'),W('解除囚车绞盘与侧笼','支撑吊笼底架','释放绞盘张力','开侧门并架稳',prop='rope'),escort('将村医与居民送至接收点',3),talk('01-09')])
    quest('1-06',1,6,[talk('01-10',chain=False),boss('推门 · 挑战赫缄'),talk('01-11'),talk('01-12',zone='1:3',chain=False)])
    quest('2-01',2,1,[talk('02-01'),fight('解除街口转运威胁'),escort('护街口居民进避难所',3),W('确认避难所内外门','查看内门锁舌','支稳外门','把通行牌交接收者'),talk('02-02')])
    quest('2-02',2,2,[talk('02-03'),evidence('hilt_mould','核模具、封口与编号','只作外检。剑柄小晶与地下赤月之心不同；没有许可不能擅拆晶核。'),
      Q('核对两种晶体','外检已经证明了什么？',['同源不同用途，剑柄小晶用于认证','剑柄里装着整座地下核心','现在折剑就能安全停灾']),talk('02-04')])
    quest('2-03',2,3,[talk('02-05'),W('取轮值钥匙并打开观察室','观察轮值空隙','按门牌取钥','解内侧门闩'),fight('解除转诊通路守卫',2),escort('护埃文医师离开观察室'),talk('02-06')])
    quest('2-04',2,4,[evidence('succession_chart','对照旧病程与同刻潮位','同刻标线：移交前 7 格，移交后 3 格，泵房恢复；旧承载者病程继续恶化。'),
      Q('对齐时间线','哪一个判断同时符合两张原件？',['继位能平息本次血潮，但不会消灭污染源','继位从来无效','继位者此后永不晶化']),talk('02-07'),talk('02-08')])
    quest('2-05',2,5,[W('打开安全排水支路','查清下游有人接应','撑稳排水侧门','留可回开的锁扣'),escort('护医师和原件走出排水支路'),talk('02-09',chain=False)])
    quest('2-06',2,6,[talk('02-10'),W('先开证人安全出口','核对证人席','解旁门隔断','将原件柜移出火线'),escort('让证人抵达安全席',2),talk('02-11',chain=False),boss('主动进入公共档案庭'),talk('02-12',zone='2:0',chain=False),film('CIN-05')])
    quest('3-01',3,1,[talk('03-01'),talk('03-02',when_key='ambush_prepared',when_value=True),
      W('预布侧梯与改索','确认高处挂点','把侧梯固定在备用平台','改索避开落闸',prop='rope',when_key='ambush_prepared',when_value=True)])
    quest('3-02',3,2,[n('branch_scene','主动查看山门落闸机关',key='ambush_prepared',yes='03-03A',no='03-03B'),
      W('切开下层拦索','确认担架安全侧','切开拦索外扣','支住通道',prop='rope'),fight('解除下层弩手',2),escort('把近处伤者带到矿口',2),talk('03-04')],True)
    quest('3-03',3,3,[W('先开风道接应雪璃','定位风道出口','关闭危险排气','卸下门闩',when_key='ambush_prepared',when_value=False),talk('03-05'),
      W('重启升降架','复位制动','调平承重点','测试空载并锁稳',prop='workbench'),escort('让最慢的担架先上井',2),talk('03-06')])
    quest('3-04',3,4,[evidence('vein_receipt','比对箭簇、签领和路线副本','维恩补绘回程绕行线，签领和追兵箭簇相符；必须保留他本人签名。'),
      Q('用现场证据核身份','指向维恩的是哪组证据？',['同批箭簇、本人签领与亲绘回程线','玩家看过的夜间幕间','他曾送过一件礼物']),talk('03-07'),talk('03-08',chain=False)])
    quest('3-05',3,5,[talk('03-09'),W('断信标，开信站侧梯','卸信标外扣','压住侧梯挂点','固定安全下行梯',prop='rope'),escort('护信站旅人离开',2)])
    quest('3-06',3,6,[talk('03-10',chain=False),boss('进入山口交接场'),talk('03-11'),talk('03-12',zone='3:0',chain=False),talk('04-I01',zone='3:0'),talk('04-I02',zone='3:0')])
    quest('4-01',4,1,[talk('04-01'),evidence('yayu_tracks','分辨自主脚印与后续拖痕','药瓶和刀鞘擦痕先自主向行宫；其后出现拘束拖痕，不把她简单写成被绑走。'),W('开荒园排水栅','确认栅后落脚','卸锁舌','撑稳通行口')])
    quest('4-02',4,2,[talk('04-02'),evidence('dress_dates','核对改尺日期和席次牌','衣服多年不断改尺，最近又被放到继位席次旁；真心与计划同时存在。')])
    quest('4-03',4,3,[talk('04-03'),evidence('room_receipt','读箱底交接单','鸦羽在地下医室，完整佩剑封在档案柜；两者分开保管。')])
    quest('4-04',4,4,[talk('04-04'),W('雪璃先稳伤','观察呼吸和晶纹','低量稳定用药','确认清醒可移动',prop='medical',hero=1),
      W('卸承重再解腕锁','支起固定架承重','松开腕锁','隔离警报',prop='workbench'),talk('04-05',party=[0,1,2]),escort('护鸦羽抵安全医室')],True)
    quest('4-05',4,5,[W('回收完整剑及原件','比对封柜编号','验完整晶核','取出剑与档案',prop='workbench',sword='contract'),
      evidence('evacuation_history','核对十年前三组撤运资料','回流堵塞、船晚、工区漏人，导致旧撤运失败；女王接冠后水位下降。'),
      Q('重排十年前的次序','哪一项符合完整记录？',['撤运条件失败在先，接冠压潮在后','女王从没试过撤运','旧撤运完全成功']),talk('04-06'),
      W('只拆剑柄外饰，不损契印','按外检模具找边界','卸外饰固定扣','保留完整契印',prop='workbench'),talk('04-07'),talk('04-08'),talk('04-09',chain=False)])
    quest('4-06',4,6,[talk('04-10'),W('独立病房最低保障','标明病房支路','接上独立最低供给','只隔离示范厅局部线',prop='valve'),escort('转出相连病房患者',2),
      talk('04-11',chain=False),boss('进入示范厅 · 瑟芮手术偶'),evidence('maintenance','保全维护原件','病房保障与示范厅程序分离；保留维护签署页，不焚毁患者记录。'),W('开安全装卸水道','检查水道出口','解吊栅','固定转运踏板'),talk('04-12')])
    quest('5-01',5,1,[talk('05-01'),W('核料修舵','验材料断口','对齐舵杆','固定限位',prop='workbench'),n('trial','实际近岸试航 · 出航与返坞'),
      W('测试清水支渠并恢复供水','核清水支渠用途','短时试闭并观察','恢复支渠确认接水',prop='valve'),talk('05-02'),talk('05-03',chain=False)])
    quest('5-02',5,2,[talk('05-04'),W('固定高地救援绳','验承重挂点','拉紧主绳','加保险结',prop='rope'),escort('逐段接七人到接收棚',7,names=['伊芙','林恩','索尔','米娜','鲁本','塔拉','阿宁']),
      W('逐名核对七人接收','对照六人船单','让第七人自己说姓名','七人逐一签收',prop='document'),talk('05-05'),talk('05-06'),talk('05-07')])
    quest('5-03',5,3,[talk('05-08'),evidence('harbor_accounts','比对民船账与押运账','民船没有下次日期，押运仓仍按期转货；安全航距真实，却不能解释无限延期。'),talk('05-09'),n('route','执行近岸夺闸办法',key='harbor_route'),W('开近岸闸并移离危险泊位','确认岸边人员退后','开启近岸闸','锁稳民船缆',prop='valve')])
    quest('5-04',5,4,[talk('05-10'),evidence('water_measurements','实测低岸、中堤、高坡','三处同刻读数；明确下游接收，不把试段当全城已经疏散。'),
      W('只开回流试段','查下游接收牌','缓开试段闸','确认出流无回顶',prop='valve'),escort('将居民与最慢担架送上高坡',3),talk('05-11')])
    quest('5-05',5,5,[talk('05-12'),W('排病人、药和行李航序','先排慢行担架','按批分药与物资','留足行李承重空间',prop='document'),escort('按最慢速度验证担架全程'),
      W('双预案写上未确认项','填写接冠监护','填写撤离回流条件','保留待查工区栏',prop='document'),talk('05-13')])
    quest('5-06',5,6,[talk('05-14',chain=False),W('解除左舷缆弩','压住弩臂','释放弦张力','卸发射卡销',prop='rope'),W('解除右舷缆弩','固定弩臂','松索','卸卡销',prop='rope'),boss('挑战莫罗 · 锁舵保证民船航距'),
      W('实放最后一批民船','核航序与安全距离','签放行许可','确认最后一船越线',prop='document'),talk('05-15'),talk('05-16',zone='5:0',chain=False)])
    quest('6-01',6,1,[talk('06-01'),W('清石开旧水门','试探落石受力','清门槽并抬闸','锁上行限位',prop='valve'),W('固定回程绳梯','系主绳','调平两侧','固定梯脚',prop='rope'),escort('等效重量担架实际走回接收点')])
    quest('6-02',6,2,[talk('06-02'),evidence('registers','交叉门牌、班次和住户三册','已知房间与最后工区分开；末段仍待查，绝不提前盖清空章。'),W('开已知房间','对门牌','卸内锁','撑门'),escort('让已知住户到接收点',3),W('从内开侧廊后门','查后门接应','卸内栓','留灯号支点'),talk('06-03')])
    quest('6-03',6,5,[n('final_gate','带原件进入会面 · 可先整备'),talk('06-04'),talk('06-05'),talk('06-06')])
    quest('6-04',6,6,[talk('06-07'),boss('王剑控制战 · 先开侧廊',last_phase=1),talk('06-09')],True)
    full=scenes['06-10']
    scenes['06-10-first']={**full,'id':'06-10-first','pages':full['pages'][:1]}
    scenes['06-10-second']={**full,'id':'06-10-second','pages':full['pages'][1:]}
    quest('6-05',6,4,[talk('06-10-first',party=[0,1,2]),W('鸦羽 · 卸第一间承重开门','核甲室三人','支撑门框','卸门外承重',hero=2),escort('接甲室伊娜、佩尔、米娅',3,names=['伊娜','佩尔','米娅']),
      talk('06-10-second'),W('鸦羽 · 清第二间门后箱子','核乙室两人','移开堵门箱','留下通行宽度',hero=2),escort('接乙室托恩、阿珂',2,names=['托恩','阿珂']),
      W('核最后一间住户','按丙室门牌敲门','确认诺亚在内','撑开门'),escort('接丙室诺亚',1,names=['诺亚']),
      evidence('workzone_received','接收六人回条抵达','甲室三人、乙室两人、丙室一人，全由水门接收者逐名确认；并非预计清空。'),talk('06-11',zone='6:6'),boss('只解除外侧强制认证节点',start_phase=2,last_phase=2,zone='6:6'),talk('06-12',zone='6:6'),n('checkpoint','保存回答前稳定记录',zone='6:6')],True)
    scenes['06-disarm']=dict(id='06-disarm',title='让她把回答说完',background='throne',cast=['feiyue','xueli','yayu'],default_costume='regular',choices=[],pages=[
      dict(speaker='旁白',actor='',text='外侧强制认证熄下去。赤月之心仍在，王冠和剑柄里的契印也仍完整。女王放开手，等待绯月自己的回答。')])
    r2=scenes['R-02']
    scenes['R-02-start']={**r2,'id':'R-02-start','pages':r2['pages'][:5]}
    scenes['R-02-finish']={**r2,'id':'R-02-finish','pages':r2['pages'][5:]}
    quest('6-06',6,6,[talk('06-13'),
      *[dict(x,when_key='resolution',when_value='A') for x in [talk('A-01'),W('落实移交前条件','原件交外侧','确认民船自由通行','雪璃登记监护',prop='document'),talk('A-02'),
         W('自愿站位与第一段认证','绯月主动进入站位','雪璃对准监护灯','确认第一段稳定',prop='lamp',hero=1),talk('A-03'),
         W('分段承接，不抢下一步','确认承载反应','接通第二段','监护确认再完成移交',prop='lamp',hero=0),film('CIN-17A'),talk('A-04',effects={'queen_alive':False,'tide_calm':True,'heart_intact':True,'city_power':True,'feiyue_crowned':True})]],
      *[dict(x,when_key='resolution',when_value='R') for x in [talk('R-01'),W('复核回流与下游接收','核真实接收回条','试回流无回顶','下游确认后开主回流',prop='valve'),
         talk('R-02-start'),W('雪璃稳近场','立好支点灯','对齐近场','确认稳流窗',prop='lamp',hero=1),W('鸦羽断连接','松外扣','等待稳流确认','切开主连接',prop='rope',hero=2),
         talk('R-02-finish'),confirm('绯月 · 确认共同终结赤月之心'),talk('R-03',effects={'tide_ended':True,'heart_intact':False,'city_power':False},sword='broken'),talk('R-04'),
         W('三人共同绳索救援','验承重锚点','卸晶桥并系救援带','三人分担张力拉回',prop='rope'),film('CIN-18R'),escort('将失冠女王交医护与看守',1,names=['女王']),talk('R-05',effects={'queen_alive':True,'queen_in_custody':True}),talk('R-06',zone='6:7',chain=False)]]],True)
    # Preserve dramatic reaction order while giving each line a real trigger.
    quest('E01',6,0,[
      *[dict(x,when_key='resolution',when_value='A') for x in [talk('A-05',chain=False),W('公开记录与复光回条','核民船放行','公开完整签署页','记复光与长期监护',prop='document'),talk('A-06'),talk('A-07')]],
      *[dict(x,when_key='resolution',when_value='R') for x in [talk('R-07',chain=False),W('交接原件和重建物资','登记临时供水缺口','交完整原件','将药粮交接收者',prop='document'),talk('R-08',chain=False),talk('R-09')]]])

    side_specs=[
      (1,3,[talk('S01-01'),evidence('lamp_glass','找旧玻璃','可修补提灯护罩的旧玻璃。'),W('修补提灯裂罩','磨平边缘','嵌合缺口','压紧铜夹',prop='lamp'),W('雪璃试照暗路','打开遮光片','对准暗路','固定支架',prop='lamp',hero=1),talk('S01-02')],'R-1-03'),
      (2,3,[talk('S02-01'),evidence('remedy','核公开替代方','灰叶和温盐低量试用，只稳定旧伤，不是治愈。'),W('低量配药并记录反应','分取灰叶','加入温盐液','低量试用记录',prop='medical'),talk('S02-02')],'R-2-03'),
      (3,0,[talk('S03-01'),W('修侧架找两位旅人','复位制动杆','调平侧架','空载试稳',prop='workbench'),n('optional_boss','可选清理岩兽兽道',boss='beast'),escort('接维斯、诺安回来',2,names=['维斯','诺安']),talk('S03-02')],'R-3-03'),
      (4,3,[talk('S04-01'),W('修补旧手套','对齐旧针脚','沿原线缝缺口','藏好线头',prop='workbench'),talk('C08-menu'),talk('S04-02')],'R-4-02'),
      (5,1,[talk('S05-01'),W('绯月固定演练绳','套岸环','拉主绳','加保险结',prop='rope',hero=0),W('雪璃照亮模拟舱口','擦灯面','对舱口','固定灯架',prop='lamp',hero=1),W('鸦羽解演练索结','托结','放松张力','解结收绳',prop='rope',hero=2),escort('按最慢速度走完整程'),talk('S05-02')],'R-5-01'),
      (6,2,[talk('S06-01'),evidence('detention_names','核额外拘留室门牌','医师指明三间已知拘留室，独立于主线未知工区。'),n('optional_boss','可选制服铁棺',boss='warden'),W('打开联锁','核三间门牌','卸联锁扣','撑通路'),escort('护三人到水门',3),talk('S06-02')],'R-6-02')]
    for index,(act,stage,nodes,requires) in enumerate(side_specs,1):
        qid=f'S{index:02}'; quest(qid,act,stage,nodes); quests[qid]['requires']=[requires]
        if qid=='S04': quests[qid]['requires_active']='R-4-03'

    # Stage clothing changes are written as transitions; actors never acquire a
    # different costume because the speaker changed. Do not dress Feiyue as Queen.
    for sid in ['01-05','03-12','A-06','A-07','R-08']:
        scenes[sid]['wardrobe_note']='安全处休息，卸下外出披肩后。'
    for sid in ['06-04','A-05']:
        scenes[sid]['wardrobe_note']='整理衣装后，带着原件进入。'
    # Match movie cue points without exposing unfinished storyboard directions.
    movie_scenes={'00-01':'CIN-00','00-04':'CIN-01','01-07':'CIN-03','01-09':'CIN-04',
      '03-03A':'CIN-06A','03-03B':'CIN-06B','04-I02':'CIN-07','04-11':'CIN-08','05-04':'CIN-09',
      '05-08':'CIN-10','05-15':'CIN-11','06-07':'CIN-13','06-08':'CIN-14','06-11':'CIN-15',
      '06-12':'CIN-16C','A-04':'CIN-18A','A-07':'CIN-19A','R-03':'CIN-17R','R-06':'CIN-19R'}
    # Films remain empty until NEW footage is supplied. Never bind old same-ID film.
    content['cinematics']={cid:dict(id=cid,title=values[0],summary=values[0],path=None) for cid,values in source['films'].items()}
    content['scene_films']=movie_scenes
    for sid,cid in movie_scenes.items(): scenes[sid]['film']=cid
    for sid in ['04-I02','04-11','06-07','A-07']: scenes[sid]['film_after']=True
    content['cinematics']['CIN-12']['summary']='三人知道两种代价，约好旧水门的退路，主动驶向王城。'
    namekeys={'inquisitor':'赫缄','judge':'白面法官','vein':'维恩','surgeon':'瑟芮','admiral':'莫罗','queen':'女王','beast':'霜脊岩兽','warden':'铁棺看守'}
    for key,name in namekeys.items():
        barks=source['boss_barks'][name]
        content['bosses'][key]['barks']=barks
        content['bosses'][key]['lines']=[barks[0][1],barks[min(3,len(barks)-1)][1],barks[-2][1]]
    content['bosses']['queen']['phases']=['王剑控制 · 保留核心与王冠','开侧廊 · 解隔断','解除强制认证 · 等待回答']
    content['bosses']['queen']['lines']=[source['boss_barks']['女王'][i][1] for i in [0,2,5]]
    content['bosses']['surgeon']['phases']=['局部针索与麻醉','保留病房保障 · 解除手术偶']
    # NPCs offer a repeatable task-site interaction, including completed handoffs.
    content['repeat_lines']=source['repeat_lines']
    content['npc_repeats']=[
      dict(id='medicine',qid='R-1-02',state='active',zone='1:2',speaker='村医',actor='village-doctor',text=source['repeat_lines'][0][2]),
      dict(id='mould',qid='R-2-02',state='active',zone='2:2',speaker='工匠',actor='craftsman',text=source['repeat_lines'][2][2]),
      dict(id='physician',qid='R-2-03',state='complete',zone='2:3',speaker='埃文医师',actor='physician',text=source['repeat_lines'][3][2]),
      dict(id='mountain',qid='R-3-01',state='active',zone='3:1',speaker='维恩',actor='vein',text=source['repeat_lines'][4][2]),
      dict(id='boat',qid='R-5-01',state='active',zone='5:1',speaker='玛菈船长',actor='captain',text=source['repeat_lines'][5][2]),
      dict(id='passage',qid='R-5-06',state='complete',zone='5:0',speaker='玛菈船长',actor='captain',text=source['repeat_lines'][6][2])]
    (ROOT/'resources/scarlet/fieldwork.json').write_text(json.dumps(profiles,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    count=Counter(p.get('pose') for s in scenes.values() for p in s['pages'] if p.get('actor') in ['feiyue','xueli','yayu'])
    print('Screenplay runtime:',len(scenes),'scenes;',sum(len(s['pages']) for s in scenes.values()),'pages;',len(profiles),'physical tasks;',dict(count))
    return content

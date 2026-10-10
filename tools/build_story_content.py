"""Compile the reviewed story and quest index into deterministic runtime content."""
from pathlib import Path
import json, re

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT/'docs/rpg'
ACTS = [
    ('风铃不再安眠','雷霆要塞','thunder',['岑烬','闻笙','赫铎','阿梨','秦渡','陶婶'],['风铃原野','断羽驿路','静钟村','雾桥浅滩','遗灯礼拜堂','白钟修院'],['field','road','village','bridge','chapel','cathedral'],'赤月葬钟主教','bell-hierophant'),
    ('白垩城的晚祷','白垩避难庭','chalk',['索恩','梅荻','梁记','陆缄','缇莎','顾淳'],['白垩外街','坠钟广场','旧审判庭','灰页书库','地下炉渠','焚书礼堂'],['street','courtyard','hall','library','canal','cathedral'],'余烬司祭·晚祷','ashen-vesper'),
    ('星光下的猎场','月晶驿站','mooncrystal',['乌杉','秋砂','乌砾','季衡','桑络','石盏'],['月晶坡地','骨鹿猎道','断星矿坑','流星坠谷','观星高塔','誓猎祭场'],['field','road','mine','field','hall','courtyard'],'荆棘誓约猎王','thorn-huntsman'),
    ('蔷薇尽处','蔷薇篱营','rose',['芙罗','艾芙','弥莎','罗纱','欧林','园生'],['蔷薇荒园','刑偶工坊','嫁衣长廊','花眠庭院','镜墓','倒影剧场'],['garden','library','hall','garden','crypt','cathedral'],'镜墓纺女·碎影','mirror-weaver'),
    ('渡过无声的海','月舟码头','moonboat',['渡遥','芦霜','温汐','照湾','潮九','橹伯'],['雾汐堤岸','沉舟滩','潮盐工事','沉钟遗迹','逆潮水道','归航灯塔'],['coast','coast','canal','crypt','bridge','hall'],'冥潮守门者','moon-leviathan'),
    ('血月尽头','王城残灯','last_lamp',['蕾安','闻笙','赫铎','伊默','秦渡','洛垣'],['朝圣大道','圣血外廊','失乡庭院','彩窗工区','大教堂下层','王座大教堂'],['street','hall','courtyard','library','crypt','cathedral'],'血潮女王·永夜月冠','blood-queen'),
]
MAIN_STEPS = [
    ['救出原野老人','点亮安全路标'],['取回药车','找到两个孩子','修复驿路灯架'],['调查征收清单','恢复三段门灯','引导村民疏散'],['跨过雾桥','打开金边圣物箱','用提灯读血晶'],['检查左侧撤离灯','打开修院道路','确认小队补给'],['解除修院吸能链','关闭黑钟导路','与主教交战'],
    ['救取水队','恢复街口供水'],['停止异常钟响','取回储能石与路引'],['查找维修记录','关闭刑灯','保存顾淳证词'],['救出抄录员','抢救维修原图'],['分离污染','修复排热阀','保护维修组'],['保存女王敕令','切断总控炉芯','与晚祷交战'],
    ['救出矿工','开通坡地回路'],['解除猎道陷阱','救出运晶队','说服被缚猎徒'],['恢复升降机','制作替代线圈','取回相位镜'],['校准观星装置','复制六路相位图'],['解开猎徒外链','保护地方月晶'],['破除祭场晶链','解除猎王控制核','与猎王交战'],
    ['找回园丁工具','清理荒园土层'],['分离刑偶指令','保护普通人偶'],['以旧婚扣辨认镜路','离开理想倒影'],['停止宴会影像','拆开镜架','救出真实客人'],['取回窗框结构','读取高空释光设计'],['切断命线','引导居民离开剧场','与碎影交战'],
    ['救出探潮队','标出安全岸线'],['找回航海记录','取回修船工具','保存事故证词'],['按时序开启闸门','保留营地支路','保护维修队'],['修复逆潮导光槽','开启海岸释光节点'],['确认民筏安全','检查归航灯标','决定继续前行'],['解除海兽晶钉','击破总门束缚','释放冥潮守门者'],
    ['救出晶化居民','接通营地返航路'],['关闭封门装置','解除护卫增幅','打开救援通道'],['出示事故证据','和平解除骑士晶束'],['关闭六翼增幅器','打开高空窗框','确认六地反馈'],['穿过教堂下层','抵达王座大教堂'],['确认断链时序','稳定备用晨灯','迎战血潮女王'],
]


def main():
    text = (DOC/'STORY.md').read_text(encoding='utf8')
    pattern = r'^### ([PAEC][\w-]+) · (.+)$'
    matches = list(re.finditer(pattern,text,re.M))
    bodies = {}
    for i,m in enumerate(matches):
        end = matches[i+1].start() if i+1<len(matches) else text.index('## 三种结局收束',m.end())
        section = text[m.end():end].split('\n## ')[0].strip()
        bodies[m[1]] = (m[2], section)
    rows = []
    for line in (DOC/'QUESTS.md').read_text(encoding='utf8').splitlines():
        if re.match(r'\| (?:P-M|A\d-[MS]|C-[FXY]|E-M)',line):
            cols = [x.strip() for x in line.strip('|').split('|')]
            rows.append(cols)
    quests = {}
    for cols in rows:
        qid,title = cols[:2]
        assert bodies[qid][0]==title
        kind = 'main' if '-M' in qid else 'side' if '-S' in qid else 'personal'
        pre = cols[2] if kind!='side' else cols[3]
        prerequisites = re.findall(r'(?:P-M\d\d|A\d-[MS]\d\d|C-[FXY]\d\d|E-M\d\d)',pre)
        if qid=='P-M03': prerequisites=[]
        act = int(qid[1]) if qid.startswith('A') else 1
        if kind=='personal':
            act = max([int(x[1]) for x in prerequisites if x.startswith('A')] or [1])
        stage = int(qid[-2:]) if kind=='main' and qid.startswith('A') else min(5,max([int(x[-2:]) for x in prerequisites if '-M' in x and x.startswith('A')] or [1]))
        description = cols[3] if kind!='side' else cols[4].split('；')[0]
        steps = MAIN_STEPS[(act-1)*6+stage-1] if qid.startswith('A') and kind=='main' else re.split('[、，；]',description)
        if kind=='side': steps = [x for x in steps if x][:3]
        if kind=='personal': steps = re.split('[、，]',description)[:3]
        if qid.startswith('P'): steps=[description]
        if qid=='E-M01': act,stage,steps=6,0,['回残灯营地报平安']
        quests[qid]={'id':qid,'title':title,'kind':kind,'act':act,'stage':stage,'requires':prerequisites,
                     'contact':cols[2] if kind=='side' else ('绯月' if qid.startswith('C-F') else '雪璃' if qid.startswith('C-X') else '鸦羽' if qid.startswith('C-Y') else ACTS[act-1][3][0]),
                     'description':description,'reward_text':cols[4],'steps':steps,'story':bodies[qid][1]}
    assert len(quests)==73
    main_order=[q for q in quests if quests[q]['kind']=='main']
    assert len(main_order)==40
    acts = [{'id':i+1,'title':a[0],'camp':a[1],'camp_id':'camp_'+a[2],'npcs':a[3],
             'maps':[{'id':f'a{i+1}_{j+1}','name':name,'layout':a[5][j]} for j,name in enumerate(a[4])],
             'boss':a[6],'boss_art':a[7]} for i,a in enumerate(ACTS)]
    exploration = [('落叶洞窟','旧守望墓室'),('灰炉暗道','弃置档案库'),('空晶支坑','矿底封室'),('枯枝地穴','失镜墓廊'),('潮下岩窟','沉锚墓室'),('避难排渠','王城旧藏库')]
    for i,act in enumerate(acts):
        for j,name in enumerate(exploration[i]):
            act['maps'].append({'id':f'a{i+1}_explore_{j+1}','name':name,'layout':'mine' if j==0 else 'crypt','optional':True})
    endings={}
    acts[0]['maps'].append({'id':'a1_castle_1','name':'灰棘旧堡','layout':'castle','optional':True,
        'description':'穿过门庭与废弃驻军庭院，探索军械西翼、书记东翼、拱顶大厅和升高的领主厅；取回遗落物资，击败守堡者后由传送阵返回。'})
    em = list(re.finditer(r'^### 结局([一二三]) · (.+)$',text,re.M))
    for i,m in enumerate(em):
        end=em[i+1].start() if i+1<len(em) else text.index('## 六地的后日谈',m.end())
        endings[m[1]]={'title':m[2],'story':text[m.end():end].strip()}
    history=text[text.index('## 故事前史'):text.index('## 序章')].strip()
    aftermath=text[text.index('## 六地的后日谈'):text.index('## 伏笔')].strip()
    data={'version':1,'acts':acts,'quests':quests,'main_order':main_order,'endings':endings,'history':history,'aftermath':aftermath}
    out=ROOT/'resources/story_content.json'
    out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print('Story content: 6 acts, 36 quest regions + 12 optional dungeon floors, 73 quests ->',out)


if __name__=='__main__': main()

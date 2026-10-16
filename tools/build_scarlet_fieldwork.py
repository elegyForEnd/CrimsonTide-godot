"""Build authored field interactions; does not modify the campaign or quest order."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Three inspectable details for every physical clue. Findings reveal only after scanning.
EVIDENCE = {
    "bootprints": ("trace", "靴跟压痕|三组深浅相近的靴跟印，行进间距整齐。", "车辙方向|靴印沿车轮轨迹延伸，没有散向林间。", "浅河岸线|河岸缺少同样的靴印，追兵没有涉水。"),
    "saddle": ("workbench", "扣面纹章|扣面有王庭信使的专用纹记。", "扣舌磨痕|磨痕新鲜，这副鞍具近日仍在使用。", "内侧泥痕|扣背留着尚未干透的浅河泥。"),
    "ledger": ("document", "涂改笔迹|厚墨盖住了一行换马费用。", "透光底字|从背面照亮，能读出王庭预付的字样。", "日期栏|账目记在昨夜，正好对应信使到达前后。"),
    "hoof": ("trace", "蹄缘沉积|蹄铁内缘积着浅灰色细泥。", "泥层颗粒|泥中细粒和浅河岸边的沉积相近。", "靴泥比对|与信使靴底泥色一致，河道路线可以互相印证。"),
    "medicine": ("medical", "箱体固定扣|先稳住箱盖，内层玻璃药瓶没有破裂。", "药瓶标签|标签是退热用药，封口仍完整。", "绷带夹层|夹层收纳干净绷带，没有武器零件。"),
    "medical_record": ("crystal", "晶面裂纹|血晶只有这一块，不能再剥离碎片。", "残留影像|影像对应一次医疗处置，画面没有后续记录。", "处置签认|女王当时清醒，并批准了秘密处置。"),
    "abbey_route": ("document", "侧院通路|一条侧院通路连接修院主厅。", "封锁标线|标线避开前门的封锁。", "传令匣注记|注记指向审判官本人，匣子不在普通仓库。"),
    "full_orders": ("document", "命令抬头|这是一份完整的王庭追缉命令。", "保护条款|明确要求绯月与她的剑不得受损。", "附加处置|其他知情者不在保护范围；必须把这一行一起保留。"),
    "seal_notice": ("document", "封条柜号|底稿存于西柜，不能只搜东台。", "台面记录|模具仍留在东台，可和底稿对照。", "保管签名|西柜钥匙由值班书记保管。"),
    "sword_plan": ("workbench", "剑柄轮廓|模型上剑柄封印与剑刃连成一体。", "剖面接缝|这里没有可安全粗拆的独立接缝。", "编号缺口|编号下的一栏被裁去，外部检验尚不足以下结论。"),
    "guard_roster": ("document", "轮班时段|南门有一段明确的换班空档。", "房间编号|医师所在房间标注为观察室。", "器具清单|该室没有刑具，和普通牢房的登记不同。"),
    "diagram_body": ("document", "原图题注|正文讨论的是血契转移通道。", "母晶编号|通道材料须来自同源母晶器。", "正文边注|这不是一般容器的替换，仍需核对缺页。"),
    "diagram_page": ("document", "装订切口|切口方向和正文装订边吻合。", "残留页码|页码为十七，不是普通用药页。", "解剖册夹页|被移走的一页夹在解剖册中，可与正文叠合。"),
    "surgery_book": ("document", "手术正文|正文说明契约能经同源母晶转移。", "缺页断口|涉及持剑继位条件的部分被抽走。", "目录比对|目录仍列着缺失条目，不能把缺页当成不存在。"),
    "arrow_supply": ("workbench", "箭簇制式|箭簇属于白垩军库的配给制式。", "军库印记|印记可以对回王庭军库。", "签领编号|对应签领人为维恩，和普通盗猎箭不同。"),
    "route_letter": ("document", "路线草图|路线与小队行进方向一致。", "保护条款|信中优先保护绯月及佩剑。", "处置条件|其他两人可处置，这不是单纯的求救信。"),
    "garden_traces": ("trace", "黑纱挂痕|黑纱痕迹延伸到王船接应口。", "去程足迹|去程是自行走动留下的足迹。", "返程拖痕|返回行宫的一段出现拖行痕迹，前后状态不同。"),
    "workshop_pass": ("document", "验收单正面|单据属于当晚药物验收。", "背面折痕|暗号写在单据背面，折叠后容易漏看。", "交接暗号|暗号对应工坊当晚交接，可用于通行。"),
    "dress_size": ("document", "最早日期|量体记录可追溯至十年前。", "尺寸改动|多次修改的尺寸记录属于同一人。", "最近修订|最后一次修改早于遗书，不能解释为临时安排。"),
    "dress_order": ("document", "衣装订单|订单列有加冕衣，而非普通礼服。", "同批模型|同一批订单包括同源剑柄模型。", "交付姓名|交付对象写着绯月，日期与尺寸页可相互核对。"),
    "detention": ("document", "箱底夹层|交接单藏在箱底，和箱面内容不同。", "收押去向|鸦羽被收押在庭院地下医室。", "物品分流|血契剑另存手术档案柜，并未随人移交。"),
    "contract_truth": ("document", "验收日期|这份验收单写于十年前，计划早已存在。", "继位条件|血亲持同源剑刺心会触发继位。", "解除目标|母晶只在仪式中开放；王冠、母晶、契印必须全部毁掉。"),
    "release_steps": ("document", "稳定记录|仪式开启后必须先稳住晶潮。", "王座内扣|第二步切断王座内扣，不能提前转刃。", "破晶毁印|再转刃破母晶，最后毁冠及契印。"),
    "timber": ("workbench", "木料编号|编号和船长保管的备用料相符。", "端面纹理|木料为耐水料，未见泡软断裂。", "尺寸比对|长度与截面正好适配转舵杆。"),
    "prison_hold": ("lock", "仓内隔断|押运仓被分成单独拘束区。", "拘束扣位|扣位用于限制行动，不是乘客扶手。", "押运标注|同行者标为另行处置，这里不是自由转乘点。"),
    "tide_low": ("trace", "昨夜刻线|石面保留昨夜最高潮线。", "新湿痕|新湿痕已经越过旧刻线。", "测尺记录|记下低岸的新水位，留作三点比对。"),
    "tide_mid": ("trace", "中堤刻度|中堤刻度附近出现新晶痕。", "增长方向|潮痕沿堤面继续升高。", "记录对照|增长方向与承载衰败记录相符。"),
    "tide_high": ("crystal", "高坡渗点|高坡原本干燥的位置开始渗晶。", "新晶边缘|边缘是新生晶层，并非旧沉积。", "三点比照|低岸、中堤和高坡一起说明灾难已超出当前港区。"),
    "vent_lock": ("lock", "外部验血盘|盘面把人引向正门验血程序。", "侧壁接缝|侧壁还有独立的检修扣。", "检修图比照|检修扣可绕过内锁，不必触碰验血盘。"),
    "lamp_glass": ("lamp", "玻璃边缘|碎片的弧度与提灯护罩接近。", "透光检查|中心没有穿透裂纹，仍可使用。", "护罩比对|尺寸适合修补缺口，须先磨平边缘。"),
    "remedy": ("medical", "旧药标签|旧药用途是抑晶，不能当作治愈药。", "替代配方|灰叶与温盐可替代王庭抑晶剂。", "试用批注|只能稳定旧伤，必须低剂量试用并记录反应。"),
    "gift_list": ("document", "未送封套|信件与礼物清单都没有寄出。", "礼物条目|清单写着为绯月缝制的一双手套。", "旧线针脚|保留旧针脚的位置，修补时不要拆散原缝线。"),
    "detention_names": ("document", "医师名册|名册保留被拘留者的姓名。", "门牌编号|三间拘留室门牌与名册相符。", "疏散标记|三间都没有完成疏散标记，需要逐一接人。"),
}

# prop | sequential operations | calibration step (-1 means sustained work only).
# Every node is authored explicitly so content changes cannot silently get generic gameplay.
OPERATIONS = {
    "R-P02:0": "cart|清开柜脚杂物|托住柜体重心|沿墙推开通道|-1",
    "R-1-01:1": "cart|解除车轮卡石|扶正车辕|将车推入西岔道|-1",
    "R-1-01:3": "trace|取湿布浸河水|沿刻痕擦除颜料|清走残留色泥|-1",
    "R-1-03:3": "medical|清点瓶签与绷带|重新扣紧药箱|交到村医接收处|-1",
    "R-1-04:0": "rope|套回松脱绳环|收紧桥索张力|固定保险绳结|1",
    "R-1-04:3": "lamp|清理灯槽遮挡|对准血晶折射角|锁定提灯支架|1",
    "R-1-05:2": "lock|托住笼门重量|退出变形锁舌|缓慢拉开笼门|1",
    "R-2-01:3": "lock|清开门后障碍|移开内侧门栓|固定庇护点内门|-1",
    "R-2-02:2": "lock|核对西柜编号|转动柜锁定位|托出底稿抽屉|1",
    "R-2-03:2": "lock|检查观察室门扣|松开内层锁舌|固定门扇留出通路|1",
    "R-2-05:0": "valve|检查压力表|缓缓回转总阀|锁住泄压销|1",
    "R-2-05:1": "valve|疏通排水格栅|调平两侧水压|升起排水门|1",
    "R-2-06:2": "lock|托住侧笼承重杆|卸下笼锁联动销|打开学徒逃生口|-1",
    "R-3-01:2": "rope|辨认侧路落脚点|试拉侧梯固定索|留下回撤绳标|1",
    "R-3-02:2": "rope|固定绯月侧支撑|找准捕猎索断点|切断索扣并收拢|1",
    "R-3-03:0": "valve|复位升降架棘爪|调平牵引轮|锁定载人踏板|1",
    "R-3-03:1": "valve|辨认毒雾进气管|回转排气阀|固定闭锁手柄|1",
    "R-3-05:1": "lamp|拆开信标护罩|等讯号回落后断线|封住残留光源|1",
    "R-3-05:3": "rope|解开侧梯挂扣|调整梯身张力|锁住下端支脚|1",
    "R-4-01:2": "lock|托住栅栏下沿|卸开锈蚀卡扣|平放栅栏露出暗沟|-1",
    "R-4-04:0": "medical|托稳受伤手臂|以灯光稳定呼吸|包扎固定伤口|1",
    "R-4-04:2": "lock|垫住刑具横梁|卸下承重销钉|移开刑具外架|1",
    "R-4-04:3": "rope|找出警报引线|压住绷紧簧片|切线并固定断端|1",
    "R-4-05:0": "lock|核对器械柜编号|打开保护扣锁|平托取出血契剑|1",
    "R-4-06:4": "valve|清理装卸道卡石|转动水道闸轮|固定开启限位|1",
    "R-5-01:2": "workbench|嵌入编号备用木料|校准舵杆中轴|拧紧两侧紧固件|1",
    "R-5-02:3": "rope|套住岸边承重环|拉紧救生主绳|加上第二道保险结|1",
    "R-5-02:5": "document|逐人核对接收名册|划分第一批登船者|确认最后一批有人接应|-1",
    "R-5-03:4": "valve|检查闸前民船位置|调平离港水位|升闸并固定限位|1",
    "R-5-05:2": "document|标出左侧弩机射界|叠合右侧射界|圈定共同盲区|-1",
    "R-5-05:3": "cart|绑紧船上诱饵|调整诱饵船朝向|松开牵索送入航道|1",
    "R-5-05:4": "rope|选择高处挂点|拉紧撤离标绳|固定迎岸一侧标志|1",
    "R-5-06:1": "rope|压住左舷弩臂|释放缆弩弦张力|卸下发射卡销|1",
    "R-5-06:2": "rope|压住右舷弩臂|释放缆弩弦张力|卸下发射卡销|1",
    "R-5-06:4": "valve|保持舵面居中|扣住锁舵限位|放开最后一批民船|1",
    "R-6-01:1": "cart|试探落石受力|移走外侧碎石|推开主石露出门槽|-1",
    "R-6-01:2": "valve|清开旧水门门槽|同步转动两侧闸轮|固定上行限位|1",
    "R-6-01:3": "rope|系牢墙顶主绳|调平绳梯两侧|固定岸边梯脚|1",
    "R-6-02:3": "lock|检查侧廊无人滞留|牵下隔断门|扣牢内侧限位|-1",
    "R-6-02:4": "lock|卸开内侧门锁|推开回营门|加上防回落支撑|-1",
    "R-6-03:1": "lock|检查侧门接应位置|卸开内层锁舌|撑住门扇让同伴通过|1",
    "R-6-03:2": "document|核对绯月所在位置|确认雪璃灯号|确认鸦羽接应位置|-1",
    "R-6-04:1": "lock|支撑外围护架|逐个卸下连接扣|沿墙放平护架|-1",
    "R-6-04:2": "lamp|架起提灯支座|对准母晶照明轴|锁定支点角度|1",
    "R-6-04:3": "rope|辨认王座内扣|找准长刀切入角|留下切入口标记|1",
    "R-6-04:4": "rope|检查回程固定点|试拉撤离绳张力|确认三人撤离方向|1",
    "S01:1": "lamp|磨平旧玻璃边缘|嵌合护罩缺口|压紧固定铜夹|1",
    "S01:2": "lamp|打开提灯遮光片|调平暗路光束|固定照明角度|1",
    "S02:2": "medical|按比例分取灰叶|缓慢加入温盐液|封存低剂量试制瓶|1",
    "S03:0": "valve|复位侧路制动杆|调平升降索轮|测试空载并锁住踏板|1",
    "S04:1": "workbench|对齐手套旧针脚|沿原线缝合缺口|收紧线头藏入内衬|1",
    "S05:0": "rope|套住岸边演练环|拉紧安全主绳|加系保险结|1",
    "S05:1": "lamp|擦净提灯灯面|对准模拟舱口|固定照明支架|1",
    "S05:2": "rope|托住演练索结|放松索结张力|解开绳结并收绳|1",
    "S06:2": "lock|按门牌复核拘留室|依次卸下联锁扣|撑开疏散通路|1",
    # Postgame warden bypass is also a physical interaction.
    "S06:1": "lock|清开拘留区门槽|卸开卡死门栓|撑开拘留区入口|1",
}


def build():
    campaign = json.loads((ROOT / "resources/scarlet/campaign.json").read_text(encoding="utf-8"))
    if campaign.get('screenplay'):
        from scarlet_screenplay_runtime import apply
        apply(campaign)
        return
    profiles = {}
    for quest in campaign["quests"].values():
        for node in quest["nodes"]:
            nid = node["id"]
            if node["kind"] == "clue":
                prop, *details = EVIDENCE[node["fact"]]
                parts = []
                for detail in details:
                    name, result = detail.split("|", 1)
                    parts.append(dict(name=name, instruction=f"仔细检查{name}，保留原物的状态。", result=result))
                profiles[nid] = dict(mode="survey", prop=prop, subtitle="观察 · 比对 · 留证", hint="三个部位都调查完毕后，才能将结论收入线索袋。", parts=parts, calibrate=-1)
            elif nid in OPERATIONS:
                prop, *operations, calibrate = OPERATIONS[nid].split("|")
                parts = [dict(name=name, instruction=f"{name}。保持操作，松开可暂歇。", result=f"已完成：{name}。") for name in operations]
                calibrate = int(calibrate)
                if calibrate >= 0:
                    parts[calibrate]["instruction"] = f"{operations[calibrate]}。观察指针，在青色安全区内确认，避免强行施力。"
                    parts[calibrate]["result"] = f"{operations[calibrate]}：受力稳定，可以继续。"
                challenge = "alignment" if prop in {"lamp", "workbench"} else "tension" if prop == "rope" else "timing"
                if calibrate >= 0 and challenge == "alignment":
                    parts[calibrate]["instruction"] = f"{operations[calibrate]}。按 A / D 或使用微调按钮，将指示线移入青色区间，再确认。"
                if calibrate >= 0 and challenge == "tension":
                    parts[calibrate]["instruction"] = f"{operations[calibrate]}。按住 E 收紧，在青色区间松开；过紧会回弹，可重新尝试。"
                profiles[nid] = dict(mode="procedure", prop=prop, subtitle="观察受力 · 依序操作 · 安全收尾", hint="安全顺序："+" → ".join(operations), parts=parts, calibrate=calibrate, challenge=challenge)
            elif node["kind"] == "mechanism":
                raise ValueError(f"Unauthored mechanism: {nid}")
    target = ROOT / "resources/scarlet/fieldwork.json"
    target.write_text(json.dumps(profiles, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(f"FIELDWORK: {len(profiles)} authored interactions / {sum(len(p['parts']) for p in profiles.values())} physical steps")


if __name__ == "__main__":
    build()

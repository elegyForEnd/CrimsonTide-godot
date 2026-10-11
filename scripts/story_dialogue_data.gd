extends RefCounted
## Presentation scripts retain the original prose; only explicit attributions name a speaker.
const HEROES := ["绯月","雪璃","鸦羽"]
const MAX_PAGE := 108
const PORTRAITS = preload("res://scripts/story_portrait_art.gd")
const EXPRESSION_CUES := {
	"静钟村还没有消息。":"worried","再等下去——":"determined",
	"它会去叫更多。":"determined","老人还在这里。":"worried",
	"你要去哪里？":"smile","我们也去。":"smile",
	"灯在这里。":"determined","链已经断了。一起。":"determined",
	"我们明天再去帮他们。":"determined","有些人后来没有明天。":"sad"
}
static func expression_for(page: Dictionary) -> String:
	var authored: String=page.get("expression","")
	if authored in PORTRAITS.EXPRESSIONS: return authored
	var line: String=str(page.get("text","")).trim_prefix("“").trim_suffix("”")
	return EXPRESSION_CUES.get(line,"neutral")
static func actor_for(person: String, content: Dictionary) -> String:
	var hero := HEROES.find(person)
	if hero>=0: return "hero:%d" % hero
	for act in content.acts:
		var index: int=act.npcs.find(person)
		if index>=0: return "npc:%d" % index
	return ""

static func paginate(text: String, speaker: String = "旁白") -> Array:
	var result: Array=[]
	while text.length()>MAX_PAGE:
		var end := MAX_PAGE
		for i in range(MAX_PAGE-1,MAX_PAGE/2,-1):
			if text[i] in ["。","！","？","；","，","”"]: end=i+1; break
		result.append({"speaker":speaker,"text":text.substr(0,end)})
		text=text.substr(end)
	if not text.is_empty(): result.append({"speaker":speaker,"text":text})
	return result

static func chapter(body: String, content: Dictionary) -> Array:
	var people: Array=HEROES.duplicate()
	for act in content.acts:
		for person in act.npcs:
			if not person in people: people.append(person)
	people.append("女王")
	var result: Array=[]
	for paragraph in body.split("\n",false):
		var cursor := 0
		while cursor<paragraph.length():
			var opening := paragraph.find("“",cursor)
			var closing := paragraph.find("”",opening+1) if opening>=0 else -1
			if opening<0 or closing<0:
				result.append_array(paginate(paragraph.substr(cursor))); break
			var lead := paragraph.substr(cursor,opening-cursor)
			if not lead.is_empty(): result.append_array(paginate(lead))
			var speaker := "旁白"
			var tail := paragraph.substr(closing+1,40)
			# Do not infer a speaker from nearby names in an unmarked narrative sentence.
			for person in people:
				if (lead.ends_with("：") and lead.contains(person)) or tail.begins_with(person+"说") or tail.begins_with(person+"问") or tail.begins_with("，"+person+"说"):
					speaker=person; break
			var pages := paginate(paragraph.substr(opening,closing-opening+1),speaker)
			for page in pages: page["actor"]=actor_for(speaker,content)
			result.append_array(pages)
			cursor=closing+1
	if result.is_empty(): result.append({"speaker":"旁白","text":"灯火还在。"})
	return result

static func npc(index: int, person: String, act: int, hero: int) -> Array:
	var lines := [
		"南门连着原野，沿小径能找到遗迹和传送阵。人们还在等着灯亮，我会替你们保留回来的路。",
		"先把灯放下，休息一会儿。你们不用把每一次伤都藏起来。",
		"工具和刃都要有人照顾。带回来的材料可以修复装备，也能让旧刃重新派上用场。",
		"记录是为了让后来的人看清发生过什么。这里保留着你们已查证的档案。",
		"药剂一直有备货。别为了带更多东西，把回来的力气也卖掉。",
		"放在这里的物品会保留下来。行囊满了，就先把不急用的东西交给我。"]
	var reply := ["我们会把消息带回来，也会把人带回来。","谢谢。今天先照顾好自己，再去照亮别人的路。","帮我看看刃口吧。这把剑还要陪我们走很远。","那就把他们的名字写下来。不要只留下战报。","给我们备一些补给吧。回来的时候，再聊一路上发生的事。","钥匙交给你。我们还会回来取的。"]
	var left := "hero:%d" % hero
	var right := "npc:%d" % index
	if act==1 and index==0:
		return [
			{"speaker":"旁白","text":"雷霆要塞的炉火低低响着。三人鞋边的湿泥还没有干，南门外的灯链在风里摇晃。","left":left,"right":right},
			{"speaker":person,"text":"先吃。","left":left,"right":right},
			{"speaker":"绯月","text":"静钟村还没有消息。","left":"hero:0","right":right},
			{"speaker":person,"text":"我知道。","left":"hero:0","right":right},
			{"speaker":"绯月","text":"再等下去——","left":"hero:0","right":right},
			{"speaker":person,"text":"汤也不用等天亮才喝。一会儿要走路，先让腿有力气。","left":"hero:0","right":right},
			{"speaker":"旁白","text":"岑烬把碗递过去，另一只手摊开南门的巡路图。通往静钟村的路上，最后一盏灯还没有熄灭。","left":"hero:0","right":right},
			{"speaker":person,"text":lines[0],"left":"hero:0","right":right}]
	return [{"speaker":person,"text":lines[index],"left":left,"right":right},{"speaker":HEROES[hero],"text":reply[index],"left":left,"right":right,"expression":["determined","smile","smile","sad","smile","smile"][index]}]

extends Node
## Actual paused campaign dialogue; temporary preview state never saves.
const Art = preload("res://scripts/story_portrait_art.gd")
var app
var screen
var hero := 0
var clothing := 0
var gesture := 0
var captured := false
var keys: Node
var examples := [
	"灯还亮着。我们回来了。","能够再见到你，真好。","今天带回来的消息，会让大家高兴一些吧。",
	"别这样看着我……我只是把心里想的说出来。","那边的灯灭了。我有些担心还没有回来的人。",
	"我记得他们的名字。那些名字不该只留在战报里。","够了。不要拿他们的生命当作可以抹去的数字。",
	"原来……那封信一直都在这里？"]
class Keys extends Node:
	var receiver: Callable
	func _input(event: InputEvent) -> void:
		if receiver.is_valid(): receiver.call(event)
func _ready() -> void:
	var window := get_tree().root
	window.size=Vector2i(1440,900); window.content_scale_size=window.size
	app.profile.path="user://portrait-preview-profile.json"
	app.go_story("user://portrait-preview-campaign.json"); screen=app.story_screen
	screen.campaign.save_enabled=false; screen.campaign.state=screen.campaign.new_state(); screen.campaign.enter(1,0)
	keys=Keys.new(); keys.receiver=key; get_tree().root.add_child.call_deferred(keys)
	show_portrait()
	if "--capture-portraits-release" in OS.get_cmdline_user_args(): capture_release.call_deferred()
func show_portrait() -> void:
	var pages: Array=[]
	for i in Art.EXPRESSIONS.size():
		pages.append({"speaker":["绯月","雪璃","鸦羽"][hero],"text":examples[i],"actor":"hero:%d" % hero,"left":"hero:%d" % hero,"right":"",
			"expression":Art.EXPRESSIONS[i],"costume":Art.COSTUMES[clothing],"pose":Art.POSES[gesture]})
	# Preview uses the same persistent outfit selector as real conversation, without saving.
	screen.dialogue_outfits["hero:%d" % hero]=Art.COSTUMES[clothing]
	screen.show_dialogue("灯下肖像 · 1/2/3 角色 · 左右服饰 · 上下姿态",pages)
func key(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode in [KEY_1,KEY_2,KEY_3]: hero=int(event.keycode)-int(KEY_1); show_portrait(); get_tree().root.set_input_as_handled()
	if event.keycode in [KEY_LEFT,KEY_RIGHT]:
		clothing=posmod(clothing+(-1 if event.keycode==KEY_LEFT else 1),Art.COSTUMES.size()); show_portrait(); get_tree().root.set_input_as_handled()
	if event.keycode in [KEY_UP,KEY_DOWN]:
		gesture=posmod(gesture+(-1 if event.keycode==KEY_UP else 1),Art.POSES.size());show_portrait();get_tree().root.set_input_as_handled()

func capture_release() -> void:
	for i in 50: await get_tree().process_frame
	for code in [KEY_3,KEY_RIGHT,KEY_RIGHT,KEY_DOWN,KEY_DOWN]:
		var down := InputEventKey.new();down.keycode=code;down.pressed=true;Input.parse_input_event(down);await get_tree().process_frame
		var up := InputEventKey.new();up.keycode=code;Input.parse_input_event(up);await get_tree().process_frame
	if hero!=2 or clothing!=2 or gesture!=2:push_error("Portrait preview keyboard routing failed");get_tree().quit(1);return
	screen.dialogue.index=2; screen.dialogue.show_page(); screen.dialogue.reveal_all()
	for i in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var target: String=OS.get_executable_path().get_base_dir().get_base_dir().path_join("build/vn-full-native-v14.png")
	var error := get_viewport().get_texture().get_image().save_png(target)
	print("VN_FULL_RELEASE_CAPTURE hero=2 outfit=travel pose=crossed expression=joy error=",error)
	get_tree().quit(error)

func _exit_tree() -> void:
	if is_instance_valid(keys): keys.queue_free()

extends Control

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const ADVICE_HOLD_SECONDS := 4.5

enum Phase { ADVICE, VIDEO, DONE }

@onready var advice: VBoxContainer = $Advice
@onready var video: VideoStreamPlayer = $VideoFrame/Video

var phase := Phase.ADVICE
var transitioning := false


func _ready() -> void:
	# Preview and screenshot test launches should keep reaching the requested game page.
	var args := OS.get_cmdline_user_args()
	if "--skip-intro" in args or "--capture" in args or _has_preview_argument(args):
		_enter_game()
		return
	play_advice()


func play_advice() -> void:
	phase = Phase.ADVICE
	advice.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(advice, "modulate:a", 1.0, 0.8)
	tween.tween_interval(ADVICE_HOLD_SECONDS)
	tween.tween_property(advice, "modulate:a", 0.0, 0.8)
	await tween.finished
	if phase == Phase.ADVICE:
		_start_video()


func _start_video() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.VIDEO
	advice.hide()
	video.show()
	video.play()


func _on_video_finished() -> void:
	_enter_game()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_enter_game()
	elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if phase == Phase.ADVICE:
			_start_video()
		elif phase == Phase.VIDEO:
			_enter_game()
	get_viewport().set_input_as_handled()


func _enter_game() -> void:
	if transitioning:
		return
	transitioning = true
	phase = Phase.DONE
	video.stop()
	get_tree().call_deferred("change_scene_to_packed", MAIN_SCENE)


func _has_preview_argument(args: PackedStringArray) -> bool:
	for arg in args:
		if arg.begins_with("--preview-"):
			return true
	return false

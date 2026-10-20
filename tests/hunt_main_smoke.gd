extends SceneTree
## 编译冒烟：把 main.gd 及其依赖全部解析一遍，确认深潜接线没有把主场景弄坏。
const MainScript = preload("res://scripts/main.gd")

func _initialize() -> void:
	print("MAIN SCRIPT LOADED: ", MainScript != null)
	quit()

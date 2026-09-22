class_name Profile
extends RefCounted

var data: Dictionary = {"version":1,"name":"守夜人","coins":160,"xp":0,"runs":0,"extracts":0,"hero":0,"gear":0,"talents":[0,0,0],"volume":0.65,"fullscreen":false,"best":0}
var path := "user://profile.json"

func load_profile() -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.get("version",0) == 1:
		for key in data:
			if parsed.has(key) and typeof(parsed[key]) == typeof(data[key]):
				data[key] = parsed[key]
		# JSON numbers are floats, while defaults contain integers.
		for key in ["coins","xp","runs","extracts","hero","gear","best"]:
			if parsed.get(key) is float or parsed.get(key) is int:
				data[key] = maxi(0,int(parsed[key]))
		data.hero = clampi(data.hero,0,2)
		data.gear = clampi(data.gear,0,2)
		if data.talents.size() != 3:
			data.talents = [0,0,0]
		for i in 3:
			data.talents[i] = clampi(int(data.talents[i]),0,5)

func save_profile() -> void:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data,"\t"))
		file.close()
		DirAccess.rename_absolute(path+".tmp",path)

func level() -> int:
	return 1 + int(data.xp / 180)

func upgrade(index: int) -> bool:
	var cost := 80 + int(data.talents[index])*65
	if data.coins < cost or data.talents[index] >= 5:
		return false
	data.coins -= cost
	data.talents[index] += 1
	save_profile()
	return true

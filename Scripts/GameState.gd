extends Node

const SAVE_PATH = "user://savegame.json"

func save_game():
	print(">>> [GameState] 저장 시작...")
	var save_data = { "units": [] }
	
	var nodes = get_tree().get_nodes_in_group("persist")
	if nodes.is_empty():
		var main_scene = get_tree().current_scene
		for child in main_scene.get_children():
			if child is GameUnit:
				nodes.append(child)
	
	for unit in nodes:
		if unit.has_method("get_save_data"):
			var data = unit.get_save_data()
			if "grid_pos" in unit:
				data["grid_x"] = unit.grid_pos.x
				data["grid_y"] = unit.grid_pos.y
				save_data["units"].append(data)
	
	_write_to_file(save_data)
	print(">>> 저장 완료 (유닛 %d개)" % save_data["units"].size())

func load_game():
	print(">>> [GameState] 로드 시작...")
	var data = _read_from_file()
	if data == null: 
		print("!!! 세이브 파일이 없습니다.")
		return
	
	# 맵 초기화
	if GameManager.has_method("clear_map"):
		GameManager.clear_map()
	
	# 유닛 재생성
	var unit_list = data.get("units", [])
	for u_data in unit_list:
		var pos = Vector2i(u_data["grid_x"], u_data["grid_y"])
		var type_str = u_data.get("type", "ENEMY")
		
		# [수정] 상수로 변경
		var type_id = GameManager.TYPE_ENEMY
		if type_str == "PLAYER": 
			type_id = GameManager.TYPE_PLAYER
		
		GameManager.spawn_unit(type_id, 1, pos, u_data)
	
	print(">>> 로드 완료")

func _write_to_file(data):
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func _read_from_file():
	if not FileAccess.file_exists(SAVE_PATH): return null
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		return json.get_data()
	return null

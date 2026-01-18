extends Node

const SAVE_PATH = "user://savegame.json"

# -------------------------------------------------------------------------
# [저장] 현재 게임 상태 스냅샷 저장
# -------------------------------------------------------------------------
func save_game():
	print(">>> 저장 시작...")
	var save_data = { "units": [] }
	
	# GameManager의 units 순회
	for grid_pos in GameManager.units:
		var unit = GameManager.units[grid_pos]
		
		# 유닛 데이터 추출 (Player.gd / Enemy.gd 의 get_save_data 호출)
		if is_instance_valid(unit) and unit.has_method("get_save_data"):
			var data = unit.get_save_data()
			
			# 위치 정보 추가 (필수)
			data["grid_x"] = grid_pos.x
			data["grid_y"] = grid_pos.y
			
			save_data["units"].append(data)
	
	_write_to_file(save_data)
	print(">>> 저장 완료! (유닛 수: %d)" % save_data["units"].size())

# -------------------------------------------------------------------------
# [로드] 파일 읽어서 복구
# -------------------------------------------------------------------------
func load_game():
	print(">>> 로드 시작...")
	var data = _read_from_file()
	if data == null: 
		print("!!! 세이브 파일이 없습니다.")
		return
	
	# 1. 현재 맵 초기화 (모든 유닛 삭제)
	GameManager.clear_all_units()
	
	# 2. 유닛 재생성
	var unit_list = data.get("units", [])
	for u_data in unit_list:
		var pos = Vector2i(u_data["grid_x"], u_data["grid_y"])
		var type_str = u_data.get("type", "ENEMY")
		
		# 타입 결정
		var type_enum = GameManager.UnitType.ENEMY
		if type_str == "PLAYER": type_enum = GameManager.UnitType.PLAYER
		
		# 생성 요청 (로드 데이터 포함)
		GameManager.spawn_unit(type_enum, 1, pos, u_data)
	
	print(">>> 로드 완료! (생성된 유닛 수: %d)" % unit_list.size())

# [내부] 파일 쓰기
func _write_to_file(data):
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

# [내부] 파일 읽기
func _read_from_file():
	if not FileAccess.file_exists(SAVE_PATH): return null
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		return json.get_data()
	return null

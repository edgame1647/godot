extends Node
# [Autoload 이름: GameState]

const SAVE_PATH = "user://savegame.json"

# [저장] 딕셔너리를 받아 파일로 저장
func save_to_file(data: Dictionary):
	print(">>> [GameState] 파일 쓰기 시작: ", SAVE_PATH)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(data, "\t")
		file.store_string(json_str)
		file.close()
		print(">>> [GameState] 파일 저장 성공.")
	else:
		push_error("!!! [GameState] 파일 저장 실패: " + str(FileAccess.get_open_error()))

# [로드] 파일을 읽어 딕셔너리로 반환
func load_from_file() -> Dictionary:
	print(">>> [GameState] 파일 읽기 시작: ", SAVE_PATH)
	if not FileAccess.file_exists(SAVE_PATH):
		print("!!! [GameState] 세이브 파일이 없습니다.")
		return {}
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			print(">>> [GameState] JSON 파싱 성공.")
			return json.get_data()
		else:
			push_error("!!! [GameState] JSON 파싱 오류: " + json.get_error_message())
	
	return {}

extends Node2D

func _ready():
	# Y-Sort 활성화 (위아래 겹침 문제 해결)
	y_sort_enabled = true
	
	print("=== 게임 시작! 유닛 배치 중... ===")
	
	# 초기 유닛 생성
	# 중복된 좌표(예: 3,1에 두 번 생성 시도)가 있어도 GameManager에서 차단됩니다.
	GameManager.spawn_unit(GameManager.UnitType.PLAYER, 1, Vector2i(0, 0))
	
	GameManager.spawn_unit(GameManager.UnitType.ENEMY, 1, Vector2i(3, 1))
	GameManager.spawn_unit(GameManager.UnitType.ENEMY, 1, Vector2i(5, 1))
	GameManager.spawn_unit(GameManager.UnitType.ENEMY, 1, Vector2i(10, 2))
	GameManager.spawn_unit(GameManager.UnitType.ENEMY, 1, Vector2i(0, 1))

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			# [저장]
			KEY_F9:
				print("[Input] F9 -> 저장")
				GameState.save_game()
			
			# [로드]
			KEY_F12:
				print("[Input] F12 -> 로드")
				
				# 1. 현재 맵의 모든 유닛과 A* 그리드 정보를 완전히 날려버림
				GameManager.clear_all_units()
				
				# 2. 그 빈 공간에 세이브 파일의 내용을 채워넣음
				GameState.load_game()
			
			# [테스트] 마우스 위치에 적 생성
			KEY_G:
				_spawn_enemy_at_mouse()

func _spawn_enemy_at_mouse():
	var mouse_pos = get_global_mouse_position()
	var grid_pos = GameManager.world_to_grid(mouse_pos)
	
	# 이미 있으면 GameManager 내부에서 "중복" 로그 띄우고 생성 안 함
	GameManager.spawn_unit(GameManager.UnitType.ENEMY, 1, grid_pos)

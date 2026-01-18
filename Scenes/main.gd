extends Node2D

func _ready():
	y_sort_enabled = true
	print("=== [Main] 게임 시작 ===")
	
	# 초기 유닛 배치는 여기서 담당
	_spawn_initial_units()

func _spawn_initial_units():
	# 플레이어 생성
	GameManager.spawn_unit(GameManager.TYPE_PLAYER, 1, Vector2i(0, 0))
	
	# 적들 생성 (이 위치가 각 적의 spawn_grid가 됨)
	var enemy_positions = [
		Vector2i(3, 1),
		Vector2i(5, 1),
		Vector2i(10, 2),
		Vector2i(0, 1)
	]
	
	for pos in enemy_positions:
		GameManager.spawn_unit(GameManager.TYPE_ENEMY, 1, pos)

func _input(event):
	if not event is InputEventKey or not event.pressed:
		return
		
	match event.keycode:
		KEY_F9:
			print("[Input] F9: 저장 요청")
			# [변경] GameManager에게 요청
			GameManager.request_save_game()
		
		KEY_F12:
			print("[Input] F12: 로드 요청")
			# [변경] GameManager에게 요청
			GameManager.request_load_game()
			
		KEY_G:
			_spawn_enemy_at_mouse()

func _spawn_enemy_at_mouse():
	var grid_pos = GameManager.world_to_grid(get_global_mouse_position())
	GameManager.spawn_unit(GameManager.TYPE_ENEMY, 1, grid_pos)

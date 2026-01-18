extends Node2D

func _ready():
	y_sort_enabled = true
	print("=== [Main] 게임 시작: 유닛 배치 ===")
	_spawn_initial_units()

func _spawn_initial_units():
	# [수정] 상수로 변경된 타입 사용
	GameManager.spawn_unit(GameManager.TYPE_PLAYER, 1, Vector2i(0, 0))
	
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
			GameState.save_game()
		
		KEY_F12:
			print("[Input] F12: 로드 요청")
			_handle_load_game()
			
		KEY_G:
			_spawn_enemy_at_mouse()

func _handle_load_game():
	GameManager.clear_map()
	GameState.load_game()

func _spawn_enemy_at_mouse():
	var grid_pos = GameManager.world_to_grid(get_global_mouse_position())
	GameManager.spawn_unit(GameManager.TYPE_ENEMY, 1, grid_pos)

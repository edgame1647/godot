extends Node2D

func _ready():
	print("게임 시작! 플레이어 생성 중...")
	
	# 초기 유닛 생성
	GameManager.spawn_unit(GameManager.UnitType.PLAYER, 1, Vector2i(0, 0))
	GameManager.spawn_unit(GameManager.UnitType.ENEMY, 1, Vector2i(3, 1))
	GameManager.spawn_unit(GameManager.UnitType.ENEMY, 1, Vector2i(5, 1))
	GameManager.spawn_unit(GameManager.UnitType.ENEMY, 1, Vector2i(10, 2))
	GameManager.spawn_unit(GameManager.UnitType.ENEMY, 1, Vector2i(0, 1))

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F9:
			print("[Input] F9 눌림 -> 저장 시도")
			GameState.save_game()
			
		elif event.keycode == KEY_F12:
			print("[Input] F12 눌림 -> 로드 시도")
			GameState.load_game()

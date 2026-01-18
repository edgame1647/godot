extends Node

# [설정]
# 한 프레임당 업데이트할 적의 수입니다.
@export var updates_per_frame: int = 3

# [내부 변수]
var _current_enemy_index: int = 0
var _reserved_slots: Dictionary = {} 

# 주변 8방향 오프셋
const SURROUND_OFFSETS = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

func _process(_delta: float):
	if get_tree().paused: return
	_update_enemies_chunk()

func _update_enemies_chunk():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	var target_player = players[0] as Node2D
	var player_grid = GameManager.world_to_grid(target_player.global_position)
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty(): return
	
	var processed_count = 0
	var total_enemies = enemies.size()
	
	while processed_count < updates_per_frame:
		_current_enemy_index = (_current_enemy_index + 1) % total_enemies
		
		if _current_enemy_index == 0:
			_reserved_slots.clear()
			
		var node = enemies[_current_enemy_index]
		
		if is_instance_valid(node) and not _is_dead(node):
			var enemy = node as Enemy
			if enemy:
				_process_single_enemy(enemy, target_player, player_grid)
		
		processed_count += 1
		if processed_count >= total_enemies:
			break

func _process_single_enemy(enemy: Enemy, target_player: Node2D, player_grid: Vector2i):
	# [핵심 수정] 픽셀 거리 대신 '그리드 좌표 거리'를 사용합니다.
	var enemy_grid = GameManager.world_to_grid(enemy.global_position)
	
	# Chebyshev Distance (체비쇼프 거리): 
	# 대각선 이동도 1칸으로 치는 계산법 (킹의 이동 범위와 동일)
	# dx, dy 중 더 큰 값이 실제 타일 거리입니다.
	var dx = abs(enemy_grid.x - player_grid.x)
	var dy = abs(enemy_grid.y - player_grid.y)
	var distance_in_tiles = max(dx, dy)
	
	# 이제 distance_in_tiles는 정확히 1, 2, 3 정수로 떨어집니다.
	var can_see = ("detection_range" in enemy and distance_in_tiles <= enemy.detection_range)
	var is_chasing = false
	
	# --- 추적 및 행동 결정 ---
	if can_see:
		if "give_up_time" in enemy:
			enemy.chase_timer = enemy.give_up_time
		is_chasing = true
	elif "chase_timer" in enemy and enemy.chase_timer > 0:
		is_chasing = true
	
	if is_chasing:
		# [수정] 정확한 정수 거리 비교 (이제 바로 옆에 있으면 1 <= 1 이 되어 True가 됨)
		if "attack_range" in enemy and distance_in_tiles <= enemy.attack_range:
			enemy.execute_attack(target_player)
		else:
			# 사거리에 닿지 않으면 이동
			var best_slot = _find_best_surround_slot(player_grid, enemy, _reserved_slots)
			var target_pos = Vector2.ZERO
			
			if best_slot != Vector2i.MAX:
				target_pos = GameManager.grid_to_world(best_slot)
				_reserved_slots[best_slot] = true
			else:
				target_pos = target_player.global_position
			
			enemy.execute_move(target_pos)
	else:
		if enemy.has_method("execute_patrol"):
			enemy.execute_patrol()

func _is_dead(unit) -> bool:
	if "current_state" in unit and unit.current_state == BaseUnit.State.DIE: return true
	return false

func _find_best_surround_slot(center_grid: Vector2i, enemy: Node2D, reserved: Dictionary) -> Vector2i:
	var enemy_grid = GameManager.world_to_grid(enemy.global_position)
	var best_slot = Vector2i.MAX
	var min_dist = 99999.0
	
	for offset in SURROUND_OFFSETS:
		var slot = center_grid + offset
		
		# 예약된 슬롯 패스
		if reserved.has(slot): continue
		# 벽인 곳 패스
		if not GameManager.is_walkable(slot): continue
		
		var d = Vector2(slot - enemy_grid).length_squared()
		if d < min_dist:
			min_dist = d
			best_slot = slot
			
	return best_slot

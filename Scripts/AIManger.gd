extends Node

# [설정]
@export var update_interval: float = 0.2

var _timer: float = 0.0

# 주변 8방향 오프셋 (포위 공격용)
const SURROUND_OFFSETS = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

func _process(delta: float):
	if get_tree().paused: return

	_timer += delta
	if _timer < update_interval:
		return
	
	_timer = 0.0
	_update_all_enemies()

func _update_all_enemies():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	var target_player = players[0] as Node2D
	var player_grid = GameManager.world_to_grid(target_player.global_position)
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	var valid_enemies = []
	
	for node in enemies:
		if is_instance_valid(node) and not _is_dead(node):
			valid_enemies.append(node)
	
	# 가까운 적부터 정렬
	valid_enemies.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(target_player.global_position) < \
			   b.global_position.distance_squared_to(target_player.global_position)
	)

	var reserved_slots = {} 

	for node in valid_enemies:
		# [핵심 수정] 타입을 Enemy로 명시하여 변수 접근 오류 해결
		var enemy = node as Enemy 
		if not enemy: continue # Enemy 스크립트가 없는 객체면 패스
		
		var dist = enemy.global_position.distance_to(target_player.global_position)
		var grid_dist = dist / 32.0
		
		var can_see = ("detection_range" in enemy and grid_dist <= enemy.detection_range)
		var is_chasing = false
		
		# 추적 로직 (변수 접근 안전하게 처리)
		if can_see:
			if "give_up_time" in enemy:
				enemy.chase_timer = enemy.give_up_time
			is_chasing = true
		elif "chase_timer" in enemy and enemy.chase_timer > 0:
			is_chasing = true
		
		# --- 행동 결정 ---
		if is_chasing:
			if "attack_range" in enemy and grid_dist <= enemy.attack_range:
				enemy.execute_attack(target_player)
			else:
				# 포위 이동 로직
				var best_slot = _find_best_surround_slot(player_grid, enemy, reserved_slots)
				var target_pos = Vector2.ZERO
				
				if best_slot != Vector2i.MAX:
					target_pos = GameManager.grid_to_world(best_slot)
					reserved_slots[best_slot] = true
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
		if reserved.has(slot): continue
		
		var d = Vector2(slot - enemy_grid).length_squared()
		if d < min_dist:
			min_dist = d
			best_slot = slot
			
	return best_slot

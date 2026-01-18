extends Node
# [Autoload 이름: AIManager]

@export var tactic_update_interval: float = 0.5
var _tactic_timer: float = 0.0

var _player: Player = null

func _process(delta):
	if not is_instance_valid(_player):
		_find_player()
		return

	# 1. [실시간 로직] 모든 적의 상태/공격/타이머 관리 (매 프레임)
	_update_enemies_state(delta)

	# 2. [전술 이동] 길찾기 및 포위망 계산 (부하를 줄이기 위해 간격 두고 실행)
	_tactic_timer -= delta
	if _tactic_timer <= 0:
		_tactic_timer = tactic_update_interval
		_update_enemy_moves()

func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Player

# -------------------------------------------------------------------------
# [실시간 로직] 상태 판단, 타이머, 공격 (매 프레임 실행)
# -------------------------------------------------------------------------
func _update_enemies_state(delta: float):
	var enemies = get_tree().get_nodes_in_group("enemy")
	var player_grid = GameManager.world_to_grid(_player.global_position)
	
	for node in enemies:
		var enemy = node as Enemy
		if not is_instance_valid(enemy): continue
		if enemy.current_state == GameUnit.State.DIE: continue
		
		# 거리 계산
		var enemy_grid = GameManager.world_to_grid(enemy.global_position)
		var dist = _get_grid_distance(enemy_grid, player_grid)
		
		# --- A. 공격 판단 ---
		# 쿨타임 체크 & 사거리 체크 & 상태 체크
		if enemy.attack_timer <= 0 and \
		   dist <= enemy.attack_range and \
		   not enemy.is_returning and \
		   enemy.current_state != GameUnit.State.ATTACK:
			
			enemy.execute_attack(_player) # 공격 명령!
			continue # 공격했으면 다른 판단 생략
		
		# --- B. 추적 타이머 및 복귀 판단 ---
		if dist <= enemy.detection_range:
			# 감지 범위 내: 복귀 중이 아니면 타이머 리셋
			if not enemy.is_returning:
				enemy.chase_timer = enemy.give_up_time
		else:
			# 감지 범위 밖: 타이머 감소
			if not enemy.is_returning:
				enemy.chase_timer -= delta
				if enemy.chase_timer <= 0:
					print("[AI] Enemy(%s) 추적 포기 -> 복귀 모드" % enemy.name)
					enemy.is_returning = true
					enemy.execute_stop() # 이동 중단 명령

		# --- C. 복귀 완료 판단 ---
		if enemy.is_returning:
			if enemy_grid == enemy.spawn_grid:
				print("[AI] Enemy(%s) 복귀 완료 -> 순찰 대기" % enemy.name)
				enemy.is_returning = false
				enemy.chase_timer = enemy.give_up_time

# -------------------------------------------------------------------------
# [전술 이동] 길찾기 및 위치 배정 (0.5초마다 실행)
# -------------------------------------------------------------------------
func _update_enemy_moves():
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty(): return
	
	var player_grid = GameManager.world_to_grid(_player.global_position)
	
	# 추적 모드인 적의 수 계산 (포위망 계산용)
	var chasing_count = 0
	for node in enemies:
		var e = node as Enemy
		if is_instance_valid(e) and not e.is_returning:
			var d = _get_grid_distance(GameManager.world_to_grid(e.global_position), player_grid)
			if d <= e.detection_range:
				chasing_count += 1
	
	var surround_slots = []
	if chasing_count > 0:
		surround_slots = _get_expanded_surround_slots(player_grid, chasing_count)
	
	# 각 적에게 이동 명령 하달
	for node in enemies:
		var enemy = node as Enemy
		if not is_instance_valid(enemy): continue
		if enemy.current_state == GameUnit.State.DIE: continue
		
		# 공격 중이면 이동 명령 X
		if enemy.current_state == GameUnit.State.ATTACK: continue

		var enemy_grid = GameManager.world_to_grid(enemy.global_position)
		var dist_to_player = _get_grid_distance(enemy_grid, player_grid)
		
		# [CASE 1] 복귀 모드
		if enemy.is_returning:
			enemy.is_patrolling = false
			var spawn_pos = GameManager.grid_to_world(enemy.spawn_grid)
			enemy.execute_move(spawn_pos) # 명령
			continue
			
		# [CASE 2] 추적 모드 (감지 범위 내 & 사거리 밖)
		if dist_to_player <= enemy.detection_range and dist_to_player > enemy.attack_range:
			
			# 순찰 중이었다면 즉시 중단
			if enemy.mover and enemy.mover.is_moving and enemy.is_patrolling:
				print("[AI] 순찰 중 적 발견 -> 추적 전환")
				enemy.execute_stop() 
			
			# 이동 중이면 간섭 X (이미 추적 경로로 가고 있음)
			if enemy.mover and enemy.mover.is_moving:
				continue
				
			if not surround_slots.is_empty():
				var best_slot = _find_closest_slot(enemy_grid, surround_slots)
				var world_pos = GameManager.grid_to_world(best_slot)
				
				enemy.is_patrolling = false
				enemy.execute_move(world_pos) # 명령
				surround_slots.erase(best_slot)
			continue
		
		# [CASE 3] 순찰 모드 (할 일 없을 때)
		if dist_to_player > enemy.detection_range:
			if enemy.mover and enemy.mover.is_moving: continue
			
			if randf() < 0.3: # 30% 확률로 순찰
				_command_patrol_move(enemy)

# -------------------------------------------------------------------------
# [내부 유틸리티]
# -------------------------------------------------------------------------
func _command_patrol_move(enemy: Enemy):
	var center = enemy.spawn_grid
	var radius = enemy.patrol_radius
	
	var rand_x = randi_range(-radius, radius)
	var rand_y = randi_range(-radius, radius)
	var target_grid = center + Vector2i(rand_x, rand_y)
	
	if _is_slot_valid(target_grid, Vector2i(-999, -999)):
		var world_pos = GameManager.grid_to_world(target_grid)
		enemy.is_patrolling = true
		enemy.execute_move(world_pos)

func _get_expanded_surround_slots(center: Vector2i, count_needed: int) -> Array[Vector2i]:
	var slots: Array[Vector2i] = []
	var radius = 1
	var max_radius = 8
	while slots.size() < count_needed and radius <= max_radius:
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				if max(abs(x), abs(y)) == radius:
					var check_pos = center + Vector2i(x, y)
					if _is_slot_valid(check_pos, center):
						slots.append(check_pos)
		radius += 1
	return slots

func _is_slot_valid(pos: Vector2i, center_to_ignore: Vector2i) -> bool:
	if not GameManager.is_walkable(pos): return false
	if GameManager.is_occupied(pos) and pos != center_to_ignore: return false
	return true

func _find_closest_slot(start: Vector2i, slots: Array[Vector2i]) -> Vector2i:
	var best_slot = slots[0]
	var min_dist = 9999
	for slot in slots:
		var d = _get_grid_distance(start, slot)
		if d < min_dist:
			min_dist = d
			best_slot = slot
	return best_slot

func _get_grid_distance(p1: Vector2i, p2: Vector2i) -> int:
	return max(abs(p1.x - p2.x), abs(p1.y - p2.y))

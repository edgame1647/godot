extends Node

# Autoload 이름: AIManager

@export var update_interval: float = 0.2
var _timer: float = 0.0

var _player: Player = null

func _process(delta):
	if not is_instance_valid(_player):
		_find_player()
		return

	_timer -= delta
	if _timer <= 0:
		_timer = update_interval
		_update_enemy_tactics()

func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Player

# -------------------------------------------------------------------------
# [전술 로직]
# -------------------------------------------------------------------------
func _update_enemy_tactics():
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty(): return
	
	var player_grid = GameManager.world_to_grid(_player.global_position)
	
	# [수정] 필요한 슬롯 개수는 적의 수만큼 (넉넉하게)
	var needed_slots = enemies.size()
	
	# 1. 적의 수만큼 충분한 빈 자리를 확장해서 찾음
	var surround_slots = _get_expanded_surround_slots(player_grid, needed_slots)
	
	# 2. 적들에게 명령 하달
	for node in enemies:
		var enemy = node as Enemy
		if not is_instance_valid(enemy): continue
		if enemy.current_state == GameUnit.State.DIE: continue
		
		var enemy_grid = GameManager.world_to_grid(enemy.global_position)
		var dist = _get_grid_distance(enemy_grid, player_grid)
		
		# 사거리 안이면 패스
		if dist <= enemy.attack_range:
			continue
		
		# 이미 이동 중이면 패스
		if enemy.mover and enemy.mover.is_moving:
			continue
			
		if not surround_slots.is_empty():
			var best_slot = _find_closest_slot(enemy_grid, surround_slots)
			var world_pos = GameManager.grid_to_world(best_slot)
			
			enemy.ai_move_to(world_pos)
			
			# 자리 배정 완료 (목록에서 제거)
			surround_slots.erase(best_slot)

# -------------------------------------------------------------------------
# [유틸리티] 확장형 빈 자리 계산 (핵심 수정)
# -------------------------------------------------------------------------
func _get_expanded_surround_slots(center: Vector2i, count_needed: int) -> Array[Vector2i]:
	var slots: Array[Vector2i] = []
	var radius = 1
	var max_radius = 6 # 최대 6칸 범위까지 확장 (적당히 조절)
	
	# 필요한 개수를 채우거나, 최대 반경에 도달할 때까지 반복
	while slots.size() < count_needed and radius <= max_radius:
		
		# 현재 radius의 테두리(Perimeter) 좌표들을 검사
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				
				# 테두리(껍질) 부분만 검사 (내부는 이미 이전 루프에서 검사했거나 플레이어 위치임)
				# 체비쇼프 거리 기준으로 링 모양을 만듦
				if max(abs(x), abs(y)) == radius:
					var offset = Vector2i(x, y)
					var check_pos = center + offset
					
					# 유효성 체크 (함수로 분리)
					if _is_slot_valid(check_pos, center):
						slots.append(check_pos)
		
		radius += 1
	
	return slots

# 타일이 이동 가능한지 + 비어있는지 체크
func _is_slot_valid(pos: Vector2i, center: Vector2i) -> bool:
	# 1. 지형 체크 (벽 여부)
	if not _is_tile_walkable(pos):
		return false
	
	# 2. 점유 체크 (다른 유닛이 있는지)
	# 단, 플레이어 위치는 제외 (중심이니까)
	if GameManager.is_occupied(pos) and pos != center:
		return false
		
	return true

func _is_tile_walkable(grid_pos: Vector2i) -> bool:
	if not "astar" in GameManager and not "_astar" in GameManager:
		return true 
	
	var astar_ref = null
	if "_astar" in GameManager: astar_ref = GameManager._astar
	elif "astar" in GameManager: astar_ref = GameManager.astar
	
	if not astar_ref: return false
	
	if not astar_ref.region.has_point(grid_pos):
		return false
		
	if astar_ref.is_point_solid(grid_pos):
		return false
		
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

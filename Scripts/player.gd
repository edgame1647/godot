extends GameUnit
class_name Player

# [변수 선언]
var mp: int = 50
var max_mp: int = 50
const SPELL_RANGE_GRID: int = 1
var locked_target: Node2D = null 
var mouse_hover_target: Node2D = null
@export var show_debug_range: bool = true 
@export var debug_color: Color = Color(0, 1, 0, 0.5) 
@export var outline_material: ShaderMaterial 
var pending_action: String = "" 
var pending_target_pos: Vector2 = Vector2.ZERO 

# [초기화]
func _init(): move_speed = 140.0 
func _ready():
	super._ready()
	if mover:
		if not mover.on_move_end.is_connected(_execute_pending_action):
			mover.on_move_end.connect(_execute_pending_action)
	if outline_material == null: print("!!! 경고: Outline Material 없음")

# [입력 처리]
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_target(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_target(-1)

# [메인 루프]
func _physics_process(_delta): 
	if show_debug_range: queue_redraw()
	if locked_target and not is_instance_valid(locked_target): locked_target = null
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]: return
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): _handle_left_click_selection()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): pending_action = ""; _do_move(get_global_mouse_position())
	if Input.is_action_just_pressed("ui_q_skill"): _handle_skill_input()

# -------------------------------------------------------------------------
# [수정됨] 휠 타겟 순환 (전체 범위)
# -------------------------------------------------------------------------
func _cycle_target(direction: int):
	# [변경] 사거리 제한 없이 모든 적 가져오기
	var candidates = _get_sorted_all_enemies()
	
	if candidates.is_empty():
		return
	
	# 현재 타겟 인덱스 찾기
	var current_idx = -1
	if locked_target and candidates.has(locked_target):
		current_idx = candidates.find(locked_target)
	
	# 다음 인덱스 계산
	var next_idx = 0
	if current_idx == -1:
		if direction == 1: next_idx = 0
		else: next_idx = candidates.size() - 1
	else:
		next_idx = (current_idx + direction) % candidates.size()
		if next_idx < 0: next_idx = candidates.size() - 1

	# 타겟 변경 적용
	var new_target = candidates[next_idx]
	if locked_target != new_target:
		if locked_target: _set_target_outline(locked_target, false)
		locked_target = new_target
		_set_target_outline(locked_target, true)
		print(">>> [휠 타겟] ", locked_target.name, " (거리: ", int(global_position.distance_to(new_target.global_position)), ")")

# -------------------------------------------------------------------------
# [수정됨] 모든 적을 거리순 정렬하여 반환 (사거리 체크 제거)
# -------------------------------------------------------------------------
func _get_sorted_all_enemies() -> Array[Node2D]:
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	var valid_enemies: Array[Node2D] = []
	
	# 1. 유효한 적 필터링 (죽은 적 제외)
	for enemy in all_enemies:
		if is_instance_valid(enemy):
			# 죽은 상태 체크 (State.DIE = 4 라고 가정, 실제 값 확인 필요)
			if "current_state" in enemy and enemy.current_state == 4: # State.DIE
				continue
			valid_enemies.append(enemy)
			
	# 2. 거리순 정렬 (가까운 순)
	valid_enemies.sort_custom(func(a, b):
		var dist_a = global_position.distance_squared_to(a.global_position)
		var dist_b = global_position.distance_squared_to(b.global_position)
		return dist_a < dist_b
	)
	
	return valid_enemies

# -------------------------------------------------------------------------
# [기존 로직 유지]
# -------------------------------------------------------------------------
func _handle_left_click_selection():
	var mouse_pos = get_global_mouse_position()
	var mouse_grid = GameManager.world_to_grid(mouse_pos)
	var enemy = _get_enemy_at_grid(mouse_grid)
	if enemy:
		if locked_target != enemy:
			if locked_target: _set_target_outline(locked_target, false)
			locked_target = enemy
			_set_target_outline(locked_target, true)
	else:
		if locked_target:
			_set_target_outline(locked_target, false)
			locked_target = null

func _set_target_outline(unit: Node2D, enable: bool):
	if not unit or not is_instance_valid(unit): return
	if outline_material == null: return 
	var sprite = _find_sprite_recursive(unit)
	if sprite:
		if enable: sprite.material = outline_material
		else: sprite.material = null

func _find_sprite_recursive(node: Node) -> Sprite2D:
	if node is Sprite2D: return node
	for child in node.get_children():
		var found = _find_sprite_recursive(child)
		if found: return found
	return null

# -------------------------------------------------------------------------
# [스킬 입력 처리] 자동 타겟팅 추가
# -------------------------------------------------------------------------
# -------------------------------------------------------------------------
# [스킬 입력 처리] 자동 타겟팅 + 외곽선 적용
# -------------------------------------------------------------------------
func _handle_skill_input():
	var final_target_unit = null
	var final_target_pos = Vector2.ZERO
	
	# 1. 고정 타겟이 있으면 최우선
	if locked_target and is_instance_valid(locked_target):
		final_target_unit = locked_target
		final_target_pos = locked_target.global_position
		
	else:
		# 2. 마우스 커서 아래에 적이 있는지 확인
		var mouse_pos = get_global_mouse_position()
		var mouse_grid = GameManager.world_to_grid(mouse_pos)
		var enemy_under_mouse = _get_enemy_at_grid(mouse_grid)
		
		if enemy_under_mouse:
			# 마우스로 직접 쏘는 경우 -> 이 녀석을 새로운 고정 타겟으로 등록!
			final_target_unit = enemy_under_mouse
			final_target_pos = enemy_under_mouse.global_position
			
			_apply_auto_lock(enemy_under_mouse) # 외곽선 켜기
		else:
			# 3. 타겟이 없다면 -> 사거리 내 가장 가까운 적 자동 탐색
			var nearest_enemy = _find_nearest_enemy_in_range()
			
			if nearest_enemy:
				final_target_unit = nearest_enemy
				final_target_pos = nearest_enemy.global_position
				
				# [핵심] 자동 타겟팅 된 녀석도 고정 타겟으로 등록 + 외곽선 켜기
				_apply_auto_lock(nearest_enemy)
				
				print(">>> [자동 타겟팅] ", nearest_enemy.name)
			else:
				# 4. 적이 아예 없으면 -> 땅바닥 시전 (타겟 해제)
				final_target_pos = mouse_pos
				# 기존 타겟이 있었다면 해제할 수도 있음 (선택사항)

	_process_skill_execution(final_target_pos, final_target_unit)

# -------------------------------------------------------------------------
# [헬퍼] 자동 락온 적용 (중복 코드 방지)
# -------------------------------------------------------------------------
func _apply_auto_lock(new_target: Node2D):
	if locked_target != new_target:
		# 기존꺼 끄기
		if locked_target:
			_set_target_outline(locked_target, false)
		
		# 새거 켜기
		locked_target = new_target
		_set_target_outline(locked_target, true)

# -------------------------------------------------------------------------
# [헬퍼] 사거리 내 가장 가까운 적 찾기
# -------------------------------------------------------------------------
func _find_nearest_enemy_in_range() -> Node2D:
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	var nearest_unit: Node2D = null
	var min_dist_sq = INF # 무한대값 초기화
	
	var my_grid = GameManager.world_to_grid(global_position)
	
	for enemy in all_enemies:
		if not is_instance_valid(enemy): continue
		
		# 죽은 적 제외 (State.DIE 체크 - 실제 프로젝트 enum 값에 맞게 수정 필요)
		if "current_state" in enemy and enemy.current_state == 4: continue 
		
		var e_grid = Vector2i.ZERO
		if "grid_pos" in enemy: e_grid = enemy.grid_pos
		else: e_grid = GameManager.world_to_grid(enemy.global_position)
		
		# 1. 사거리 체크 (그리드 거리)
		if get_grid_distance(my_grid, e_grid) <= SPELL_RANGE_GRID:
			# 2. 물리적 거리 비교 (가장 가까운 놈 찾기)
			var dist_sq = global_position.distance_squared_to(enemy.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				nearest_unit = enemy
				
	return nearest_unit

func _process_skill_execution(target_pos: Vector2, target_unit_ref: Node2D):
	mouse_hover_target = target_unit_ref 
	var my_grid = GameManager.world_to_grid(global_position)
	var target_grid = GameManager.world_to_grid(target_pos)
	var dist = get_grid_distance(my_grid, target_grid)
	if dist <= SPELL_RANGE_GRID:
		if mover and mover.is_moving:
			mover.current_path.clear()
			pending_action = "cast_spell_immediate"
			pending_target_pos = target_pos
		else:
			cast_spell_at(target_pos)
			pending_action = ""
	else:
		pending_action = "move_and_cast"
		pending_target_pos = target_pos
		_move_to_attack_range(target_pos)

func _execute_pending_action():
	if pending_action == "": return
	var final_pos = pending_target_pos
	if locked_target and is_instance_valid(locked_target): final_pos = locked_target.global_position
	elif mouse_hover_target and is_instance_valid(mouse_hover_target): final_pos = mouse_hover_target.global_position
	var my_grid = GameManager.world_to_grid(global_position)
	var target_grid = GameManager.world_to_grid(final_pos)
	var dist = get_grid_distance(my_grid, target_grid)
	
	if pending_action == "move_and_cast":
		if dist <= SPELL_RANGE_GRID: call_deferred("cast_spell_at", final_pos)
	elif pending_action == "cast_spell_immediate":
		if dist <= SPELL_RANGE_GRID + 1: call_deferred("cast_spell_at", final_pos)
		else:
			if locked_target:
				_move_to_attack_range(final_pos)
				pending_action = "move_and_cast"
				pending_target_pos = final_pos
				return
	pending_action = ""

func _move_to_attack_range(target_pos: Vector2):
	var my_grid = GameManager.world_to_grid(global_position)
	var target_grid = GameManager.world_to_grid(target_pos)
	var valid_dest_grid = _get_valid_cast_position(my_grid, target_grid)
	var valid_dest_pos = GameManager.grid_to_world(valid_dest_grid)
	_do_move(valid_dest_pos)

func _get_valid_cast_position(start_grid: Vector2i, target_grid: Vector2i) -> Vector2i:
	var current_sim_grid = start_grid
	var max_loops = 100
	var loop_count = 0
	while get_grid_distance(current_sim_grid, target_grid) > SPELL_RANGE_GRID:
		var dir = Vector2(target_grid - current_sim_grid).sign()
		current_sim_grid += Vector2i(dir)
		loop_count += 1
		if current_sim_grid == target_grid or loop_count > max_loops: break
	return current_sim_grid

func _do_move(pos: Vector2):
	if not mover: return
	if move_speed <= 70.0: current_state = State.WALK
	else: current_state = State.RUN
	mover.move_to(pos)

func cast_spell_at(target_pos: Vector2):
	var dir_vec = (target_pos - global_position).normalized()
	var dir_idx = get_iso_dir_index_from_vec(dir_vec)
	if anim_ctrl: anim_ctrl.current_dir_index = dir_idx 
	cast_spell() 

func _get_enemy_at_grid(grid_pos: Vector2i) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		var e_grid = Vector2i.ZERO
		if "grid_pos" in enemy: e_grid = enemy.grid_pos
		else: e_grid = GameManager.world_to_grid(enemy.global_position)
		if e_grid == grid_pos: return enemy
	return null

func get_grid_distance(p1: Vector2i, p2: Vector2i) -> int:
	var dx = abs(p1.x - p2.x)
	var dy = abs(p1.y - p2.y)
	return max(dx, dy)

func _draw():
	if not show_debug_range: return
	var my_grid = GameManager.world_to_grid(global_position)
	var center_world = GameManager.grid_to_world(my_grid)
	var vec_x = GameManager.grid_to_world(my_grid + Vector2i(1, 0)) - center_world
	var vec_y = GameManager.grid_to_world(my_grid + Vector2i(0, 1)) - center_world
	var r = float(SPELL_RANGE_GRID)
	var r_ext = float(SPELL_RANGE_GRID) + 1.0 
	var p1 = center_world - (vec_x * r) - (vec_y * r) 
	var p2 = center_world + (vec_x * r_ext) - (vec_y * r) 
	var p3 = center_world + (vec_x * r_ext) + (vec_y * r_ext) 
	var p4 = center_world - (vec_x * r) + (vec_y * r_ext) 
	var points = [to_local(p1), to_local(p2), to_local(p3), to_local(p4), to_local(p1)]
	draw_polyline(points, debug_color, 2.0)

func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data["type"] = "PLAYER"
	data["mp"] = mp
	return data

func load_from_data(data: Dictionary):
	super.load_from_data(data)
	mp = data.get("mp", 50)

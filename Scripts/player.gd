class_name Player
extends BaseUnit

# -------------------------------------------------------------------------
# [설정 및 변수]
# -------------------------------------------------------------------------
@export var show_debug_range: bool = true 
@export var debug_color: Color = Color(0, 1, 0, 0.5) 
@export var outline_material: ShaderMaterial 

var mp: int = 50
var max_mp: int = 50

# 타겟 시스템
var locked_target: Node2D = null 
var _current_skill_data: Dictionary = {}
var _deferred_attack_pos: Vector2 = Vector2.ZERO

# 디버깅용
var _last_attack_grid: Vector2i = Vector2i(-999, -999)
var _debug_attack_timer: float = 0.0

# -------------------------------------------------------------------------
# [초기화]
# -------------------------------------------------------------------------
func _init():
	move_speed = 80.0 

func _ready():
	super._ready() # BaseUnit의 _ready 실행 (컴포넌트 연결 등)
	
	if not outline_material:
		push_warning("[Player] Outline Material이 할당되지 않았습니다.")
	
	_current_skill_data = GameManager.get_skill_data(1)
	
	# 이동 종료 후 스킬 발동 로직 연결 (BaseUnit 로직 외 추가 동작)
	if mover:
		mover.on_move_end.connect(_on_move_finished)

# -------------------------------------------------------------------------
# [입력 및 프로세스]
# -------------------------------------------------------------------------
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_target(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_target(-1)
			
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			_try_use_skill(1)
		elif event.keycode == KEY_W:
			_try_use_skill(2)

func _physics_process(delta): 
	queue_redraw()
	
	if _debug_attack_timer > 0:
		_debug_attack_timer -= delta
		if _debug_attack_timer <= 0: _last_attack_grid = Vector2i(-999, -999)

	if locked_target and not is_instance_valid(locked_target):
		locked_target = null

	# 상태 체크
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]:
		return
	
	# IDLE일 때 마우스/타겟 바라보기
	if current_state == State.IDLE:
		_face_mouse_direction()
	
	# 이동 및 클릭 처리
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_left_click_selection()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_deferred_attack_pos = Vector2.ZERO 
		_do_move(get_global_mouse_position())

func _face_mouse_direction():
	var look_target_pos = Vector2.ZERO
	if locked_target and is_instance_valid(locked_target):
		look_target_pos = locked_target.global_position
	else:
		look_target_pos = get_global_mouse_position()
	
	var dir_vec = (look_target_pos - global_position).normalized()
	if anim_ctrl:
		var new_dir_idx = get_iso_dir_index_from_vec(dir_vec)
		if anim_ctrl.current_dir_index != new_dir_idx:
			anim_ctrl.play_anim_by_index(current_state, new_dir_idx)

# -------------------------------------------------------------------------
# # Region: 오버라이드 및 추가 로직
# -------------------------------------------------------------------------
func _on_move_finished():
	# BaseUnit의 _on_move_end는 이미 호출됨 (mover 시그널)
	# 여기서는 플레이어의 예약된 스킬 발동 처리만 담당
	if _deferred_attack_pos != Vector2.ZERO:
		_execute_skill_logic(_deferred_attack_pos)
		_deferred_attack_pos = Vector2.ZERO 

# -------------------------------------------------------------------------
# # Region: 타겟팅 시스템
# -------------------------------------------------------------------------
func _cycle_target(direction: int):
	var candidates = _get_sorted_all_enemies()
	if candidates.is_empty(): return
	var current_idx = -1
	if locked_target and candidates.has(locked_target):
		current_idx = candidates.find(locked_target)
	var next_idx = 0
	if current_idx == -1: next_idx = 0 if direction == 1 else candidates.size() - 1
	else:
		next_idx = (current_idx + direction) % candidates.size()
		if next_idx < 0: next_idx = candidates.size() - 1
	_apply_lock_target(candidates[next_idx])

func _handle_left_click_selection():
	var mouse_grid = GameManager.world_to_grid(get_global_mouse_position())
	var enemy = _get_enemy_at_grid(mouse_grid)
	if enemy: _apply_lock_target(enemy)
	else: if locked_target: _apply_lock_target(null)

func _apply_lock_target(new_target: Node2D):
	if locked_target != new_target:
		if locked_target: _set_target_outline(locked_target, false)
		locked_target = new_target
		if locked_target: _set_target_outline(locked_target, true)

func _get_sorted_all_enemies() -> Array[Node2D]:
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	var valid_enemies: Array[Node2D] = []
	for enemy in all_enemies:
		if is_instance_valid(enemy):
			if "current_state" in enemy and enemy.current_state == State.DIE: continue
			valid_enemies.append(enemy)
	valid_enemies.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	return valid_enemies

# -------------------------------------------------------------------------
# # Region: 스킬 및 전투 실행
# -------------------------------------------------------------------------
func _try_use_skill(skill_id: int):
	var data = GameManager.get_skill_data(skill_id)
	if data.is_empty(): return 

	var cost = data.get("mp_cost", 0)
	var s_name = data.get("name", "Unknown")
	
	if mp < cost:
		print("[Skill] MP 부족! %s (필요: %d, 현재: %d)" % [s_name, cost, mp])
		return

	_handle_skill_input(data)

func _handle_skill_input(skill_data: Dictionary):
	_current_skill_data = skill_data
	
	var final_pos: Vector2 = Vector2.ZERO
	var range_limit = skill_data.get("range", 1)
	
	var mouse_pos = get_global_mouse_position()
	var mouse_grid = GameManager.world_to_grid(mouse_pos)
	var enemy_under_mouse = _get_enemy_at_grid(mouse_grid)
	var my_grid = GameManager.world_to_grid(global_position)
	
	if enemy_under_mouse:
		var dist = _get_grid_distance(my_grid, mouse_grid)
		if dist <= range_limit:
			_apply_lock_target(enemy_under_mouse)
			final_pos = enemy_under_mouse.global_position
		else:
			if locked_target and is_instance_valid(locked_target):
				final_pos = locked_target.global_position
			else:
				final_pos = mouse_pos
	else:
		if locked_target and is_instance_valid(locked_target):
			final_pos = locked_target.global_position
		else:
			final_pos = mouse_pos
	
	_process_skill_execution(final_pos)

func _process_skill_execution(target_pos: Vector2):
	if mover and mover.is_moving:
		mover.stop_gracefully() 
		_deferred_attack_pos = target_pos 
		return 
	
	_execute_skill_logic(target_pos)

func _execute_skill_logic(target_pos: Vector2):
	var my_grid = GameManager.world_to_grid(global_position)
	var target_grid = GameManager.world_to_grid(target_pos)
	var dist = _get_grid_distance(my_grid, target_grid)
	
	var range_limit = _current_skill_data.get("range", 1)
	var cast_grid = target_grid
	
	# 사거리 보정 (Clamp)
	if dist > range_limit:
		cast_grid = _calculate_clamped_cast_grid(my_grid, target_grid, range_limit)
		print("[Skill] 사거리 초과! 최대 사거리 지점(%s)으로 보정" % cast_grid)

	var enemy_at_cast = _get_enemy_at_grid(cast_grid)
	if enemy_at_cast:
		if locked_target != enemy_at_cast:
			_apply_lock_target(enemy_at_cast)
			print("[Skill] 보정된 위치의 적 발견 -> 타겟 변경: ", enemy_at_cast.name)

	_last_attack_grid = cast_grid
	_debug_attack_timer = 1.0

	var cast_world_pos = GameManager.grid_to_world(cast_grid)
	_cast_spell_at(cast_world_pos)

func _calculate_clamped_cast_grid(start: Vector2i, end: Vector2i, range_limit: int) -> Vector2i:
	var current = start
	for i in range(range_limit):
		var diff = end - current
		if diff == Vector2i.ZERO: break
		var step = Vector2i.ZERO
		step.x = sign(diff.x)
		step.y = sign(diff.y)
		current += step
		if current == end: break
	return current

func _do_move(pos: Vector2):
	if not mover: return
	# 애니메이션 상태 변경은 BaseUnit의 _on_move_step_grid에서 처리하므로 여기선 이동 명령만 내림
	mover.move_to(pos)

func _cast_spell_at(pos: Vector2):
	if _current_skill_data.is_empty(): return
	
	var cost = _current_skill_data.get("mp_cost", 0)
	mp -= cost
	print("[Skill] %s 발동! (MP -%d, 잔여: %d)" % [_current_skill_data.get("name"), cost, mp])
	
	var dir_vec = (pos - global_position).normalized()
	if anim_ctrl:
		anim_ctrl.current_dir_index = get_iso_dir_index_from_vec(dir_vec)
	
	var anim_state_id = _current_skill_data.get("anim_state", 3)
	current_state = anim_state_id 
	
	if anim_ctrl:
		anim_ctrl.play_anim_by_index(current_state, anim_ctrl.current_dir_index)

# -------------------------------------------------------------------------
# # Region: 유틸리티 및 그리기
# -------------------------------------------------------------------------
func _get_enemy_at_grid(grid_pos: Vector2i) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		var e_grid = Vector2i.ZERO
		if "grid_pos" in enemy: e_grid = enemy.grid_pos
		else: e_grid = GameManager.world_to_grid(enemy.global_position)
		
		if e_grid == grid_pos: return enemy
	return null

func _get_grid_distance(p1: Vector2i, p2: Vector2i) -> int:
	return max(abs(p1.x - p2.x), abs(p1.y - p2.y))

func _set_target_outline(unit: Node2D, enable: bool):
	if not is_instance_valid(unit) or not outline_material: return
	var s = _find_sprite_recursive(unit)
	if s: s.material = outline_material if enable else null

func _find_sprite_recursive(node: Node) -> Sprite2D:
	if node is Sprite2D: return node
	for child in node.get_children():
		var f = _find_sprite_recursive(child)
		if f: return f
	return null

func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data["type"] = "PLAYER"
	data["mp"] = mp
	return data

func load_from_data(data: Dictionary):
	super.load_from_data(data)
	mp = data.get("mp", 50)

func _draw():
	var range_to_draw = 1
	if not _current_skill_data.is_empty():
		range_to_draw = _current_skill_data.get("range", 1)

	if show_debug_range:
		_draw_exact_diamond_at(GameManager.world_to_grid(global_position), range_to_draw, debug_color, false)
	
	if _last_attack_grid != Vector2i(-999, -999):
		_draw_exact_diamond_at(_last_attack_grid, 0, Color(1, 0, 0, 0.6), true)

func _draw_exact_diamond_at(center_grid: Vector2i, radius: int, color: Color, filled: bool):
	var cx = center_grid.x
	var cy = center_grid.y
	var half_w = GameManager.TILE_SIZE.x * 0.5
	var half_h = GameManager.TILE_SIZE.y * 0.5
	var tile_h = GameManager.TILE_SIZE.y
	
	var top_grid = Vector2i(cx - radius, cy - radius)
	var p_top = GameManager.grid_to_world(top_grid)
	
	var right_grid = Vector2i(cx + radius, cy - radius)
	var p_right = GameManager.grid_to_world(right_grid) + Vector2(half_w, half_h)
	
	var bottom_grid = Vector2i(cx + radius, cy + radius)
	var p_bottom = GameManager.grid_to_world(bottom_grid) + Vector2(0, tile_h)
	
	var left_grid = Vector2i(cx - radius, cy + radius)
	var p_left = GameManager.grid_to_world(left_grid) + Vector2(-half_w, half_h)
	
	var points = PackedVector2Array([
		to_local(p_top), to_local(p_right), to_local(p_bottom), to_local(p_left), to_local(p_top)
	])
	
	if filled: draw_colored_polygon(points, color)
	else: draw_polyline(points, color, 2.0)

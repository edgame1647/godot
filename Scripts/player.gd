class_name Player
extends GameUnit

# -------------------------------------------------------------------------
# [설정 및 변수]
# -------------------------------------------------------------------------
@export var show_debug_range: bool = true 
@export var debug_color: Color = Color(0, 1, 0, 0.5) 
@export var outline_material: ShaderMaterial 

const SPELL_RANGE_GRID: int = 4

var mp: int = 50
var max_mp: int = 50

# 타겟 시스템
var locked_target: Node2D = null 
var mouse_hover_target: Node2D = null

# 디버깅용: 마지막 공격 위치
var _last_attack_grid: Vector2i = Vector2i(-999, -999)
var _debug_attack_timer: float = 0.0

# -------------------------------------------------------------------------
# [초기화]
# -------------------------------------------------------------------------
func _init():
	move_speed = 140.0 

func _ready():
	super._ready()
	if not outline_material:
		push_warning("[Player] Outline Material이 할당되지 않았습니다.")

# -------------------------------------------------------------------------
# [입력 및 프로세스]
# -------------------------------------------------------------------------
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_target(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_target(-1)

func _physics_process(delta): 
	queue_redraw()
	
	if _debug_attack_timer > 0:
		_debug_attack_timer -= delta
		if _debug_attack_timer <= 0: _last_attack_grid = Vector2i(-999, -999)

	if locked_target and not is_instance_valid(locked_target):
		locked_target = null

	# 조작 불가능 상태 체크
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]:
		return
	
	# [핵심 추가] 마우스 방향 바라보기 실행
	_face_mouse_direction()
	
	# 마우스 입력 처리
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_left_click_selection()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_do_move(get_global_mouse_position())
	
	if Input.is_action_just_pressed("ui_q_skill"):
		_handle_skill_input()

# [추가] 마우스 커서 방향을 계산하여 바라보는 함수
func _face_mouse_direction():
	# 이동, 대기 상태일 때만 시선 변경 허용
	if not current_state in [State.IDLE, State.WALK, State.RUN]: return
	
	var mouse_pos = get_global_mouse_position()
	var dir_vec = (mouse_pos - global_position).normalized()
	
	if anim_ctrl:
		var new_dir_idx = get_iso_dir_index_from_vec(dir_vec)
		# 방향이 실제로 바뀔 때만 애니메이션 갱신 (최적화)
		if anim_ctrl.current_dir_index != new_dir_idx:
			anim_ctrl.play_anim_by_index(current_state, new_dir_idx)

# -------------------------------------------------------------------------
# # Region: 오버라이드 (Override)
# -------------------------------------------------------------------------
# region Override

# [중요] 부모(GameUnit)의 이동 시 방향 전환 로직을 무력화함
# 플레이어는 이동 방향이 아니라 마우스 방향을 봐야 하기 때문.
func _on_move_step_grid(diff: Vector2i):
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]: 
		return

	# 방향 전환 코드를 제거하고 애니메이션 상태만 갱신
	# var dir_index = get_iso_dir_index(diff) <- 이거 안 함
	
	if current_state == State.RUN:
		if anim_ctrl: anim_ctrl.play_anim(AnimController.State.RUN) # 현재 방향 유지
	elif current_state == State.WALK:
		if anim_ctrl: anim_ctrl.play_anim(AnimController.State.WALK) # 현재 방향 유지

# endregion

# -------------------------------------------------------------------------
# # Region: 타겟팅 시스템 (Targeting)
# -------------------------------------------------------------------------
# region Targeting

func _cycle_target(direction: int):
	var candidates = _get_sorted_all_enemies()
	if candidates.is_empty(): return
	
	var current_idx = -1
	if locked_target and candidates.has(locked_target):
		current_idx = candidates.find(locked_target)
	
	var next_idx = 0
	if current_idx == -1:
		next_idx = 0 if direction == 1 else candidates.size() - 1
	else:
		next_idx = (current_idx + direction) % candidates.size()
		if next_idx < 0: next_idx = candidates.size() - 1

	_apply_lock_target(candidates[next_idx])

func _handle_left_click_selection():
	var mouse_grid = GameManager.world_to_grid(get_global_mouse_position())
	var enemy = _get_enemy_at_grid(mouse_grid)
	
	if enemy:
		_apply_lock_target(enemy)
	else:
		if locked_target: _apply_lock_target(null)

func _apply_lock_target(new_target: Node2D):
	if locked_target != new_target:
		if locked_target: _set_target_outline(locked_target, false)
		locked_target = new_target
		if locked_target: 
			_set_target_outline(locked_target, true)
			print("[Target] Lock: ", locked_target.name)

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

# endregion

# -------------------------------------------------------------------------
# # Region: 스킬 및 전투 실행 (Skill Execution)
# -------------------------------------------------------------------------
# region Skill Execution

func _handle_skill_input():
	var final_pos: Vector2 = Vector2.ZERO
	
	if locked_target and is_instance_valid(locked_target):
		final_pos = locked_target.global_position
	else:
		var mouse_grid = GameManager.world_to_grid(get_global_mouse_position())
		var enemy_under_mouse = _get_enemy_at_grid(mouse_grid)
		
		if enemy_under_mouse:
			final_pos = enemy_under_mouse.global_position
			_apply_lock_target(enemy_under_mouse)
		else:
			final_pos = get_global_mouse_position()

	_process_skill_execution(final_pos)

func _process_skill_execution(target_pos: Vector2):
	if mover: mover.is_moving = false
	
	var my_grid = GameManager.world_to_grid(global_position)
	var target_grid = GameManager.world_to_grid(target_pos)
	var dist = _get_grid_distance(my_grid, target_grid)
	
	var cast_grid = target_grid
	
	if dist > SPELL_RANGE_GRID:
		cast_grid = _calculate_clamped_cast_grid(my_grid, target_grid, SPELL_RANGE_GRID)
		print("[Skill] 사거리 초과! 최대 사거리 지점 공격")
	else:
		print("[Skill] 사거리 내 공격")

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
	current_state = State.WALK if move_speed <= 70.0 else State.RUN
	mover.move_to(pos)

func _cast_spell_at(pos: Vector2):
	# 스킬 시전 시 순간적으로 해당 방향을 보게 함 (선택 사항)
	# var dir_vec = (pos - global_position).normalized()
	# if anim_ctrl:
	# 	anim_ctrl.current_dir_index = get_iso_dir_index_from_vec(dir_vec)
	cast_spell()

# endregion

# -------------------------------------------------------------------------
# # Region: 유틸리티 및 그리기 (Utils & Debug)
# -------------------------------------------------------------------------
# region Utils & Debug

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
	if show_debug_range:
		_draw_diamond_at(GameManager.world_to_grid(global_position), SPELL_RANGE_GRID, debug_color, false)
	
	if _last_attack_grid != Vector2i(-999, -999):
		_draw_diamond_at(_last_attack_grid, 0, Color(1, 0, 0, 0.6), true)

func _draw_diamond_at(grid_pos: Vector2i, radius: int, color: Color, filled: bool):
	var center = GameManager.grid_to_world(grid_pos)
	center.y += GameManager.TILE_SIZE.y * 0.5 
	
	var tile_half = GameManager.TILE_SIZE * 0.5
	var iso_x = Vector2(tile_half.x, tile_half.y)  
	var iso_y = Vector2(-tile_half.x, tile_half.y) 
	
	var r = float(radius)
	var r_ext = r + 1.0
	
	if filled:
		var top = center - Vector2(0, tile_half.y)
		var right = center + Vector2(tile_half.x, 0)
		var bottom = center + Vector2(0, tile_half.y)
		var left = center - Vector2(tile_half.x, 0)
		var points = [to_local(top), to_local(right), to_local(bottom), to_local(left)]
		draw_colored_polygon(points, color)
	else:
		var top = center - (iso_y * r) - (iso_x * r)
		top -= Vector2(0, tile_half.y)
		var right = center + (iso_x * r_ext) - (iso_y * r)
		right += Vector2(tile_half.x, 0)
		var bottom = center + (iso_x * r_ext) + (iso_y * r_ext)
		bottom += Vector2(0, tile_half.y)
		var left = center - (iso_x * r) + (iso_y * r_ext)
		left -= Vector2(tile_half.x, 0)
		var points = [to_local(top), to_local(right), to_local(bottom), to_local(left), to_local(top)]
		draw_polyline(points, color, 2.0)

# endregion

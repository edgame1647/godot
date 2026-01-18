class_name Player
extends GameUnit

# -------------------------------------------------------------------------
# [설정 및 변수]
# -------------------------------------------------------------------------
@export var show_debug_range: bool = true 
@export var debug_color: Color = Color(0, 1, 0, 0.5) 
@export var outline_material: ShaderMaterial 

const SPELL_RANGE_GRID: int = 1

var mp: int = 50
var max_mp: int = 50

# 타겟 시스템
var locked_target: Node2D = null 
var mouse_hover_target: Node2D = null

# 예약된 행동 (이동 후 공격 등)
var _pending_action: String = "" 
var _pending_target_pos: Vector2 = Vector2.ZERO 

# -------------------------------------------------------------------------
# [초기화]
# -------------------------------------------------------------------------
func _init():
	move_speed = 140.0 

func _ready():
	super._ready()
	if mover:
		mover.on_move_end.connect(_on_movement_finished_check_pending)
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

func _physics_process(_delta): 
	if show_debug_range: queue_redraw()
	
	# 유효하지 않은 타겟 해제
	if locked_target and not is_instance_valid(locked_target):
		locked_target = null

	# 조작 불가능 상태 체크
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]:
		return
	
	# 마우스 입력 처리
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_left_click_selection()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_pending_action = "" # 이동 시 예약 취소
		_do_move(get_global_mouse_position())
	
	if Input.is_action_just_pressed("ui_q_skill"): # 프로젝트 설정 키맵 확인 필요
		_handle_skill_input()

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
		# 빈 땅 클릭 시 타겟 해제 (원하는 경우 주석 처리)
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
			# 죽은 상태(4) 제외 (State Enum 값 확인)
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
	var final_target: Node2D = null
	var final_pos: Vector2 = Vector2.ZERO
	
	if locked_target and is_instance_valid(locked_target):
		final_target = locked_target
		final_pos = locked_target.global_position
	else:
		# 마우스 아래 적 확인
		var mouse_grid = GameManager.world_to_grid(get_global_mouse_position())
		var enemy_under_mouse = _get_enemy_at_grid(mouse_grid)
		
		if enemy_under_mouse:
			final_target = enemy_under_mouse
			final_pos = enemy_under_mouse.global_position
			_apply_lock_target(enemy_under_mouse)
		else:
			# 자동 타겟팅
			var nearest = _find_nearest_enemy_in_range()
			if nearest:
				final_target = nearest
				final_pos = nearest.global_position
				_apply_lock_target(nearest)
			else:
				# 맨땅 시전
				final_pos = get_global_mouse_position()

	_process_skill_execution(final_pos, final_target)

func _process_skill_execution(target_pos: Vector2, target_unit_ref: Node2D):
	mouse_hover_target = target_unit_ref 
	var my_grid = GameManager.world_to_grid(global_position)
	var target_grid = GameManager.world_to_grid(target_pos)
	var dist = _get_grid_distance(my_grid, target_grid)
	
	# 사거리 내에 있으면 즉시 시전 or 이동 중이면 예약
	if dist <= SPELL_RANGE_GRID:
		if mover and mover.is_moving:
			mover.current_path.clear()
			_pending_action = "cast_spell_immediate"
			_pending_target_pos = target_pos
		else:
			_cast_spell_at(target_pos)
			_pending_action = ""
	else:
		# 사거리 밖이면 이동 후 시전 예약
		_pending_action = "move_and_cast"
		_pending_target_pos = target_pos
		_move_to_attack_range(target_pos)

func _on_movement_finished_check_pending():
	if _pending_action == "": return
	
	var final_pos = _pending_target_pos
	if is_instance_valid(locked_target): final_pos = locked_target.global_position
	elif is_instance_valid(mouse_hover_target): final_pos = mouse_hover_target.global_position
	
	var my_grid = GameManager.world_to_grid(global_position)
	var target_grid = GameManager.world_to_grid(final_pos)
	var dist = _get_grid_distance(my_grid, target_grid)
	
	if _pending_action == "move_and_cast":
		if dist <= SPELL_RANGE_GRID: 
			call_deferred("_cast_spell_at", final_pos)
			
	elif _pending_action == "cast_spell_immediate":
		# 이동 멈춤 직후 사거리 체크
		if dist <= SPELL_RANGE_GRID + 1: 
			call_deferred("_cast_spell_at", final_pos)
		else:
			# 여전히 멀면 다시 추격
			if locked_target:
				_move_to_attack_range(final_pos)
				_pending_action = "move_and_cast"
				_pending_target_pos = final_pos
				return
	
	_pending_action = ""

func _move_to_attack_range(target_pos: Vector2):
	var my_grid = GameManager.world_to_grid(global_position)
	var target_grid = GameManager.world_to_grid(target_pos)
	
	# 사거리 끝자락 좌표 계산
	var dest_grid = my_grid
	var current_sim = my_grid
	
	# 간단한 Raycast 느낌으로 타겟 쪽으로 한 칸씩 가보며 사거리 닿는 곳 찾기
	# (실제 A*는 GameManager가 하겠지만 여기선 목표 지점만 선정)
	var max_iter = 50
	while _get_grid_distance(current_sim, target_grid) > SPELL_RANGE_GRID and max_iter > 0:
		max_iter -= 1
		var dir = Vector2(target_grid - current_sim).sign()
		current_sim += Vector2i(dir)
		if current_sim == target_grid: break
		dest_grid = current_sim
		
	var dest_pos = GameManager.grid_to_world(dest_grid)
	_do_move(dest_pos)

func _do_move(pos: Vector2):
	if not mover: return
	current_state = State.WALK if move_speed <= 70.0 else State.RUN
	mover.move_to(pos)

func _cast_spell_at(pos: Vector2):
	var dir_vec = (pos - global_position).normalized()
	if anim_ctrl:
		anim_ctrl.current_dir_index = get_iso_dir_index_from_vec(dir_vec)
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

func _find_nearest_enemy_in_range() -> Node2D:
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	var nearest_unit: Node2D = null
	var min_dist_sq = INF
	var my_grid = GameManager.world_to_grid(global_position)
	
	for enemy in all_enemies:
		if not is_instance_valid(enemy): continue
		if "current_state" in enemy and enemy.current_state == State.DIE: continue
		
		var e_grid = enemy.grid_pos if "grid_pos" in enemy else GameManager.world_to_grid(enemy.global_position)
		
		if _get_grid_distance(my_grid, e_grid) <= SPELL_RANGE_GRID:
			var dist_sq = global_position.distance_squared_to(enemy.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				nearest_unit = enemy
	return nearest_unit

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
	if not show_debug_range: return
	
	# 사거리 표시 (다이아몬드 형태 근사)
	var center = GameManager.grid_to_world(GameManager.world_to_grid(global_position))
	
	# Isometric offset 계산 (Tile Size 기반)
	var tile_half = GameManager.TILE_SIZE * 0.5
	# 한 칸의 Vector (x, y축)
	var iso_x = Vector2(tile_half.x, tile_half.y)  # 우하향
	var iso_y = Vector2(-tile_half.x, tile_half.y) # 좌하향
	
	var r = float(SPELL_RANGE_GRID)
	var r_ext = r + 1.0 # 외곽선 포함
	
	# 사거리 마름모 꼭짓점
	var top = center - (iso_y * r) - (iso_x * r)
	var right = center + (iso_x * r_ext) - (iso_y * r)
	var bottom = center + (iso_x * r_ext) + (iso_y * r_ext)
	var left = center - (iso_x * r) + (iso_y * r_ext)
	
	# 로컬 좌표 변환
	var points = [to_local(top), to_local(right), to_local(bottom), to_local(left), to_local(top)]
	draw_polyline(points, debug_color, 2.0)

# endregion

class_name Enemy
extends GameUnit

# -------------------------------------------------------------------------
# [AI 설정]
# -------------------------------------------------------------------------
@export_group("AI Settings")
@export var wander_radius: int = 3
@export var wander_interval: float = 3.0
@export var wander_chance: float = 0.5

@export var detect_range: int = 2
@export var give_up_chase_time: float = 20.0

const NEIGHBOR_OFFSETS = [
	Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

# [AI 상태]
var _wander_timer: float = 0.0
var _lost_aggro_timer: float = 0.0

var _is_chasing: bool = false
var _is_returning: bool = false
var _initial_spawn_pos: Vector2i = Vector2i.ZERO

# -------------------------------------------------------------------------
# [초기화]
# -------------------------------------------------------------------------
func _init():
	move_speed = 70.0

func _ready():
	super._ready()
	_wander_timer = randf_range(1.0, wander_interval)
	
	if grid_pos != Vector2i.ZERO:
		_initial_spawn_pos = grid_pos
	else:
		_initial_spawn_pos = GameManager.world_to_grid(global_position)
	
	# [변경] AIManager에 등록
	# (주의: AIManager를 Autoload에 등록해야 작동합니다)
	AIManager.register_enemy(self)

func _exit_tree():
	# [변경] AIManager에서 해제
	AIManager.unregister_enemy(self)

# -------------------------------------------------------------------------
# [AI 실행 (AIManager가 호출)]
# -------------------------------------------------------------------------
func execute_ai(delta: float, player: Node2D, can_calculate_path: bool) -> bool:
	if current_state in [State.DIE, State.TAKE_DAMAGE]:
		return false 

	if current_state == State.ATTACK:
		_process_attack_behavior(player)
		return false 

	return _process_decision_logic(delta, player, can_calculate_path)

# -------------------------------------------------------------------------
# [내부 로직]
# -------------------------------------------------------------------------
func _process_decision_logic(delta: float, player: Node2D, can_calc: bool) -> bool:
	var did_calc = false
	var dist_to_player = 999
	
	if player:
		var my_grid = grid_pos if grid_pos != Vector2i.ZERO else GameManager.world_to_grid(global_position)
		var p_grid = player.grid_pos
		dist_to_player = max(abs(my_grid.x - p_grid.x), abs(my_grid.y - p_grid.y))

	# 1. 추적 로직
	if player and dist_to_player <= detect_range:
		_lost_aggro_timer = 0.0
		if not _is_chasing:
			print("[%s] 추적 시작" % name)
			_is_chasing = true
			_is_returning = false
		
		if can_calc:
			_move_to_surround_target(player)
			did_calc = true
		
	elif _is_chasing:
		_lost_aggro_timer += delta
		if _lost_aggro_timer > give_up_chase_time:
			print("[%s] 추적 포기 -> 복귀" % name)
			_is_chasing = false
			_is_returning = true
			
			if can_calc:
				_move_to_grid(_initial_spawn_pos)
				did_calc = true
		else:
			if can_calc and player:
				_move_to_surround_target(player)
				did_calc = true

	# 2. 복귀 로직
	elif _is_returning:
		if grid_pos == _initial_spawn_pos:
			print("[%s] 복귀 완료" % name)
			_is_returning = false
			_wander_timer = wander_interval
		else:
			if not mover.is_moving and can_calc:
				_move_to_grid(_initial_spawn_pos)
				did_calc = true

	# 3. 배회 로직
	elif current_state == State.IDLE:
		if not mover.is_moving:
			_wander_timer -= delta
			if _wander_timer <= 0:
				_wander_timer = wander_interval + randf_range(-0.5, 0.5)
				if randf() <= wander_chance and can_calc:
					_try_wander_move()
					did_calc = true

	return did_calc

# -------------------------------------------------------------------------
# [이동 및 행동 헬퍼]
# -------------------------------------------------------------------------
func _process_attack_behavior(player_ref):
	var target_node = target if is_instance_valid(target) else player_ref
	if is_instance_valid(target_node):
		var attack_dir = (target_node.global_position - global_position).normalized()
		if anim_ctrl: anim_ctrl.play_anim(AnimController.State.ATTACK, attack_dir)
	else:
		if anim_ctrl: anim_ctrl.play_anim(AnimController.State.ATTACK)

func _move_to_surround_target(target_unit: Node2D):
	var target_grid = target_unit.grid_pos
	var my_grid = grid_pos
	
	if (my_grid - target_grid).length_squared() <= 2: 
		if my_grid == target_grid: pass 
		else: return 

	var best_neighbor_grid = Vector2i.ZERO
	var min_dist_sq = INF
	var found_spot = false

	for offset in NEIGHBOR_OFFSETS:
		var neighbor_grid = target_grid + offset
		if not GameManager.is_occupied(neighbor_grid):
			var dist_sq = GameManager.grid_to_world(my_grid).distance_squared_to(GameManager.grid_to_world(neighbor_grid))
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				best_neighbor_grid = neighbor_grid
				found_spot = true
	
	if found_spot:
		_move_to_grid(best_neighbor_grid)
	else:
		_move_to_target_pos(target_unit.global_position)

func _try_wander_move():
	var current_grid = grid_pos
	if current_grid == Vector2i.ZERO:
		current_grid = GameManager.world_to_grid(global_position)
	
	var rand_x = randi_range(-wander_radius, wander_radius)
	var rand_y = randi_range(-wander_radius, wander_radius)
	if rand_x == 0 and rand_y == 0: return
	
	_move_to_grid(current_grid + Vector2i(rand_x, rand_y))

func _move_to_grid(g_pos: Vector2i):
	var w_pos = GameManager.grid_to_world(g_pos)
	_move_to_target_pos(w_pos)

func _move_to_target_pos(pos: Vector2):
	if current_state in [State.ATTACK, State.DIE]: return
	current_state = State.WALK if move_speed <= 70.0 else State.RUN
	mover.move_to(pos)

func _on_move_end():
	super._on_move_end()
	if current_state == State.IDLE:
		_wander_timer = wander_interval

func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data["type"] = "ENEMY"
	return data

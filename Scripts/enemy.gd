class_name Enemy
extends GameUnit

# -------------------------------------------------------------------------
# [설정]
# -------------------------------------------------------------------------
@export var attack_range: int = 1
@export var detection_range: int = 2
@export var patrol_radius: int = 3
@export var give_up_time: float = 20.0
@export var attack_cooldown: float = 1.5

# [상태 데이터] (판단은 AIManager가 하지만, 데이터는 개체가 가짐)
var spawn_grid: Vector2i = Vector2i.ZERO
var chase_timer: float = 0.0 # AIManager가 접근하도록 _ 제거
var is_returning: bool = false
var is_patrolling: bool = false 

var attack_timer: float = 0.0 # AIManager가 접근하도록 _ 제거

# 내부 변수
var _target: Node2D = null

# -------------------------------------------------------------------------
# [초기화]
# -------------------------------------------------------------------------
func _init():
	move_speed = 100.0 

func _ready():
	super._ready()
	_find_player()
	
	if spawn_grid == Vector2i.ZERO:
		spawn_grid = GameManager.world_to_grid(global_position)
		
	chase_timer = give_up_time
	
	# 생성 직후 IDLE 애니메이션
	if anim_ctrl:
		anim_ctrl.play_anim_by_index(State.IDLE, 3)

func _physics_process(delta):
	if current_state == State.DIE: return
	
	# [단순 수치 갱신] 쿨타임 감소만 수행 (판단 X)
	if attack_timer > 0:
		attack_timer -= delta
	
	# 애니메이션 상태 복귀 (이동 끝났으면 IDLE로)
	if mover and not mover.is_moving and current_state == State.RUN:
		current_state = State.IDLE
		if anim_ctrl:
			anim_ctrl.play_anim_by_index(State.IDLE, anim_ctrl.current_dir_index)

# -------------------------------------------------------------------------
# [명령 수행 메서드] (AIManager가 호출)
# -------------------------------------------------------------------------

# 1. 이동 명령
func execute_move(target_pos: Vector2):
	if current_state in [State.ATTACK, State.TAKE_DAMAGE, State.DIE]: return
	if mover and mover.is_moving: return
	mover.move_to(target_pos)

# 2. 순찰/이동 중지 명령
func execute_stop():
	if mover and mover.is_moving:
		mover.stop_gracefully()
	is_patrolling = false

# 3. 공격 명령
func execute_attack(target_unit: Node2D):
	# 쿨타임이나 상태 체크는 AIManager가 이미 하고 보냈다고 가정
	if mover and mover.is_moving:
		mover.stop_gracefully()
		return 
	
	current_state = State.ATTACK
	attack_timer = attack_cooldown
	
	# 방향 전환 및 애니메이션
	var dir_vec = (target_unit.global_position - global_position).normalized()
	if anim_ctrl:
		var dir_idx = get_iso_dir_index_from_vec(dir_vec)
		anim_ctrl.play_anim_by_index(State.ATTACK, dir_idx)
	
	print("[Enemy] AIManager 명령으로 공격 수행!")

# -------------------------------------------------------------------------
# [저장 및 로드]
# -------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data["type"] = "ENEMY"
	
	# 위치 저장
	if "grid_pos" in self:
		data["grid_x"] = grid_pos.x
		data["grid_y"] = grid_pos.y
	
	data["attack_range"] = attack_range
	data["detection_range"] = detection_range
	data["patrol_radius"] = patrol_radius
	data["give_up_time"] = give_up_time
	
	data["spawn_grid_x"] = spawn_grid.x
	data["spawn_grid_y"] = spawn_grid.y
	data["is_returning"] = is_returning
	data["chase_timer"] = chase_timer
	
	return data

func load_from_data(data: Dictionary):
	super.load_from_data(data)
	
	var gx = int(data.get("grid_x", 0))
	var gy = int(data.get("grid_y", 0))
	if "grid_pos" in self: grid_pos = Vector2i(gx, gy)
	global_position = GameManager.grid_to_world(Vector2i(gx, gy))
	
	attack_range = data.get("attack_range", 1)
	detection_range = data.get("detection_range", 8)
	patrol_radius = data.get("patrol_radius", 3)
	give_up_time = data.get("give_up_time", 20.0)
	
	var sx = data.get("spawn_grid_x", 0)
	var sy = data.get("spawn_grid_y", 0)
	spawn_grid = Vector2i(sx, sy)
	
	is_returning = data.get("is_returning", false)
	chase_timer = data.get("chase_timer", 20.0)
	
	_find_player()

# -------------------------------------------------------------------------
# [유틸리티]
# -------------------------------------------------------------------------
func _on_move_step_grid(diff: Vector2i):
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK]: return
	var dir_index = get_iso_dir_index(diff)
	current_state = State.RUN
	if anim_ctrl:
		anim_ctrl.play_anim_by_index(current_state, dir_index)
		anim_ctrl.current_dir_index = dir_index

func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0]

func _get_grid_distance(p1: Vector2i, p2: Vector2i) -> int:
	return max(abs(p1.x - p2.x), abs(p1.y - p2.y))

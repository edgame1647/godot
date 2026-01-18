class_name Enemy
extends BaseUnit

# -------------------------------------------------------------------------
# [Enemy 전용 설정]
# -------------------------------------------------------------------------
@export var attack_range: int = 1
@export var detection_range: int = 6 
@export var patrol_radius: int = 4   
@export var attack_cooldown: float = 1.5
@export var give_up_time: float = 20.0

# [변수]
var spawn_grid: Vector2i = Vector2i.ZERO 
var patrol_wait_timer: float = 0.0       
var is_patrolling: bool = false
var chase_timer: float = 0.0

var attack_timer: float = 0.0
var _target: Node2D = null

# [로드 상태 플래그]
var _loaded_from_data: bool = false

# [최적화 변수: 마지막 이동 목표]
var _last_target_grid: Vector2i = Vector2i.MAX

func _init():
	move_speed = 80.0 

func _ready():
	super._ready() 
	add_to_group("enemy")
	_find_player()
	
	if spawn_grid == Vector2i.ZERO:
		spawn_grid = GameManager.world_to_grid(global_position)
	
	# [중요] 세이브 파일에서 로드된 게 아닐 때만 초기화
	if not _loaded_from_data:
		chase_timer = give_up_time

func _physics_process(delta):
	if current_state == State.DIE: return
	
	if attack_timer > 0: attack_timer -= delta
	if patrol_wait_timer > 0: patrol_wait_timer -= delta
	if chase_timer > 0: chase_timer -= delta

func is_busy() -> bool:
	if mover and mover.is_moving: return true
	if current_state == State.ATTACK: return true
	if patrol_wait_timer > 0: return true 
	return false

# -------------------------------------------------------------------------
# [명령 수행]
# -------------------------------------------------------------------------
func execute_move(target_pos: Vector2):
	is_patrolling = false
	
	if not mover: return

	# [최적화] 이미 해당 목표 그리드로 이동 중이라면 경로 재계산 스킵
	var new_target_grid = GameManager.world_to_grid(target_pos)
	if mover.is_moving and _last_target_grid == new_target_grid:
		return
	
	_last_target_grid = new_target_grid
	mover.move_to(target_pos)

func execute_attack(target_unit: Node2D):
	if mover and mover.is_moving: 
		mover.stop_gracefully()
		_last_target_grid = Vector2i.MAX # 정지 시 목표 초기화
		return 
		
	if attack_timer > 0: return
	
	current_state = State.ATTACK
	attack_timer = attack_cooldown
	
	var dir_vec = (target_unit.global_position - global_position).normalized()
	if anim_ctrl:
		var dir_idx = get_iso_dir_index_from_vec(dir_vec)
		anim_ctrl.play_anim_by_index(int(State.ATTACK), dir_idx)

func execute_patrol():
	if is_patrolling and patrol_wait_timer > 0: return
	is_patrolling = true
	var rx = randi_range(-patrol_radius, patrol_radius)
	var ry = randi_range(-patrol_radius, patrol_radius)
	var target_pos = GameManager.grid_to_world(spawn_grid + Vector2i(rx, ry))
	
	if mover:
		# 패트롤은 랜덤성이므로 즉시 이동하되, 너무 잦은 호출 방지는 상위 로직에 의존
		mover.move_to(target_pos)
		patrol_wait_timer = randf_range(1.0, 3.0) 

func execute_stop():
	if mover and mover.is_moving: 
		mover.stop_gracefully()
	_last_target_grid = Vector2i.MAX
	is_patrolling = false

# -------------------------------------------------------------------------
# [데이터 저장 및 로드]
# -------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data["type"] = "ENEMY"
	data["spawn_grid_x"] = spawn_grid.x
	data["spawn_grid_y"] = spawn_grid.y
	data["chase_timer"] = chase_timer 
	return data

func load_from_data(data: Dictionary):
	_loaded_from_data = true
	super.load_from_data(data)
	spawn_grid = Vector2i(data.get("spawn_grid_x", 0), data.get("spawn_grid_y", 0))
	chase_timer = data.get("chase_timer", 0.0)
	
	if is_inside_tree():
		_find_player()

func _find_player():
	if not is_inside_tree(): return
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0: _target = players[0]

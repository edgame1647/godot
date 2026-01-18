class_name Enemy
extends GameUnit

# -------------------------------------------------------------------------
# [AI 설정]
# -------------------------------------------------------------------------
@export_group("AI Settings")
@export var wander_radius: int = 3
@export var wander_interval: float = 3.0
@export var wander_chance: float = 0.5

var _wander_timer: float = 0.0

# -------------------------------------------------------------------------
# [초기화 및 루프]
# -------------------------------------------------------------------------
func _init():
	move_speed = 70.0

func _ready():
	super._ready()
	_wander_timer = randf_range(1.0, wander_interval)

func _physics_process(delta):
	if current_state in [State.DIE, State.TAKE_DAMAGE]:
		return

	if current_state == State.ATTACK:
		_process_attack_behavior()
	elif current_state == State.IDLE:
		if mover and not mover.is_moving:
			_process_wander_behavior(delta)

# -------------------------------------------------------------------------
# [AI 행동 로직]
# -------------------------------------------------------------------------
func _process_attack_behavior():
	if is_instance_valid(target):
		var attack_dir = (target.global_position - global_position).normalized()
		if anim_ctrl: anim_ctrl.play_anim(AnimController.State.ATTACK, attack_dir)
	else:
		if anim_ctrl: anim_ctrl.play_anim(AnimController.State.ATTACK)

func _process_wander_behavior(delta: float):
	_wander_timer -= delta
	
	if _wander_timer <= 0:
		_wander_timer = wander_interval + randf_range(-0.5, 0.5)
		if randf() > wander_chance: return
		
		_try_wander_move()

func _try_wander_move():
	if not mover: return

	var current_grid = grid_pos
	if current_grid == Vector2i.ZERO:
		current_grid = GameManager.world_to_grid(global_position)
	
	var rand_x = randi_range(-wander_radius, wander_radius)
	var rand_y = randi_range(-wander_radius, wander_radius)
	
	if rand_x == 0 and rand_y == 0: return
	
	var target_grid = current_grid + Vector2i(rand_x, rand_y)
	var target_pos = GameManager.grid_to_world(target_grid)
	
	_move_to_target_pos(target_pos)

func _move_to_target_pos(pos: Vector2):
	if current_state in [State.ATTACK, State.DIE]: return
	
	current_state = State.WALK if move_speed <= 70.0 else State.RUN
	mover.move_to(pos)

# -------------------------------------------------------------------------
# [오버라이드]
# -------------------------------------------------------------------------
func _on_move_end():
	super._on_move_end() # 부모 로직 실행 (IDLE 전환 등)
	
	# 적군 전용: 복귀 후 즉시 이동하지 않도록 타이머 리셋
	if current_state == State.IDLE:
		_wander_timer = wander_interval

func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data["type"] = "ENEMY"
	return data

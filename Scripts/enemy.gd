class_name Enemy
extends GameUnit

# -------------------------------------------------------------------------
# [설정]
# -------------------------------------------------------------------------
@export var attack_range: int = 1
@export var attack_cooldown: float = 1.5

var _target: Node2D = null
var _attack_timer: float = 0.0

# -------------------------------------------------------------------------
# [초기화]
# -------------------------------------------------------------------------
func _init():
	move_speed = 100.0 

func _ready():
	super._ready()
	_find_player()

func _physics_process(delta):
	if current_state == State.DIE: return
	
	if _attack_timer > 0:
		_attack_timer -= delta

	if not is_instance_valid(_target):
		_find_player()
		return
	
	# [이동 로직 삭제됨] -> AIManager가 시킬 때만 움직임
	
	# [공격 로직] 사거리 체크는 스스로 함 (공격은 즉발적이어야 하므로)
	var my_grid = GameManager.world_to_grid(global_position)
	var target_grid = GameManager.world_to_grid(_target.global_position)
	var dist = _get_grid_distance(my_grid, target_grid)
	
	if dist <= attack_range:
		_try_attack()
	
	# 이동 중이 아닐 때 상태 복귀
	if mover and not mover.is_moving and current_state == State.RUN:
		current_state = State.IDLE

# -------------------------------------------------------------------------
# [명령 수신] AIManager가 호출하는 함수
# -------------------------------------------------------------------------
func ai_move_to(target_pos: Vector2):
	if current_state in [State.ATTACK, State.TAKE_DAMAGE, State.DIE]: return
	
	# 이미 이동 중이면 명령 무시 (GridMover가 가고 있으니까)
	if mover and mover.is_moving: return
	
	# GridMover를 통해 이동 (자동으로 좌표 선점 처리됨)
	mover.move_to(target_pos)

# -------------------------------------------------------------------------
# [전투]
# -------------------------------------------------------------------------
func _try_attack():
	if _attack_timer > 0: return
	if current_state in [State.ATTACK, State.TAKE_DAMAGE]: return
	
	# 공격 시도 시 이동 중이라면 멈춤
	if mover and mover.is_moving:
		mover.stop_gracefully()
		return 
	
	current_state = State.ATTACK
	_attack_timer = attack_cooldown
	
	var dir_vec = (_target.global_position - global_position).normalized()
	if anim_ctrl:
		var dir_idx = get_iso_dir_index_from_vec(dir_vec)
		anim_ctrl.play_anim_by_index(State.ATTACK, dir_idx)
	
	print("[Enemy] 공격 수행!")

# -------------------------------------------------------------------------
# [오버라이드] 이동 애니메이션 동기화
# -------------------------------------------------------------------------
func _on_move_step_grid(diff: Vector2i):
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK]: return
	
	var dir_index = get_iso_dir_index(diff)
	current_state = State.RUN
	
	if anim_ctrl:
		anim_ctrl.play_anim_by_index(current_state, dir_index)
		anim_ctrl.current_dir_index = dir_index

# -------------------------------------------------------------------------
# [유틸리티]
# -------------------------------------------------------------------------
func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0]

func _get_grid_distance(p1: Vector2i, p2: Vector2i) -> int:
	return max(abs(p1.x - p2.x), abs(p1.y - p2.y))

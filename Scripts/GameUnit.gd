class_name GameUnit
extends CharacterBody2D

# -------------------------------------------------------------------------
# [설정]
# -------------------------------------------------------------------------
@export var move_speed: float = 80.0

# [상태 열거형]
enum State { IDLE, WALK, RUN, ATTACK, DIE, TAKE_DAMAGE, ATTACK5 }

# [데이터]
var hp: int = 100
var max_hp: int = 100
var grid_pos: Vector2i = Vector2i.ZERO 
var current_state: State = State.IDLE

# [참조]
var target: Node2D = null 
@onready var anim_ctrl: AnimController = $AnimController 
@onready var mover: GridMover = $GridMover 

# -------------------------------------------------------------------------
# [라이프사이클]
# -------------------------------------------------------------------------
func _ready():
	_setup_components()

func _setup_components():
	if mover:
		mover.move_speed = move_speed
		mover.on_move_step_grid.connect(_on_move_step_grid)
		mover.on_move_end.connect(_on_move_end)
		
	if anim_ctrl and anim_ctrl.anim_player:
		if not anim_ctrl.anim_player.animation_finished.is_connected(_on_anim_finished):
			anim_ctrl.anim_player.animation_finished.connect(_on_anim_finished)

# -------------------------------------------------------------------------
# # Region: 전투 및 상태 (Combat & State)
# -------------------------------------------------------------------------
# region Combat & State

func take_damage(amount: int):
	if current_state == State.DIE: return

	hp -= amount
	if hp <= 0:
		die()
	else:
		_play_take_damage_anim()

func _play_take_damage_anim():
	current_state = State.TAKE_DAMAGE
	if mover: mover.is_moving = false
	if anim_ctrl:
		anim_ctrl.play_anim_by_index(AnimController.State.TAKE_DAMAGE, anim_ctrl.current_dir_index)

func die():
	hp = 0
	current_state = State.DIE
	
	if mover:
		mover.is_moving = false
		mover.current_path.clear()
	
	if anim_ctrl:
		anim_ctrl.play_anim_by_index(AnimController.State.DIE, anim_ctrl.current_dir_index)
		
	print("[%s] 사망했습니다." % name)

func cast_spell():
	if current_state in [State.DIE, State.TAKE_DAMAGE]: return
	
	if mover: mover.is_moving = false
	current_state = State.ATTACK5
	
	var cast_dir_idx = anim_ctrl.current_dir_index if anim_ctrl else 3
	if is_instance_valid(target):
		var dir_vec = (target.global_position - global_position).normalized()
		cast_dir_idx = get_iso_dir_index_from_vec(dir_vec)
	
	if anim_ctrl:
		anim_ctrl.play_anim_by_index(AnimController.State.ATTACK5, cast_dir_idx)

# 애니메이션 종료 콜백
func _on_anim_finished(_anim_name: String):
	if current_state == State.DIE: return
	
	# 특수 행동 후 IDLE 복귀
	if current_state in [State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]:
		current_state = State.IDLE
		if anim_ctrl: anim_ctrl.play_anim(AnimController.State.IDLE)

# endregion

# -------------------------------------------------------------------------
# # Region: 이동 이벤트 (Movement Events)
# -------------------------------------------------------------------------
# region Movement Events

func _on_move_step_grid(diff: Vector2i):
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]: 
		return

	var dir_index = get_iso_dir_index(diff)
	
	# 상태에 따른 걷기/뛰기 애니메이션
	if current_state == State.RUN:
		if anim_ctrl: anim_ctrl.play_anim_by_index(AnimController.State.RUN, dir_index)
	elif current_state == State.WALK:
		if anim_ctrl: anim_ctrl.play_anim_by_index(AnimController.State.WALK, dir_index)

func _on_move_end():
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]: 
		return

	current_state = State.IDLE
	if anim_ctrl: anim_ctrl.play_anim(AnimController.State.IDLE)

# endregion

# -------------------------------------------------------------------------
# # Region: 데이터 및 유틸 (Data & Utils)
# -------------------------------------------------------------------------
# region Data & Utils

func get_save_data() -> Dictionary:
	var dir_idx = anim_ctrl.current_dir_index if anim_ctrl else 0
	return { "type": "UNIT", "hp": hp, "dir": dir_idx, "move_speed": move_speed }

func load_from_data(data: Dictionary):
	hp = data.get("hp", max_hp)
	move_speed = data.get("move_speed", move_speed)
	if mover: mover.move_speed = move_speed
	
	var dir = data.get("dir", 3)
	if anim_ctrl: anim_ctrl.play_anim_by_index(0, dir)

func set_textures_directly(
	idle: Texture2D, run: Texture2D, walk: Texture2D, attack: Texture2D, 
	die: Texture2D = null, take_damage: Texture2D = null, attack5: Texture2D = null
):
	if anim_ctrl:
		anim_ctrl.texture_idle = idle
		anim_ctrl.texture_run = run
		anim_ctrl.texture_walk = walk
		anim_ctrl.texture_attack = attack
		anim_ctrl.texture_die = die
		anim_ctrl.texture_take_damage = take_damage
		anim_ctrl.texture_cast_spell = attack5
		
		# 즉시 갱신
		anim_ctrl._update_texture_by_state(anim_ctrl.current_state)

# 그리드 차이(Vector2i)를 8방향 인덱스로 변환
func get_iso_dir_index(diff: Vector2i) -> int:
	match diff:
		Vector2i(-1, 1): return 4
		Vector2i(1, -1): return 0
		Vector2i(-1, -1): return 6
		Vector2i(1, 1): return 2
		Vector2i(-1, 0): return 5
		Vector2i(0, -1): return 7
		Vector2i(0, 1): return 3
		Vector2i(1, 0): return 1
	return 2

# 벡터 각도를 8방향 인덱스로 변환
func get_iso_dir_index_from_vec(dir: Vector2) -> int:
	var angle = rad_to_deg(dir.angle())
	if angle < 0: angle += 360
	return int((angle + 22.5) / 45.0) % 8

# endregion

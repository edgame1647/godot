class_name GameUnit
extends CharacterBody2D

# -------------------------------------------------------------------------
# [공통 설정]
# -------------------------------------------------------------------------
@export var move_speed: float = 80.0

# [공통 데이터]
var hp: int = 100
var max_hp: int = 100
var grid_pos: Vector2i = Vector2i.ZERO 

# [공통 변수]
var target: Node2D = null 

@onready var anim_ctrl = $AnimController 
@onready var mover = $GridMover 

# [상태] 7가지 상태 정의
enum State { IDLE, WALK, RUN, ATTACK, DIE, TAKE_DAMAGE, ATTACK5 }
var current_state = State.IDLE

func _ready():
	if mover:
		mover.move_speed = move_speed
		mover.on_move_step_grid.connect(_on_move_step_grid)
		mover.on_move_end.connect(_on_move_end)
		
	# [이벤트] 애니메이션 종료 시점 감지 (피격, 공격, 마법 후 복귀용)
	if anim_ctrl and anim_ctrl.anim_player:
		if not anim_ctrl.anim_player.animation_finished.is_connected(_on_anim_finished):
			anim_ctrl.anim_player.animation_finished.connect(_on_anim_finished)

# -------------------------------------------------------------------------
# [전투 시스템] 피격 및 사망
# -------------------------------------------------------------------------
func take_damage(amount: int):
	# 이미 죽었으면 무시
	if current_state == State.DIE: return

	hp -= amount
	if hp <= 0:
		die()
	else:
		play_take_damage_anim()

func play_take_damage_anim():
	current_state = State.TAKE_DAMAGE
	
	if mover: mover.is_moving = false # 경직(멈춤)
	
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
		
	print(name, " 가 사망했습니다.")

# -------------------------------------------------------------------------
# [전투 시스템] 주문 시전 (Attack5)
# -------------------------------------------------------------------------
func cast_spell():
	# 죽거나, 맞고 있거나, 이미 특수 행동 중이면 무시
	if current_state in [State.DIE, State.TAKE_DAMAGE]: return
	
	if mover: mover.is_moving = false # 시전 중 이동 불가
	
	current_state = State.ATTACK5
	
	var cast_dir_idx = anim_ctrl.current_dir_index
	# 타겟이 있으면 그쪽을 바라보고 시전
	if target:
		var dir_vec = (target.global_position - global_position).normalized()
		cast_dir_idx = get_iso_dir_index_from_vec(dir_vec)
	
	if anim_ctrl:
		anim_ctrl.play_anim_by_index(AnimController.State.ATTACK5, cast_dir_idx)

# -------------------------------------------------------------------------
# [이벤트 핸들러] 애니메이션 종료 (IDLE 복귀)
# -------------------------------------------------------------------------
func _on_anim_finished(_anim_name: String):
	if current_state == State.DIE: return # 죽은 상태는 복귀 안 함
	
	# 피격, 공격, 주문 시전이 끝나면 IDLE로 돌아감
	if current_state in [State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]:
		current_state = State.IDLE
		if anim_ctrl: anim_ctrl.play_anim(AnimController.State.IDLE)

# -------------------------------------------------------------------------
# [이동 시스템] 그리드 이동
# -------------------------------------------------------------------------
func _on_move_step_grid(diff: Vector2i):
	# 특수 상태일 때는 걷는 모션 재생 안 함 (미끄러지듯 이동 방지)
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]: return

	var dir_index = get_iso_dir_index(diff)
	if current_state == State.RUN:
		if anim_ctrl: anim_ctrl.play_anim_by_index(AnimController.State.RUN, dir_index)
	elif current_state == State.WALK:
		if anim_ctrl: anim_ctrl.play_anim_by_index(AnimController.State.WALK, dir_index)

func _on_move_end():
	# [중요] 특수 상태(공격, 시전 등)가 진행 중이라면 IDLE로 덮어쓰지 않음
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]: return

	current_state = State.IDLE
	if anim_ctrl: anim_ctrl.play_anim(AnimController.State.IDLE) 

# -------------------------------------------------------------------------
# [데이터 시스템] 저장/로드
# -------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	var dir_idx = 0
	if anim_ctrl: dir_idx = anim_ctrl.current_dir_index
	return { "type": "UNIT", "hp": hp, "dir": dir_idx, "move_speed": move_speed }

func load_from_data(data: Dictionary):
	hp = data.get("hp", max_hp)
	move_speed = data.get("move_speed", move_speed)
	if mover: mover.move_speed = move_speed
	var dir = data.get("dir", 3)
	if anim_ctrl: anim_ctrl.play_anim_by_index(0, dir)

# -------------------------------------------------------------------------
# [유틸리티] 텍스처 설정 및 방향 계산
# -------------------------------------------------------------------------
# [수정됨] 모든 상태(7종)에 대한 텍스처를 받아서 설정
func set_textures_directly(
	idle: Texture2D, 
	run: Texture2D, 
	walk: Texture2D, 
	attack: Texture2D, 
	die: Texture2D = null, 
	take_damage: Texture2D = null, 
	attack5: Texture2D = null
):
	if anim_ctrl:
		anim_ctrl.texture_idle = idle
		anim_ctrl.texture_run = run
		anim_ctrl.texture_walk = walk
		anim_ctrl.texture_attack = attack
		
		# [추가된 연결]
		anim_ctrl.texture_die = die
		anim_ctrl.texture_take_damage = take_damage
		anim_ctrl.texture_cast_spell = attack5
		
		# 현재 상태 텍스처 즉시 갱신 (만약 이미 해당 상태라면 그림이 바뀜)
		anim_ctrl._update_texture_by_state(anim_ctrl.current_state)

func get_iso_dir_index(diff: Vector2i) -> int:
	if diff == Vector2i(-1, 1): return 4
	if diff == Vector2i(1, -1): return 0
	if diff == Vector2i(-1, -1): return 6
	if diff == Vector2i(1, 1): return 2
	if diff == Vector2i(-1, 0): return 5
	if diff == Vector2i(0, -1): return 7
	if diff == Vector2i(0, 1): return 3
	if diff == Vector2i(1, 0): return 1
	return 2

func get_iso_dir_index_from_vec(dir: Vector2) -> int:
	var angle = rad_to_deg(dir.angle())
	if angle < 0: angle += 360
	var idx = int((angle + 22.5) / 45.0) % 8
	return idx

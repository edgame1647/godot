class_name BaseUnit
extends CharacterBody2D

# -------------------------------------------------------------------------
# [설정 및 변수]
# -------------------------------------------------------------------------
@export_group("Identity")
@export var character_id: int = 1:
	set(value):
		character_id = value
		_update_anim_config() # ID 바뀌면 즉시 이미지 갱신 시도

@export_group("Stats")
@export var move_speed: float = 100.0
@export var max_hp: int = 100
@export var hp: int = 100

enum State { IDLE, WALK, RUN, ATTACK, DIE, TAKE_DAMAGE, ATTACK5 }

var grid_pos: Vector2i = Vector2i.ZERO 
var current_state: State = State.IDLE

@onready var anim_ctrl: AnimController = $AnimController 
@onready var mover: GridMover = $GridMover 

# -------------------------------------------------------------------------
# [라이프사이클]
# -------------------------------------------------------------------------
func _ready():
	add_to_group("unit")
	
	grid_pos = GameManager.world_to_grid(global_position)
	global_position = GameManager.grid_to_world(grid_pos)
	
	_setup_components()

func _setup_components():
	# 1. 이동 컴포넌트 연결
	if mover:
		mover.move_speed = move_speed
		if not mover.on_move_step_grid.is_connected(_on_move_step_grid):
			mover.on_move_step_grid.connect(_on_move_step_grid)
		if not mover.on_move_end.is_connected(_on_move_end):
			mover.on_move_end.connect(_on_move_end)
		
	# 2. 애니메이션 컴포넌트 설정
	if anim_ctrl:
		_update_anim_config() # 경로 설정
		
		if anim_ctrl.anim_player:
			if not anim_ctrl.anim_player.animation_finished.is_connected(_on_anim_finished):
				anim_ctrl.anim_player.animation_finished.connect(_on_anim_finished)
	
	# 3. 초기 상태 재생
	call_deferred("_initial_anim_play")

func _update_anim_config():
	if not is_inside_tree() or not anim_ctrl: return
	
	# [통합 경로] GameManager에 정의된 경로 하나만 씁니다.
	var path_to_use = "res://Images/Characters/Player" # 기본값(안전장치)
	if "BASE_SKIN_PATH" in GameManager:
		path_to_use = GameManager.BASE_SKIN_PATH
	
	anim_ctrl.set_config(path_to_use, character_id)

func _initial_anim_play():
	if anim_ctrl:
		_update_anim_config()
		var start_dir = anim_ctrl.current_dir_index if anim_ctrl.current_dir_index else 3
		anim_ctrl.play_anim_by_index(int(current_state), start_dir)

# -------------------------------------------------------------------------
# [이동 이벤트 & 방향 계산]
# -------------------------------------------------------------------------
func _on_move_step_grid(diff: Vector2i):
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]: return
	
	# [중요] 그리드 변화량(diff)에 따른 방향 인덱스 추출
	var dir_index = get_iso_dir_index(diff)
	
	var next_state = State.RUN
	if move_speed <= 70.0: next_state = State.WALK
	current_state = next_state
	
	if anim_ctrl:
		anim_ctrl.play_anim_by_index(int(current_state), dir_index)
		anim_ctrl.current_dir_index = dir_index # 방향 기억

func _on_move_end():
	if current_state in [State.DIE, State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]: return
	current_state = State.IDLE
	if anim_ctrl: anim_ctrl.play_anim(int(State.IDLE))

# [방향 계산 로직]
# 0:NE, 1:E, 2:SE, 3:S, 4:SW, 5:W, 6:NW, 7:N
func get_iso_dir_index(diff: Vector2i) -> int:
	# 아이소메트릭 그리드에서:
	# (1, 0) 은 화면 오른쪽 아래 -> SE(2)
	# (0, 1) 은 화면 왼쪽 아래 -> SW(4)
	# (0, -1) 은 화면 오른쪽 위 -> NE(0)
	# (-1, 0) 은 화면 왼쪽 위 -> NW(6)
	
	match diff:
		Vector2i(0, -1): return 0 # NE (우상단)
		Vector2i(1, 0):  return 2 # SE (우하단)
		Vector2i(0, 1):  return 4 # SW (좌하단)
		Vector2i(-1, 0): return 6 # NW (좌상단)
		
		# 혹시 대각선 이동(그리드 2칸 점프 등)이 있다면 보정
		Vector2i(1, -1): return 1 # E
		Vector2i(1, 1):  return 3 # S
		Vector2i(-1, 1): return 5 # W
		Vector2i(-1, -1):return 7 # N

	return 3 # 기본값 South

# 각도 기반 방향 계산 (공격 시 사용)
func get_iso_dir_index_from_vec(dir: Vector2) -> int:
	var angle = rad_to_deg(dir.angle())
	if angle < 0: angle += 360
	return int((angle + 22.5) / 45.0) % 8

# -------------------------------------------------------------------------
# [전투 및 데이터]
# -------------------------------------------------------------------------
func take_damage(amount: int):
	if current_state == State.DIE: return
	hp -= amount
	if hp <= 0: die()
	else: _play_take_damage_anim()

func _play_take_damage_anim():
	current_state = State.TAKE_DAMAGE
	if mover: mover.is_moving = false
	if anim_ctrl: anim_ctrl.play_anim_by_index(int(State.TAKE_DAMAGE), anim_ctrl.current_dir_index)

func die():
	hp = 0
	current_state = State.DIE
	if mover: mover.is_moving = false; mover.current_path.clear()
	if is_in_group("unit"): remove_from_group("unit")
	if is_in_group("enemy"): remove_from_group("enemy")
	if anim_ctrl: anim_ctrl.play_anim_by_index(int(State.DIE), anim_ctrl.current_dir_index)

func _on_anim_finished(_anim_name: String):
	if current_state == State.DIE: return
	if current_state in [State.TAKE_DAMAGE, State.ATTACK, State.ATTACK5]:
		current_state = State.IDLE
		if anim_ctrl: anim_ctrl.play_anim(int(State.IDLE))

func get_save_data() -> Dictionary:
	var dir_idx = anim_ctrl.current_dir_index if anim_ctrl else 0
	return { "type": "UNIT", "hp": hp, "dir": dir_idx, "move_speed": move_speed, "grid_x": grid_pos.x, "grid_y": grid_pos.y, "character_id": character_id }

func load_from_data(data: Dictionary):
	hp = data.get("hp", max_hp)
	move_speed = data.get("move_speed", move_speed)
	character_id = data.get("character_id", 1)
	grid_pos = Vector2i(data.get("grid_x", 0), data.get("grid_y", 0))
	global_position = GameManager.grid_to_world(grid_pos)
	if mover: mover.move_speed = move_speed
	var dir = data.get("dir", 3)
	if anim_ctrl: anim_ctrl.play_anim_by_index(int(State.IDLE), dir)

extends GameUnit
class_name Enemy

# [배회 설정]
@export var wander_radius: int = 3      # 배회 반경 (칸)
@export var wander_interval: float = 3.0 # 대기 시간 (초)
@export var wander_chance: float = 0.5   # 이동 확률

var _wander_timer: float = 0.0

# [초기화]
func _init():
	move_speed = 70.0 # 적 기본 속도

func _ready():
	super._ready() # GameUnit의 _ready 실행 (신호 연결 등 포함됨)
	
	# 초기 타이머 랜덤 설정
	_wander_timer = randf_range(1.0, wander_interval)

	# (중요) GameUnit에서 on_move_end를 _on_move_end에 이미 연결했을 수도 있음.
	# 하지만 자식 클래스에서 오버라이드한 _on_move_end 로직이 필요하므로,
	# GameUnit의 _on_move_end도 호출되면서 추가 로직이 돌도록 설계해야 함.
	# 여기서는 super._on_move_end()를 오버라이드 함수 안에서 부르는 방식으로 처리.

func _physics_process(delta):
	# 죽거나 피격 중이면 로직 중단
	if current_state in [State.DIE, State.TAKE_DAMAGE]:
		return

	# 공격 상태 처리
	if current_state == State.ATTACK:
		if target and is_instance_valid(target):
			var attack_dir = (target.global_position - global_position).normalized()
			if anim_ctrl:
				anim_ctrl.play_anim(AnimController.State.ATTACK, attack_dir)
		else:
			if anim_ctrl:
				anim_ctrl.play_anim(AnimController.State.ATTACK)
	
	# 대기 상태일 때 배회 로직 (이동 중이 아닐 때)
	elif current_state == State.IDLE:
		if mover and not mover.is_moving:
			_process_wander(delta)

# -------------------------------------------------------------------------
# [AI 로직] 그리드 기반 랜덤 배회
# -------------------------------------------------------------------------
func _process_wander(delta):
	_wander_timer -= delta
	
	if _wander_timer <= 0:
		# 타이머 리셋
		_wander_timer = wander_interval + randf_range(-0.5, 0.5)
		
		# 확률 체크
		if randf() > wander_chance:
			return
			
		_do_random_move_grid()

func _do_random_move_grid():
	if not mover: return

	# 1. 현재 그리드 좌표 (GameUnit의 grid_pos 활용)
	var current_grid = grid_pos 
	if current_grid == Vector2i.ZERO: # 혹시 초기화 안됐으면 계산
		current_grid = GameManager.world_to_grid(global_position)
	
	# 2. 랜덤 이동 칸 수
	var rand_x = randi_range(-wander_radius, wander_radius)
	var rand_y = randi_range(-wander_radius, wander_radius)
	
	if rand_x == 0 and rand_y == 0: return # 제자리는 패스
	
	var target_grid = current_grid + Vector2i(rand_x, rand_y)
	
	# 3. 월드 좌표로 변환하여 GridMover에 전달
	# (GridMover.move_to는 내부적으로 다시 world_to_grid를 하므로 정확한 타일 중앙값 전달이 중요)
	var target_world_pos = GameManager.grid_to_world(target_grid)
	
	# 이동 시작
	move_to_target(target_world_pos)

# -------------------------------------------------------------------------
# [이동 헬퍼]
# -------------------------------------------------------------------------
func move_to_target(pos: Vector2):
	if current_state != State.ATTACK and current_state != State.DIE:
		# 속도에 따라 상태 결정
		if move_speed <= 70.0:
			current_state = State.WALK
		else:
			current_state = State.RUN
		
		# GridMover에게 이동 위임
		mover.move_to(pos)

# -------------------------------------------------------------------------
# [오버라이드] GameUnit의 메서드 확장
# -------------------------------------------------------------------------
func _on_move_end():
	# 1. 부모(GameUnit)의 기본 로직 실행 (상태를 IDLE로 변경 등)
	super._on_move_end()
	
	# 2. 적 전용 추가 로직: 배회 타이머 리셋
	if current_state == State.IDLE:
		_wander_timer = wander_interval

# -------------------------------------------------------------------------
# [데이터 시스템]
# -------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data["type"] = "ENEMY"
	return data

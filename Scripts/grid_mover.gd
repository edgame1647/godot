class_name GridMover
extends Node

# -------------------------------------------------------------------------
# [설정 및 신호]
# -------------------------------------------------------------------------
signal on_move_step_grid(diff: Vector2i) 
signal on_move_end                

@export var move_speed: float = 200.0

# [상태 변수]
var is_moving: bool = false
var current_path: Array[Vector2i] = []

var _parent: Node2D = null   
var _target_world_pos: Vector2 = Vector2.ZERO
var _current_diff: Vector2i = Vector2i.ZERO 

# -------------------------------------------------------------------------
# [초기화 및 프로세스]
# -------------------------------------------------------------------------
func _ready():
	_parent = get_parent() as Node2D
	if not _parent: 
		set_process(false)
		push_error("[GridMover] 부모 노드가 Node2D가 아닙니다.")

func _process(delta: float):
	if is_moving:
		_process_movement(delta)

# -------------------------------------------------------------------------
# [이동 로직]
# -------------------------------------------------------------------------
func move_to(world_pos: Vector2):
	if not _parent: return

	# 부모의 move_speed 속성이 있다면 동기화 (옵션)
	if "move_speed" in _parent:
		move_speed = _parent.move_speed

	# 1. 시작점 결정
	var start_grid: Vector2i
	if is_moving and "grid_pos" in _parent:
		# 이동 중이면 현재 목표였던 칸을 시작점으로 잡음
		start_grid = _parent.grid_pos
	else:
		# 정지 상태면 현재 위치 기준
		start_grid = GameManager.world_to_grid(_parent.global_position)
	
	var end_grid = GameManager.world_to_grid(world_pos)
	
	if start_grid == end_grid: return

	# 2. 경로 계산 (GameManager 위임)
	var path = GameManager.get_path_route(start_grid, end_grid)
	if path.is_empty(): return
	
	# 시작점 제외
	path.remove_at(0)
	if path.is_empty(): return
	
	# 3. 경로 등록 및 이동 시작
	current_path = path 
	
	if not is_moving:
		is_moving = true
		_set_next_waypoint()

func _set_next_waypoint():
	if current_path.is_empty():
		_stop_movement()
		return
	
	var next_grid = current_path.pop_front()
	var current_grid = Vector2i.ZERO
	
	if "grid_pos" in _parent:
		current_grid = _parent.grid_pos
	else:
		current_grid = GameManager.world_to_grid(_parent.global_position)
	
	_current_diff = next_grid - current_grid
	
	# GameManager를 통해 실제 이동 가능 여부 및 점유 처리
	if GameManager.move_unit_on_grid(_parent, current_grid, next_grid):
		_target_world_pos = GameManager.grid_to_world(next_grid)
		on_move_step_grid.emit(_current_diff)
	else:
		# 길이 막힘 (이동 중 장애물 생김 등)
		_stop_movement()

func _process_movement(delta: float):
	var dist = _parent.global_position.distance_to(_target_world_pos)
	
	# 도착 판정 (픽셀 단위 근접)
	if dist < 4.0:
		_parent.global_position = _target_world_pos
		_set_next_waypoint()
		return
		
	var move_dir = _parent.global_position.direction_to(_target_world_pos)
	_parent.global_position += move_dir * move_speed * delta
	
	# [애니메이션 동기화] 이동 중 방향 정보 계속 전송
	# (필요에 따라 emit 빈도를 줄일 수도 있음)
	on_move_step_grid.emit(_current_diff)

func _stop_movement():
	is_moving = false
	current_path.clear()
	on_move_end.emit()

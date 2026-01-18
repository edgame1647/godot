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
# [공개 함수]
# -------------------------------------------------------------------------
func move_to(world_pos: Vector2):
	if not _parent: return

	if "move_speed" in _parent:
		move_speed = _parent.move_speed

	# 시작점 결정
	var start_grid: Vector2i
	if is_moving and "grid_pos" in _parent:
		start_grid = _parent.grid_pos
	else:
		start_grid = GameManager.world_to_grid(_parent.global_position)
	
	var end_grid = GameManager.world_to_grid(world_pos)
	
	if start_grid == end_grid: return

	var path = GameManager.get_path_route(start_grid, end_grid)
	if path.is_empty(): return
	
	path.remove_at(0)
	if path.is_empty(): return
	
	current_path = path 
	
	if not is_moving:
		is_moving = true
		_set_next_waypoint()

# [핵심 수정] 부드러운 정지 (현재 발걸음은 마치고 멈춤)
func stop_gracefully():
	if not is_moving: return
	# 남은 경로만 삭제하면, _process_movement가 현재 목표까지 이동 후 
	# _set_next_waypoint에서 경로가 없음을 확인하고 자연스럽게 멈춤.
	current_path.clear()

# -------------------------------------------------------------------------
# [내부 이동 로직]
# -------------------------------------------------------------------------
func _set_next_waypoint():
	if current_path.is_empty():
		_stop_internal()
		return
	
	var next_grid = current_path.pop_front()
	var current_grid = Vector2i.ZERO
	
	if "grid_pos" in _parent:
		current_grid = _parent.grid_pos
	else:
		current_grid = GameManager.world_to_grid(_parent.global_position)
	
	# 좌표 선(先) 점유
	if GameManager.move_unit_on_grid(_parent, current_grid, next_grid):
		_target_world_pos = GameManager.grid_to_world(next_grid)
		_current_diff = next_grid - current_grid
		
		# 이동 방향 신호 방출
		on_move_step_grid.emit(_current_diff)
	else:
		_stop_internal()

func _process_movement(delta: float):
	var dist = _parent.global_position.distance_to(_target_world_pos)
	
	if dist < 4.0:
		_parent.global_position = _target_world_pos
		_set_next_waypoint() # 도착했으니 다음거 확인 (없으면 멈춤)
		return
		
	var move_dir = _parent.global_position.direction_to(_target_world_pos)
	_parent.global_position += move_dir * move_speed * delta

func _stop_internal():
	is_moving = false
	current_path.clear()
	on_move_end.emit() # 정지 신호 보냄

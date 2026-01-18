class_name GridMover
extends Node

# [설정] 기본 속도
@export var move_speed: float = 200.0

# [신호]
signal on_move_step_grid(diff: Vector2i) 
signal on_move_end                

var parent: Node2D = null   
var is_moving: bool = false
var current_path: Array[Vector2i] = []
var current_target_world_pos: Vector2 = Vector2.ZERO
var current_diff: Vector2i = Vector2i.ZERO 

func _ready():
	parent = get_parent()
	if not parent: set_process(false) 

func _process(delta):
	if is_moving:
		_process_movement(delta)

func move_to(world_pos: Vector2):
	if not parent: return

	# [안전장치] 속도 동기화
	if "move_speed" in parent:
		move_speed = parent.move_speed

	# 1. 시작점 결정
	var start_grid: Vector2i
	
	if is_moving:
		# [수정됨] 이동 중이라면, '지금 가고 있는 칸(parent.grid_pos)'이 다음 경로의 시작점이 됨
		# (이미 _set_next_waypoint에서 grid_pos를 도착 예정지로 업데이트 했기 때문)
		start_grid = parent.grid_pos
	else:
		# 멈춰있다면 현재 위치가 시작점
		if "grid_pos" in parent:
			start_grid = parent.grid_pos
		else:
			start_grid = GameManager.world_to_grid(parent.global_position)
	
	var end_grid = GameManager.world_to_grid(world_pos)
	
	# 같은 자리면 무시 (이동 중일 때 도착 예정지랑 같아도 무시됨)
	if start_grid == end_grid: 
		# [선택사항] 이동 중 같은 칸을 또 찍으면 멈추게 하려면 여기서 current_path.clear() 할 수도 있음
		return

	# 2. 경로 계산
	var path = GameManager.get_path_route(start_grid, end_grid)
	if path.is_empty(): return
	
	# 시작점(현재 칸) 제외
	path.remove_at(0)
	
	# 경로가 비었으면 리턴 (바로 옆칸이라 시작점 빼니 빈 경우 등)
	if path.is_empty(): return
	
	# 3. 경로 업데이트 (여기가 핵심!)
	current_path = path # 가던 길을 버리고 새 길로 덮어씌움 (예약)
	
	# 4. 멈춰있을 때만 시동을 건다.
	# 이동 중이었다면? current_path만 바꿨으니 _process_movement가 
	# 현재 칸 도착 후 다음 루프(_set_next_waypoint)에서 자연스럽게 새 경로를 꺼내감.
	if not is_moving:
		is_moving = true
		_set_next_waypoint()

func _set_next_waypoint():
	if current_path.is_empty():
		is_moving = false
		on_move_end.emit()
		return
	
	var next_grid = current_path.pop_front()
	var current_grid = parent.grid_pos
	
	current_diff = next_grid - current_grid
	
	# 논리적 이동 처리 (여기서 parent.grid_pos가 next_grid로 바뀜)
	if GameManager.move_unit_on_grid(parent, current_grid, next_grid):
		current_target_world_pos = GameManager.grid_to_world(next_grid)
		on_move_step_grid.emit(current_diff)
	else:
		is_moving = false
		on_move_end.emit()

func _process_movement(delta):
	var dist = parent.global_position.distance_to(current_target_world_pos)
	
	# 도착 판정 (픽셀 단위 근접)
	if dist < 4.0:
		parent.global_position = current_target_world_pos
		_set_next_waypoint() # 여기서 다음 예약된 경로(current_path)를 확인함
		return
		
	var move_dir = parent.global_position.direction_to(current_target_world_pos)
	
	parent.global_position += move_dir * move_speed * delta
	
	# 이동 중에도 방향을 계속 쏴줘야 애니메이션이 자연스러움
	on_move_step_grid.emit(current_diff)

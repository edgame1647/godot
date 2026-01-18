@tool
extends Node2D

# 격자 크기 설정 (가로 칸 수, 세로 칸 수)
@export var grid_map_size := Vector2i(10, 10)
# 타일 크기 (가로 64, 세로 32가 표준 아이소메트릭 비율)
@export var tile_size := Vector2i(64, 32)
# 격자 색상 및 두께
@export var grid_color := Color.WHITE
@export var line_width := 1.0

func _draw():
	var half_w = tile_size.x / 2.0
	var half_h = tile_size.y / 2.0
	
	# 세로 방향 선 그리기 (X축 고정, Y축 변화)
	for x in range(grid_map_size.x + 1):
		var start_pos = cartesian_to_isometric(Vector2(x, 0), half_w, half_h)
		var end_pos = cartesian_to_isometric(Vector2(x, grid_map_size.y), half_w, half_h)
		draw_line(start_pos, end_pos, grid_color, line_width)

	# 가로 방향 선 그리기 (Y축 고정, X축 변화)
	for y in range(grid_map_size.y + 1):
		var start_pos = cartesian_to_isometric(Vector2(0, y), half_w, half_h)
		var end_pos = cartesian_to_isometric(Vector2(grid_map_size.x, y), half_w, half_h)
		draw_line(start_pos, end_pos, grid_color, line_width)

# 좌표 변환 함수 (핵심 공식)
func cartesian_to_isometric(cart: Vector2, half_w: float, half_h: float) -> Vector2:
	return Vector2(
		(cart.x - cart.y) * half_w,
		(cart.x + cart.y) * half_h
	)

# 에디터에서 값을 바꿀 때마다 다시 그리기 위함
func _process(_delta):
	if Engine.is_editor_hint():
		queue_redraw()

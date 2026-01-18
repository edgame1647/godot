extends Node2D

var _highlighted_grid: Vector2i = Vector2i(-999, -999)

func _process(_delta: float):
	# 마우스 위치를 그리드 좌표로 변환
	var mouse_pos = get_global_mouse_position()
	var current_grid = GameManager.world_to_grid(mouse_pos)
	
	if current_grid != _highlighted_grid:
		_highlighted_grid = current_grid
		queue_redraw()

func _draw():
	if _highlighted_grid == Vector2i(-999, -999): return
	
	# [수정] GameManager의 통합된 TILE_SIZE 사용
	var half_w = GameManager.TILE_SIZE.x * 0.5
	var half_h = GameManager.TILE_SIZE.y * 0.5
	
	# 타일의 기준점 (위쪽 꼭짓점)
	var top_vertex = GameManager.grid_to_world(_highlighted_grid)
	
	# 중앙점 계산 (마름모의 중심)
	var center = top_vertex + Vector2(0, half_h) 
	
	# 마름모 꼭짓점 계산
	var points = PackedVector2Array([
		center + Vector2(0, -half_h), # Top
		center + Vector2(half_w, 0),  # Right
		center + Vector2(0, half_h),  # Bottom
		center + Vector2(-half_w, 0)  # Left
	])
	
	# 그리기 (닫힌 도형)
	points.append(points[0]) 
	draw_colored_polygon(points, Color(0, 1, 0, 0.2)) # 반투명 초록 채우기
	draw_polyline(points, Color(0, 1, 0, 0.8), 2.0)   # 테두리
	
	# 좌표 텍스트 표시
	draw_string(
		ThemeDB.fallback_font, 
		center + Vector2(-20, 5), 
		str(_highlighted_grid), 
		HORIZONTAL_ALIGNMENT_CENTER, 
		-1, 
		16, 
		Color.WHITE
	)

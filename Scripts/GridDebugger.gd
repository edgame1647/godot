extends Node2D

var highlighted_grid: Vector2i = Vector2i(-999, -999)

func _process(_delta):
	# 마우스 위치를 그리드 좌표로 변환
	var mouse_pos = get_global_mouse_position()
	var current_grid = GameManager.world_to_grid(mouse_pos)
	
	if current_grid != highlighted_grid:
		highlighted_grid = current_grid
		queue_redraw()

func _draw():
	if highlighted_grid == Vector2i(-999, -999): return
	
	var half_w = GameManager.TILE_WIDTH * 0.5
	var half_h = GameManager.TILE_HEIGHT * 0.5
	
	# [기존] 타일의 '위쪽 꼭짓점' 좌표
	var top_vertex = GameManager.grid_to_world(highlighted_grid)
	
	# [수정] 디버그 박스는 '중앙'에 그리기 위해 반 칸 아래로 내림!
	var center = top_vertex + Vector2(0, half_h) 
	
	# 마름모 꼭짓점 계산 (center 기준)
	var points = PackedVector2Array([
		center + Vector2(0, -half_h), # 위
		center + Vector2(half_w, 0),  # 오른쪽
		center + Vector2(0, half_h),  # 아래
		center + Vector2(-half_w, 0)  # 왼쪽
	])
	
	# 그리기
	points.append(points[0]) # 닫힌 도형
	draw_colored_polygon(points, Color(0, 1, 0, 0.2)) # 내부 채우기
	draw_polyline(points, Color(0, 1, 0, 0.8), 2.0)   # 테두리
	
	# 좌표 텍스트도 중앙에 표시
	draw_string(ThemeDB.fallback_font, center + Vector2(-20, 5), str(highlighted_grid), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

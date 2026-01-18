extends Node2D

@export_group("Grid Settings")
@export var tile_size = Vector2i(32, 32)
@export var map_rect = Rect2i(-100, -100, 200, 200) # 시작 좌표(x,y), 크기(w,h)

@export_group("Visuals")
@export var grid_color = Color(1, 1, 1, 0.2) # 희미한 흰색
@export var border_color = Color(1, 0, 0, 0.5) # 맵 테두리는 빨간색
@export var line_width = 1.0

func _draw():
	# 1. 수직선 그리기 (X축 이동)
	for x in range(map_rect.position.x, map_rect.position.x + map_rect.size.x + 1):
		var start_pos = Vector2(x * tile_size.x, map_rect.position.y * tile_size.y)
		var end_pos = Vector2(x * tile_size.x, (map_rect.position.y + map_rect.size.y) * tile_size.y)
		draw_line(start_pos, end_pos, grid_color, line_width)

	# 2. 수평선 그리기 (Y축 이동)
	for y in range(map_rect.position.y, map_rect.position.y + map_rect.size.y + 1):
		var start_pos = Vector2(map_rect.position.x * tile_size.x, y * tile_size.y)
		var end_pos = Vector2((map_rect.position.x + map_rect.size.x) * tile_size.x, y * tile_size.y)
		draw_line(start_pos, end_pos, grid_color, line_width)
	
	# 3. 전체 맵 테두리 (디버그용)
	var rect_start = Vector2(map_rect.position.x * tile_size.x, map_rect.position.y * tile_size.y)
	var rect_size = Vector2(map_rect.size.x * tile_size.x, map_rect.size.y * tile_size.y)
	draw_rect(Rect2(rect_start, rect_size), border_color, false, 2.0)

	# 4. (선택사항) 좌표 텍스트 표시 - 너무 많으면 렉 걸릴 수 있으니 주의
	# _draw_coordinates() 

func _draw_coordinates():
	var font = ThemeDB.fallback_font
	var font_size = 8
	for x in range(map_rect.position.x, map_rect.position.x + map_rect.size.x):
		for y in range(map_rect.position.y, map_rect.position.y + map_rect.size.y):
			var pos = Vector2(x * tile_size.x, y * tile_size.y) + Vector2(2, 10)
			draw_string(font, pos, str(x) + "," + str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.5))

func _ready():
	# Z-Index를 낮춰서 캐릭터들 발 밑에 그려지게 함
	z_index = -1 
	queue_redraw()

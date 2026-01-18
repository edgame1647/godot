extends Node

# -------------------------------------------------------------------------
# [설정] 그리드 및 씬 리소스
# -------------------------------------------------------------------------
const TILE_WIDTH = 64
const TILE_HEIGHT = 32
const BASE_PATH = "res://Images/Characters/Player"

# 프리로드 (경로가 정확한지 확인해주세요)
var player_scene: PackedScene = preload("res://Player/Player.tscn")
var enemy_scene: PackedScene = preload("res://Enemy/Enemy.tscn") 

enum UnitType { PLAYER, ENEMY, NPC }

# [변수] 유닛 관리 딕셔너리 { Vector2i(좌표) : Node(유닛) }
var units: Dictionary = {}

# A* 길찾기 객체
var astar = AStarGrid2D.new()

func _ready():
	_setup_astar()

func _setup_astar():
	# 맵 크기에 맞춰 영역 설정 (필요시 조절)
	astar.region = Rect2i(-100, -100, 200, 200)
	astar.cell_size = Vector2(TILE_WIDTH, TILE_HEIGHT)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS 
	astar.update()

# 길찾기 함수 (GridMover에서 호출)
func get_path_route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return astar.get_id_path(from, to)

# -------------------------------------------------------------------------
# [기능 0] 맵 초기화
# -------------------------------------------------------------------------
func clear_all_units():
	print(">>> 맵 초기화 시작 (모든 유닛 제거)")
	
	for pos in units:
		var unit = units[pos]
		if is_instance_valid(unit):
			unit.queue_free()
	
	units.clear()
	_setup_astar()

# -------------------------------------------------------------------------
# [기능 1] 유닛 생성 (핵심)
# -------------------------------------------------------------------------
func spawn_unit(type: UnitType, id: int, grid_pos: Vector2i, load_data: Dictionary = {}):
	var scene_to_spawn = null
	var unit_name_prefix = ""
	
	match type:
		UnitType.PLAYER: 
			scene_to_spawn = player_scene
			unit_name_prefix = "Player"
		UnitType.ENEMY: 
			scene_to_spawn = enemy_scene
			unit_name_prefix = "Enemy"
	
	if not scene_to_spawn:
		print("오류: 생성할 씬이 없습니다. Type: ", type)
		return

	var unit = scene_to_spawn.instantiate()
	
	# [이름 지정] 디버깅을 위해 좌표를 이름에 포함 (예: Enemy_3_1)
	unit.name = "%s_%d_%d" % [unit_name_prefix, grid_pos.x, grid_pos.y]
	
	unit.visible = false 
	unit.position = grid_to_world(grid_pos)
	
	# 유닛 내부에 그리드 좌표 저장
	if "grid_pos" in unit: 
		unit.grid_pos = grid_pos
		
	# 관리 목록에 등록
	units[grid_pos] = unit
	astar.set_point_solid(grid_pos, true) # 유닛이 있는 자리는 장애물 처리
	
	# 플레이어 스킨 적용
	if type == UnitType.PLAYER:
		_apply_skin_data_immediate(unit, id)

	# 씬 트리에 추가 (Main 씬)
	get_tree().current_scene.call_deferred("add_child", unit)
	
	# 초기화 대기 (애니메이션 및 데이터 로드)
	if load_data.is_empty():
		_wait_and_init_anim(unit, 3) # 기본 방향 3 (남동쪽)
	else:
		_wait_and_load_data(unit, load_data)
		
	print(">>> 유닛 생성됨: ", unit.name, " 위치: ", grid_pos)

# 데이터 로드 대기 코루틴
func _wait_and_load_data(unit: Node, data: Dictionary):
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(unit) and unit.has_method("load_from_data"):
		unit.load_from_data(data)
		unit.visible = true

# 애니메이션 초기화 대기 코루틴
func _wait_and_init_anim(unit: Node, dir_index: int):
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_instance_valid(unit): return
	
	var anim_ctrl = unit.get_node_or_null("AnimController")
	if anim_ctrl:
		if anim_ctrl.has_method("_init_nodes"): 
			anim_ctrl._init_nodes()
		if anim_ctrl.has_method("_update_texture_by_state"): 
			anim_ctrl._update_texture_by_state(0) # IDLE
		if anim_ctrl.has_method("play_anim_by_index"): 
			anim_ctrl.play_anim_by_index(0, dir_index) 
			
	unit.visible = true

# -------------------------------------------------------------------------
# [기능 2] 이동 관리 (GridMover에서 호출)
# -------------------------------------------------------------------------
func move_unit_on_grid(unit: Node, from: Vector2i, to: Vector2i) -> bool:
	# 제자리 이동은 성공으로 처리
	if from == to: return true

	# 목적지에 다른 유닛이 있으면 이동 불가
	if units.has(to) and is_instance_valid(units[to]) and units[to] != unit:
		return false
	
	# 기존 위치 비우기
	if units.has(from) and units[from] == unit:
		units.erase(from)
		astar.set_point_solid(from, false) 
	
	# 새 위치 등록
	units[to] = unit
	astar.set_point_solid(to, true) 
	
	# 유닛 내부 좌표 업데이트
	if "grid_pos" in unit: 
		unit.grid_pos = to
	
	return true

# -------------------------------------------------------------------------
# [기능 3] 유틸리티 및 리소스 로드
# -------------------------------------------------------------------------
func _apply_skin_data_immediate(player: Node, id: int):
	var folder_path = "%s/%d/" % [BASE_PATH, id]
	
	var tex_idle = load_safe(folder_path + "Idle.png")
	var tex_run = load_safe(folder_path + "Run.png")
	var tex_walk = load_safe(folder_path + "Walk.png")
	var tex_attack = load_safe(folder_path + "Attack.png")
	var tex_die = load_safe(folder_path + "Die.png") 
	var tex_damage = load_safe(folder_path + "TakeDamage.png") 
	var tex_attack5 = load_safe(folder_path + "Attack5.png") 
	
	if player.has_method("set_textures_directly"):
		player.set_textures_directly(
			tex_idle, tex_run, tex_walk, tex_attack, 
			tex_die, tex_damage, tex_attack5
		)

# 그리드 -> 월드 좌표 변환 (Isometric)
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var screen_x = (grid_pos.x - grid_pos.y) * (TILE_WIDTH * 0.5)
	var screen_y = (grid_pos.x + grid_pos.y) * (TILE_HEIGHT * 0.5)
	return Vector2(screen_x, screen_y)

# 월드 -> 그리드 좌표 변환 (Isometric)
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var half_w = TILE_WIDTH * 0.5
	var half_h = TILE_HEIGHT * 0.5
	# 정교한 변환 공식
	var x = (world_pos.x / half_w + world_pos.y / half_h) * 0.5
	var y = (world_pos.y / half_h - world_pos.x / half_w) * 0.5
	return Vector2i(floor(x), floor(y))

func load_safe(path: String) -> Texture2D:
	if FileAccess.file_exists(path):
		return load(path)
	return null

extends Node

# -------------------------------------------------------------------------
# [설정] 그리드 및 씬 리소스
# -------------------------------------------------------------------------
const TILE_WIDTH = 64
const TILE_HEIGHT = 32
const BASE_PATH = "res://Images/Characters/Player"

# 프리로드
var player_scene: PackedScene = preload("res://Player/Player.tscn")
var enemy_scene: PackedScene = preload("res://Enemy/Enemy.tscn") 

enum UnitType { PLAYER, ENEMY, NPC }

# [변수] 유닛 관리 딕셔너리 { Vector2i(좌표) : Node(유닛) }
var units: Dictionary = {}

# A* 길찾기 객체 (초기화 시 매번 새로 생성)
var astar: AStarGrid2D

func _ready():
	_setup_astar()

# A* 그리드 시스템 (재)구축
func _setup_astar():
	# 기존 객체가 있다면 메모리에서 해제될 것임
	astar = AStarGrid2D.new()
	
	# 맵 크기 설정 (넉넉하게 잡음)
	astar.region = Rect2i(-100, -100, 200, 200)
	astar.cell_size = Vector2(TILE_WIDTH, TILE_HEIGHT)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS 
	astar.update()

# 길찾기 경로 요청
func get_path_route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return astar.get_id_path(from, to)

# -------------------------------------------------------------------------
# [기능 0] 맵 초기화 (세이브 로드 시 필수)
# -------------------------------------------------------------------------
func clear_all_units():
	print(">>> [GameManager] 맵 초기화: 모든 유닛 제거 및 A* 리셋")
	
	# 1. 모든 유닛 노드 삭제
	for pos in units:
		var unit = units[pos]
		if is_instance_valid(unit):
			unit.queue_free() # 즉시 삭제 대기
	
	units.clear()
	
	# 2. A* 그리드 완전 초기화 (유령 장애물 방지)
	_setup_astar()

# -------------------------------------------------------------------------
# [기능 1] 유닛 생성 (중복 방지 및 애니메이션 동기화 추가)
# -------------------------------------------------------------------------
func spawn_unit(type: UnitType, id: int, grid_pos: Vector2i, load_data: Dictionary = {}):
	# [중복 방지] 이미 해당 위치에 유닛이 관리되고 있다면 생성하지 않음
	if units.has(grid_pos):
		print("!!! [생성 실패] 좌표 중복: ", grid_pos, " 이미 유닛이 있습니다.")
		return

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
		return

	var unit = scene_to_spawn.instantiate()
	
	# 이름 및 기본 설정
	unit.name = "%s_%d_%d" % [unit_name_prefix, grid_pos.x, grid_pos.y]
	unit.position = grid_to_world(grid_pos)
	
	# [중요] 생성 직후에는 보이지 않게 처리 (애니메이션 셋팅 후 공개)
	unit.visible = false 
	
	# 유닛 내부 좌표 저장
	if "grid_pos" in unit: 
		unit.grid_pos = grid_pos
		
	# 관리 목록 등록 및 장애물 설치
	units[grid_pos] = unit
	astar.set_point_solid(grid_pos, true) 
	
	# 플레이어 스킨 로드
	if type == UnitType.PLAYER:
		_apply_skin_data_immediate(unit, id)

	# 씬 트리에 추가
	get_tree().current_scene.call_deferred("add_child", unit)
	
	# [비동기 초기화] 데이터 로드 or 기본 초기화
	if load_data.is_empty():
		_wait_and_init_anim(unit, 3) # 기본값: 방향 3
	else:
		_wait_and_load_data(unit, load_data)
		
	print(">>> 유닛 생성됨: ", unit.name, " @ ", grid_pos)

# -------------------------------------------------------------------------
# [기능 2] 데이터 로드 및 애니메이션 동기화
# -------------------------------------------------------------------------
# 세이브 데이터 로드 시 실행되는 코루틴
func _wait_and_load_data(unit: Node, data: Dictionary):
	# 노드가 트리에 완전히 들어올 때까지 대기
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_instance_valid(unit): return

	# 1. 데이터 복원 (체력, 상태 변수 등)
	if unit.has_method("load_from_data"):
		unit.load_from_data(data)
	
	# 2. [버그 수정] 애니메이션/스프라이트 강제 동기화
	# 데이터는 로드되었지만 화면(스프라이트)은 기본값일 수 있으므로 강제로 맞춤
	var anim = unit.get_node_or_null("AnimController")
	if anim:
		# 필요한 노드 참조 확보
		if anim.has_method("_init_nodes"): 
			anim._init_nodes()
		
		# 유닛의 현재 상태(current_state)에 맞는 텍스처로 교체
		# (예: data에 state가 0(Idle)이었다면 Idle 텍스처 로드)
		var state = unit.get("current_state") if "current_state" in unit else 0
		var direction = unit.get("current_direction") if "current_direction" in unit else 3
		
		if anim.has_method("_update_texture_by_state"):
			anim._update_texture_by_state(state)
			
		# 해당 프레임 즉시 재생
		if anim.has_method("play_anim_by_index"):
			anim.play_anim_by_index(state, direction)
	
	# 3. 모든 준비가 끝났으니 보이게 설정
	unit.visible = true

# 일반 생성 시 실행되는 코루틴
func _wait_and_init_anim(unit: Node, dir_index: int):
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_instance_valid(unit): return
	
	var anim = unit.get_node_or_null("AnimController")
	if anim:
		if anim.has_method("_init_nodes"): anim._init_nodes()
		if anim.has_method("_update_texture_by_state"): anim._update_texture_by_state(0) # IDLE
		if anim.has_method("play_anim_by_index"): anim.play_anim_by_index(0, dir_index) 
			
	unit.visible = true

# -------------------------------------------------------------------------
# [기능 3] 이동 관리
# -------------------------------------------------------------------------
func move_unit_on_grid(unit: Node, from: Vector2i, to: Vector2i) -> bool:
	if from == to: return true

	# 목표 지점에 다른 유닛이 있는지 확인
	if units.has(to) and is_instance_valid(units[to]) and units[to] != unit:
		return false
	
	# 기존 위치 비우기
	if units.has(from) and units[from] == unit:
		units.erase(from)
		astar.set_point_solid(from, false) # 장애물 해제
	
	# 새 위치 등록
	units[to] = unit
	astar.set_point_solid(to, true) # 장애물 설정
	
	if "grid_pos" in unit: 
		unit.grid_pos = to
	
	return true

# -------------------------------------------------------------------------
# [기능 4] 유틸리티
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
		player.set_textures_directly(tex_idle, tex_run, tex_walk, tex_attack, tex_die, tex_damage, tex_attack5)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var screen_x = (grid_pos.x - grid_pos.y) * (TILE_WIDTH * 0.5)
	var screen_y = (grid_pos.x + grid_pos.y) * (TILE_HEIGHT * 0.5)
	return Vector2(screen_x, screen_y)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var half_w = TILE_WIDTH * 0.5
	var half_h = TILE_HEIGHT * 0.5
	var x = (world_pos.x / half_w + world_pos.y / half_h) * 0.5
	var y = (world_pos.y / half_h - world_pos.x / half_w) * 0.5
	return Vector2i(floor(x), floor(y))

func load_safe(path: String) -> Texture2D:
	if FileAccess.file_exists(path): return load(path)
	return null

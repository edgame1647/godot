extends Node
# Autoload 이름: GameManager

# -------------------------------------------------------------------------
# [설정] 상수
# -------------------------------------------------------------------------
const TILE_SIZE = Vector2i(64, 32)
const BASE_SKIN_PATH = "res://Images/Characters/Player"

const PATH_PLAYER_SCENE = "res://Player/Player.tscn"
const PATH_ENEMY_SCENE = "res://Enemy/Enemy.tscn"

const TYPE_PLAYER = 0
const TYPE_ENEMY = 1

var _enemy_packed_scene: PackedScene 
var _units: Dictionary = {} 
var _astar: AStarGrid2D

# -------------------------------------------------------------------------
# [스킬 데이터]
# -------------------------------------------------------------------------
const SKILL_DATABASE = {
	1: { "name": "일반 공격", "range": 1, "mp_cost": 0, "anim_state": 3 },
	2: { "name": "원거리 화염구", "range": 4, "mp_cost": 1, "anim_state": 6 }
}

# -------------------------------------------------------------------------
# [초기화]
# -------------------------------------------------------------------------
func _ready():
	_init_grid_system()
	if ResourceLoader.exists(PATH_ENEMY_SCENE):
		_enemy_packed_scene = load(PATH_ENEMY_SCENE)
	else:
		push_error("[GameManager] Enemy Scene을 찾을 수 없습니다: " + PATH_ENEMY_SCENE)

func _init_grid_system():
	# [수정 포인트] AStar 인스턴스를 새로 생성하여 이전 세션의 잔여 데이터를 완전히 제거합니다.
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(-100, -100, 200, 200)
	_astar.cell_size = Vector2(TILE_SIZE.x, TILE_SIZE.y)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	_astar.update()
	print("[GameManager] 그리드 시스템 초기화 완료")

# -------------------------------------------------------------------------
# [저장 및 로드]
# -------------------------------------------------------------------------
func request_save_game():
	print(">>> [GameManager] 저장 데이터 수집 중...")
	var save_data = { "units": [] }
	
	var nodes = get_tree().get_nodes_in_group("persist")
	for unit in nodes:
		if unit.has_method("get_save_data"):
			save_data["units"].append(unit.get_save_data())
	
	GameState.save_to_file(save_data)

func request_load_game():
	print(">>> [GameManager] 로드 요청...")
	var loaded_data = GameState.load_from_file()
	if loaded_data.is_empty(): return

	# 여기서 맵과 그리드를 초기화합니다.
	clear_map()
	
	var unit_list = loaded_data.get("units", [])
	for u_data in unit_list:
		var type_str = u_data.get("type", "ENEMY")
		var type_id = TYPE_ENEMY
		if type_str == "PLAYER": type_id = TYPE_PLAYER
		
		# [확인] Enemy.gd에서 저장한 grid_x, grid_y 키를 정확히 읽음
		var gx = int(u_data.get("grid_x", 0))
		var gy = int(u_data.get("grid_y", 0))
		var spawn_pos = Vector2i(gx, gy)
		
		spawn_unit(type_id, 1, spawn_pos, u_data)
	
	print(">>> [GameManager] 로드 완료.")

# -------------------------------------------------------------------------
# [유닛 생성]
# -------------------------------------------------------------------------
func spawn_unit(type: int, id: int, grid_pos: Vector2i, load_data: Dictionary = {}):
	if is_occupied(grid_pos) and load_data.is_empty(): 
		return

	var unit = _create_unit_instance(type)
	if not unit: return

	_configure_new_unit(unit, type, id, grid_pos)
	_register_unit_to_grid(unit, grid_pos)

	var main_scene = get_tree().current_scene
	main_scene.call_deferred("add_child", unit)

	_post_spawn_initialization(unit, load_data)

func clear_map():
	print(">>> [Map] 맵 초기화")
	# 1. 기존 유닛 객체 제거
	for pos in _units:
		if is_instance_valid(_units[pos]):
			_units[pos].queue_free()
	_units.clear()
	
	# 2. [핵심 수정] 그리드 시스템을 재초기화하여 '유령 장애물' 제거
	# 기존에는 _astar.update()만 호출했을 수 있으나, 이는 set_point_solid 상태를 초기화하지 않을 수 있습니다.
	_init_grid_system()

# -------------------------------------------------------------------------
# [내부 로직: 생성 후 처리]
# -------------------------------------------------------------------------
func _post_spawn_initialization(unit: Node, data: Dictionary):
	# 데이터가 있으면 복구 (위치, HP 등)
	if not data.is_empty() and unit.has_method("load_from_data"):
		unit.load_from_data(data)
	
	# [중요] 생성된 유닛이 씬 트리에 붙고 준비될 때까지 대기
	await get_tree().process_frame
	
	# 애니메이션 및 시각적 상태 동기화
	_sync_unit_animation(unit, data)
	unit.visible = true

func _sync_unit_animation(unit: Node, _data: Dictionary):
	var anim_ctrl = unit.get_node_or_null("AnimController")
	if not anim_ctrl: return
	
	# [수정] AnimController가 아직 준비 안됐을 수 있으므로 강제 초기화
	if anim_ctrl.has_method("_init_nodes"): 
		anim_ctrl._init_nodes()
	
	# 저장된 상태가 있으면 사용, 없으면 IDLE(0)
	var state = 0 
	var dir = 3 # 기본 방향 (남동쪽)
	
	if not _data.is_empty():
		state = int(_data.get("current_state", 0))
		dir = int(_data.get("current_direction", 3))
	
	# [수정] 강제로 애니메이션 재생 명령
	if anim_ctrl.has_method("play_anim_by_index"): 
		anim_ctrl.play_anim_by_index(state, dir)

# -------------------------------------------------------------------------
# [유틸리티]
# -------------------------------------------------------------------------
func is_walkable(grid_pos: Vector2i) -> bool:
	if not _astar: return false
	if not _astar.region.has_point(grid_pos): return false
	if _astar.is_point_solid(grid_pos): return false
	return true

func get_skill_data(skill_id: int) -> Dictionary:
	if SKILL_DATABASE.has(skill_id): return SKILL_DATABASE[skill_id]
	return {}

func move_unit_on_grid(unit: Node, from: Vector2i, to: Vector2i) -> bool:
	if from == to: return true
	if is_occupied(to) and _units[to] != unit: return false
	
	# 이전 위치 해제
	if _units.get(from) == unit:
		_units.erase(from)
		_astar.set_point_solid(from, false)
	
	# 새 위치 점유
	_units[to] = unit
	_astar.set_point_solid(to, true)
	if "grid_pos" in unit: unit.grid_pos = to
	return true

func get_path_route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return _astar.get_id_path(from, to)

func is_occupied(grid_pos: Vector2i) -> bool:
	return _units.has(grid_pos) and is_instance_valid(_units[grid_pos])

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var half_w = TILE_SIZE.x * 0.5
	var half_h = TILE_SIZE.y * 0.5
	var x = (world_pos.x / half_w + world_pos.y / half_h) * 0.5
	var y = (world_pos.y / half_h - world_pos.x / half_w) * 0.5
	return Vector2i(floor(x), floor(y))

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var x = (grid_pos.x - grid_pos.y) * (TILE_SIZE.x * 0.5)
	var y = (grid_pos.x + grid_pos.y) * (TILE_SIZE.y * 0.5)
	return Vector2(x, y)

func _create_unit_instance(type: int) -> Node:
	if type == TYPE_PLAYER:
		return load(PATH_PLAYER_SCENE).instantiate()
	elif type == TYPE_ENEMY:
		if _enemy_packed_scene: return _enemy_packed_scene.instantiate()
	return null

func _configure_new_unit(unit: Node, type: int, id: int, grid_pos: Vector2i):
	var prefix = "Player" if type == TYPE_PLAYER else "Enemy"
	unit.name = "%s_%d_%d" % [prefix, grid_pos.x, grid_pos.y]
	unit.position = grid_to_world(grid_pos)
	unit.visible = false # 생성 직후 깜빡임 방지
	
	if "grid_pos" in unit: unit.grid_pos = grid_pos
	
	if not unit.is_in_group("persist"): unit.add_to_group("persist")
	if type == TYPE_ENEMY:
		if not unit.is_in_group("enemy"): unit.add_to_group("enemy")
	elif type == TYPE_PLAYER:
		if not unit.is_in_group("player"): unit.add_to_group("player")
		_load_and_apply_skin(unit, id)

func _register_unit_to_grid(unit: Node, grid_pos: Vector2i):
	_units[grid_pos] = unit
	_astar.set_point_solid(grid_pos, true)

func _load_and_apply_skin(player: Node, id: int):
	# [주의] GameUnit에는 이 메서드가 있지만 BaseUnit에는 없을 수 있습니다.
	# 현재 구조는 GameUnit에 맞춰져 있습니다.
	if not player.has_method("set_textures_directly"): return
	var path = "%s/%d/" % [BASE_SKIN_PATH, id]
	player.set_textures_directly(
		_load_safe(path + "Idle.png"), _load_safe(path + "Run.png"), _load_safe(path + "Walk.png"),
		_load_safe(path + "Attack.png"), _load_safe(path + "Die.png"), 
		_load_safe(path + "TakeDamage.png"), _load_safe(path + "Attack5.png")
	)

func _load_safe(path: String) -> Texture2D:
	return load(path) if FileAccess.file_exists(path) else null

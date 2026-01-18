extends Node

# [주의] class_name 없음 (Autoload 충돌 방지)

# -------------------------------------------------------------------------
# [설정] 상수
# -------------------------------------------------------------------------
const TILE_SIZE = Vector2i(64, 32)
const BASE_SKIN_PATH = "res://Images/Characters/Player"

const PATH_PLAYER_SCENE = "res://Player/Player.tscn"
const PATH_ENEMY_SCENE = "res://Enemy/Enemy.tscn"

const TYPE_PLAYER = 0
const TYPE_ENEMY = 1
const TYPE_NPC = 2

# -------------------------------------------------------------------------
# [스킬 데이터베이스]
# -------------------------------------------------------------------------
const SKILL_DATABASE = {
	1: { 
		"name": "일반 공격", 
		"range": 1, 
		"mp_cost": 0, 
		"anim_state": 3 # AnimController.State.ATTACK
	},
	2: { 
		"name": "원거리 화염구", 
		"range": 4, 
		"mp_cost": 1, 
		"anim_state": 6 # AnimController.State.ATTACK5
	}
}

# -------------------------------------------------------------------------
# [상태]
# -------------------------------------------------------------------------
var _units: Dictionary = {} 
var _astar: AStarGrid2D

# -------------------------------------------------------------------------
# [초기화]
# -------------------------------------------------------------------------
func _ready():
	_init_grid_system()

# [누락되었던 함수 추가]
func _init_grid_system():
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(-100, -100, 200, 200)
	_astar.cell_size = Vector2(TILE_SIZE.x, TILE_SIZE.y)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	_astar.update()
	print("[GameManager] 그리드 시스템 초기화 완료")

# -------------------------------------------------------------------------
# # Region: 공개 메서드
# -------------------------------------------------------------------------
# region Public Methods

# 스킬 데이터 조회 함수
func get_skill_data(skill_id: int) -> Dictionary:
	if SKILL_DATABASE.has(skill_id):
		return SKILL_DATABASE[skill_id]
	print("오류: 존재하지 않는 스킬 ID입니다 (%d)" % skill_id)
	return {}

func clear_map():
	print(">>> [Map] 맵 초기화")
	for pos in _units:
		var unit = _units[pos]
		if is_instance_valid(unit):
			unit.queue_free()
	_units.clear()
	_init_grid_system()

func spawn_unit(type: int, id: int, grid_pos: Vector2i, load_data: Dictionary = {}):
	if is_occupied(grid_pos): return

	var unit = _create_unit_instance(type)
	if not unit: return

	_configure_new_unit(unit, type, id, grid_pos)
	_register_unit_to_grid(unit, grid_pos)

	get_tree().current_scene.call_deferred("add_child", unit)
	_post_spawn_initialization(unit, load_data)

func move_unit_on_grid(unit: Node, from: Vector2i, to: Vector2i) -> bool:
	if from == to: return true
	if is_occupied(to) and _units[to] != unit: return false
	
	if _units.get(from) == unit:
		_units.erase(from)
		_astar.set_point_solid(from, false)
	
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

# endregion

# -------------------------------------------------------------------------
# # Region: 내부 로직
# -------------------------------------------------------------------------
# region Private Methods

func _create_unit_instance(type: int) -> Node:
	var scene_path = ""
	match type:
		TYPE_PLAYER: scene_path = PATH_PLAYER_SCENE
		TYPE_ENEMY: scene_path = PATH_ENEMY_SCENE
	
	if scene_path != "" and ResourceLoader.exists(scene_path):
		var scn = load(scene_path)
		if scn: return scn.instantiate()
	return null

func _configure_new_unit(unit: Node, type: int, id: int, grid_pos: Vector2i):
	var prefix = "Player" if type == TYPE_PLAYER else "Enemy"
	unit.name = "%s_%d_%d" % [prefix, grid_pos.x, grid_pos.y]
	unit.position = grid_to_world(grid_pos)
	unit.visible = false
	
	if "grid_pos" in unit:
		unit.grid_pos = grid_pos
		
	if type == TYPE_PLAYER:
		_load_and_apply_skin(unit, id)

func _register_unit_to_grid(unit: Node, grid_pos: Vector2i):
	_units[grid_pos] = unit
	_astar.set_point_solid(grid_pos, true)

func _post_spawn_initialization(unit: Node, data: Dictionary):
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(unit): return
	if not data.is_empty() and unit.has_method("load_from_data"): unit.load_from_data(data)
	_sync_unit_animation(unit, data)
	unit.visible = true

func _sync_unit_animation(unit: Node, _data: Dictionary):
	var anim_ctrl = unit.get_node_or_null("AnimController")
	if not anim_ctrl: return
	if anim_ctrl.has_method("_init_nodes"): anim_ctrl._init_nodes()
	
	var state = unit.get("current_state") if "current_state" in unit else 0
	var dir = unit.get("current_direction") if "current_direction" in unit else 3
	
	if anim_ctrl.has_method("_update_texture_by_state"): anim_ctrl._update_texture_by_state(state)
	if anim_ctrl.has_method("play_anim_by_index"): anim_ctrl.play_anim_by_index(state, dir)

func _load_and_apply_skin(player: Node, id: int):
	if not player.has_method("set_textures_directly"): return
	var path = "%s/%d/" % [BASE_SKIN_PATH, id]
	player.set_textures_directly(
		_load_safe(path + "Idle.png"), _load_safe(path + "Run.png"), _load_safe(path + "Walk.png"),
		_load_safe(path + "Attack.png"), _load_safe(path + "Die.png"), 
		_load_safe(path + "TakeDamage.png"), _load_safe(path + "Attack5.png")
	)

func _load_safe(path: String) -> Texture2D:
	return load(path) if FileAccess.file_exists(path) else null

# endregion

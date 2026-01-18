class_name AnimController
extends Node

# -------------------------------------------------------------------------
# [리소스 설정]
# -------------------------------------------------------------------------
@export_group("Unit Textures") 
@export var texture_idle: Texture2D
@export var texture_run: Texture2D
@export var texture_walk: Texture2D
@export var texture_attack: Texture2D
@export var texture_die: Texture2D 
@export var texture_take_damage: Texture2D 
@export var texture_cast_spell: Texture2D 

# GameUnit.State 와 일치해야 함
enum State { IDLE, RUN, WALK, ATTACK, DIE, TAKE_DAMAGE, ATTACK5 }

const DIR_NAMES = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

# [내부 변수]
var parent: Node = null
var sprite: Sprite2D = null
var anim_player: AnimationPlayer = null

var current_state: State = State.IDLE
var current_dir_index: int = 3 

func _ready():
	_init_nodes() 

func _init_nodes():
	if not parent: parent = get_parent()
	if not parent: return 

	if not sprite: sprite = parent.get_node_or_null("Sprite2D")
	if not anim_player: anim_player = parent.get_node_or_null("AnimationPlayer")

# -------------------------------------------------------------------------
# [애니메이션 제어]
# -------------------------------------------------------------------------
func play_anim_by_index(state: State, dir_index: int):
	_init_nodes()
	
	if current_state != state:
		current_state = state
		_update_texture_by_state(state)
	
	current_dir_index = dir_index
	_play_animation_internal()

func play_anim(state: State, _dir: Vector2 = Vector2.ZERO):
	_init_nodes()
	# 벡터 기반 호출 시에도 내부적으로는 인덱스나 상태만 갱신 (필요 시 확장)
	if current_state != state:
		current_state = state
		_update_texture_by_state(state)
	
	_play_animation_internal()

func _play_animation_internal():
	if not anim_player: return 

	var state_str = _get_state_string(current_state)
	var dir_suffix = DIR_NAMES[current_dir_index % 8]
	var anim_name = "%s_%s" % [state_str, dir_suffix]
	
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)

func _update_texture_by_state(state: State):
	if not sprite: return 

	var target_tex: Texture2D = null
	match state:
		State.IDLE: target_tex = texture_idle
		State.RUN: target_tex = texture_run
		State.WALK: target_tex = texture_walk
		State.ATTACK: target_tex = texture_attack
		State.DIE: target_tex = texture_die 
		State.TAKE_DAMAGE: target_tex = texture_take_damage 
		State.ATTACK5: target_tex = texture_cast_spell 
	
	if target_tex:
		sprite.texture = target_tex

func _get_state_string(state: State) -> String:
	match state:
		State.IDLE: return "Idle"
		State.RUN: return "Run"
		State.WALK: return "Walk"
		State.ATTACK: return "Attack"
		State.DIE: return "Die"
		State.TAKE_DAMAGE: return "TakeDamage"
		State.ATTACK5: return "Attack5"
	return "Idle"

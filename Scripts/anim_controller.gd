class_name AnimController
extends Node

# -------------------------------------------------------------------------
# [설정] 유닛 텍스처 (GameManager에서 주입받음)
# -------------------------------------------------------------------------
@export_group("Unit Textures") 
@export var texture_idle: Texture2D
@export var texture_run: Texture2D
@export var texture_walk: Texture2D
@export var texture_attack: Texture2D
@export var texture_die: Texture2D 
@export var texture_take_damage: Texture2D 
@export var texture_cast_spell: Texture2D 

# [상태] GameUnit의 Enum과 순서/값이 같아야 함
enum State { IDLE, RUN, WALK, ATTACK, DIE, TAKE_DAMAGE, ATTACK5 }

# 0:E, 1:SE, 2:S, 3:SW, 4:W, 5:NW, 6:N, 7:NE
const DIR_NAMES = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

var parent: Node = null
var sprite: Sprite2D = null
var anim_player: AnimationPlayer = null

var current_state = State.IDLE
var current_dir_index: int = 3 

func _ready():
	_init_nodes() 

func _init_nodes():
	if not parent: parent = get_parent()
	if not parent: return 

	if not sprite: sprite = parent.get_node_or_null("Sprite2D")
	if not anim_player: anim_player = parent.get_node_or_null("AnimationPlayer")

# -------------------------------------------------------------------------
# [핵심] 인덱스 기반 애니메이션 재생
# -------------------------------------------------------------------------
func play_anim_by_index(state: State, dir_index: int):
	_init_nodes()
	
	if current_state != state:
		current_state = state
		_update_texture_by_state(state)
	
	current_dir_index = dir_index
	_play_animation()

# -------------------------------------------------------------------------
# [호환성] 벡터 기반 재생
# -------------------------------------------------------------------------
func play_anim(state: State, _dir: Vector2 = Vector2.ZERO):
	_init_nodes()
	
	if current_state != state:
		current_state = state
		_update_texture_by_state(state)
	
	_play_animation()

# -------------------------------------------------------------------------
# [내부 로직] 애니메이션 이름 생성 및 재생
# -------------------------------------------------------------------------
func _play_animation():
	if not anim_player: return 

	var state_str = ""
	
	match current_state:
		State.IDLE: state_str = "Idle"
		State.RUN: state_str = "Run"
		State.WALK: state_str = "Walk"
		State.ATTACK: state_str = "Attack"
		State.DIE: state_str = "Die"
		State.TAKE_DAMAGE: state_str = "TakeDamage"
		State.ATTACK5: state_str = "Attack5" 
	
	var dir_suffix = DIR_NAMES[current_dir_index]
	var anim_name = state_str + "_" + dir_suffix
	
	# [수정] 로그 삭제됨
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
	else:
		pass

# -------------------------------------------------------------------------
# [내부 로직] 텍스처 교체 (스프라이트 시트 변경)
# -------------------------------------------------------------------------
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
	
	if target_tex != null:
		sprite.texture = target_tex
	else:
		# 에러 로그는 디버깅을 위해 남겨두는 것을 추천하지만, 원하시면 삭제 가능
		print("오류: ", State.keys()[state], " 상태의 텍스처가 비어있습니다(NULL)!")

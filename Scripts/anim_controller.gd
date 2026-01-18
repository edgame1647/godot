class_name AnimController
extends Node

enum State { IDLE, WALK, RUN, ATTACK, DIE, TAKE_DAMAGE, ATTACK5 }

@export var anim_player: AnimationPlayer
@export var sprite: Sprite2D 

var folder_path: String = "" 
var character_id: int = 1
var _texture_cache: Dictionary = {}

const DIR_NAMES = ["NE", "E", "SE", "S", "SW", "W", "NW", "N"]
var current_dir_index: int = 3
var current_state: State = State.IDLE

var state_prefixes = {
	State.IDLE: "Idle",
	State.WALK: "Walk",
	State.RUN: "Run",
	State.ATTACK: "Attack",
	State.DIE: "Die",
	State.TAKE_DAMAGE: "Hit",
	State.ATTACK5: "Skill"
}

func _ready():
	if not anim_player:
		anim_player = find_child("AnimationPlayer", false, false)
		if not anim_player and get_parent():
			anim_player = get_parent().find_child("AnimationPlayer", true, false)
			
	if not sprite:
		sprite = find_child("Sprite2D", false, false)
		if not sprite and get_parent():
			sprite = get_parent().find_child("Sprite2D", true, false)

func set_config(path: String, id: int):
	var need_refresh = (folder_path != path) or (character_id != id)
	folder_path = path
	character_id = id
	if need_refresh:
		_texture_cache.clear()
		_update_texture_by_state(int(current_state))

func play_anim(state_idx: int):
	play_anim_by_index(state_idx, current_dir_index)

func play_anim_by_index(state_idx: int, dir_index: int):
	current_state = state_idx as State
	current_dir_index = wrapi(dir_index, 0, 8)
	
	_update_texture_by_state(state_idx)
	
	var prefix = state_prefixes.get(state_idx, "Idle")
	var suffix = DIR_NAMES[current_dir_index]
	var anim_name = "%s_%s" % [prefix, suffix]
	
	if anim_player:
		if not anim_player.has_animation(anim_name):
			if anim_player.has_animation(prefix):
				anim_name = prefix
			else:
				return

		# [핵심 수정] 이동/대기 동작은 무조건 루프(반복) 되도록 강제 설정
		# 이렇게 하면 애니메이션 파일 설정이 Loop가 아니어도 끊김 없이 재생됨
		if state_idx in [int(State.IDLE), int(State.WALK), int(State.RUN)]:
			var anim_res = anim_player.get_animation(anim_name)
			if anim_res:
				anim_res.loop_mode = Animation.LOOP_LINEAR
		
		# 이미 재생 중이면 다시 실행하지 않음 (끊김 방지)
		if anim_player.current_animation == anim_name and anim_player.is_playing():
			return
		
		anim_player.play(anim_name)

func _update_texture_by_state(state_idx: int):
	if not sprite or folder_path.is_empty(): return
	var st = state_idx as State
	var file_name = state_prefixes.get(st, "Idle")
	if _texture_cache.has(file_name):
		if sprite.texture != _texture_cache[file_name]:
			sprite.texture = _texture_cache[file_name]
		return
	var full_path = "%s/%d/%s.png" % [folder_path, character_id, file_name]
	if ResourceLoader.exists(full_path):
		var tex = load(full_path)
		if tex:
			_texture_cache[file_name] = tex
			sprite.texture = tex

extends CharacterBody2D
class_name BaseUnit

@export_group("Stats")
@export var speed: float = 100.0
@export var max_health: int = 100
@export var damage: int = 5
@export var attack_speed: float = 1.0

var tile_size = Vector2i(32, 32)

var current_health: int = 0
var last_dir_index: int = 2
const DIR_NAMES = ["d", "sd", "s", "sa", "a", "wa", "w", "wd"]
const INVALID_TILE = Vector2i(-9999, -9999)

@onready var sprite = $Sprite2D
@onready var health_bar = $HealthBar

var start_grid_pos: Vector2i = Vector2i.ZERO
var anim_offsets = { "idle": Vector2.ZERO, "run": Vector2.ZERO, "attack": Vector2.ZERO }

func _ready():
	tile_size = GameManager.tile_size
	current_health = max_health
	add_to_group("unit")
	
	var start_grid = GameManager.local_to_grid(global_position)
	global_position = GameManager.grid_to_world(start_grid)
	start_grid_pos = start_grid
	
	GameManager.register_unit(self, start_grid)
	
	if health_bar:
		health_bar.initialize(max_health, current_health)
		health_bar.visible = false

func _exit_tree():
	GameManager.unregister_unit(self)

# ---------------- 공통 대미지 / 공격 처리 ----------------
func take_damage(amount, attacker_name = "Unknown"):
	var old_health = current_health
	current_health -= amount
	print("[System] %s > %s (HP: %d > %d) (%d)" % [attacker_name, self.name, old_health, current_health, amount])
	
	if health_bar:
		health_bar.update_health(current_health)
		health_bar.visible = true
	
	if current_health <= 0:
		die()

func apply_hit_to(target: BaseUnit, attacker_name: String = ""):
	if not target or not is_instance_valid(target):
		return
	if not target.has_method("take_damage"):
		return
	target.take_damage(damage, attacker_name)

func die():
	GameManager.unregister_unit(self)
	queue_free()

func play_animation(anim_prefix: String, dir: Vector2, force_play: bool = false):
	if dir.length() > 0:
		var angle = dir.angle()
		var index = int(round(angle / (PI / 4)))
		last_dir_index = wrapi(index, 0, 8)
	
	var target_name = (anim_prefix + "_" + DIR_NAMES[last_dir_index]).to_lower()
	
	if not sprite.sprite_frames.has_animation(target_name):
		if sprite.sprite_frames.has_animation(anim_prefix):
			target_name = anim_prefix
		else:
			return

	if "attack" in anim_prefix:
		sprite.position = anim_offsets["attack"]
	elif "run" in anim_prefix:
		sprite.position = anim_offsets["run"]
	else:
		sprite.position = anim_offsets["idle"]

	var frame_count = float(sprite.sprite_frames.get_frame_count(target_name))
	var fps = float(sprite.sprite_frames.get_animation_speed(target_name))
	var original_anim_duration = 0.0
	if fps > 0:
		original_anim_duration = frame_count / fps
	
	if "run" in anim_prefix:
		var move_duration = float(tile_size.x) / speed
		if move_duration > 0:
			sprite.speed_scale = original_anim_duration / move_duration
	elif "attack" in anim_prefix:
		if attack_speed > 0:
			sprite.speed_scale = original_anim_duration / attack_speed
	else:
		sprite.speed_scale = 1.0

	if sprite.animation == target_name and not force_play:
		if not sprite.is_playing() and "attack" not in anim_prefix:
			sprite.play(target_name)
		return 
	
	sprite.play(target_name)

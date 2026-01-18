extends CanvasLayer

# -------------------------------------------------------------------------
# 노드 참조
# -------------------------------------------------------------------------
@onready var hp_bar = %HP_ProgressBar
@onready var hp_label = %HP_Label
@onready var mp_bar = %MP_ProgressBar
@onready var mp_label = %MP_Label

# 감시할 플레이어 객체
var player_ref: Node = null

# 이전 상태값 저장 (값이 변했을 때만 UI 갱신하려고)
var prev_hp: int = -1
var prev_max_hp: int = -1
var prev_mp: int = -1
var prev_max_mp: int = -1

func _ready():
	# 게임 시작 시 플레이어를 찾음
	find_player()

func _process(delta):
	# 플레이어가 없으면 계속 찾기 시도 (비동기 로딩 대비)
	if not is_instance_valid(player_ref):
		find_player()
		return
	
	# 플레이어의 변수들을 실시간 감시
	check_player_status()

func find_player():
	# "player" 그룹의 첫 번째 멤버를 플레이어로 간주
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]
		# 찾자마자 강제 업데이트 1회
		force_update_ui()
		print("HUD: 플레이어 연결 성공!")

func check_player_status():
	# 1. HP 변화 감지 (hp, max_hp 변수가 있다고 가정)
	if "hp" in player_ref and "max_hp" in player_ref:
		var current_hp = player_ref.hp
		var current_max_hp = player_ref.max_hp
		
		# 값이 달라졌을 때만 UI 갱신 (성능 최적화)
		if current_hp != prev_hp or current_max_hp != prev_max_hp:
			update_hp_ui(current_hp, current_max_hp)
			prev_hp = current_hp
			prev_max_hp = current_max_hp
			
	# 2. MP 변화 감지 (mp, max_mp 변수가 있다고 가정)
	if "mp" in player_ref and "max_mp" in player_ref:
		var current_mp = player_ref.mp
		var current_max_mp = player_ref.max_mp
		
		if current_mp != prev_mp or current_max_mp != prev_max_mp:
			update_mp_ui(current_mp, current_max_mp)
			prev_mp = current_mp
			prev_max_mp = current_max_mp

func force_update_ui():
	prev_hp = -1
	prev_mp = -1 # 강제로 다르게 설정해서 갱신 유도
	check_player_status()

# -------------------------------------------------------------------------
# UI 그리기 전용 함수 (내부용)
# -------------------------------------------------------------------------
func update_hp_ui(val, max_val):
	if hp_bar:
		hp_bar.max_value = max_val
		hp_bar.value = val
	if hp_label:
		hp_label.text = "%d / %d" % [val, max_val]

func update_mp_ui(val, max_val):
	if mp_bar:
		mp_bar.max_value = max_val
		mp_bar.value = val
	if mp_label:
		mp_label.text = "%d / %d" % [val, max_val]

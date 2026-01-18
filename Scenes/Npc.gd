extends CharacterBody2D

# NPC와 상호작용할 때 발생할 시그널
signal talked_to_npc(npc_name)

@export var npc_name: String = "잡화상인 판도라"
@onready var label = $Label
@onready var sprite = $AnimatedSprite2D

func _ready():
	# 머리 위 이름 설정
	if label:
		label.text = npc_name
	
	# 클릭 영역(Area2D) 시그널 연결
	# 에디터의 Node 탭에서 연결해도 되지만 코드로 하는 것이 깔끔합니다.
	var click_area = $ClickArea
	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	
	# NPC 애니메이션 재생 (기본 숨쉬기 등)
	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

# 마우스 클릭 처리
func _on_click_area_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print(npc_name + " 클릭됨!")
		
		# 여기서 플레이어에게 "나한테 와서 말을 걸어라"라고 신호를 보낼 수 있음
		# 예: Player.set_target(this_npc) 구현 필요
		
		# 일단은 바로 대화창 띄우는 예시
		interact()

# 마우스 커서 변경 (리니지 느낌: 말풍선 아이콘)
func _on_mouse_entered():
	# 마우스 커서를 '상호작용 가능' 모양으로 변경
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	# 선택되었다는 느낌으로 밝게 처리 (선택사항)
	modulate = Color(1.2, 1.2, 1.2) 

func _on_mouse_exited():
	# 마우스 커서 원래대로
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	# 밝기 원상복구
	modulate = Color(1, 1, 1)

# 실제 대화 로직
func interact():
	# 플레이어와의 거리를 체크 (너무 멀면 대화 불가)
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist > 150.0: # 거리가 150픽셀보다 멀면
			print("너무 멉니다. 가까이 가세요.")
			# 여기에 플레이어를 NPC 쪽으로 이동시키는 코드 추가 가능
			return
			
	print("대화창을 엽니다...")
	# 여기에 대화 UI를 띄우는 함수 호출
	# DialogManager.start_dialog(npc_name)

extends Node2D
class_name HealthBar

@onready var progress_bar = $ProgressBar

# 부모가 설정할 수 있도록 외부에서 접근 가능
func initialize(max_hp: int, current_hp: int):
	"""최초 설정: 최대 체력과 현재 체력 전달"""
	progress_bar.max_value = max_hp
	progress_bar.value = current_hp

func update_health(current_hp: int):
	"""체력 변경 시 호출"""
	progress_bar.value = current_hp
	
	# 체력이 0이면 숨기기 (선택사항)
	if current_hp <= 0:
		visible = false
	else:
		visible = true

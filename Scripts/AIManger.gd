extends Node

# -------------------------------------------------------------------------
# [설정] AI 연산 예산
# -------------------------------------------------------------------------
# 한 프레임에 최대 몇 마리의 적이 길찾기(A*)를 수행할 수 있는지 제한
const MAX_PATHFINDING_PER_FRAME = 10 

# 관리 대상 적 목록
var _active_enemies: Array = []

# -------------------------------------------------------------------------
# [메인 루프] 중앙 집중식 AI 제어
# -------------------------------------------------------------------------
func _physics_process(delta):
	# 플레이어 찾기 (캐싱하거나 그룹으로 찾기)
	var player = get_tree().get_first_node_in_group("player")
	
	# 이번 프레임의 예산 설정
	var pathfinding_budget = MAX_PATHFINDING_PER_FRAME
	
	# 등록된 모든 적의 AI 실행
	for enemy in _active_enemies:
		if not is_instance_valid(enemy): continue
		
		# 적에게 행동 명령 (예산 정보를 넘겨줌)
		# execute_ai가 true를 반환하면 무거운 연산을 수행했다는 뜻 -> 예산 차감
		var consumed_budget = enemy.execute_ai(delta, player, pathfinding_budget > 0)
		
		if consumed_budget:
			pathfinding_budget -= 1

# -------------------------------------------------------------------------
# [관리 메서드] Enemy 스크립트에서 호출
# -------------------------------------------------------------------------
func register_enemy(enemy_node):
	if not _active_enemies.has(enemy_node):
		_active_enemies.append(enemy_node)

func unregister_enemy(enemy_node):
	if _active_enemies.has(enemy_node):
		_active_enemies.erase(enemy_node)

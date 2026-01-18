@tool
extends EditorScript

# -------------------------------------------------------------------------
# [설정] 실행 전 여기를 꼭 확인하세요!
# -------------------------------------------------------------------------
const ACTION_NAME = "Attack5"        # 생성할 동작 이름 (Idle, Run, Walk, Attack 등)
const FRAMES_PER_DIR = 15           # 한 방향당 프레임 수 (가로 개수)
const FRAME_DURATION = 0.04          # 프레임당 시간

# 루프 설정
const USE_SKIP_LOOP = false         # 첫 프레임 건너뛰기 루프 (달리기 등)
const USE_NORMAL_LOOP = false       # 일반 루프 (대기 등) - Attack은 보통 false

# [수정됨] 스프라이트 시트 줄 순서에 맞춘 방향 이름 배열
# 1번줄: 우 (E)
# 2번줄: 우하 (SE)
# 3번줄: 하 (S)
# 4번줄: 좌하 (SW)
# 5번줄: 좌 (W)
# 6번줄: 좌상 (NW)
# 7번줄: 상 (N)
# 8번줄: 우상 (NE)
const DIRS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

func _run():
	var root = get_scene()
	if not root: return
	var anim_player = root.get_node_or_null("AnimationPlayer")
	if not anim_player:
		print("오류: 선택한 씬 루트에 AnimationPlayer가 없습니다.")
		return
		
	var library = anim_player.get_animation_library("")
	
	print(">>> 애니메이션 생성 시작: ", ACTION_NAME)
	
	for i in range(DIRS.size()):
		var dir_name = DIRS[i]
		var anim_full_name = ACTION_NAME + "_" + dir_name
		
		var anim = Animation.new()
		anim.length = FRAMES_PER_DIR * FRAME_DURATION
		
		# 루프 모드 설정
		if USE_SKIP_LOOP:
			anim.loop_mode = Animation.LOOP_NONE 
		else:
			if USE_NORMAL_LOOP: anim.loop_mode = Animation.LOOP_LINEAR
			else: anim.loop_mode = Animation.LOOP_NONE
		
		# 트랙 1: Sprite2D:frame
		var track_idx = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_idx, "Sprite2D:frame")
		
		# 해당 방향의 시작 프레임 계산 (줄 번호 * 줄당 프레임 수)
		var start_frame = i * FRAMES_PER_DIR
		
		for f in range(FRAMES_PER_DIR):
			var time = float(f) * FRAME_DURATION
			anim.track_insert_key(track_idx, time, start_frame + f)
			
		# 트랙 2: 특수 루프 처리 (첫 프레임 스킵용)
		if USE_SKIP_LOOP:
			var method_track_idx = anim.add_track(Animation.TYPE_METHOD)
			anim.track_set_path(method_track_idx, "AnimationPlayer")  # AnimationPlayer가 붙은 노드 기준이 아니라 보통 자기자신(Player) 호출
			# 주의: 실제로는 AnimationPlayer의 root_node 설정에 따라 다름. 보통 "."이면 부모 노드
			
			var loop_time = FRAMES_PER_DIR * FRAME_DURATION
			
			var key_data = {
				"method": "seek",
				"args": [FRAME_DURATION] # 0초가 아니라 2번째 프레임 시간으로 점프
			}
			anim.track_insert_key(method_track_idx, loop_time, key_data)
			
			# 루프 이벤트를 위해 길이 살짝 늘림
			#anim.length += 0.001

		# 라이브러리에 등록
		if library.has_animation(anim_full_name):
			library.remove_animation(anim_full_name) # 기존 거 삭제 후 갱신
			
		library.add_animation(anim_full_name, anim)
		print(" - 생성 완료: " + anim_full_name)
		
	print(">>> 전체 완료! (AnimationPlayer를 확인하세요)")

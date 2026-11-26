extends Node

const FIRST_KNOCK_SOUND: AudioStream = preload("res://audio/knockfirst.wav")
const JUMPSCARE_SOUND: AudioStream = preload("res://audio/jumpscare.wav")
const OUZ_MODULE_SCRIPT: Script = preload("res://ouz_ai.gd")

var mayinmelih_enabled: bool = true
var ouz_enabled: bool = true


enum State { SLEEP, ROAM, DOOR, INSIDE, JUMPSCARE, DONE }

# CameraSystemUI'daki buton sırasına göre odalar
const CAM_ROOMS: PackedStringArray = [
	"fireescape", "storage", "northhall", "janitorcloset", "backstage",
	"frontauditorium", "coliseum", "westhall", "southhall", "tearoom",
	"commonroom", "auditoriumenterance", "auditorium"
]
const DOOR_WINDOW_LURE_ROOMS: PackedStringArray = ["westhall", "southhall"]

const LINKS: Dictionary = {
	"fireescape": ["janitorcloset", "northhall"],
	"storage": ["northhall", "backstage", "janitorcloset"],
	"northhall": ["storage", "frontauditorium", "backstage", "janitorcloset"],
	"janitorcloset": ["northhall", "fireescape", "backstage", "westhall"],
	"backstage": ["northhall", "frontauditorium", "janitorcloset"],
	"frontauditorium": ["auditorium", "auditoriumenterance", "backstage"],
	"auditoriumenterance": ["frontauditorium", "auditorium", "commonroom", "southhall"],
	"auditorium": ["frontauditorium", "auditoriumenterance"],
	"coliseum": ["westhall", "southhall", "tearoom"],
	"westhall": ["southhall", "coliseum", "tearoom", "janitorcloset"],
	"southhall": ["tearoom", "commonroom", "westhall", "coliseum", "auditoriumenterance"],
	"tearoom": ["commonroom", "southhall", "coliseum", "westhall"],
	"commonroom": ["tearoom", "southhall", "auditoriumenterance"],
}

@export_group("Rota")
## Ofis kapısına açılan odalar (kör nokta olan kapı önüne buralardan geçilir). KENDİ HARİTANA GÖRE DEĞİŞTİR
@export var door_rooms: PackedStringArray = ["westhall", "southhall"]
## Odalar arasında gezerken kullanılacak poz (sit yerine stand)
@export var roam_pose: String = "pose_stand"
## Tek yönlü yazılmış bağlantıları iki yönlü say
@export var symmetric_links: bool = true
## Kapı odasındayken kapıya yönelme olasılığı
@export_range(0.0, 1.0) var door_bias: float = 0.7
## Ofise yaklaştıran odayı seçme olasılığı
@export_range(0.0, 1.0) var forward_bias: float = 0.7
## Saldırıdan sonra geri çekileceği minimum uzaklık (adım)
@export var retreat_min_distance: int = 3

@export_group("Zamanlama")
@export var wake_delay_min: float = 10.0
@export var wake_delay_max: float = 20.0
@export var move_interval_min: float = 18.0
@export var move_interval_max: float = 35.0
@export_range(1.0, 8.0, 0.25) var roam_speed_multiplier: float = 3.0
## Play Sound'tan sonra canavarın gelme gecikmesi
@export var lure_delay_min: float = 5.0
@export var lure_delay_max: float = 10.0
@export_range(0.0, 1.0) var lure_success_chance: float = 0.5
@export_range(0.0, 1.0) var door_window_lure_success_chance: float = 0.75

@export_group("Kapı Saldırısı")
## Kapı penceresinde/önünde durma süresi (saniye)
@export var peek_time: float = 14.0
## Vuruşlar arasındaki bekleme süresi (düşük = daha hızlı kapı kırma)
@export var knock_gap: float = 1.4
## Tekmeden önceki vuruş sayısı (her vuruşta kapı bir aşama bükülür)
@export var knocks_before_kick: int = 2
## Tekme sonrası içeri girmeden önceki kısa bekleme (düşük = daha hızlı giriş)
@export var break_wait: float = 0.55
## Oyuncu saklanmadıysa tekmeden sonra jumpscare öncesi verilecek kısa fırsat
@export var unhidden_kick_jumpscare_delay: float = 0.65

@export_group("İçeride")
## Canavar girince oyuncunun saklanması için tanınan kısa süre
@export var react_time: float = 0.9
@export var inside_step_time: float = 1.8
@export var enter_office_walk_time: float = 1.25
@export var inside_walk_time: float = 1.0
@export_range(0.0, 1.0) var notice_chance: float = 0.25
@export_range(0.0, 1.0) var broken_door_notice_chance: float = 0.75
@export_range(0.0, 1.0) var broken_door_hidden_kill_chance: float = 0.5
@export var broken_door_window_wait_min: float = 5.0
@export var broken_door_window_wait_max: float = 10.0
@export var notice_delay_min: float = 2.0
@export var notice_delay_max: float = 5.0
@export var search_time_min: float = 2.5
@export var search_time_max: float = 4.0
## Kapı saldırısından sonra tekrar harekete geçmeden önce bekleme
@export var rearm_delay: float = 25.0

@export_group("Jumpscare")
@export var jumpscare_time: float = 1.4
@export var jumpscare_shake: float = 0.9
@export var jumpscare_rotation_shake_deg: float = 32.0
## Canavarın kameraya doğru atılma oranı (0-1)
@export_range(0.0, 1.0) var jumpscare_lunge: float = 0.3

@export_group("Test")
## 0 veya üzeri yaparsan canavar bu kadar saniye sonra doğrudan kapıya gelir (test için). -1 = kapalı
@export var debug_door_attack_delay: float = -1.0

var _state: State = State.SLEEP
var _busy: bool = false
var _room: String = "backstage"
var _safe_to_unhide: bool = false
var _sleep_left: float = 0.0
var _move_left: float = 0.0
var _lure_room: String = ""
var _lure_left: float = 0.0

var _graph: Dictionary = {}
var _dist: Dictionary = {}

var _monster: Node3D
var _monster_scale: Vector3 = Vector3.ONE
var _anim: AnimationPlayer
var _door: DoorSystem
var _hide: HideController
var _player_cam: PlayerCamera
var _scare_cam: Camera3D
var _jumpscare_camera: Camera3D
var _cam_system: CameraSystemUI
var _game: GameManager
var _audio_listener: AudioListener3D
var _lure_sounds: Array[AudioStreamPlayer3D] = []
var _knock_sound: AudioStreamPlayer3D
var _first_knock_sound: AudioStreamPlayer3D
var _break_sound: AudioStreamPlayer3D
var _scare_sound: AudioStreamPlayer3D
var _woosh_sound: AudioStreamPlayer3D
var _kicked_door_recently: bool = false


func _ready() -> void:
	var scene_root := get_tree().root
	var mayinmelih_model := scene_root.find_child("MayinMelih", true, false) as Node3D
	var ouz_model := scene_root.find_child("Ouz", true, false) as Node3D
	if mayinmelih_model:
		mayinmelih_model.visible = mayinmelih_enabled
	if ouz_model:
		ouz_model.visible = ouz_enabled
	if ouz_enabled:
		var ouz_module := OUZ_MODULE_SCRIPT.new() as Node
		ouz_module.name = "OuzModule"
		add_child(ouz_module)
	if not mayinmelih_enabled:
		set_process(false)
		return
	if not _find_nodes():
		set_process(false)
		return

	_build_graph()
	_compute_distances()

	_place_in_room("backstage", "pose_sit")
	_state = State.SLEEP
	_sleep_left = randf_range(wake_delay_min, wake_delay_max) * _night_scale()

	if _cam_system:
		_cam_system.lure_requested.connect(_on_lure_requested)
	if _game:
		_game.night_won.connect(_on_night_over)
		_game.night_lost.connect(_on_night_over)
	if _hide:
		_hide.unhide_clicked.connect(_on_unhide_clicked)
		_hide.hidden_changed.connect(_on_hidden_changed)

	if debug_door_attack_delay >= 0.0:
		_debug_door_attack()


# ---------- Kurulum ----------

func _find_nodes() -> bool:
	var r := get_tree().root
	_monster = r.find_child("MayinMelih", true, false) as Node3D
	if _monster:
		_anim = _monster.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_monster_scale = _monster.global_transform.basis.get_scale()
	_door = r.find_child("DoorSystem", true, false) as DoorSystem
	_hide = r.find_child("HideHitbox", true, false) as HideController
	_player_cam = r.find_child("Camera3D", true, false) as PlayerCamera
	_scare_cam = r.find_child("ScareCam", true, false) as Camera3D
	if not _scare_cam:
		push_warning("MonsterAI: ScareCam sahnede bulunamadı; jumpscare mevcut oyuncu kamerasını kullanacak.")
	_cam_system = r.find_child("CameraSystemUI", true, false) as CameraSystemUI
	_game = r.find_child("GameManager", true, false) as GameManager
	_audio_listener = r.find_child("OfficeAudioListener", true, false) as AudioListener3D
	if _audio_listener:
		_audio_listener.make_current()
	_lure_sounds.clear()
	for sound_name: String in ["LureSound", "LureSound2", "LureSound3"]:
		var lure_player := r.find_child(sound_name, true, false) as AudioStreamPlayer3D
		if lure_player:
			_lure_sounds.append(lure_player)
	_knock_sound = r.find_child("KnockSound", true, false) as AudioStreamPlayer3D
	_first_knock_sound = r.find_child("FirstKnockSound", true, false) as AudioStreamPlayer3D
	_break_sound = r.find_child("DoorBreakSound", true, false) as AudioStreamPlayer3D
	_scare_sound = r.find_child("JumpscareSound", true, false) as AudioStreamPlayer3D
	_woosh_sound = r.find_child("WooshMonster", true, false) as AudioStreamPlayer3D

	if _first_knock_sound:
		_first_knock_sound.stream = FIRST_KNOCK_SOUND
	if _scare_sound:
		_scare_sound.stream = JUMPSCARE_SOUND
	var audio_players: Array[AudioStreamPlayer3D] = _lure_sounds.duplicate()
	for sound: AudioStreamPlayer3D in [_knock_sound, _first_knock_sound, _break_sound, _scare_sound, _woosh_sound]:
		if sound:
			audio_players.append(sound)
	for sound: AudioStreamPlayer3D in audio_players:
		sound.max_distance = 100.0
		sound.unit_size = 20.0
		sound.volume_db = AudioSettings.DEFAULT_WORLD_SFX_DB
	for lure_player: AudioStreamPlayer3D in _lure_sounds:
		lure_player.volume_db = AudioSettings.LURE_DB
		lure_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	if _scare_sound:
		_scare_sound.volume_db = AudioSettings.JUMPSCARE_DB
	if not _monster or not _anim or not _door or not _hide or not _player_cam:
		push_error("MonsterAI: gerekli düğümler bulunamadı (MayinMelih+AnimationPlayer, DoorSystem, HideHitbox, Camera3D). Scriptlerin bağlı olduğundan emin ol.")
		return false
	if not _audio_listener:
		push_warning("MonsterAI: OfficeAudioListener bulunamadı; 3D sesler sessiz kalabilir.")
	return true


func _build_graph() -> void:
	_graph.clear()
	for room: String in LINKS:
		_graph[room] = []
	for room: String in LINKS:
		for n: String in LINKS[room]:
			if not _graph[room].has(n):
				_graph[room].append(n)
			if symmetric_links and _graph.has(n) and not _graph[n].has(room):
				_graph[n].append(room)


## Kapı odaları = 1 adım, kapı önü = 0
func _compute_distances() -> void:
	_dist.clear()
	var queue: Array[String] = []
	for r in door_rooms:
		_dist[r] = 1
		queue.append(r)
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for n: String in _graph.get(cur, []):
			if not _dist.has(n):
				_dist[n] = int(_dist[cur]) + 1
				queue.append(n)


func _night_scale() -> float:
	var n := _game.night if _game else 1
	return clampf(1.0 - 0.12 * float(n - 1), 0.4, 1.0)


# ---------- Ana döngü ----------

func _process(delta: float) -> void:
	match _state:
		State.SLEEP:
			_sleep_left -= delta
			if _sleep_left <= 0.0:
				_wake_up()
		State.ROAM:
			if _busy:
				return
			if _lure_room != "":
				_lure_left -= delta
				if _lure_left <= 0.0:
					var target := _lure_room
					_lure_room = ""
					_schedule_next_move()
					_do_room_move(target)
				return
			_move_left -= delta
			if _move_left <= 0.0:
				_decide_move()


func _wake_up() -> void:
	_state = State.ROAM
	_busy = true
	if _cam_system:
		var transition_finished: Signal = _cam_system.lost_signal_finished
		_cam_system.play_lost_signal(Callable(self, "_set_pose").bind(roam_pose))
		await transition_finished
	else:
		_set_pose(roam_pose)
	if _state != State.ROAM:
		return
	_busy = false
	_schedule_next_move()


func _schedule_next_move(extra: float = 0.0) -> void:
	var roam_interval := randf_range(move_interval_min, move_interval_max) * _night_scale()
	_move_left = roam_interval / maxf(roam_speed_multiplier, 1.0) + extra


func _alive() -> bool:
	return _state == State.DOOR or _state == State.INSIDE


func _on_night_over() -> void:
	_state = State.DONE


func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.01)).timeout


# ---------- Oda değiştirme ----------

func _decide_move() -> void:
	if door_rooms.has(_room) and randf() < door_bias:
		_start_door_attack()
		return
	var next := _pick_next_room()
	_schedule_next_move()
	if next != "":
		_do_room_move(next)


func _do_room_move(room: String) -> void:
	_busy = true
	var spot := _spot("Spot_" + room)
	if _room == "doorway":
		if _cam_system:
			var signal_covers_walk := _cam_system.is_camera_feed_active()
			var transition_finished: Signal = _cam_system.lost_signal_finished
			_cam_system.play_lost_signal(Callable(self, "_walk_to_lured_room").bind(spot, room, signal_covers_walk))
			await transition_finished
		else:
			await _walk_to_lured_room(spot, room, false)
	else:
		await _relocate(spot, roam_pose, room)
	_busy = false


func _walk_to_lured_room(spot: Node3D, room: String, _signal_covers_walk: bool) -> void:
	if room == "southhall":
		var pre_southhall := _spot("Spot_preSouthhall")
		if pre_southhall:
			await _walk_to_spot(pre_southhall, inside_walk_time, roam_pose)
			if _state == State.DONE or _state == State.JUMPSCARE:
				return
	await _walk_to_spot(spot, inside_walk_time, roam_pose)
	if spot and _state == State.ROAM:
		_room = room


func _pick_next_room() -> String:
	var options: Array = _graph.get(_room, [])
	if options.is_empty():
		return ""
	var cur_d: int = int(_dist.get(_room, 99))
	var closer: Array[String] = []
	for n: String in options:
		if int(_dist.get(n, 99)) < cur_d:
			closer.append(n)
	if not closer.is_empty() and randf() < forward_bias:
		return String(closer.pick_random())
	return String(options.pick_random())


func _pick_retreat_room() -> String:
	var far: Array[String] = []
	for r: String in _dist:
		if int(_dist[r]) >= retreat_min_distance:
			far.append(r)
	if far.is_empty():
		return "backstage"
	return String(far.pick_random())


## Canavarı bir noktaya ışınlar. Kameralar açıksa LOST SIGNAL ekranının arkasında yapılır
func _relocate(spot: Node3D, pose: String, room_name: String) -> void:
	if spot == null:
		push_warning("MonsterAI: Spot bulunamadı (oda: %s)" % room_name)
		return
	var apply := func() -> void:
		_room = room_name
		_place_at(spot, pose)
	if _cam_system:
		var transition_finished: Signal = _cam_system.lost_signal_finished
		_cam_system.play_lost_signal(apply)
		await transition_finished
	else:
		apply.call()


## Ses çekme: Play Sound butonu
func _on_lure_requested(cam_index: int) -> void:
	if cam_index < 0 or cam_index >= CAM_ROOMS.size():
		return
	var target: String = CAM_ROOMS[cam_index]
	if not ouz_enabled:
		_play_lure_sound(target)

	if target == _room:
		return

	var from_door_window := _room == "doorway" and _state == State.DOOR
	if from_door_window:
		if not DOOR_WINDOW_LURE_ROOMS.has(target):
			return
		if randf() >= door_window_lure_success_chance:
			return
		_state = State.ROAM
		_busy = false
		_lure_room = target
		_lure_left = randf_range(lure_delay_min, lure_delay_max)
		return

	if _state != State.ROAM:
		return
	var neighbors: Array = _graph.get(_room, [])
	if not neighbors.has(target):
		return
	if int(_dist.get(target, 99)) <= int(_dist.get(_room, 99)):
		return
	if randf() >= lure_success_chance:
		return
	_lure_room = target
	_lure_left = randf_range(lure_delay_min, lure_delay_max)


func _play_lure_sound(room: String) -> void:
	if _lure_sounds.is_empty():
		return
	var player: AudioStreamPlayer3D = _lure_sounds.pick_random()
	player.stop()
	var spot := _spot("Spot_" + room)
	if spot:
		player.global_position = spot.global_position
	player.play()

# ---------- Kapı saldırısı ----------

func _start_door_attack() -> void:
	_state = State.DOOR
	_busy = true
	_safe_to_unhide = false
	_lure_room = ""
	var door_window := _spot("Spot_DoorWindow")
	if door_window == null:
		push_warning("MonsterAI: Spot_DoorWindow bulunamadı.")
		_busy = false
		_state = State.ROAM
		return
	if _cam_system:
		var signal_covers_walk := _cam_system.is_camera_feed_active()
		var transition_finished: Signal = _cam_system.lost_signal_finished
		_cam_system.play_lost_signal(Callable(self, "_walk_to_door_window").bind(signal_covers_walk))
		await transition_finished
	else:
		await _walk_to_door_window()
	if not _alive():
		return
	await _door_sequence()


func _walk_to_door_window(signal_covers_walk: bool = false) -> void:
	var covered_walk_budget := 0.0
	if signal_covers_walk and _cam_system:
		covered_walk_budget = maxf(0.1, _cam_system.lost_signal_time + _cam_system.pending_after_lost_time - 0.15)
	var pre_approach_duration := 0.0
	if _room == "southhall":
		var pre_southhall := _spot("Spot_preSouthhall")
		if pre_southhall:
			var pre_distance := _monster.global_position.distance_to(pre_southhall.global_position)
			var door_window_marker := _spot("Spot_DoorWindow")
			var door_distance := pre_southhall.global_position.distance_to(door_window_marker.global_position) if door_window_marker else 0.0
			var pre_approach_time := maxf(enter_office_walk_time, pre_distance / 2.5)
			if signal_covers_walk:
				var total_distance := maxf(pre_distance + door_distance, 0.001)
				pre_approach_time = covered_walk_budget * pre_distance / total_distance
			pre_approach_duration = pre_approach_time
			await _walk_to_spot(pre_southhall, pre_approach_time, roam_pose)
			if not _alive():
				return
	var door_window := _spot("Spot_DoorWindow")
	if door_window == null:
		return
	var approach_time := maxf(enter_office_walk_time, _monster.global_position.distance_to(door_window.global_position) / 2.5)
	if signal_covers_walk:
		approach_time = maxf(0.05, covered_walk_budget - pre_approach_duration)
	await _walk_to_spot(door_window, approach_time, "pose_window")
	if _alive():
		_room = "doorway"


func _door_sequence() -> void:
	var door_was_already_broken := _door.is_broken if _door else false
	if door_was_already_broken:
		await _broken_door_window_sequence()
		return

	# 1) Kapı penceresinden bakış
	await _wait(peek_time)
	if not _alive():
		return

	var knock_spot := _spot("Spot_DoorKnock")
	if knock_spot:
		_place_at(knock_spot, "pose_knock_b")
	else:
		push_warning("MonsterAI: Spot_DoorKnock bulunamadı, mevcut konumda kapıya vuruluyor.")
		_set_pose("pose_knock_b")

	if knocks_before_kick > 0:
		await _first_knock_at_door()
	for hit_number in range(2, knocks_before_kick + 1):
		await _wait(randf_range(knock_gap * 0.8, knock_gap * 1.2))
		if not _alive():
			return
		await _knock(hit_number)
		if not _alive():
			return
	await _wait(knock_gap)
	if not _alive():
		return
	await _kick()
	if not _alive():
		return
	# Tekmeden sonra kısa fırsat ver; oyuncu hâlâ saklanmadıysa saldır.
	if _hide and not _hide.is_concealed():
		await _wait(unhidden_kick_jumpscare_delay)
		if not _alive():
			return
		if _hide and not _hide.is_concealed():
			_jumpscare("Spot_JumpscareOffice")
			return
	await _wait(break_wait)
	if not _alive():
		return

	await _enter_office(false, false)


func _broken_door_window_sequence() -> void:
	var door_window := _spot("Spot_DoorWindow")
	if door_window:
		_place_at(door_window, "pose_stand")
	else:
		_set_pose("pose_stand")

	await _wait(randf_range(broken_door_window_wait_min, broken_door_window_wait_max))
	if not _alive():
		return

	if _hide and not _hide.is_concealed():
		_jumpscare("Spot_JumpscareOffice")
		return

	await _lock_cams_for_door()
	if not _alive():
		return

	await _enter_office_broken_door_hidden()


func _enter_office_broken_door_hidden() -> void:
	_state = State.INSIDE
	if _player_cam:
		_player_cam.set_hidden_ambient_sway_enabled(false)
	if _cam_system:
		_cam_system.play_office_static()
	await _walk_to_spot(_spot("Spot_Inside1"), enter_office_walk_time)
	if not _alive():
		return
	await _wait(inside_step_time)
	if not _alive():
		return
	await _walk_to_spot(_spot("Spot_Inside2"), inside_walk_time)
	if not _alive():
		return
	await _wait(randf_range(search_time_min, search_time_max))
	if not _alive():
		return

	if randf() < broken_door_hidden_kill_chance:
		_jumpscare("Spot_JumpscareDesk")
		return

	_leave()


func _lock_cams_for_door() -> void:
	if _cam_system == null:
		return
	_cam_system.lock_cams("door")
	if _cam_system.is_open():
		_cam_system.force_close()
		# Kamera kapanma sinyali gelmezse akışın takılmaması için 1.5s güvenlik süresi
		var timer := get_tree().create_timer(1.5)
		await _wait_signal_or_timeout(_cam_system.closed, timer)


func _wait_signal_or_timeout(sig: Signal, timer: SceneTreeTimer) -> void:
	var done := [false]
	var on_sig := func(_a = null, _b = null, _c = null) -> void:
		done[0] = true
	var on_to := func() -> void:
		done[0] = true
	sig.connect(on_sig, CONNECT_ONE_SHOT)
	timer.timeout.connect(on_to, CONNECT_ONE_SHOT)
	while not done[0]:
		await get_tree().process_frame
	if sig.is_connected(on_sig):
		sig.disconnect(on_sig)
	if timer.timeout.is_connected(on_to):
		timer.timeout.disconnect(on_to)


func _knock(hit_number: int) -> void:
	_set_pose("pose_knock_a")
	await _wait(0.25)
	if not _alive():
		return
	_set_pose("pose_knock_b")
	var knock_player := _first_knock_sound if hit_number == 1 else _knock_sound
	if knock_player:
		knock_player.global_position = _knock_sound.global_position if _knock_sound else _monster.global_position
	_play_sound(knock_player)
	if _door:
		_door.hit(hit_number)
	if _player_cam:
		_player_cam.shake(0.45, 0.4)
	await _wait(0.2)
	if not _alive():
		return
	_set_pose("pose_knock_a")


func _first_knock_at_door() -> void:
	_set_pose("pose_knock_b")
	if _first_knock_sound:
		_first_knock_sound.global_position = _knock_sound.global_position if _knock_sound else _monster.global_position
	_play_sound(_first_knock_sound)
	await _lock_cams_for_door()
	if not _alive():
		return
	if _door:
		_door.hit(1)
	if _player_cam:
		_player_cam.shake(0.45, 0.4)
	await _wait(0.2)
	if _alive():
		_set_pose("pose_knock_a")


func _kick() -> void:
	_kicked_door_recently = true
	_set_pose("pose_kick")
	_play_sound(_break_sound)
	if _cam_system:
		_cam_system.play_office_static()
	var from_spot := _spot("Spot_DoorKnock")
	var to_spot := _spot("Spot_Inside1")
	var dir := Vector3.FORWARD
	if from_spot and to_spot:
		dir = to_spot.global_position - from_spot.global_position
		dir.y = 0.0
	if _door:
		_door.break_door(dir)
	if _player_cam:
		_player_cam.shake(0.7, 0.6)


func _enter_office(jumpscare_on_inside1_if_unhidden: bool = false, is_broken_door_entry: bool = false) -> void:
	_state = State.INSIDE
	if _player_cam:
		_player_cam.set_hidden_ambient_sway_enabled(false)
	if _cam_system:
		_cam_system.play_office_static()
	await _walk_to_spot(_spot("Spot_Inside1"), enter_office_walk_time)
	if not _alive():
		return
	if jumpscare_on_inside1_if_unhidden and _hide and not _hide.is_concealed():
		_jumpscare("Spot_JumpscareOffice")
		return
	await _wait(react_time)
	if not _alive():
		return

	if _hide and not _hide.is_concealed():
		_jumpscare("Spot_JumpscareOffice")
		return

	await _wait(inside_step_time)
	if not _alive():
		return
	await _walk_to_spot(_spot("Spot_Inside2"), inside_walk_time)
	if not _alive():
		return

	var active_notice_chance := broken_door_notice_chance if is_broken_door_entry else notice_chance
	if randf() < active_notice_chance:
		await _wait(randf_range(notice_delay_min, notice_delay_max))
		if not _alive():
			return
		_jumpscare("Spot_JumpscareDesk")
		return

	await _wait(randf_range(search_time_min, search_time_max))
	if not _alive():
		return
	_leave()


func _leave() -> void:
	if _cam_system:
		_cam_system.stop_office_static()
	var door_window := _spot("Spot_DoorWindow")
	await _walk_to_spot(door_window, enter_office_walk_time, roam_pose)
	if not _alive():
		return
	_room = "doorway"
	_safe_to_unhide = true
	var room := "southhall" if randf() < 0.5 else "westhall"
	_play_monster_woosh()
	if room == "southhall":
		await _walk_to_spot(_spot("Spot_preSouthhall"), inside_walk_time, roam_pose)
		if not _alive():
			return
	await _walk_to_spot(_spot("Spot_" + room), maxf(inside_walk_time, 2.0), roam_pose)
	if not _alive():
		return
	_room = room
	if _player_cam:
		_player_cam.set_hidden_ambient_sway_enabled(true)
	if _cam_system:
		_cam_system.unlock_cams("door")
	_state = State.ROAM
	_busy = false
	_schedule_next_move(rearm_delay)


## Canavar içerideyken saklanırken ekrana tıklanırsa yakalanır
func _on_unhide_clicked() -> void:
	if _state == State.INSIDE and not _safe_to_unhide:
		_jumpscare("Spot_JumpscareDesk")
	elif _hide:
		_hide.unhide()


func _on_hidden_changed(value: bool) -> void:
	if value and _kicked_door_recently and _alive():
		_kicked_door_recently = false
		_jumpscare("Spot_JumpscareDesk")
		return
	if not _player_cam:
		return
	if value and _state == State.INSIDE:
		_player_cam.set_hidden_ambient_sway_enabled(false)
		_player_cam.shake(0.35, 0.6)
	elif not value and _state != State.INSIDE:
		_player_cam.set_hidden_ambient_sway_enabled(true)


# ---------- Jumpscare ----------

func _jumpscare(spot_name: String) -> void:
	if _state == State.JUMPSCARE or _state == State.DONE:
		return
	_state = State.JUMPSCARE
	_busy = true
	_lure_room = ""
	var was_watching_cameras := _cam_system != null and _cam_system.is_open()
	if _cam_system:
		_cam_system.lock_cams("jumpscare")
		if was_watching_cameras:
			_cam_system.interrupt_for_jumpscare()

	var player_is_hidden := _hide.is_concealed() if _hide else false
	_jumpscare_camera = _player_cam
	var scare_cam_is_usable := (
		_scare_cam != null
		and is_instance_valid(_scare_cam)
		and _player_cam != null
		and _scare_cam.get_viewport() == _player_cam.get_viewport()
	)
	if scare_cam_is_usable:
		if not was_watching_cameras and not player_is_hidden and _player_cam:
			_player_cam.snap_to_base()
		_jumpscare_camera = _scare_cam
		_jumpscare_camera.make_current()
	elif _player_cam:
		_player_cam.make_current()
	if _player_cam:
		_player_cam.set_frozen(true)
	var scare_camera_controller := _jumpscare_camera as PlayerCamera
	if scare_camera_controller:
		scare_camera_controller.set_frozen(true)
		scare_camera_controller.shake(jumpscare_shake, jumpscare_time)

	var target_spot := _spot(spot_name)
	if target_spot:
		_place_at(target_spot, "pose_jumpscare")
	else:
		_set_pose("pose_jumpscare")
	_play_sound(_scare_sound)
	await _jumpscare_effect()

	if _game:
		_game.trigger_game_over()
	else:
		get_tree().reload_current_scene()


func _jumpscare_effect() -> void:
	if _jumpscare_camera == null or not is_instance_valid(_jumpscare_camera):
		await _wait(jumpscare_time)
		return
	var start_pos := _monster.global_position
	var target_pos := _jumpscare_camera.global_position
	var base_cam_pos := _jumpscare_camera.position
	var base_cam_rotation := _jumpscare_camera.rotation
	var base_h_offset := _jumpscare_camera.h_offset
	var base_v_offset := _jumpscare_camera.v_offset
	var poses := _jumpscare_poses()
	var elapsed := 0.0
	var pose_timer := 0.0
	var pose_idx := 0

	while elapsed < jumpscare_time:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		elapsed += dt
		var k := clampf(elapsed / jumpscare_time, 0.0, 1.0)

		_jumpscare_camera.position = base_cam_pos + Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0
		) * jumpscare_shake
		var rotation_shake := deg_to_rad(jumpscare_rotation_shake_deg)
		_jumpscare_camera.rotation = base_cam_rotation + Vector3(
			randf_range(-rotation_shake, rotation_shake),
			randf_range(-rotation_shake, rotation_shake),
			randf_range(-rotation_shake, rotation_shake)
		)
		if _jumpscare_camera != _player_cam:
			_jumpscare_camera.h_offset = base_h_offset + randf_range(-jumpscare_shake, jumpscare_shake)
			_jumpscare_camera.v_offset = base_v_offset + randf_range(-jumpscare_shake, jumpscare_shake)
		_monster.global_position = start_pos.lerp(target_pos, jumpscare_lunge * k)

		if poses.size() > 1:
			pose_timer += dt
			if pose_timer >= 0.08:
				pose_timer = 0.0
				pose_idx = (pose_idx + 1) % poses.size()
				_set_pose(poses[pose_idx])


func _jumpscare_poses() -> Array[String]:
	var result: Array[String] = []
	for p in ["pose_jumpscare", "pose_jumpscare_a", "pose_jumpscare_b", "pose_jumpscare_c"]:
		if _anim.has_animation(p):
			result.append(p)
	return result


# ---------- Yardımcılar ----------

func _spot(spot_name: String) -> Node3D:
	return get_tree().root.find_child(spot_name, true, false) as Node3D


## Canavarı Spot'un konumuna ve yönüne taşır (ölçeğini korur)
func _place_at(spot: Node3D, pose: String) -> void:
	if spot == null:
		return
	var xf := spot.global_transform
	xf.basis = xf.basis.orthonormalized().scaled(_monster_scale)
	_monster.global_transform = xf
	_set_pose(pose)


func _place_in_room(room: String, pose: String = "") -> void:
	var spot := _spot("Spot_" + room)
	if spot == null:
		push_warning("MonsterAI: Spot_%s bulunamadı." % room)
		return
	_room = room
	var final_pose := pose if pose != "" else roam_pose
	_place_at(spot, final_pose)


## Ofis içindeki geçişleri ışınlanma yerine marker transformları arasında yürütür.
func _walk_to_spot(spot: Node3D, duration: float, final_pose: String = "pose_inside") -> void:
	if spot == null:
		push_warning("MonsterAI: Yürüme hedefi bulunamadı.")
		return
	var start_xf := _monster.global_transform
	var target_xf := spot.global_transform
	var arrival_basis := target_xf.basis.orthonormalized()
	var facing_basis := arrival_basis
	var travel_direction := target_xf.origin - start_xf.origin
	travel_direction.y = 0.0
	if not travel_direction.is_zero_approx():
		facing_basis = Basis.looking_at(travel_direction.normalized(), Vector3.UP)
	var start_basis := start_xf.basis.orthonormalized()
	_set_pose(roam_pose)
	var elapsed := 0.0
	var travel_time := maxf(duration, 0.01)
	while elapsed < travel_time and _state != State.DONE and _state != State.JUMPSCARE:
		await get_tree().process_frame
		if _state == State.DONE or _state == State.JUMPSCARE:
			return
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / travel_time, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		var walking_xf := Transform3D.IDENTITY
		walking_xf.origin = start_xf.origin.lerp(target_xf.origin, t)
		var walking_basis := start_basis.slerp(facing_basis, t)
		var arrival_turn := clampf((t - 0.75) / 0.25, 0.0, 1.0)
		arrival_turn = arrival_turn * arrival_turn * (3.0 - 2.0 * arrival_turn)
		walking_basis = walking_basis.slerp(arrival_basis, arrival_turn)
		walking_xf.basis = walking_basis.scaled(_monster_scale)
		_monster.global_transform = walking_xf
	if _state != State.DONE and _state != State.JUMPSCARE:
		target_xf.basis = arrival_basis.scaled(_monster_scale)
		_monster.global_transform = target_xf
		_set_pose(final_pose)


## Önce RESET, sonra poz: anahtarlanmamış parçalar eski pozdan kalmaz
func _set_pose(pose: String) -> void:
	if _anim == null:
		return
	if _anim.has_animation("RESET"):
		_anim.play("RESET", 0.0)
		_anim.advance(0.0)
	if _anim.has_animation(pose):
		_anim.play(pose, 0.0)
		_anim.advance(0.0)
	else:
		push_warning("MonsterAI: '%s' animasyonu bulunamadı." % pose)


func _play_sound(player: AudioStreamPlayer3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.stop()
	if player.stream == null:
		return
	player.play()


func _play_monster_woosh() -> void:
	if not _woosh_sound or not is_instance_valid(_woosh_sound):
		return
	_woosh_sound.global_position = _monster.global_position
	_play_sound(_woosh_sound)

func _debug_door_attack() -> void:
	await _wait(debug_door_attack_delay)
	if _state == State.SLEEP or _state == State.ROAM:
		_state = State.ROAM
		_room = door_rooms[0] if not door_rooms.is_empty() else "westhall"
		_start_door_attack()

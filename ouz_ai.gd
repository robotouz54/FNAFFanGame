extends Node
## Ouz'un davranışlarını MayinMelih'in AI'sinden ayrı tutar.

const MUSIC_BOX_ECHO_CAMERA := 10 # CAM 11
const MUSIC_BOX_REMOTE_CAMERAS: Array[int] = [9, 8, 11] # CAM 10, CAM 9, CAM 6B
const LURE_CAM_ROOMS: PackedStringArray = [
	"fireescape", "storage", "northhall", "janitorcloset", "backstage",
	"frontauditorium", "coliseum", "westhall", "southhall", "tearoom",
	"commonroom", "auditoriumenterance", "auditorium"
]
const MUSIC_BOX_MUTED_VOLUME_DB := -80.0
const COMMONROOM_POSE := "pose_listening_commonroom"
const AWAKE_POSE := "pose_awake_commonroom"
const STANDING_POSE := "pose_stand_general"
const KICKING_POSE := "pose_kicking"
const JUMPSCARE_POSE := "pose_jumpscare"
const TRANSFORMING_BUS_NAME := "TransformingEcho"
const TRANSFORMING_VOLUME_DB := -24.0
const TRANSFORMING_REVERB_ROOM_SIZE := 0.5
const TRANSFORMING_REVERB_DAMPING := 0.15
const TRANSFORMING_REVERB_WET := 0.5
const MAP_LIGHT_COUNT := 20
const FIRST_KNOCK_SOUND: AudioStream = preload("res://audio/knockfirst.wav")
const JUMPSCARE_SOUND: AudioStream = preload("res://audio/jumpscare.wav")

@export_group("Music Box")
@export_range(0.1, 600.0, 0.1) var charge_drain_seconds: float = 5.0
@export_range(1.0, 60.0, 1.0) var full_wind_seconds: float = 5.0
@export_range(10.0, 20.0, 0.5) var commonroom_pose_wait_min: float = 5.0
@export_range(10.0, 20.0, 0.5) var commonroom_pose_wait_max: float = 7.0
@export_range(0.0, 60.0, 0.5) var wake_delay_min: float = 7.0
@export_range(0.0, 60.0, 0.5) var wake_delay_max: float = 11.0
@export_group("Ambiyans")
@export_range(-80.0, 12.0, 0.1) var office_ambience_office_db: float = -50.000
@export_range(-80.0, 12.0, 0.1) var office_ambience_monitor_db: float = -60.000
@export_group("Karamsar WorldEnvironment")
@export_range(1.0, 30.0, 0.5) var dread_env_fade_seconds: float = 10.0
@export var dread_bg_color: Color = Color(0.14, 0.28, 0.48, 1.0)
@export_range(0.0, 2.0, 0.05) var dread_ambient_energy: float = 1.12
@export var dread_fog_color: Color = Color(0.32, 0.52, 0.78, 1.0)
@export_range(0.001, 0.5, 0.001) var dread_fog_density: float = 0.009
@export_range(0.5, 2.0, 0.05) var dread_contrast: float = 1.02
@export_range(0.0, 1.5, 0.05) var dread_saturation: float = 0.85
@export_range(0.2, 1.5, 0.05) var dread_brightness: float = 1.04
@export var dread_light_color: Color = Color(0.45, 0.72, 1.0, 1.0)
@export_group("Oda Rotası")
@export_range(15.0, 20.0, 0.5) var room_wait_min: float = 7.0
@export_range(15.0, 20.0, 0.5) var room_wait_max: float = 10.0
@export_range(-80.0, 12.0, 0.5) var music_box_cam11_volume_db: float = -4.0
@export_range(-80.0, 12.0, 0.5) var music_box_cam10_volume_db: float = -6.0
@export_range(-80.0, 12.0, 0.5) var music_box_cam9_volume_db: float = -7.0
@export_range(-80.0, 12.0, 0.5) var music_box_cam6b_volume_db: float = -10.0
@export_range(-80.0, 12.0, 0.5) var music_box_late_volume_db: float = -6.0
@export_range(0.5, 15.0, 0.5) var office_approach_walk_seconds: float = 3.0

@export_group("Transforming")
@export_range(-80.0, 12.0, 0.5) var transforming_volume_db: float = TRANSFORMING_VOLUME_DB
@export_range(0.0, 1.0, 0.05) var transforming_reverb_wet: float = TRANSFORMING_REVERB_WET

@export_group("Jumpscare")
@export_range(0.2, 5.0, 0.1) var jumpscare_time: float = 1.4
@export_range(0.1, 3.0, 0.1) var jumpscare_shake: float = 0.9
@export_range(5.0, 60.0, 1.0) var jumpscare_rotation_shake_deg: float = 32.0
@export_range(-12.0, 18.0, 0.5) var jumpscare_volume_db: float = 12.0
@export_range(0.0, 1.0, 0.05) var jumpscare_lunge: float = 0.3
@export_range(0.0, 30.0, 0.05) var door_window_kick_delay_min: float = 1.0
@export_range(0.0, 30.0, 0.05) var door_window_kick_delay_max: float = 3.0
@export_range(0.0, 30.0, 0.05) var post_break_jumpscare_delay_min: float = 1.0
@export_range(0.0, 30.0, 0.05) var post_break_jumpscare_delay_max: float = 2.0
@export_range(0.02, 2.0, 0.02) var camera_approach_walk_seconds: float = 0.45
@export_range(0.02, 1.0, 0.01) var door_break_dash_seconds: float = 0.12

var _ouz: Node3D
var _animation: AnimationPlayer
var _spots: Node3D
var _monster_spots: Node3D
var _door: DoorSystem
var _lure_sounds: Array[AudioStreamPlayer3D] = []
var _music_box: AudioStreamPlayer3D
var _music_box_late: AudioStreamPlayer3D
var _camera_ui: CameraSystemUI
var _game: GameManager
var _audio_listener: AudioListener3D
var _player_camera: PlayerCamera
var _scare_camera: Camera3D
var _jumpscare_camera: Camera3D
var _world_env: WorldEnvironment
var _env: Environment
var _env_initialized := false
var _map_lights: Array[Light3D] = []
var _init_light_colors: Array[Color] = []
var _dread_tween: Tween
var _init_bg_color: Color
var _init_ambient_energy: float
var _init_fog_enabled: bool
var _init_fog_color: Color
var _init_fog_density: float
var _init_adj_enabled: bool
var _init_contrast: float
var _init_saturation: float
var _init_brightness: float
var _transforming_sound: Node
var _transforming_reverb: AudioEffectReverb
var _first_knock_sound: AudioStreamPlayer3D
var _door_break_sound: AudioStreamPlayer3D
var _jumpscare_sound: AudioStreamPlayer3D
var _hide_controller: HideController
var _office_ambience: AudioStreamPlayer3D
var _charge := 1.0
var _awake := false
var _sequence_running := false
var _ended := false
var _room := "commonroom"
var _ouz_scale := Vector3.ONE


func _ready() -> void:
	var world := get_tree().root
	_ouz = world.find_child("Ouz", true, false) as Node3D
	_spots = world.find_child("OuzSpots", true, false) as Node3D
	_monster_spots = world.find_child("MonsterSpots", true, false) as Node3D
	_door = world.find_child("DoorSystem", true, false) as DoorSystem
	_animation = world.find_child("AnimationPlayerOuz", true, false) as AnimationPlayer
	_music_box = world.find_child("MusicBox", true, false) as AudioStreamPlayer3D
	_music_box_late = world.find_child("MusicBoxLate", true, false) as AudioStreamPlayer3D
	_camera_ui = world.find_child("CameraSystemUI", true, false) as CameraSystemUI
	_game = world.find_child("GameManager", true, false) as GameManager
	_audio_listener = world.find_child("OfficeAudioListener", true, false) as AudioListener3D
	_office_ambience = world.find_child("OfficeAmbiance", true, false) as AudioStreamPlayer3D
	_player_camera = world.find_child("Camera3D", true, false) as PlayerCamera
	_scare_camera = world.find_child("ScareCam", true, false) as Camera3D
	_world_env = world.find_child("WorldEnvironment", true, false) as WorldEnvironment
	_transforming_sound = world.find_child("Transforming", true, false)
	_first_knock_sound = world.find_child("FirstKnockSound", true, false) as AudioStreamPlayer3D
	_door_break_sound = world.find_child("DoorBreakSound", true, false) as AudioStreamPlayer3D
	_jumpscare_sound = world.find_child("OuzJumpscareSound", true, false) as AudioStreamPlayer3D
	if not _jumpscare_sound:
		_jumpscare_sound = world.find_child("JumpscareSound", true, false) as AudioStreamPlayer3D
	_hide_controller = world.find_child("HideHitbox", true, false) as HideController
	if not _ouz or not _spots or not _animation or not _music_box or not _music_box_late or not _camera_ui:
		push_error("OuzAI: Ouz, OuzSpots, AnimationPlayerOuz, MusicBox/MusicBoxLate veya CameraSystemUI eksik.")
		set_process(false)
		return
	_setup_world_environment()
	_setup_map_lights(world)
	_reset_dread_environment_and_lights()
	for sound_name: String in ["LureSound", "LureSound2", "LureSound3"]:
		var lure_player := world.find_child(sound_name, true, false) as AudioStreamPlayer3D
		if lure_player:
			lure_player.max_distance = 100.0
			lure_player.unit_size = 20.0
			lure_player.volume_db = 6.0
			lure_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
			_lure_sounds.append(lure_player)
	if not _camera_ui.lure_requested.is_connected(_on_lure_requested):
		_camera_ui.lure_requested.connect(_on_lure_requested)

	_ensure_music_buses()
	_ensure_transforming_bus()
	_configure_transforming_sound()
	_ouz_scale = _ouz.global_transform.basis.get_scale()
	if _audio_listener:
		_audio_listener.make_current()
	if _office_ambience:
		_set_office_ambience_reduced(_camera_ui.is_open())
		_camera_ui.opened.connect(_on_camera_system_opened)
		_camera_ui.closed.connect(_on_camera_system_closed)
	_teleport_to("commonroom", COMMONROOM_POSE)
	_charge = 1.0
	_music_box_late.stop()
	_music_box.global_position = _ouz.global_position
	_music_box.max_distance = 100.0
	_music_box.unit_size = 12.0
	_music_box.volume_db = MUSIC_BOX_MUTED_VOLUME_DB
	_music_box.max_db = 12.0
	_music_box.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_music_box_late.bus = "MusicBoxLateEcho"
	_music_box_late.volume_db = music_box_late_volume_db
	_music_box_late.max_db = 12.0
	_music_box_late.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	if _first_knock_sound:
		if _first_knock_sound.stream == null:
			_first_knock_sound.stream = FIRST_KNOCK_SOUND
		_first_knock_sound.max_distance = 100.0
		_first_knock_sound.unit_size = 20.0
	if _jumpscare_sound:
		if _jumpscare_sound.stream == null:
			_jumpscare_sound.stream = JUMPSCARE_SOUND
		_jumpscare_sound.volume_db = jumpscare_volume_db
		if _jumpscare_sound is AudioStreamPlayer3D:
			var scare_3d := _jumpscare_sound as AudioStreamPlayer3D
			scare_3d.max_distance = 100.0
			scare_3d.unit_size = 20.0
	if _music_box.stream is AudioStreamOggVorbis:
		(_music_box.stream as AudioStreamOggVorbis).loop = true
	_update_music_bus()
	_music_box.play()
	_camera_ui.set_music_box_enabled(true)
	_camera_ui.set_music_box_charge(_charge)
	if _game:
		_game.night_won.connect(_on_game_finished)
		_game.night_lost.connect(_on_game_finished)


func _process(delta: float) -> void:
	if _ended or _awake or _sequence_running:
		return
	if _camera_ui.is_music_box_winding():
		_charge = minf(_charge + delta / maxf(full_wind_seconds, 0.1), 1.0)
	else:
		_charge = maxf(_charge - delta / maxf(charge_drain_seconds, 0.1), 0.0)
	_camera_ui.set_music_box_charge(_charge)
	_update_music_bus()
	if _charge <= 0.0:
		_begin_wake_sequence()


func _begin_wake_sequence() -> void:
	if _sequence_running or _awake or _ended:
		return
	_sequence_running = true
	_awake = true
	_start_dread_environment_fade()
	_camera_ui.set_music_box_late_active(true)
	_camera_ui.set_music_box_enabled(false)
	_music_box.stop()
	_music_box_late.global_position = _ouz.global_position
	_music_box_late.max_distance = 100.0
	_music_box_late.unit_size = 12.0
	if _music_box_late.stream is AudioStreamOggVorbis:
		(_music_box_late.stream as AudioStreamOggVorbis).loop = true
	_music_box_late.play()
	_update_music_bus()
	var wake_delay := randf_range(minf(wake_delay_min, wake_delay_max), maxf(wake_delay_min, wake_delay_max))
	if wake_delay > 0.0:
		await get_tree().create_timer(wake_delay).timeout
	if _ended:
		return

	# Commonroom içinde poz değişimi
	await _play_pose_with_signal(AWAKE_POSE, true)
	await _wait_commonroom_pose_change()
	if _ended:
		return
	if _room == "commonroom" and _spots and _spots.get_node_or_null("ouzSpot_commonroom2"):
		await _teleport_with_signal("commonroom2", STANDING_POSE, 1.0, true)
		_room = "commonroom"
	else:
		await _play_pose_with_signal(STANDING_POSE, true)
	await _wait_commonroom_pose_change()
	if _ended:
		return

	# Vent rotası bu sürümde kapalı; uyanışın ilk hedefi her zaman South Hall.
	await _teleport_with_signal("southhall", STANDING_POSE, 1.0, true)
	if _ended:
		return
	await _wait_in_room()
	if _ended:
		return

	# ouzSpot_southhall -> ouzSpot_preSouthhall -> ouzSpot_preDoorWindow -> ouzSpot_DoorWindow
	await _walk_to_room_with_signal("preSouthhall", STANDING_POSE, office_approach_walk_seconds)
	if _ended:
		return
	await get_tree().create_timer(1.0).timeout
	if _ended:
		return
	await _walk_to_room("preDoorWindow", STANDING_POSE, office_approach_walk_seconds)
	if _ended:
		return
	await _walk_to_room("DoorWindow", STANDING_POSE, office_approach_walk_seconds)
	if _ended:
		return

	var kick_delay := randf_range(
		minf(door_window_kick_delay_min, door_window_kick_delay_max),
		maxf(door_window_kick_delay_min, door_window_kick_delay_max)
	)
	if kick_delay > 0.0:
		await get_tree().create_timer(kick_delay).timeout
	if _ended:
		return

	var door_already_broken := _door != null and is_instance_valid(_door) and _door.is_broken
	if not door_already_broken:
		_set_pose(KICKING_POSE)
		_break_door_stage3()
		if _player_camera:
			_player_camera.shake(0.7, 0.6)

		var post_break_delay := randf_range(
			minf(post_break_jumpscare_delay_min, post_break_jumpscare_delay_max),
			maxf(post_break_jumpscare_delay_min, post_break_jumpscare_delay_max)
		)
		if post_break_delay > 0.0:
			await get_tree().create_timer(post_break_delay).timeout
		if _ended:
			return

	_sequence_running = false
	await _walk_to_camera_xz_in_jumpscare_pose()
	if _ended:
		return
	await _start_jumpscare()


func _setup_world_environment() -> void:
	if not _world_env or not is_instance_valid(_world_env):
		return
	_env = _world_env.environment
	if not _env:
		_env = Environment.new()
		_world_env.environment = _env
	if _env_initialized:
		return
	_init_bg_color = _env.background_color
	_init_ambient_energy = _env.ambient_light_energy
	_init_fog_enabled = _env.fog_enabled
	_init_fog_color = _env.fog_light_color
	_init_fog_density = _env.fog_density
	_init_adj_enabled = _env.adjustment_enabled
	_init_contrast = _env.adjustment_contrast
	_init_saturation = _env.adjustment_saturation
	_init_brightness = _env.adjustment_brightness
	_env_initialized = true


func _setup_map_lights(world: Node) -> void:
	var already_captured := not _map_lights.is_empty() and _map_lights.size() == _init_light_colors.size()
	var lights_parent := world.find_child("isiklar", true, false) as Node
	if not already_captured:
		_map_lights.clear()
		_init_light_colors.clear()
	for idx in range(1, MAP_LIGHT_COUNT + 1):
		var light_name := "isiks%d" % idx
		var light_node: Light3D = null
		if lights_parent:
			light_node = lights_parent.find_child(light_name, true, false) as Light3D
		if not light_node:
			light_node = world.find_child(light_name, true, false) as Light3D
		if light_node and not already_captured:
			_map_lights.append(light_node)
			_init_light_colors.append(light_node.light_color)


func _reset_dread_environment_and_lights() -> void:
	if _dread_tween and _dread_tween.is_valid():
		_dread_tween.kill()
		_dread_tween = null

	if _env and _env_initialized:
		if _env.background_mode == Environment.BG_COLOR:
			_env.background_color = _init_bg_color
		_env.ambient_light_energy = _init_ambient_energy
		_env.fog_enabled = _init_fog_enabled
		_env.fog_light_color = _init_fog_color
		_env.fog_density = _init_fog_density
		_env.adjustment_enabled = _init_adj_enabled
		_env.adjustment_contrast = _init_contrast
		_env.adjustment_saturation = _init_saturation
		_env.adjustment_brightness = _init_brightness

	for i in range(mini(_map_lights.size(), _init_light_colors.size())):
		var light_node := _map_lights[i]
		if light_node and is_instance_valid(light_node):
			light_node.light_color = _init_light_colors[i]


func _start_dread_environment_fade() -> void:
	var duration := maxf(dread_env_fade_seconds, 0.1)
	if _dread_tween and _dread_tween.is_valid():
		_dread_tween.kill()

	var has_env := _env != null
	if not has_env:
		_setup_world_environment()
		has_env = _env != null

	if has_env:
		if _env.background_mode == Environment.BG_COLOR:
			_env.background_color = _init_bg_color
		_env.ambient_light_energy = _init_ambient_energy
		_env.fog_enabled = true
		if not _init_fog_enabled:
			_env.fog_light_color = dread_fog_color
			_env.fog_density = 0.0
		else:
			_env.fog_light_color = _init_fog_color
			_env.fog_density = _init_fog_density

		_env.adjustment_enabled = true
		if not _init_adj_enabled:
			_env.adjustment_contrast = 1.0
			_env.adjustment_saturation = 1.0
			_env.adjustment_brightness = 1.0
		else:
			_env.adjustment_contrast = _init_contrast
			_env.adjustment_saturation = _init_saturation
			_env.adjustment_brightness = _init_brightness

	for i in range(mini(_map_lights.size(), _init_light_colors.size())):
		var light_node := _map_lights[i]
		if light_node and is_instance_valid(light_node):
			light_node.light_color = _init_light_colors[i]

	if not has_env and _map_lights.is_empty():
		return

	_dread_tween = create_tween()
	_dread_tween.set_parallel(true)
	_dread_tween.set_trans(Tween.TRANS_SINE)
	_dread_tween.set_ease(Tween.EASE_IN_OUT)
	if has_env:
		if _env.background_mode == Environment.BG_COLOR:
			_dread_tween.tween_property(_env, "background_color", dread_bg_color, duration)
		_dread_tween.tween_property(_env, "ambient_light_energy", dread_ambient_energy, duration)
		_dread_tween.tween_property(_env, "fog_light_color", dread_fog_color, duration)
		_dread_tween.tween_property(_env, "fog_density", dread_fog_density, duration)
		_dread_tween.tween_property(_env, "adjustment_contrast", dread_contrast, duration)
		_dread_tween.tween_property(_env, "adjustment_saturation", dread_saturation, duration)
		_dread_tween.tween_property(_env, "adjustment_brightness", dread_brightness, duration)

	for light_node in _map_lights:
		if light_node and is_instance_valid(light_node):
			_dread_tween.tween_property(light_node, "light_color", dread_light_color, duration)


func _break_door_stage3() -> void:
	if _door_break_sound and is_instance_valid(_door_break_sound):
		_door_break_sound.stop()
		if _door_break_sound.stream != null:
			_door_break_sound.play()
	if _first_knock_sound and is_instance_valid(_first_knock_sound):
		_first_knock_sound.stop()
		if _first_knock_sound.stream != null:
			_first_knock_sound.play()
	if not _door or not is_instance_valid(_door):
		return
	var from_spot := _get_spot_node("DoorKnock")
	if not from_spot:
		from_spot = _get_spot_node("DoorWindow")
	var to_spot := _get_spot_node("Inside1")
	if not to_spot:
		to_spot = _get_spot_node("JumpscareOffice")
	var dir := Vector3.FORWARD
	if from_spot and to_spot:
		dir = to_spot.global_position - from_spot.global_position
		dir.y = 0.0
	if dir.is_zero_approx():
		dir = -_ouz.global_transform.basis.z
		dir.y = 0.0
	if not _door.is_broken:
		_door.set_stage(2)
		_door.break_door(dir)


func _wait_in_room() -> void:
	await get_tree().create_timer(randf_range(room_wait_min, room_wait_max)).timeout


func _wait_commonroom_pose_change() -> void:
	await get_tree().create_timer(randf_range(commonroom_pose_wait_min, commonroom_pose_wait_max)).timeout


func _play_pose_with_signal(pose_name: String, sync_transforming: bool = false) -> void:
	if _camera_ui:
		var transition_finished: Signal = _camera_ui.lost_signal_finished
		_camera_ui.play_lost_signal(Callable(self, "_set_pose").bind(pose_name))
		if sync_transforming:
			_play_transforming_sound()
		await transition_finished
	else:
		_set_pose(pose_name)
		if sync_transforming:
			_play_transforming_sound()


func _teleport_with_signal(
	room_name: String,
	pose_name: String,
	duration_multiplier: float = 1.0,
	sync_transforming: bool = false
) -> void:
	if _camera_ui:
		if not _camera_ui.is_camera_feed_active() and duration_multiplier > 1.0:
			_teleport_to(room_name, pose_name)
			if sync_transforming:
				_play_transforming_sound()
			var transition_time := (_camera_ui.lost_signal_time + _camera_ui.pending_after_lost_time) * duration_multiplier
			await get_tree().create_timer(transition_time).timeout
			return
		var transition_finished: Signal = _camera_ui.lost_signal_finished
		_camera_ui.play_lost_signal(Callable(self, "_teleport_to").bind(room_name, pose_name), duration_multiplier)
		if sync_transforming:
			_play_transforming_sound()
		await transition_finished
	else:
		_teleport_to(room_name, pose_name)
		if sync_transforming:
			_play_transforming_sound()


func _teleport_to(room_name: String, pose_name: String) -> void:
	var spot := _get_spot_node(room_name)
	if not spot:
		push_warning("OuzAI: %s spotu bulunamadı." % room_name)
		return
	var next_transform := spot.global_transform
	next_transform.basis = next_transform.basis.orthonormalized().scaled(_ouz_scale)
	_ouz.global_transform = next_transform
	_room = room_name
	_set_pose(pose_name)
	_music_box.global_position = _ouz.global_position
	_music_box_late.global_position = _ouz.global_position


func _walk_to_room(room_name: String, pose_name: String, duration: float) -> void:
	var spot := _get_walk_marker(room_name)
	if not spot:
		push_warning("OuzAI: %s yürüyüş marker'ı bulunamadı." % room_name)
		return
	await _walk_to_marker(spot, room_name, pose_name, duration)


func _get_walk_marker(room_name: String) -> Node3D:
	return _get_spot_node(room_name)


func _get_spot_node(spot_key: String) -> Node3D:
	if _spots:
		var direct := _spots.get_node_or_null("ouzSpot_" + spot_key) as Node3D
		if direct:
			return direct
		var plain := _spots.get_node_or_null(spot_key) as Node3D
		if plain:
			return plain
	var root := get_tree().root
	var fallback := root.find_child("ouzSpot_" + spot_key, true, false) as Node3D
	if fallback:
		return fallback
	return root.find_child(spot_key, true, false) as Node3D


func _walk_to_marker(spot: Node3D, room_name: String, pose_name: String, duration: float) -> void:
	if not spot:
		push_warning("OuzAI: %s yürüyüş marker'ı bulunamadı." % room_name)
		return
	var start_xf := _ouz.global_transform
	var target_xf := spot.global_transform
	var start_basis := start_xf.basis.orthonormalized()
	var target_basis := target_xf.basis.orthonormalized()
	var elapsed := 0.0
	var travel_time := maxf(duration, 0.01)
	while elapsed < travel_time and not _ended:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / travel_time, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		var walking_xf := Transform3D.IDENTITY
		walking_xf.origin = start_xf.origin.lerp(target_xf.origin, t)
		walking_xf.basis = start_basis.slerp(target_basis, t).scaled(_ouz_scale)
		_ouz.global_transform = walking_xf
	if _ended:
		return
	target_xf.basis = target_basis.scaled(_ouz_scale)
	_ouz.global_transform = target_xf
	_room = room_name
	_set_pose(pose_name)
	_music_box.global_position = _ouz.global_position
	_music_box_late.global_position = _ouz.global_position


func _walk_to_room_with_signal(room_name: String, pose_name: String, duration: float) -> void:
	var spot := _get_walk_marker(room_name)
	if not spot:
		push_warning("OuzAI: %s yürüyüş marker'ı bulunamadı." % room_name)
		return
	if _camera_ui:
		var transition_finished: Signal = _camera_ui.lost_signal_finished
		_camera_ui.play_lost_signal(
			Callable(self, "_walk_to_marker").bind(spot, room_name, pose_name, duration)
		)
		await transition_finished
	else:
		await _walk_to_marker(spot, room_name, pose_name, duration)


func _set_pose(pose_name: String) -> void:
	if _animation:
		if _animation.has_animation("RESET"):
			_animation.play("RESET", 0.0)
			_animation.advance(0.0)
		if _animation.has_animation(pose_name):
			_animation.play(pose_name, 0.0)
			_animation.advance(0.0)
		else:
			push_warning("OuzAI: AnimationPlayerOuz/%s animasyonu bulunamadı." % pose_name)


func _ensure_transforming_bus() -> void:
	var bus_idx := _ensure_bus(TRANSFORMING_BUS_NAME)
	if bus_idx < 0:
		return
	if AudioServer.get_bus_effect_count(bus_idx) == 0:
		_transforming_reverb = AudioEffectReverb.new()
		_transforming_reverb.room_size = TRANSFORMING_REVERB_ROOM_SIZE
		_transforming_reverb.damping = TRANSFORMING_REVERB_DAMPING
		_transforming_reverb.wet = transforming_reverb_wet
		AudioServer.add_bus_effect(bus_idx, _transforming_reverb)
	else:
		_transforming_reverb = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectReverb
		if _transforming_reverb:
			_transforming_reverb.room_size = TRANSFORMING_REVERB_ROOM_SIZE
			_transforming_reverb.damping = TRANSFORMING_REVERB_DAMPING
			_transforming_reverb.wet = transforming_reverb_wet


func _configure_transforming_sound() -> void:
	if not _transforming_sound or not is_instance_valid(_transforming_sound):
		return
	if _transforming_sound is AudioStreamPlayer:
		var p2d := _transforming_sound as AudioStreamPlayer
		p2d.volume_db = transforming_volume_db
		if AudioServer.get_bus_index(TRANSFORMING_BUS_NAME) >= 0:
			p2d.bus = TRANSFORMING_BUS_NAME
	elif _transforming_sound is AudioStreamPlayer3D:
		var p3d := _transforming_sound as AudioStreamPlayer3D
		p3d.volume_db = transforming_volume_db
		p3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		p3d.max_distance = 100.0
		p3d.unit_size = 20.0
		if AudioServer.get_bus_index(TRANSFORMING_BUS_NAME) >= 0:
			p3d.bus = TRANSFORMING_BUS_NAME


func _play_transforming_sound() -> void:
	if not _transforming_sound or not is_instance_valid(_transforming_sound):
		return
	_configure_transforming_sound()
	if _transforming_reverb:
		_transforming_reverb.room_size = TRANSFORMING_REVERB_ROOM_SIZE
		_transforming_reverb.damping = TRANSFORMING_REVERB_DAMPING
		_transforming_reverb.wet = transforming_reverb_wet
	if _transforming_sound is AudioStreamPlayer:
		var p2d := _transforming_sound as AudioStreamPlayer
		p2d.stop()
		if p2d.stream != null:
			p2d.play()
	elif _transforming_sound is AudioStreamPlayer3D:
		var p3d := _transforming_sound as AudioStreamPlayer3D
		if _audio_listener and is_instance_valid(_audio_listener):
			p3d.global_position = _audio_listener.global_position
		p3d.stop()
		if p3d.stream != null:
			p3d.play()


func _walk_to_camera_xz_in_jumpscare_pose() -> void:
	if _ended or not _ouz or not is_instance_valid(_ouz):
		return
	_set_pose(JUMPSCARE_POSE)
	if not _player_camera or not is_instance_valid(_player_camera):
		return
	var start_xf := _ouz.global_transform
	var start_basis := start_xf.basis.orthonormalized()
	var cam_pos := _player_camera.global_position
	var target_origin := Vector3(cam_pos.x, start_xf.origin.y, cam_pos.z)
	var travel_vec := target_origin - start_xf.origin
	travel_vec.y = 0.0
	var target_basis := start_basis
	if not travel_vec.is_zero_approx():
		target_basis = Basis.looking_at(travel_vec.normalized(), Vector3.UP)
	var elapsed := 0.0
	var travel_time := maxf(camera_approach_walk_seconds, 0.01)
	while elapsed < travel_time and not _ended:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / travel_time, 0.0, 1.0)
		var cur_cam := _player_camera.global_position
		var cur_target := Vector3(cur_cam.x, start_xf.origin.y, cur_cam.z)
		var step_xf := Transform3D.IDENTITY
		step_xf.origin = start_xf.origin.lerp(cur_target, t)
		step_xf.basis = start_basis.slerp(target_basis, t).scaled(_ouz_scale)
		_ouz.global_transform = step_xf
		_set_pose(JUMPSCARE_POSE)
	if _ended:
		return
	var final_cam := _player_camera.global_position
	var end_xf := Transform3D.IDENTITY
	end_xf.origin = Vector3(final_cam.x, start_xf.origin.y, final_cam.z)
	end_xf.basis = target_basis.scaled(_ouz_scale)
	_ouz.global_transform = end_xf
	_set_pose(JUMPSCARE_POSE)


func _start_jumpscare() -> void:
	if _ended:
		return
	var player_hidden := _hide_controller != null and _hide_controller.is_concealed()
	var jumpscare_spot_name := "JumpscareDesk" if player_hidden else "JumpscareOffice"
	var target_spot := _get_spot_node(jumpscare_spot_name)
	if target_spot:
		_teleport_to(jumpscare_spot_name, JUMPSCARE_POSE)
	else:
		_room = jumpscare_spot_name
		_set_pose(JUMPSCARE_POSE)
	_ended = true
	_reset_dread_environment_and_lights()
	var was_watching_cameras := _camera_ui != null and _camera_ui.is_open()
	if _camera_ui:
		_camera_ui.lock_cams("jumpscare")
		if was_watching_cameras:
			_camera_ui.interrupt_for_jumpscare()
	if _player_camera:
		_jumpscare_camera = _player_camera
		var scare_cam_is_usable := (
			_scare_camera != null
			and is_instance_valid(_scare_camera)
			and _scare_camera.get_viewport() == _player_camera.get_viewport()
		)
		if scare_cam_is_usable:
			if not was_watching_cameras and not player_hidden:
				_player_camera.snap_to_base()
			_jumpscare_camera = _scare_camera
			_jumpscare_camera.make_current()
		else:
			_player_camera.make_current()
		_player_camera.set_frozen(true)
		var scare_controller := _jumpscare_camera as PlayerCamera
		if scare_controller:
			scare_controller.set_frozen(true)
			scare_controller.shake(jumpscare_shake, jumpscare_time)
	_set_pose(JUMPSCARE_POSE)
	if _jumpscare_sound and is_instance_valid(_jumpscare_sound):
		if _jumpscare_sound is AudioStreamPlayer3D:
			(_jumpscare_sound as AudioStreamPlayer3D).global_position = _ouz.global_position
		_jumpscare_sound.stop()
		if _jumpscare_sound.stream != null:
			_jumpscare_sound.play()
	if _jumpscare_camera:
		await _run_jumpscare_shake()
	if _game:
		_game.trigger_game_over()
	else:
		get_tree().reload_current_scene()


func _run_jumpscare_shake() -> void:
	var start_position := _ouz.global_position
	var target_position := _jumpscare_camera.global_position
	var base_camera_position := _jumpscare_camera.position
	var base_camera_rotation := _jumpscare_camera.rotation
	var base_h_offset := _jumpscare_camera.h_offset
	var base_v_offset := _jumpscare_camera.v_offset
	var elapsed := 0.0
	while elapsed < jumpscare_time:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var progress := clampf(elapsed / jumpscare_time, 0.0, 1.0)
		_ouz.global_position = start_position.lerp(target_position, jumpscare_lunge * progress)
		_jumpscare_camera.position = base_camera_position + Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0
		) * jumpscare_shake
		var angle := deg_to_rad(jumpscare_rotation_shake_deg)
		_jumpscare_camera.rotation = base_camera_rotation + Vector3(
			randf_range(-angle, angle), randf_range(-angle, angle), randf_range(-angle, angle)
		)
		if _jumpscare_camera != _player_camera:
			_jumpscare_camera.h_offset = base_h_offset + randf_range(-jumpscare_shake, jumpscare_shake)
			_jumpscare_camera.v_offset = base_v_offset + randf_range(-jumpscare_shake, jumpscare_shake)


func _update_music_bus() -> void:
	var feed_active := _camera_ui.is_camera_feed_active()
	var camera_index := _camera_ui.get_current_camera_index()
	var is_echo_camera := camera_index == MUSIC_BOX_ECHO_CAMERA
	var is_remote_camera := MUSIC_BOX_REMOTE_CAMERAS.has(camera_index)
	_music_box.bus = "MusicBoxEcho" if is_echo_camera else "MusicBoxMuffledEcho"
	if feed_active and is_echo_camera:
		_music_box.volume_db = music_box_cam11_volume_db
	elif feed_active and is_remote_camera:
		match camera_index:
			9:
				_music_box.volume_db = music_box_cam10_volume_db
			8:
				_music_box.volume_db = music_box_cam9_volume_db
			11:
				_music_box.volume_db = music_box_cam6b_volume_db
	else:
		_music_box.volume_db = MUSIC_BOX_MUTED_VOLUME_DB


func _on_camera_system_opened() -> void:
	_set_office_ambience_reduced(true)


func _on_camera_system_closed() -> void:
	_set_office_ambience_reduced(false)


func _set_office_ambience_reduced(reduced: bool) -> void:
	if not _office_ambience or not is_instance_valid(_office_ambience):
		return
	_office_ambience.volume_db = office_ambience_monitor_db if reduced else office_ambience_office_db


func _ensure_music_buses() -> void:
	var late_echo_bus := _ensure_bus("MusicBoxLateEcho")
	if late_echo_bus >= 0 and AudioServer.get_bus_effect_count(late_echo_bus) == 0:
		var late_reverb := AudioEffectReverb.new()
		late_reverb.room_size = 0.9
		late_reverb.damping = 0.1
		late_reverb.wet = 0.5
		AudioServer.add_bus_effect(late_echo_bus, late_reverb)
	var echo_bus := _ensure_bus("MusicBoxEcho")
	if echo_bus >= 0 and AudioServer.get_bus_effect_count(echo_bus) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.72
		reverb.damping = 0.58
		reverb.wet = 0.4
		AudioServer.add_bus_effect(echo_bus, reverb)
	var muffled_echo_bus := _ensure_bus("MusicBoxMuffledEcho")
	if muffled_echo_bus >= 0 and AudioServer.get_bus_effect_count(muffled_echo_bus) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.72
		reverb.damping = 0.58
		reverb.wet = 0.3
		AudioServer.add_bus_effect(muffled_echo_bus, reverb)
		var low_pass := AudioEffectLowPassFilter.new()
		low_pass.cutoff_hz = 1750.0
		AudioServer.add_bus_effect(muffled_echo_bus, low_pass)


func _ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
	return index


func _on_game_finished() -> void:
	_ended = true
	_reset_dread_environment_and_lights()
	_camera_ui.set_music_box_late_active(false)
	_camera_ui.set_music_box_enabled(false)
	_music_box.stop()
	_music_box_late.stop()
	set_process(false)


func _on_lure_requested(cam_index: int) -> void:
	if cam_index < 0 or cam_index >= LURE_CAM_ROOMS.size() or _lure_sounds.is_empty():
		return
	var player: AudioStreamPlayer3D = _lure_sounds.pick_random()
	var spot := _monster_spots.get_node_or_null("Spot_" + LURE_CAM_ROOMS[cam_index]) as Node3D if _monster_spots else null
	if spot:
		player.global_position = spot.global_position
	player.stop()
	player.play()

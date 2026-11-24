class_name CameraSystemUI
extends CanvasLayer

enum State { IDLE, ZOOMING_IN, OPENING, ACTIVE, CLOSING, ZOOMING_OUT }

const CURSOR_ARROW = preload("res://png/cursor_arrow.png")
const CURSOR_HAND = preload("res://png/cursor_hand.png")
const BTN_NORMAL = preload("res://png/btn_normal.png")
const BTN_HOVER = preload("res://png/btn_hover.png")
const BTN_PRESSED = preload("res://png/btn_pressed.png")
const MUSIC_BOX_CAUTION_TEXTURE: Texture2D = preload("res://png/caution.png")
const CAMERA_MAP_TEX: Texture2D = preload("res://png/camera_map.png")
const AUDIO_WAVE_EFFECT_SCRIPT = preload("res://audio_wave_effect.gd")
const CAM_COUNT: int = 13
const STATIC_DIR_CANDIDATES: PackedStringArray = [
	"res://textures",
	"res://static",
	"res://png",
	"res://"
]
signal lure_requested(cam_index: int)
signal opened
signal closed
signal lost_signal_finished

@export_group("Görsel")
## İsteğe bağlı: özel .ttf/.otf font dosyası (boşsa sistem fontu kullanılır)
@export var win95_font: FontFile
## Harita görseli (boş bırakılırsa res://png/camera_map.png kullanılır)
@export var camera_map_texture: Texture2D = CAMERA_MAP_TEX
## Haritanın ekrandaki boyutu (piksel)
@export var map_size_px: Vector2 = Vector2(480.0, 480.0)
## Harita merkezinin ekran içindeki konumu (0.0 - 1.0 arası oran; (0.5, 0.5) tam orta)
@export var map_anchor: Vector2 = Vector2(0.80, 0.50)
## Haritanın sağ kenardan boşluğu (piksel) [eski uyumluluk / yedek]
@export var map_margin_px: float = 24.0
## Haritanın alt kenardan yukarı kayma mesafesi (EXIT butonuyla çakışmaması için) [eski uyumluluk / yedek]
@export var map_bottom_offset_px: float = 96.0
## Kamera değiştirme butonlarının boyutu (genişlik, yükseklik)
@export var cam_button_size: Vector2 = Vector2(44.0, 26.0)
## Frame (harita) içinde YOU etiketi merkez konumu (0.0 - 1.0 arası oran)
@export var you_map_anchor: Vector2 = Vector2(0.45, 0.62)
## Frame (harita) içinde büyüyüp küçülen karenin merkez konumu (0.0 - 1.0 arası oran)
@export var you_square_map_anchor: Vector2 = Vector2(0.45, 0.58)
## YOU etiketi için çeviri anahtarı (text alanına yazılır, çeviri sistemi otomatik çevirir)
@export var you_translation_key: String = "YOU"
## Kamera geçiş ekranı etiketi için çeviri anahtarı (text alanına yazılır, çeviri sistemi otomatik çevirir)
@export var pending_translation_key: String = "PENDING"
## static_01 ... static_09 dosyalarını buraya ekle (boş bırakılırsa kod otomatik yükler)
@export var static_frames: Array[Texture2D]
@export_range(0.0, 1.0) var static_alpha: float = 0.06
## Çizgi her saniye ekran yüksekliğinin bu oranı kadar iner
@export_range(0.005, 0.5) var scanline_step: float = 0.06
## Çizginin kalınlığı (piksel)
@export var scanline_height: float = 240.0
## İkinci ince çizginin her saniye ekran yüksekliğinin bu oranı kadar iner (daha hızlı)
@export_range(0.005, 0.8) var thin_scanline_step: float = 0.15
## İkinci ince çizginin kalınlığı (piksel)
@export var thin_scanline_height: float = 40.0
## Üçüncü çizginin her saniye ekran yüksekliğinin bu oranı kadar iner
@export_range(0.005, 0.8) var third_scanline_step: float = 0.22
## Üçüncü çizginin kalınlığı (piksel)
@export var third_scanline_height: float = 80.0
## El imlecinin tıklama noktası (parmak ucu)
@export var hand_hotspot: Vector2 = Vector2.ZERO
@export var button_margin: int = 4
## Açıksa buton ve etiketleri kod yerleştirir
@export var auto_layout: bool = true

@export_group("Kamera Çeviri Anahtarları")
@export var cam1_translation_key: String = "CAM_1_NAME"
@export var cam2_translation_key: String = "CAM_2_NAME"
@export var cam3_translation_key: String = "CAM_3_NAME"
@export var cam4_translation_key: String = "CAM_4_NAME"
@export var cam5_translation_key: String = "CAM_5_NAME"
@export var cam6_translation_key: String = "CAM_6A_NAME"
@export var cam7_translation_key: String = "CAM_6B_NAME"
@export var cam8_translation_key: String = "CAM_6C_NAME"
@export var cam9_translation_key: String = "CAM_7_NAME"
@export var cam10_translation_key: String = "CAM_8_NAME"
@export var cam11_translation_key: String = "CAM_9_NAME"
@export var cam12_translation_key: String = "CAM_10_NAME"
@export var cam13_translation_key: String = "CAM_11_NAME"

@export_group("Kamera Konumları")
@export var cam1_map_anchor: Vector2 = Vector2(0.28, 0.30)
@export var cam2_map_anchor: Vector2 = Vector2(0.49, 0.22)
@export var cam3_map_anchor: Vector2 = Vector2(0.51, 0.32)
@export var cam4_map_anchor: Vector2 = Vector2(0.43, 0.41)
@export var cam5_map_anchor: Vector2 = Vector2(0.57, 0.44)
@export var cam6_map_anchor: Vector2 = Vector2(0.68, 0.42)
@export var cam7_map_anchor: Vector2 = Vector2(0.13, 0.51)
@export var cam8_map_anchor: Vector2 = Vector2(0.33, 0.57)
@export var cam9_map_anchor: Vector2 = Vector2(0.41, 0.68)
@export var cam10_map_anchor: Vector2 = Vector2(0.35, 0.78)
@export var cam11_map_anchor: Vector2 = Vector2(0.47, 0.78)
@export var cam12_map_anchor: Vector2 = Vector2(0.68, 0.74)
@export var cam13_map_anchor: Vector2 = Vector2(0.82, 0.74)

@export_group("Güvenlik Kamerası")
## Kameranın sağa-sola sallanma açısı (± derece)
@export var sway_deg: float = 8.0
## Bir uçtan diğer uca tek yön dönüş süresi (saniye — artırdıkça daha yavaş döner)
@export var sway_move_time: float = 6.0
## Sağa veya sola döndükten sonra uçta bekleme süresi (saniye)
@export var sway_pause_time: float = 4.0

@export_group("Geçişler")
@export var zoom_time: float = 0.35
@export var open_fade_time: float = 0.35
@export var close_fade_time: float = 0.28
## Yaklaşırken/çıkarken rotasyon yumuşatma hızı
@export var aim_turn_speed: float = 16.0
## Alfa 0 bırakırsan monitör ekranının rengi kullanılır
@export var overlay_color_override: Color = Color(0, 0, 0, 0)

@export_group("Monitör Efekti")
@export_range(-80.0, 12.0, 0.5) var monitor_open_volume_db: float = -36.0
@export_range(-80.0, 12.0, 0.5) var monitor_glow_max_volume_db: float = -48.0
@export_range(0.01, 1.0, 0.01) var monitor_glow_fade_in_time: float = 0.06
@export_range(0.01, 2.0, 0.01) var monitor_glow_fade_out_time: float = 0.55

@export_group("Canavar Sistemi")
@export var play_sound_translation_key: String = "PLAY_AUDIO"
@export var lost_signal_translation_key: String = "LOST_SIGNAL"
## Play Sound butonunun bekleme süresi (saniye)
@export var play_sound_cooldown: float = 10.0
## LOST SIGNAL yazısının ekranda kalma süresi
@export var lost_signal_time: float = 2.5
## LOST SIGNAL'dan sonra PENDING'in kalma süresi
@export var pending_after_lost_time: float = 1.45
@export var play_sound_button_size: Vector2 = Vector2(220.0, 48.0)
@export_range(0.0, 0.2) var office_static_alpha: float = 0.05
@export var office_static_fade_time: float = 0.5
@export_range(40.0, 200.0, 0.01) var music_box_bpm: float = 81.27
@export_group("Music Box Caution Anchors")
## 81 BPM caution anchor (normalized viewport X/Y) and pixel offset from that anchor.
@export var caution_81_bpm_anchor: Vector2 = Vector2(0.0, 1.0)
@export var caution_81_bpm_offset: Vector2 = Vector2(280.0, -111.0)
## 70 BPM caution anchor (normalized viewport X/Y) and pixel offset from that anchor.
@export var caution_70_bpm_anchor: Vector2 = Vector2(0.0, 1.0)
@export var caution_70_bpm_offset: Vector2 = Vector2(85.0, -250.0)

@onready var root_ctrl: Control = $Root
@onready var cam_viewport: SubViewport = $Root/CamViewContainer/CamViewport
@onready var cam_camera: Camera3D = $Root/CamViewContainer/CamViewport/CamCamera
@onready var static_noise: TextureRect = $Root/StaticNoise
@onready var scanline: Control = $Root/Scanline
@onready var frame_rect: TextureRect = $Root/Frame
@onready var cam_label: Label = $Root/CamLabel
@onready var btn_cam1: Button = $Root/BtnCam1
@onready var btn_cam2: Button = $Root/BtnCam2
@onready var btn_exit: Button = $Root/BtnExit
@onready var overlay: ColorRect = $Root/ScreenOverlay
@onready var snap_timer: Timer = $Root/SnapTimer

var _cam_buttons: Array[Button] = []
var _hovered_cam_idx: int = -1
var _thin_scanline: Control
var _third_scanline: Control
var _pending_overlay: ColorRect
var _pending_label: Label
var _you_label: Label
var _you_square: ColorRect
var _you_square_large: bool = true
var _switching_cam: bool = false
var _lost_signal_active: bool = false
var _state: State = State.IDLE
var _player_cam: PlayerCamera
var _mouse_mode_before_cams: int = Input.MOUSE_MODE_VISIBLE
var _hitbox: GlowHitbox
var _zoom_view: Camera3D
var _cam_points: Array[Camera3D] = []
var _current_cam: int = 0
var _scan_y: float = 0.0
var _thin_scan_y: float = 0.0
var _third_scan_y: float = 0.0
var _last_static: int = -1
var _buttons_initialized: bool = false
var _base_cam_quat: Quaternion = Quaternion.IDENTITY
var _btn_play_sound: Button
var _audio_wave_effect: Control
var _lost_signal_audio: AudioStreamPlayer3D
var _after_lost_audio: AudioStreamPlayer3D
var _camera_select_audio: AudioStreamPlayer3D
var _monitor_glow_audio: AudioStreamPlayer3D
var _monitor_open_audio: AudioStreamPlayer3D
var _click_audio: AudioStreamPlayer3D
var _monitor_glow_tween: Tween
var _monitor_open_fade_tween: Tween
var _play_cooldown_left: float = 0.0
var _cam_locks: Dictionary = {}
var _close_requested: bool = false
var _office_static_layer: CanvasLayer
var _office_static_noise: TextureRect
var _office_static_left: float = 0.0
var _office_static_frame_left: float = 0.0
var _office_static_last: int = -1
var _office_static_active: bool = false
var _office_static_tween: Tween
var _music_box_wind_button: Button
var _music_box_bar_bg: ColorRect
var _music_box_bar_fill: ColorRect
var _music_box_caution: TextureRect
var _music_box_caution_late: TextureRect
var _music_box_caution_tween: Tween
var _music_box_warning_late_tween: Tween
var _music_box_opacity_tween: Tween
var _music_box_warning_tween: Tween
var _music_box_charge: float = 1.0
var _music_box_enabled: bool = true
var _music_box_winding: bool = false
var _music_box_beat_left: float = 0.0
var _music_box_beat_sign: float = 1.0
var _music_box_warning_target: bool = false
var _music_box_warning_late_target: bool = false
var _music_box_late_active: bool = false
var _jumpscare_interrupted: bool = false


func _ready() -> void:
	for stale_layer in get_tree().root.find_children("OfficeStaticEffect", "CanvasLayer", true, false):
		stale_layer.queue_free()
	visible = false
	cam_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	_load_static_frames_if_empty()

	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	static_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Mavi monitor katmanı büyük caution ikonunun üstünde kalsın.
	overlay.z_index = 26

	static_noise.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	static_noise.stretch_mode = TextureRect.STRETCH_TILE
	static_noise.visible = true
	static_noise.modulate = Color(1.0, 1.0, 1.0, static_alpha)

	_ensure_extra_scanlines()
	_ensure_you_label()
	_ensure_you_square()
	_ensure_pending_overlay()

	snap_timer.wait_time = 1.0
	snap_timer.one_shot = false
	if not snap_timer.timeout.is_connected(_tick):
		snap_timer.timeout.connect(_tick)
	snap_timer.start()

	_force_layout()
	_update_static()
	_apply_win95_font()
	_layout_pending_label()
	_refresh_label()
	if auto_layout:
		_layout_ui()
	_setup_map_frame()
	_order_pending_behind_hud()
	_order_overlay_on_top()
	_layout_play_sound_button()

	if _find_world_nodes():
		_start_monitor_glow()
		_clamp_current_cam()
		if not _hitbox.clicked.is_connected(_on_monitor_clicked):
			_hitbox.clicked.connect(_on_monitor_clicked)

func _get_cam_translation_keys() -> Array[String]:
	return [
		cam1_translation_key,
		cam2_translation_key,
		cam3_translation_key,
		cam4_translation_key,
		cam5_translation_key,
		cam6_translation_key,
		cam7_translation_key,
		cam8_translation_key,
		cam9_translation_key,
		cam10_translation_key,
		cam11_translation_key,
		cam12_translation_key,
		cam13_translation_key
	]


func _get_cam_translation_key(index: int) -> String:
	var keys := _get_cam_translation_keys()
	if index >= 0 and index < keys.size():
		var k: String = keys[index].strip_edges()
		if not k.is_empty():
			return k
	return "CAM_%s" % _get_cam_code(index).to_upper()


func _get_cam_anchors() -> Array[Vector2]:
	return [
		cam1_map_anchor,
		cam2_map_anchor,
		cam3_map_anchor,
		cam4_map_anchor,
		cam5_map_anchor,
		cam6_map_anchor,
		cam7_map_anchor,
		cam8_map_anchor,
		cam9_map_anchor,
		cam10_map_anchor,
		cam11_map_anchor,
		cam12_map_anchor,
		cam13_map_anchor
	]


func _get_cam_code(index: int) -> String:
	match index:
		5:
			return "6a"
		11:
			return "6b"
		12:
			return "6c"
		_:
			return str(index + 1)


func _get_cam_button_text(index: int) -> String:
	return "CAM\n%s" % _get_cam_code(index)


func _clamp_current_cam() -> void:
	_current_cam = clampi(_current_cam, 0, CAM_COUNT - 1)


func _load_static_frames_if_empty() -> void:
	if not static_frames.is_empty():
		return

	var found_paths: Dictionary = {}
	for i in range(1, 10):
		var file_name: String = "static_%02d.png" % i
		for base_dir: String in STATIC_DIR_CANDIDATES:
			var candidate: String = base_dir.path_join(file_name)
			if ResourceLoader.exists(candidate):
				found_paths[i] = candidate
				break

	if found_paths.size() < 9:
		_scan_dir_for_statics("res://", found_paths)

	for i in range(1, 10):
		if found_paths.has(i):
			var path_str: String = str(found_paths[i])
			var tex := load(path_str) as Texture2D
			if tex:
				static_frames.append(tex)


func _scan_dir_for_statics(dir_path: String, found_paths: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with(".") and entry != "addons":
				var sub_dir: String = dir_path.path_join(entry)
				_scan_dir_for_statics(sub_dir, found_paths)
		else:
			for i in range(1, 10):
				var target: String = "static_%02d.png" % i
				if entry == target and not found_paths.has(i):
					var full_path: String = dir_path.path_join(entry)
					found_paths[i] = full_path
		entry = dir.get_next()
	dir.list_dir_end()


func _process(delta: float) -> void:
	_process_office_static(delta)
	_process_music_box_warning(delta)
	_update_music_box_winding_from_mouse()
	if _play_cooldown_left > 0.0:
		_play_cooldown_left = maxf(_play_cooldown_left - delta, 0.0)
		_update_play_sound_button()
	if not _player_cam or not is_instance_valid(_player_cam):
		return
	if _state == State.ZOOMING_IN and _zoom_view and is_instance_valid(_zoom_view):
		var zoom_quat := _zoom_view.global_transform.basis.get_rotation_quaternion().normalized()
		_blend_camera_rotation(zoom_quat, delta)
	elif _state == State.ZOOMING_OUT:
		_blend_camera_rotation(_base_cam_quat, delta)


func _blend_camera_rotation(target_quat: Quaternion, delta: float) -> void:
	var current_quat := _player_cam.global_transform.basis.get_rotation_quaternion().normalized()
	var end_quat := target_quat.normalized()
	if current_quat.dot(end_quat) < 0.0:
		end_quat = -end_quat
	var t := clampf(aim_turn_speed * delta, 0.0, 1.0)
	var blended_basis := Basis(current_quat.slerp(end_quat, t).normalized())
	_player_cam.global_transform = Transform3D(blended_basis, _player_cam.global_transform.origin)


func _ensure_extra_scanlines() -> void:
	var base_idx: int = scanline.get_index()
	if not _thin_scanline or not is_instance_valid(_thin_scanline):
		_thin_scanline = scanline.duplicate() as Control
		_thin_scanline.name = "ThinScanline"
		_thin_scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_ctrl.add_child(_thin_scanline)
		root_ctrl.move_child(_thin_scanline, base_idx + 1)

	if not _third_scanline or not is_instance_valid(_third_scanline):
		_third_scanline = scanline.duplicate() as Control
		_third_scanline.name = "ThirdScanline"
		_third_scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_ctrl.add_child(_third_scanline)
		root_ctrl.move_child(_third_scanline, base_idx + 2)


func _ensure_you_label() -> void:
	if not _you_label or not is_instance_valid(_you_label):
		_you_label = Label.new()
		_you_label.name = "YouLabel"
		_you_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_you_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_you_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_ctrl.add_child(_you_label)
	_you_label.text = you_translation_key
	_you_label.visible = true


func _ensure_you_square() -> void:
	if not _you_square or not is_instance_valid(_you_square):
		_you_square = ColorRect.new()
		_you_square.name = "YouSquare"
		_you_square.color = Color(1.0, 1.0, 1.0, 1.0)
		_you_square.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_ctrl.add_child(_you_square)
	_you_square.visible = true


func _layout_you_square() -> void:
	if not _you_square or not is_instance_valid(_you_square):
		return
	var sq_size_px: float = 10.0 if _you_square_large else 6.0
	var sq_size := Vector2(sq_size_px, sq_size_px)
	_place_control_on_map(_you_square, you_square_map_anchor, sq_size)


func _order_overlay_on_top() -> void:
	if not overlay or not is_instance_valid(overlay) or overlay.get_parent() != root_ctrl:
		return
	var below_overlay: Array[Control] = [frame_rect, _you_label, _you_square, cam_label, btn_exit]
	for b: Button in _cam_buttons:
		if b and is_instance_valid(b):
			below_overlay.append(b)
	if _btn_play_sound and is_instance_valid(_btn_play_sound):
		below_overlay.append(_btn_play_sound)
	for ctrl: Control in below_overlay:
		if ctrl and is_instance_valid(ctrl) and ctrl.get_parent() == root_ctrl:
			if ctrl.get_index() >= overlay.get_index():
				root_ctrl.move_child(ctrl, maxi(overlay.get_index() - 1, 0))


func _layout_pending_label() -> void:
	if not _pending_label or not is_instance_valid(_pending_label):
		return
	var margin: float = 24.0
	_pending_label.text = pending_translation_key
	_pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pending_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_pending_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	var p_size: Vector2 = _pending_label.get_combined_minimum_size().max(Vector2(120.0, 40.0))
	_pending_label.offset_left = margin
	_pending_label.offset_right = margin + p_size.x
	_pending_label.offset_bottom = -margin
	_pending_label.offset_top = -margin - p_size.y


func _ensure_pending_overlay() -> void:
	if not _pending_overlay or not is_instance_valid(_pending_overlay):
		_pending_overlay = ColorRect.new()
		_pending_overlay.name = "PendingOverlay"
		_pending_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
		_pending_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pending_overlay.visible = false
		root_ctrl.add_child(_pending_overlay)

		_pending_label = Label.new()
		_pending_label.name = "PendingLabel"
		_pending_label.text = pending_translation_key
		_pending_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pending_overlay.add_child(_pending_label)
	elif _pending_label and is_instance_valid(_pending_label):
		_pending_label.text = pending_translation_key

	_layout_pending_label()
	_order_pending_behind_hud()


func _order_pending_behind_hud() -> void:
	if not _pending_overlay or not is_instance_valid(_pending_overlay):
		return
	if _pending_overlay.get_parent() != root_ctrl:
		return
	var hud_nodes: Array[Control] = [frame_rect, _you_label, _you_square, cam_label, btn_exit]
	for b: Button in _cam_buttons:
		if b and is_instance_valid(b):
			hud_nodes.append(b)
	if _btn_play_sound and is_instance_valid(_btn_play_sound):
		hud_nodes.append(_btn_play_sound)
	var first_hud_idx: int = root_ctrl.get_child_count()
	for hud_node: Control in hud_nodes:
		if hud_node and hud_node.get_parent() == root_ctrl:
			first_hud_idx = mini(first_hud_idx, hud_node.get_index())
	var desired_idx: int = maxi(first_hud_idx - 1, 0)
	if _pending_overlay.get_index() >= first_hud_idx:
		desired_idx = first_hud_idx
	root_ctrl.move_child(_pending_overlay, desired_idx)
	for hud_node: Control in hud_nodes:
		if hud_node and hud_node.get_parent() == root_ctrl and hud_node.get_index() < _pending_overlay.get_index():
			root_ctrl.move_child(hud_node, _pending_overlay.get_index() + 1)


func _set_transition_controls_behind(behind: bool) -> void:
	var controls: Array[Control] = [_btn_play_sound, _music_box_wind_button, _music_box_bar_bg, _audio_wave_effect]
	for control: Control in controls:
		if control and is_instance_valid(control):
			if behind:
				control.z_index = -1
			elif control == _audio_wave_effect:
				control.z_index = 20
			elif control == _btn_play_sound:
				control.z_index = 0
			else:
				control.z_index = 24
	if _music_box_caution and is_instance_valid(_music_box_caution):
		_music_box_caution.z_index = -1 if behind else 25


func _get_root_viewport_size() -> Vector2:
	var root_size: Vector2 = root_ctrl.size
	if root_size.x <= 1.0 or root_size.y <= 1.0:
		root_size = get_viewport().get_visible_rect().size
	return root_size


func _get_map_rect_in_root() -> Rect2:
	var root_size: Vector2 = _get_root_viewport_size()
	var clamped_anchor := Vector2(
		clampf(map_anchor.x, 0.0, 1.0),
		clampf(map_anchor.y, 0.0, 1.0)
	)
	var center_pos := Vector2(
		root_size.x * clamped_anchor.x,
		root_size.y * clamped_anchor.y
	)
	var top_left: Vector2 = center_pos - (map_size_px * 0.5)
	return Rect2(top_left, map_size_px)


func _setup_map_frame() -> void:
	if not frame_rect or not is_instance_valid(frame_rect):
		return
	var tex: Texture2D = camera_map_texture if camera_map_texture else CAMERA_MAP_TEX
	if tex:
		frame_rect.texture = tex
	frame_rect.visible = true
	frame_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var map_rect: Rect2 = _get_map_rect_in_root()
	frame_rect.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	frame_rect.offset_left = map_rect.position.x
	frame_rect.offset_top = map_rect.position.y
	frame_rect.offset_right = map_rect.position.x + map_rect.size.x
	frame_rect.offset_bottom = map_rect.position.y + map_rect.size.y


func _place_control_on_map(ctrl: Control, map_uv: Vector2, ctrl_size: Vector2) -> void:
	if not ctrl or not is_instance_valid(ctrl):
		return
	var map_rect: Rect2 = _get_map_rect_in_root()
	var center_pos: Vector2 = map_rect.position + Vector2(
		map_rect.size.x * map_uv.x,
		map_rect.size.y * map_uv.y
	)
	var top_left: Vector2 = center_pos - (ctrl_size * 0.5)
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	ctrl.offset_left = top_left.x
	ctrl.offset_top = top_left.y
	ctrl.offset_right = top_left.x + ctrl_size.x
	ctrl.offset_bottom = top_left.y + ctrl_size.y


func _force_layout() -> void:
	for c: Control in [root_ctrl, $Root/CamViewContainer, static_noise, overlay]:
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	static_noise.modulate.a = static_alpha

	_ensure_extra_scanlines()
	_ensure_you_label()
	_ensure_you_square()
	_ensure_pending_overlay()

	_pending_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout_pending_label()

	scanline.custom_minimum_size = Vector2(0.0, scanline_height)
	scanline.size.y = scanline_height
	scanline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	_thin_scanline.custom_minimum_size = Vector2(0.0, thin_scanline_height)
	_thin_scanline.size.y = thin_scanline_height
	_thin_scanline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	_third_scanline.custom_minimum_size = Vector2(0.0, third_scanline_height)
	_third_scanline.size.y = third_scanline_height
	_third_scanline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	_setup_buttons()
	_ensure_play_sound_button()
	_ensure_music_box_controls()
	_apply_win95_font()
	_layout_pending_label()
	_refresh_label()
	if auto_layout:
		_layout_ui()
	_setup_map_frame()
	_order_pending_behind_hud()
	_order_overlay_on_top()
	_layout_play_sound_button()
	_layout_music_box_controls()


func _exit_tree() -> void:
	_set_cursor(false)
	_office_static_active = false
	_office_static_left = 0.0
	if _office_static_layer and is_instance_valid(_office_static_layer):
		_office_static_layer.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _state == State.ACTIVE:
		_on_exit_pressed()


# ---------- Kurulum ----------

func _find_world_nodes() -> bool:
	var tree_root := get_tree().root
	_player_cam = tree_root.find_child("Camera3D", true, false) as PlayerCamera
	_hitbox = tree_root.find_child("MonitorHitbox", true, false) as GlowHitbox
	_zoom_view = tree_root.find_child("MonitorZoomView", true, false) as Camera3D
	_lost_signal_audio = tree_root.find_child("LostSignal", true, false) as AudioStreamPlayer3D
	_after_lost_audio = tree_root.find_child("AfterLost", true, false) as AudioStreamPlayer3D
	_camera_select_audio = tree_root.find_child("CameraSelect", true, false) as AudioStreamPlayer3D
	_monitor_glow_audio = tree_root.find_child("MonitorGlow", true, false) as AudioStreamPlayer3D
	_monitor_open_audio = tree_root.find_child("MonitorOpens", true, false) as AudioStreamPlayer3D
	_click_audio = tree_root.find_child("Click", true, false) as AudioStreamPlayer3D
	for player: AudioStreamPlayer3D in [_lost_signal_audio, _after_lost_audio, _camera_select_audio, _monitor_glow_audio, _monitor_open_audio, _click_audio]:
		if player:
			player.max_distance = 100.0
			player.unit_size = 20.0
			player.volume_db = -4.0
	# Keep these effects quieter than the shared default above.
	if _after_lost_audio:
		_after_lost_audio.volume_db = -16.0
	if _monitor_open_audio:
		_monitor_open_audio.volume_db = monitor_open_volume_db
	if _hitbox and not _hitbox.hover_changed.is_connected(_on_monitor_hover_changed):
		_hitbox.hover_changed.connect(_on_monitor_hover_changed)
	_cam_points.clear()
	_cam_points.resize(CAM_COUNT)
	var any_cam_found: bool = false
	for i in range(1, CAM_COUNT + 1):
		var cam_name: String = "SecCam%d" % i
		var c := tree_root.find_child(cam_name, true, false) as Camera3D
		if c:
			_cam_points[i - 1] = c
			any_cam_found = true
		else:
			push_warning("Kamera sistemi: %s düğümü sahnede bulunamadı." % cam_name)

	if not _player_cam or not _hitbox or not _zoom_view or not any_cam_found:
		push_error("Kamera sistemi: gerekli düğümler bulunamadı (Camera3D, MonitorHitbox, MonitorZoomView, SecCam1..SecCam%d)." % CAM_COUNT)
		return false
	return true


func _build_cam_btn_font() -> Font:
	if win95_font:
		return win95_font
	var cam_font := SystemFont.new()
	cam_font.font_names = PackedStringArray(["Fixedsys", "Terminal", "Lucida Console", "Consolas", "Courier New"])
	cam_font.font_weight = 700
	cam_font.font_stretch = 110
	cam_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	cam_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return cam_font


func _build_pending_font() -> Font:
	if win95_font:
		return win95_font
	var sys_font := SystemFont.new()
	sys_font.font_names = PackedStringArray(["MS Sans Serif", "Fixedsys", "Terminal", "Courier New", "Arial"])
	sys_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	sys_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return sys_font


func _build_exit_wide_font() -> Font:
	if win95_font:
		return win95_font
	var wide_font := SystemFont.new()
	wide_font.font_names = PackedStringArray(["Fixedsys", "Terminal", "Lucida Console", "Consolas", "Courier New"])
	wide_font.font_weight = 700
	wide_font.font_stretch = 150
	wide_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	wide_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return wide_font


func _apply_win95_font() -> void:
	var cam_btn_f := _build_cam_btn_font()
	var initial_f := _build_pending_font()
	var exit_f := _build_exit_wide_font()

	cam_label.add_theme_font_override("font", initial_f)
	cam_label.add_theme_font_size_override("font_size", 22)
	cam_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

	if _you_label and is_instance_valid(_you_label):
		_you_label.text = you_translation_key
		_you_label.add_theme_font_override("font", initial_f)
		_you_label.add_theme_font_size_override("font_size", 16)
		_you_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

	var cam_text_white := Color(1.0, 1.0, 1.0, 1.0)
	var cam_shadow_black := Color(0.0, 0.0, 0.0, 1.0)
	for b: Button in _cam_buttons:
		b.add_theme_font_override("font", cam_btn_f)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_constant_override("line_spacing", -1)
		b.add_theme_constant_override("spacing_glyph", 0)
		b.add_theme_constant_override("outline_size", 0)
		b.add_theme_color_override("font_color", cam_text_white)
		b.add_theme_color_override("font_hover_color", cam_text_white)
		b.add_theme_color_override("font_pressed_color", cam_text_white)
		b.add_theme_color_override("font_hover_pressed_color", cam_text_white)
		b.add_theme_color_override("font_shadow_color", cam_shadow_black)
		b.add_theme_constant_override("shadow_offset_x", 1)
		b.add_theme_constant_override("shadow_offset_y", 1)

	var exit_red := Color(0.75, 0.14, 0.14, 1.0)
	btn_exit.add_theme_font_override("font", exit_f)
	btn_exit.add_theme_font_size_override("font_size", 20)
	btn_exit.add_theme_constant_override("spacing_glyph", 3)
	btn_exit.add_theme_color_override("font_color", exit_red)
	btn_exit.add_theme_color_override("font_hover_color", exit_red)
	btn_exit.add_theme_color_override("font_pressed_color", exit_red)
	btn_exit.add_theme_color_override("font_hover_pressed_color", exit_red)
	btn_exit.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	btn_exit.add_theme_constant_override("shadow_offset_x", 1)
	btn_exit.add_theme_constant_override("shadow_offset_y", 1)
	btn_exit.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	btn_exit.add_theme_constant_override("outline_size", 1)

	if _pending_label and is_instance_valid(_pending_label):
		_pending_label.text = pending_translation_key
		_pending_label.add_theme_font_override("font", initial_f)
		_pending_label.add_theme_font_size_override("font_size", 36)
		_pending_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))


func _setup_buttons() -> void:
	if _cam_buttons.is_empty():
		_cam_buttons.append(btn_cam1)
		_cam_buttons.append(btn_cam2)
		for i in range(3, CAM_COUNT + 1):
			var extra_btn := Button.new()
			extra_btn.name = "BtnCam%d" % i
			root_ctrl.add_child(extra_btn)
			_cam_buttons.append(extra_btn)

	for i in range(_cam_buttons.size()):
		var b: Button = _cam_buttons[i]
		b.text = _get_cam_button_text(i)
		b.clip_contents = false
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = cam_button_size

	btn_exit.text = "EXIT"
	btn_exit.custom_minimum_size = Vector2(144, 48)

	if _buttons_initialized:
		return
	_buttons_initialized = true

	var group := ButtonGroup.new()
	for i in range(_cam_buttons.size()):
		var b: Button = _cam_buttons[i]
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_select_cam.bind(i))
		b.mouse_entered.connect(_on_cam_btn_hover_changed.bind(i, true))
		b.mouse_exited.connect(_on_cam_btn_hover_changed.bind(i, false))
		var normal_style := _make_cam_style(BTN_NORMAL)
		b.add_theme_stylebox_override("normal", normal_style)
		b.add_theme_stylebox_override("hover", _make_cam_style(BTN_HOVER))
		b.add_theme_stylebox_override("pressed", normal_style)
		b.add_theme_stylebox_override("hover_pressed", normal_style)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var exit_pressed_style := _make_style(BTN_PRESSED)
	btn_exit.add_theme_stylebox_override("normal", _make_style(BTN_NORMAL))
	btn_exit.add_theme_stylebox_override("hover", _make_style(BTN_HOVER))
	btn_exit.add_theme_stylebox_override("pressed", exit_pressed_style)
	btn_exit.add_theme_stylebox_override("hover_pressed", exit_pressed_style)
	btn_exit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_exit.focus_mode = Control.FOCUS_NONE
	btn_exit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	btn_exit.pressed.connect(_on_exit_pressed)
	_update_cam_button_opacities()


func _on_cam_btn_hover_changed(index: int, entered: bool) -> void:
	if entered:
		_hovered_cam_idx = index
	elif _hovered_cam_idx == index:
		_hovered_cam_idx = -1
	_update_cam_button_opacities()


func _update_cam_button_opacities() -> void:
	for i in range(_cam_buttons.size()):
		var b: Button = _cam_buttons[i]
		if not b or not is_instance_valid(b):
			continue
		var alpha: float = 0.5
		if i == _current_cam:
			alpha = 1.0
		elif i == _hovered_cam_idx:
			alpha = 0.75
		b.modulate.a = alpha


func _make_style(tex: Texture2D) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = button_margin
	sb.texture_margin_right = button_margin
	sb.texture_margin_top = button_margin
	sb.texture_margin_bottom = button_margin
	return sb


func _make_cam_style(tex: Texture2D) -> StyleBoxTexture:
	var sb := _make_style(tex)
	sb.content_margin_left = 2.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 2.0
	sb.content_margin_bottom = 0.0
	return sb


func _layout_ui() -> void:
	var margin: float = 24.0

	cam_label.visible = true
	cam_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	cam_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	cam_label.add_theme_font_size_override("font_size", 22)
	cam_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	var lbl_size: Vector2 = cam_label.get_combined_minimum_size().max(Vector2(120.0, 28.0))
	cam_label.offset_left = margin
	cam_label.offset_top = margin
	cam_label.offset_right = margin + lbl_size.x
	cam_label.offset_bottom = margin + lbl_size.y

	_setup_map_frame()
	var anchors := _get_cam_anchors()
	for i in range(mini(_cam_buttons.size(), anchors.size())):
		_place_control_on_map(_cam_buttons[i], anchors[i], cam_button_size)

	if _you_label and is_instance_valid(_you_label):
		_you_label.text = you_translation_key
		var you_size: Vector2 = _you_label.get_combined_minimum_size().max(Vector2(56.0, 24.0))
		_place_control_on_map(_you_label, you_map_anchor, you_size)

	_layout_you_square()
	_layout_pending_label()

	var exit_size: Vector2 = btn_exit.get_combined_minimum_size()
	btn_exit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	btn_exit.offset_right = -margin
	btn_exit.offset_left = -margin - exit_size.x
	btn_exit.offset_bottom = -margin
	btn_exit.offset_top = -margin - exit_size.y


# ---------- Açılış ----------

func _on_monitor_clicked() -> void:
	if are_cams_locked():
		return
	if _state != State.IDLE:
		return
	_jumpscare_interrupted = false
	_mouse_mode_before_cams = Input.mouse_mode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	opened.emit()
	_base_cam_quat = _player_cam.global_transform.basis.get_rotation_quaternion().normalized()
	_state = State.ZOOMING_IN
	_hitbox.set_in_use(true)
	_play_monitor_open_audio()
	_player_cam.zoom_to(_zoom_view.global_transform, _zoom_view.fov, zoom_time)
	await _player_cam.zoom_finished
	if _jumpscare_interrupted:
		return
	await _open_ui()


func _open_ui() -> void:
	_state = State.OPENING
	_ensure_pending_overlay()
	_pending_overlay.visible = true
	overlay.color = _get_overlay_color()
	overlay.modulate.a = 1.0
	visible = true
	await get_tree().process_frame
	if _jumpscare_interrupted:
		return

	_clamp_current_cam()
	_sync_buttons()
	_refresh_label()
	_update_static()
	_randomize_scanlines()
	_render_cam()
	await RenderingServer.frame_post_draw
	if _jumpscare_interrupted:
		return

	_set_cursor(true)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(overlay, "modulate:a", 0.0, open_fade_time)
	await tw.finished
	if _jumpscare_interrupted:
		return

	await get_tree().create_timer(0.25).timeout
	if _jumpscare_interrupted:
		return
	if _pending_overlay and is_instance_valid(_pending_overlay):
		_pending_overlay.visible = false

	_state = State.ACTIVE
	_update_music_box_controls()
	if _close_requested:
		_close_requested = false
		_close_ui()


# ---------- Kapanış ----------

func _on_exit_pressed() -> void:
	if _state != State.ACTIVE:
		return
	_play_audio(_click_audio)
	_close_ui()


func _close_ui() -> void:
	_state = State.CLOSING
	closed.emit()
	_close_requested = false
	overlay.color = _get_overlay_color()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(overlay, "modulate:a", 1.0, close_fade_time)
	await tw.finished

	visible = false
	if _pending_overlay and is_instance_valid(_pending_overlay):
		_pending_overlay.visible = false
	_music_box_winding = false
	_update_music_box_controls()
	_set_cursor(false)
	cam_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_force_layout()

	_state = State.ZOOMING_OUT
	_player_cam.return_to_base(zoom_time)
	await _player_cam.return_finished
	Input.set_mouse_mode(_mouse_mode_before_cams)

	_hitbox.set_in_use(false)
	_state = State.IDLE


# ---------- Saniyede bir çalışan kısım (1 FPS) ----------

func _tick() -> void:
	_you_square_large = not _you_square_large
	_layout_you_square()
	_update_static()
	if not visible and _state != State.ACTIVE:
		return
	_step_scanline()
	_render_cam()


func _get_sway_angle_rad() -> float:
	var move_t: float = maxf(sway_move_time, 0.05)
	var pause_t: float = maxf(sway_pause_time, 0.0)
	var cycle_len: float = (move_t + pause_t) * 2.0
	var elapsed: float = fmod(Time.get_ticks_msec() / 1000.0, cycle_len)

	var factor: float = -1.0
	if elapsed < move_t:
		var p: float = smoothstep(0.0, 1.0, elapsed / move_t)
		factor = lerpf(-1.0, 1.0, p)
	elif elapsed < move_t + pause_t:
		factor = 1.0
	elif elapsed < (move_t * 2.0) + pause_t:
		var p: float = smoothstep(0.0, 1.0, (elapsed - move_t - pause_t) / move_t)
		factor = lerpf(1.0, -1.0, p)
	else:
		factor = -1.0

	return factor * deg_to_rad(sway_deg)


func _render_cam() -> void:
	if _cam_points.is_empty():
		return
	_clamp_current_cam()
	if _current_cam < 0 or _current_cam >= _cam_points.size():
		return
	var point := _cam_points[_current_cam]
	if not point or not is_instance_valid(point):
		return
	var angle: float = _get_sway_angle_rad()
	var xf := point.global_transform
	cam_camera.global_transform = Transform3D(xf.basis * Basis(Vector3.UP, angle), xf.origin)
	cam_camera.fov = point.fov
	cam_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func play_office_static(duration: float = -1.0) -> void:
	_load_static_frames_if_empty()
	if static_frames.is_empty():
		return
	if not _office_static_layer or not is_instance_valid(_office_static_layer):
		_office_static_layer = CanvasLayer.new()
		_office_static_layer.name = "OfficeStaticEffect"
		_office_static_layer.layer = 90
		var scene_root := get_tree().current_scene
		if scene_root == null:
			scene_root = get_tree().root
		scene_root.add_child(_office_static_layer)
		_office_static_noise = TextureRect.new()
		_office_static_noise.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_office_static_noise.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_office_static_noise.stretch_mode = TextureRect.STRETCH_TILE
		_office_static_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_office_static_layer.add_child(_office_static_noise)

	_office_static_left = duration
	_office_static_frame_left = 0.0
	_office_static_active = true
	_office_static_layer.visible = true
	_office_static_noise.modulate.a = 0.0
	if _office_static_tween:
		_office_static_tween.kill()
	_office_static_tween = create_tween()
	_office_static_tween.tween_property(_office_static_noise, "modulate:a", office_static_alpha, maxf(office_static_fade_time, 0.01))
	_process_office_static(0.0)

func stop_office_static() -> void:
	if not _office_static_active:
		return
	_office_static_active = false
	if _office_static_tween:
		_office_static_tween.kill()
	if not _office_static_noise or not is_instance_valid(_office_static_noise):
		return
	_office_static_tween = create_tween()
	_office_static_tween.tween_property(_office_static_noise, "modulate:a", 0.0, maxf(office_static_fade_time, 0.01))
	_office_static_tween.finished.connect(func() -> void:
		if not _office_static_active and _office_static_layer and is_instance_valid(_office_static_layer):
			_office_static_layer.visible = false
	)

func _process_office_static(delta: float) -> void:
	if not _office_static_noise or not is_instance_valid(_office_static_noise):
		return
	if not _office_static_active:
		return
	if _office_static_left > 0.0:
		_office_static_left = maxf(_office_static_left - delta, 0.0)
		if _office_static_left <= 0.0:
			stop_office_static()
			return
	_office_static_frame_left -= delta
	if _office_static_frame_left <= 0.0 and not static_frames.is_empty():
		var idx := randi() % static_frames.size()
		while static_frames.size() > 1 and idx == _office_static_last:
			idx = randi() % static_frames.size()
		_office_static_last = idx
		_office_static_noise.texture = static_frames[idx]
		_office_static_frame_left = 0.045


func _update_static() -> void:
	_load_static_frames_if_empty()
	var n: int = static_frames.size()
	if n == 0:
		return
	var idx: int = randi() % n
	while n > 1 and idx == _last_static:
		idx = randi() % n
	_last_static = idx
	static_noise.texture = static_frames[idx]
	static_noise.modulate.a = static_alpha


func _step_scanline() -> void:
	_scan_y += root_ctrl.size.y * scanline_step
	if _scan_y > root_ctrl.size.y:
		_scan_y = -scanline.size.y

	_thin_scan_y += root_ctrl.size.y * thin_scanline_step
	if _thin_scan_y > root_ctrl.size.y:
		_thin_scan_y = -_thin_scanline.size.y

	_third_scan_y += root_ctrl.size.y * third_scanline_step
	if _third_scan_y > root_ctrl.size.y:
		_third_scan_y = -_third_scanline.size.y

	_apply_scanline()


func _randomize_scanlines() -> void:
	var h: float = maxf(root_ctrl.size.y, 1.0)
	_scan_y = randf_range(-scanline.size.y, h)
	_thin_scan_y = randf_range(-_thin_scanline.size.y, h)
	_third_scan_y = randf_range(-_third_scanline.size.y, h)
	_apply_scanline()


func _apply_scanline() -> void:
	scanline.position.y = _scan_y
	if _thin_scanline and is_instance_valid(_thin_scanline):
		_thin_scanline.position.y = _thin_scan_y
	if _third_scanline and is_instance_valid(_third_scanline):
		_third_scanline.position.y = _third_scan_y


# ---------- Kamera seçimi ----------

func _select_cam(index: int) -> void:
	if _state != State.ACTIVE or index == _current_cam:
		return
	if _switching_cam:
		if not _lost_signal_active:
			return
		_play_audio(_camera_select_audio)
		_current_cam = index
		_music_box_winding = false
		_clamp_current_cam()
		_sync_buttons()
		_refresh_label()
		_update_music_box_controls()
		_update_static()
		_randomize_scanlines()
		_render_cam()
		return
	_play_audio(_camera_select_audio)
	_switching_cam = true
	_current_cam = index
	_music_box_winding = false
	_update_music_box_controls()
	_clamp_current_cam()
	_sync_buttons()
	_refresh_label()

	_ensure_pending_overlay()
	_pending_overlay.visible = true

	await get_tree().create_timer(0.25).timeout

	_update_static()
	_randomize_scanlines()
	_render_cam()

	if _pending_overlay and is_instance_valid(_pending_overlay):
		_pending_overlay.visible = false
	_switching_cam = false
	_update_music_box_controls()


func _sync_buttons() -> void:
	for i in range(_cam_buttons.size()):
		_cam_buttons[i].set_pressed_no_signal(i == _current_cam)
	_update_cam_button_opacities()


func _refresh_label() -> void:
	cam_label.text = _get_cam_translation_key(_current_cam)
	cam_label.visible = true
	if auto_layout:
		var margin: float = 24.0
		var lbl_size: Vector2 = cam_label.get_combined_minimum_size().max(Vector2(120.0, 28.0))
		cam_label.offset_right = margin + lbl_size.x
		cam_label.offset_bottom = margin + lbl_size.y


# ---------- Yardımcılar ----------

func _get_overlay_color() -> Color:
	var c := overlay_color_override
	if c.a <= 0.0:
		c = _hitbox.get_on_color()
	c.a = 1.0
	return c


func _set_cursor(on: bool) -> void:
	if on:
		Input.set_custom_mouse_cursor(CURSOR_ARROW, Input.CURSOR_ARROW, Vector2.ZERO)
		Input.set_custom_mouse_cursor(CURSOR_HAND, Input.CURSOR_POINTING_HAND, hand_hotspot)
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)


# ---------- Canavar sistemi ----------

func lock_cams(reason: String) -> void:
	_cam_locks[reason] = true


func unlock_cams(reason: String) -> void:
	_cam_locks.erase(reason)


func are_cams_locked() -> bool:
	return not _cam_locks.is_empty()


func is_camera_feed_active() -> bool:
	return _state == State.ACTIVE


func get_current_camera_index() -> int:
	return _current_cam


func get_current_camera_transform() -> Transform3D:
	_clamp_current_cam()
	if _current_cam >= 0 and _current_cam < _cam_points.size():
		var point := _cam_points[_current_cam]
		if point and is_instance_valid(point):
			return point.global_transform
	return Transform3D.IDENTITY


func is_music_box_winding() -> bool:
	return _music_box_winding and _music_box_enabled and _state == State.ACTIVE and _current_cam == 10


func set_music_box_enabled(value: bool) -> void:
	if _music_box_enabled == value:
		_update_music_box_controls()
		return
	_music_box_enabled = value
	_music_box_winding = false
	if value:
		_update_music_box_controls()
		return
	if _music_box_opacity_tween and _music_box_opacity_tween.is_valid():
		_music_box_opacity_tween.kill()
	_music_box_opacity_tween = create_tween()
	_music_box_opacity_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for control: Control in [_music_box_wind_button, _music_box_bar_bg]:
		if control and is_instance_valid(control):
			control.visible = true
			_music_box_opacity_tween.parallel().tween_property(control, "modulate:a", 0.0, 0.18)
	_update_music_box_warning()
	_music_box_opacity_tween.finished.connect(func() -> void:
		for control: Control in [_music_box_wind_button, _music_box_bar_bg]:
			if control and is_instance_valid(control):
				control.visible = false
	)


func set_music_box_late_active(value: bool) -> void:
	_music_box_late_active = value
	_music_box_beat_left = 0.0
	_layout_music_box_controls()
	_update_music_box_warning()


func set_music_box_charge(value: float) -> void:
	_music_box_charge = clampf(value, 0.0, 1.0)
	if not _music_box_bar_bg or not is_instance_valid(_music_box_bar_bg):
		return
	var width := _music_box_bar_bg.size.x * _music_box_charge
	_music_box_bar_fill.position.x = 0.0
	_music_box_bar_fill.size.x = width
	_music_box_bar_fill.color = Color.WHITE.lerp(Color(1.0, 0.04, 0.02, 1.0), 1.0 - _music_box_charge)
	_update_music_box_warning()


func _ensure_music_box_controls() -> void:
	if _music_box_wind_button and is_instance_valid(_music_box_wind_button):
		return
	_music_box_bar_bg = ColorRect.new()
	_music_box_bar_bg.name = "MusicBoxChargeBar"
	_music_box_bar_bg.color = Color(1.0, 1.0, 1.0, 0.12)
	_music_box_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_music_box_bar_bg.z_index = 24
	root_ctrl.add_child(_music_box_bar_bg)

	_music_box_bar_fill = ColorRect.new()
	_music_box_bar_fill.name = "MusicBoxChargeFill"
	_music_box_bar_fill.color = Color.WHITE
	_music_box_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_music_box_bar_bg.add_child(_music_box_bar_fill)

	_music_box_wind_button = Button.new()
	_music_box_wind_button.name = "BtnWindMusicBox"
	_music_box_wind_button.text = "WIND MUSIC BOX"
	_music_box_wind_button.custom_minimum_size = Vector2(240.0, 48.0)
	_music_box_wind_button.z_index = 24
	_music_box_wind_button.focus_mode = Control.FOCUS_NONE
	_music_box_wind_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_music_box_wind_button.add_theme_stylebox_override("normal", _make_style(BTN_NORMAL))
	_music_box_wind_button.add_theme_stylebox_override("hover", _make_style(BTN_HOVER))
	_music_box_wind_button.add_theme_stylebox_override("pressed", _make_style(BTN_PRESSED))
	_music_box_wind_button.add_theme_stylebox_override("hover_pressed", _make_style(BTN_PRESSED))
	_music_box_wind_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_music_box_wind_button.add_theme_font_override("font", _build_exit_wide_font())
	_music_box_wind_button.add_theme_font_size_override("font_size", 16)
	_music_box_wind_button.add_theme_color_override("font_color", Color.WHITE)
	_music_box_wind_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_music_box_wind_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	root_ctrl.add_child(_music_box_wind_button)

	_music_box_caution = TextureRect.new()
	_music_box_caution.name = "MusicBoxCaution"
	_music_box_caution.texture = MUSIC_BOX_CAUTION_TEXTURE
	_music_box_caution.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_music_box_caution.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_music_box_caution.custom_minimum_size = Vector2(56.0, 56.0)
	_music_box_caution.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_music_box_caution.pivot_offset = Vector2(28.0, 28.0)
	_music_box_caution.z_index = 25
	_music_box_caution.visible = true
	_music_box_caution.modulate = Color(1.0, 1.0, 1.0, 0.0)
	root_ctrl.add_child(_music_box_caution)

	_music_box_caution_late = TextureRect.new()
	_music_box_caution_late.name = "MusicBoxCautionLate"
	_music_box_caution_late.texture = MUSIC_BOX_CAUTION_TEXTURE
	_music_box_caution_late.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_music_box_caution_late.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_music_box_caution_late.custom_minimum_size = Vector2(120.0, 120.0)
	_music_box_caution_late.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_music_box_caution_late.pivot_offset = Vector2(60.0, 60.0)
	_music_box_caution_late.z_index = 25
	_music_box_caution_late.visible = true
	_music_box_caution_late.modulate = Color(1.0, 1.0, 1.0, 0.0)
	root_ctrl.add_child(_music_box_caution_late)
	_layout_music_box_controls()
	_update_music_box_controls()
	set_music_box_charge(_music_box_charge)


func _layout_music_box_controls() -> void:
	if not _music_box_wind_button or not is_instance_valid(_music_box_wind_button):
		return
	_music_box_wind_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	_music_box_wind_button.offset_left = 24.0
	_music_box_wind_button.offset_right = 264.0
	_music_box_wind_button.offset_bottom = -58.0
	_music_box_wind_button.offset_top = -106.0
	if _music_box_bar_bg and is_instance_valid(_music_box_bar_bg):
		_music_box_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_music_box_bar_bg.offset_left = 0.0
		_music_box_bar_bg.offset_right = 0.0
		_music_box_bar_bg.offset_top = -6.0
		_music_box_bar_bg.offset_bottom = 0.0
		_music_box_bar_fill.position.y = 0.0
		_music_box_bar_fill.size.y = _music_box_bar_bg.size.y
	_layout_caution_icon(_music_box_caution, 56.0, caution_81_bpm_anchor, caution_81_bpm_offset)
	_layout_caution_icon(_music_box_caution_late, 120.0, caution_70_bpm_anchor, caution_70_bpm_offset)


func _layout_caution_icon(icon: TextureRect, icon_size: float, anchor: Vector2, offset: Vector2) -> void:
	if not icon or not is_instance_valid(icon):
		return
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.pivot_offset = Vector2(icon_size * 0.5, icon_size * 0.5)
	icon.anchor_left = anchor.x
	icon.anchor_right = anchor.x
	icon.anchor_top = anchor.y
	icon.anchor_bottom = anchor.y
	icon.offset_left = offset.x
	icon.offset_right = offset.x + icon_size
	icon.offset_top = offset.y
	icon.offset_bottom = offset.y + icon_size


func _update_music_box_controls() -> void:
	if not _music_box_wind_button or not is_instance_valid(_music_box_wind_button):
		return
	var should_show := _music_box_enabled and _state == State.ACTIVE and not _switching_cam and _current_cam == 10
	_music_box_wind_button.visible = should_show and not _music_box_late_active
	_music_box_bar_bg.visible = should_show and not _music_box_late_active
	if not should_show or _music_box_late_active:
		_music_box_winding = false
	_update_music_box_warning()
	set_music_box_charge(_music_box_charge)


func _update_music_box_warning() -> void:
	if not _music_box_caution or not is_instance_valid(_music_box_caution) or not _music_box_caution_late or not is_instance_valid(_music_box_caution_late):
		return
	var camera_visible := _state == State.ACTIVE
	var warning_active := _music_box_enabled and _music_box_charge > 0.0 and _music_box_charge <= 0.33
	var should_show := camera_visible and _current_cam == 10 and not _music_box_late_active and warning_active
	_music_box_caution.visible = true
	if should_show != _music_box_warning_target:
		_music_box_warning_target = should_show
		if _music_box_warning_tween and _music_box_warning_tween.is_valid():
			_music_box_warning_tween.kill()
		_music_box_warning_tween = create_tween()
		_music_box_warning_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_music_box_warning_tween.tween_property(_music_box_caution, "modulate:a", 1.0 if should_show else 0.0, 0.22)
	var should_show_late := camera_visible and (_music_box_late_active or (warning_active and _current_cam != 10))
	_music_box_caution_late.visible = true
	if should_show_late != _music_box_warning_late_target:
		_music_box_warning_late_target = should_show_late
		if _music_box_warning_late_tween and _music_box_warning_late_tween.is_valid():
			_music_box_warning_late_tween.kill()
		_music_box_warning_late_tween = create_tween()
		_music_box_warning_late_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_music_box_warning_late_tween.tween_property(_music_box_caution_late, "modulate:a", 1.0 if should_show_late else 0.0, 0.22)


func _process_music_box_warning(delta: float) -> void:
	var late_icon_visible := _music_box_caution_late and _music_box_caution_late.modulate.a > 0.01
	var animated_icon := _music_box_caution_late if late_icon_visible else _music_box_caution
	if not animated_icon or animated_icon.modulate.a <= 0.0 or (not _music_box_late_active and (_music_box_charge > 0.33 or _music_box_charge <= 0.0)):
		return
	_music_box_beat_left -= delta
	if _music_box_beat_left > 0.0:
		return
	_music_box_beat_left = 60.0 / (70.0 if _music_box_late_active else maxf(music_box_bpm, 1.0))
	_music_box_beat_sign *= -1.0
	if _music_box_caution_tween and _music_box_caution_tween.is_valid():
		_music_box_caution_tween.kill()
	animated_icon.rotation = 0.0
	animated_icon.scale = Vector2.ONE
	var caution_alpha := animated_icon.modulate.a
	animated_icon.modulate = Color(1.0, 1.0, 1.0, caution_alpha) if _music_box_beat_sign > 0.0 else Color(1.0, 0.12, 0.12, caution_alpha)
	_music_box_caution_tween = create_tween()
	_music_box_caution_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_music_box_caution_tween.tween_property(animated_icon, "rotation", _music_box_beat_sign * 0.18, 0.08)
	var beat_scale := 1.6 if _music_box_late_active else 1.2
	_music_box_caution_tween.parallel().tween_property(animated_icon, "scale", Vector2(beat_scale, beat_scale), 0.08)
	_music_box_caution_tween.tween_property(animated_icon, "rotation", 0.0, 0.16)
	_music_box_caution_tween.parallel().tween_property(animated_icon, "scale", Vector2.ONE, 0.16)


func _update_music_box_winding_from_mouse() -> void:
	var can_wind := (
		_music_box_enabled
		and not _music_box_late_active
		and _state == State.ACTIVE
		and not _switching_cam
		and _current_cam == 10
		and _music_box_wind_button != null
		and is_instance_valid(_music_box_wind_button)
		and _music_box_wind_button.visible
		and not _music_box_wind_button.disabled
	)
	_music_box_winding = (
		can_wind
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and _music_box_wind_button.get_global_rect().has_point(_music_box_wind_button.get_global_mouse_position())
	)


func is_open() -> bool:
	return _state != State.IDLE


## Jumpscare sırasında monitör görüntüsünü geçiş animasyonu olmadan kapatır.
func interrupt_for_jumpscare() -> void:
	_jumpscare_interrupted = true
	_state = State.IDLE
	_switching_cam = false
	_music_box_winding = false
	visible = false
	cam_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_set_cursor(false)
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.set_in_use(false)


## Kamera sistemini mümkün olan en kısa sürede kapatır
func force_close() -> void:
	if _state == State.ACTIVE:
		_switching_cam = false
		_close_ui()
	elif _state == State.ZOOMING_IN or _state == State.OPENING:
		_close_requested = true


func _ensure_play_sound_button() -> void:
	if _btn_play_sound and is_instance_valid(_btn_play_sound):
		_ensure_audio_wave_effect()
		return
	_btn_play_sound = Button.new()
	_btn_play_sound.name = "BtnPlaySound"
	_btn_play_sound.text = play_sound_translation_key
	_btn_play_sound.custom_minimum_size = play_sound_button_size
	_btn_play_sound.focus_mode = Control.FOCUS_NONE
	_btn_play_sound.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var pressed_style := _make_style(BTN_PRESSED)
	_btn_play_sound.add_theme_stylebox_override("normal", _make_style(BTN_NORMAL))
	_btn_play_sound.add_theme_stylebox_override("hover", _make_style(BTN_HOVER))
	_btn_play_sound.add_theme_stylebox_override("pressed", pressed_style)
	_btn_play_sound.add_theme_stylebox_override("hover_pressed", pressed_style)
	_btn_play_sound.add_theme_stylebox_override("disabled", _make_style(BTN_PRESSED))
	_btn_play_sound.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	_btn_play_sound.add_theme_font_override("font", _build_exit_wide_font())
	_btn_play_sound.add_theme_font_size_override("font_size", 20)
	_btn_play_sound.add_theme_constant_override("spacing_glyph", 3)
	_btn_play_sound.add_theme_color_override("font_shadow_color", Color.BLACK)
	_btn_play_sound.add_theme_constant_override("shadow_offset_x", 1)
	_btn_play_sound.add_theme_constant_override("shadow_offset_y", 1)
	_btn_play_sound.add_theme_color_override("font_outline_color", Color.BLACK)
	_btn_play_sound.add_theme_constant_override("outline_size", 1)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_btn_play_sound.add_theme_color_override(color_name, Color.WHITE)
	_btn_play_sound.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.45))

	_btn_play_sound.pressed.connect(_on_play_sound_pressed)
	root_ctrl.add_child(_btn_play_sound)
	_ensure_audio_wave_effect()
	_update_play_sound_button()


func _ensure_audio_wave_effect() -> void:
	if _audio_wave_effect and is_instance_valid(_audio_wave_effect):
		return
	_audio_wave_effect = Control.new()
	_audio_wave_effect.name = "AudioWaveEffect"
	_audio_wave_effect.set_script(AUDIO_WAVE_EFFECT_SCRIPT)
	_audio_wave_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_audio_wave_effect.z_index = 20
	root_ctrl.add_child(_audio_wave_effect)
	_audio_wave_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _layout_play_sound_button() -> void:
	if not _btn_play_sound or not is_instance_valid(_btn_play_sound):
		return
	var margin: float = 24.0
	var s: Vector2 = _btn_play_sound.get_combined_minimum_size().max(play_sound_button_size)
	_btn_play_sound.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE)
	_btn_play_sound.offset_left = -s.x * 0.5
	_btn_play_sound.offset_right = s.x * 0.5
	_btn_play_sound.offset_bottom = -margin
	_btn_play_sound.offset_top = -margin - s.y


func _update_play_sound_button() -> void:
	if not _btn_play_sound or not is_instance_valid(_btn_play_sound):
		return
	var cooling: bool = _play_cooldown_left > 0.0
	_btn_play_sound.disabled = cooling
	_btn_play_sound.modulate.a = 0.6 if cooling else 1.0


func _on_play_sound_pressed() -> void:
	if _state != State.ACTIVE or _switching_cam or _play_cooldown_left > 0.0:
		return
	_ensure_audio_wave_effect()
	var wave_origin := _btn_play_sound.position + Vector2(_btn_play_sound.size.x * 0.5, 0.0)
	_audio_wave_effect.call("play_wave", wave_origin)
	_play_cooldown_left = play_sound_cooldown
	_update_play_sound_button()
	lure_requested.emit(_current_cam)


## Canavar yer değiştirirken çağrılır: kameralar açıksa LOST SIGNAL → PENDING gösterir.
## move_callable, ekran tamamen kapalıyken çalıştırılır.
func play_lost_signal(move_callable: Callable, duration_multiplier: float = 1.0) -> void:
	# Kamera değiştirme gibi başka bir geçiş sürüyorsa bitmesini bekle
	while _switching_cam and _state == State.ACTIVE:
		await get_tree().process_frame

	if _state != State.ACTIVE:
		await move_callable.call()
		await get_tree().process_frame
		lost_signal_finished.emit()
		return

	_switching_cam = true
	_lost_signal_active = true
	_set_transition_controls_behind(true)
	_ensure_pending_overlay()
	_pending_label.text = lost_signal_translation_key
	_pending_overlay.visible = true
	_play_audio(_lost_signal_audio)
	await get_tree().process_frame
	# Hareketi LOST SIGNAL altında başlat; Lost Signal ve Pending süreleri
	# hareket süresinden bağımsız olarak diğer oda geçişleriyle aynı kalır.
	move_callable.call()

	var transition_multiplier := maxf(duration_multiplier, 1.0)
	await get_tree().create_timer(lost_signal_time * transition_multiplier).timeout
	if _pending_label and is_instance_valid(_pending_label):
		_pending_label.text = pending_translation_key
	_play_audio(_after_lost_audio)
	await get_tree().create_timer(pending_after_lost_time * transition_multiplier).timeout

	if _state == State.ACTIVE:
		_update_static()
		_randomize_scanlines()
		_render_cam()
	if _pending_overlay and is_instance_valid(_pending_overlay) and _state != State.CLOSING:
		_pending_overlay.visible = false
	_lost_signal_active = false
	_switching_cam = false
	_set_transition_controls_behind(false)
	if _state == State.ACTIVE:
		_update_music_box_controls()
	lost_signal_finished.emit()


func _start_monitor_glow() -> void:
	if not _monitor_glow_audio or not is_instance_valid(_monitor_glow_audio):
		return
	_monitor_glow_audio.volume_db = -80.0
	if not _monitor_glow_audio.playing:
		_monitor_glow_audio.play()


func _on_monitor_hover_changed(is_hovering: bool) -> void:
	if not _monitor_glow_audio or not is_instance_valid(_monitor_glow_audio):
		return
	if _monitor_glow_tween and _monitor_glow_tween.is_valid():
		_monitor_glow_tween.kill()
	if not _monitor_glow_audio.playing:
		_monitor_glow_audio.play()
	_monitor_glow_tween = create_tween()
	_monitor_glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var target_db := monitor_glow_max_volume_db if is_hovering else -80.0
	var fade_time := monitor_glow_fade_in_time if is_hovering else monitor_glow_fade_out_time
	_monitor_glow_tween.tween_property(_monitor_glow_audio, "volume_db", target_db, fade_time)


func _play_audio(player: AudioStreamPlayer3D) -> void:
	if not player or not is_instance_valid(player) or player.stream == null:
		return
	player.stop()
	player.play()


func _play_monitor_open_audio() -> void:
	if not _monitor_open_audio or not is_instance_valid(_monitor_open_audio) or _monitor_open_audio.stream == null:
		return
	if _monitor_open_fade_tween and _monitor_open_fade_tween.is_valid():
		_monitor_open_fade_tween.kill()
	_monitor_open_audio.stop()
	_monitor_open_audio.volume_db = monitor_open_volume_db
	_monitor_open_audio.play()
	_monitor_open_fade_tween = create_tween()
	_monitor_open_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_monitor_open_fade_tween.tween_interval(0.6)
	_monitor_open_fade_tween.tween_property(_monitor_open_audio, "volume_db", -80.0, 2.0)

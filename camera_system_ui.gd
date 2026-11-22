extends CanvasLayer

enum State { IDLE, ZOOMING_IN, OPENING, ACTIVE, CLOSING, ZOOMING_OUT }

const CURSOR_ARROW = preload("res://png/cursor_arrow.png")
const CURSOR_HAND = preload("res://png/cursor_hand.png")
const BTN_NORMAL = preload("res://png/btn_normal.png")
const BTN_HOVER = preload("res://png/btn_hover.png")
const BTN_PRESSED = preload("res://png/btn_pressed.png")
const CAMERA_MAP_TEX: Texture2D = preload("res://png/camera_map.png")
const CAM_COUNT: int = 13
const STATIC_DIR_CANDIDATES: PackedStringArray = [
	"res://textures",
	"res://static",
	"res://png",
	"res://"
]

@export_group("Görsel")
## İsteğe bağlı: Windows 95 tarzı .ttf/.otf font dosyası (boşsa sistem fontu kullanılır)
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
@export var you_map_anchor: Vector2 = Vector2(0.45, 0.58)
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

@export_group("Kamera Konumları")
@export var cam1_map_anchor: Vector2 = Vector2(0.26, 0.30)
@export var cam2_map_anchor: Vector2 = Vector2(0.51, 0.07)
@export var cam3_map_anchor: Vector2 = Vector2(0.52, 0.19)
@export var cam4_map_anchor: Vector2 = Vector2(0.41, 0.30)
@export var cam5_map_anchor: Vector2 = Vector2(0.61, 0.34)
@export var cam6_map_anchor: Vector2 = Vector2(0.73, 0.31)
@export var cam7_map_anchor: Vector2 = Vector2(0.11, 0.41)
@export var cam8_map_anchor: Vector2 = Vector2(0.35, 0.48)
@export var cam9_map_anchor: Vector2 = Vector2(0.41, 0.61)
@export var cam10_map_anchor: Vector2 = Vector2(0.34, 0.74)
@export var cam11_map_anchor: Vector2 = Vector2(0.54, 0.78)
@export var cam12_map_anchor: Vector2 = Vector2(0.73, 0.71)
@export var cam13_map_anchor: Vector2 = Vector2(0.86, 0.71)

@export_group("Güvenlik Kamerası")
## Kameranın sağa-sola sallanma açısı (± derece)
@export var sway_deg: float = 8.0
## Bir gidiş-gelişin süresi (saniye)
@export var sway_period: float = 10.0

@export_group("Geçişler")
@export var zoom_time: float = 0.35
@export var open_fade_time: float = 0.35
@export var close_fade_time: float = 0.28
## Yaklaşırken/çıkarken rotasyon yumuşatma hızı
@export var aim_turn_speed: float = 16.0
## Alfa 0 bırakırsan monitör ekranının rengi kullanılır
@export var overlay_color_override: Color = Color(0, 0, 0, 0)

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
var _thin_scanline: Control
var _third_scanline: Control
var _pending_overlay: ColorRect
var _pending_label: Label
var _you_label: Label
var _switching_cam: bool = false
var _state: State = State.IDLE
var _player_cam: PlayerCamera
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


func _ready() -> void:
	visible = false
	cam_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	_load_static_frames_if_empty()

	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	static_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	static_noise.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	static_noise.stretch_mode = TextureRect.STRETCH_TILE
	static_noise.visible = true
	static_noise.modulate = Color(1.0, 1.0, 1.0, static_alpha)

	_ensure_extra_scanlines()
	_ensure_you_label()
	_ensure_pending_overlay()

	snap_timer.wait_time = 1.0
	snap_timer.one_shot = false
	if not snap_timer.timeout.is_connected(_tick):
		snap_timer.timeout.connect(_tick)
	snap_timer.start()

	_force_layout()
	_update_static()

	if _find_world_nodes():
		_clamp_current_cam()
		if not _hitbox.clicked.is_connected(_on_monitor_clicked):
			_hitbox.clicked.connect(_on_monitor_clicked)


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


func _clamp_current_cam() -> void:
	if _cam_points.is_empty():
		_current_cam = 0
		return
	_current_cam = clampi(_current_cam, 0, _cam_points.size() - 1)


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


func _order_overlay_on_top() -> void:
	if not overlay or not is_instance_valid(overlay) or overlay.get_parent() != root_ctrl:
		return
	var below_overlay: Array[Control] = [frame_rect, _you_label, cam_label, btn_exit]
	for b: Button in _cam_buttons:
		if b and is_instance_valid(b):
			below_overlay.append(b)
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
	var hud_nodes: Array[Control] = [frame_rect, _you_label, cam_label, btn_exit]
	for b: Button in _cam_buttons:
		if b and is_instance_valid(b):
			hud_nodes.append(b)
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
	_apply_win95_font()
	_layout_pending_label()
	_refresh_label()
	if auto_layout:
		_layout_ui()
	_setup_map_frame()
	_order_pending_behind_hud()
	_order_overlay_on_top()


func _exit_tree() -> void:
	_set_cursor(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _state == State.ACTIVE and not _switching_cam:
		_on_exit_pressed()


# ---------- Kurulum ----------

func _find_world_nodes() -> bool:
	var tree_root := get_tree().root
	_player_cam = tree_root.find_child("Camera3D", true, false) as PlayerCamera
	_hitbox = tree_root.find_child("MonitorHitbox", true, false) as GlowHitbox
	_zoom_view = tree_root.find_child("MonitorZoomView", true, false) as Camera3D
	_cam_points.clear()
	for i in range(1, CAM_COUNT + 1):
		var cam_name: String = "SecCam%d" % i
		var c := tree_root.find_child(cam_name, true, false) as Camera3D
		if c:
			_cam_points.append(c)

	if not _player_cam or not _hitbox or not _zoom_view or _cam_points.is_empty():
		push_error("Kamera sistemi: gerekli düğümler bulunamadı (Camera3D, MonitorHitbox, MonitorZoomView, SecCam1..SecCam%d)." % CAM_COUNT)
		return false
	return true


func _build_win95_font() -> Font:
	if win95_font:
		return win95_font
	var sys_font := SystemFont.new()
	sys_font.font_names = PackedStringArray(["MS Sans Serif", "Fixedsys", "Terminal", "Courier New", "Arial"])
	sys_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	sys_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return sys_font


func _apply_win95_font() -> void:
	var f := _build_win95_font()
	cam_label.add_theme_font_override("font", f)
	cam_label.add_theme_font_size_override("font_size", 36)
	cam_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	cam_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	cam_label.add_theme_constant_override("shadow_offset_x", 1)
	cam_label.add_theme_constant_override("shadow_offset_y", 1)

	if _you_label and is_instance_valid(_you_label):
		_you_label.text = you_translation_key
		_you_label.add_theme_font_override("font", f)
		_you_label.add_theme_font_size_override("font_size", 18)
		_you_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		_you_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
		_you_label.add_theme_constant_override("shadow_offset_x", 1)
		_you_label.add_theme_constant_override("shadow_offset_y", 1)

	for b: Button in _cam_buttons:
		b.add_theme_font_override("font", f)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))
		b.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.0, 1.0))
		b.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.0, 1.0))
		b.add_theme_color_override("font_hover_pressed_color", Color(0.0, 0.0, 0.0, 1.0))

	var exit_red := Color(0.482, 0.122, 0.122, 1.0)
	btn_exit.add_theme_font_override("font", f)
	btn_exit.add_theme_font_size_override("font_size", 24)
	btn_exit.add_theme_color_override("font_color", exit_red)
	btn_exit.add_theme_color_override("font_hover_color", exit_red)
	btn_exit.add_theme_color_override("font_pressed_color", exit_red)
	btn_exit.add_theme_color_override("font_hover_pressed_color", exit_red)

	if _pending_label and is_instance_valid(_pending_label):
		_pending_label.text = pending_translation_key
		_pending_label.add_theme_font_override("font", f)
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
		b.text = "C%d" % (i + 1)
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

	var all_btns: Array[Button] = []
	all_btns.append_array(_cam_buttons)
	all_btns.append(btn_exit)

	for b: Button in all_btns:
		var pressed_style := _make_style(BTN_PRESSED)
		b.add_theme_stylebox_override("normal", _make_style(BTN_NORMAL))
		b.add_theme_stylebox_override("hover", _make_style(BTN_HOVER))
		b.add_theme_stylebox_override("pressed", pressed_style)
		b.add_theme_stylebox_override("hover_pressed", pressed_style)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	btn_exit.pressed.connect(_on_exit_pressed)


func _make_style(tex: Texture2D) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = button_margin
	sb.texture_margin_right = button_margin
	sb.texture_margin_top = button_margin
	sb.texture_margin_bottom = button_margin
	return sb


func _layout_ui() -> void:
	var margin: float = 24.0

	cam_label.visible = true
	cam_label.add_theme_font_size_override("font_size", 36)
	cam_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	var lbl_size: Vector2 = cam_label.get_combined_minimum_size()
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

	_layout_pending_label()

	var exit_size: Vector2 = btn_exit.get_combined_minimum_size()
	btn_exit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	btn_exit.offset_right = -margin
	btn_exit.offset_left = -margin - exit_size.x
	btn_exit.offset_bottom = -margin
	btn_exit.offset_top = -margin - exit_size.y


# ---------- Açılış ----------

func _on_monitor_clicked() -> void:
	if _state != State.IDLE:
		return
	_base_cam_quat = _player_cam.global_transform.basis.get_rotation_quaternion().normalized()
	_state = State.ZOOMING_IN
	_hitbox.set_in_use(true)
	_player_cam.zoom_to(_zoom_view.global_transform, _zoom_view.fov, zoom_time)
	await _player_cam.zoom_finished
	await _open_ui()


func _open_ui() -> void:
	_state = State.OPENING
	_ensure_pending_overlay()
	_pending_overlay.visible = true
	overlay.color = _get_overlay_color()
	overlay.modulate.a = 1.0
	visible = true
	await get_tree().process_frame

	_clamp_current_cam()
	_sync_buttons()
	_refresh_label()
	_update_static()
	_randomize_scanlines()
	_render_cam()
	await RenderingServer.frame_post_draw

	_set_cursor(true)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(overlay, "modulate:a", 0.0, open_fade_time)
	await tw.finished

	await get_tree().create_timer(0.25).timeout
	if _pending_overlay and is_instance_valid(_pending_overlay):
		_pending_overlay.visible = false

	_state = State.ACTIVE


# ---------- Kapanış ----------

func _on_exit_pressed() -> void:
	if _state != State.ACTIVE or _switching_cam:
		return
	_close_ui()


func _close_ui() -> void:
	_state = State.CLOSING
	if _pending_overlay and is_instance_valid(_pending_overlay):
		_pending_overlay.visible = false
	overlay.color = _get_overlay_color()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(overlay, "modulate:a", 1.0, close_fade_time)
	await tw.finished

	visible = false
	_set_cursor(false)
	cam_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_force_layout()

	_state = State.ZOOMING_OUT
	_player_cam.return_to_base(zoom_time)
	await _player_cam.return_finished

	_hitbox.set_in_use(false)
	_state = State.IDLE


# ---------- Saniyede bir çalışan kısım (1 FPS) ----------

func _tick() -> void:
	_update_static()
	if not visible and _state != State.ACTIVE:
		return
	_step_scanline()
	_render_cam()


func _render_cam() -> void:
	if _cam_points.is_empty():
		return
	_clamp_current_cam()
	var point := _cam_points[_current_cam]
	var t: float = Time.get_ticks_msec() / 1000.0
	var angle: float = sin(t * TAU / sway_period) * deg_to_rad(sway_deg)
	var xf := point.global_transform
	cam_camera.global_transform = Transform3D(xf.basis * Basis(Vector3.UP, angle), xf.origin)
	cam_camera.fov = point.fov
	cam_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


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
		_third_scanline.position.y = _third_scanline.position.y if false else _third_scan_y


# ---------- Kamera seçimi ----------

func _select_cam(index: int) -> void:
	if _state != State.ACTIVE or index == _current_cam or _switching_cam:
		return
	_switching_cam = true
	_current_cam = index
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


func _sync_buttons() -> void:
	for i in range(_cam_buttons.size()):
		_cam_buttons[i].set_pressed_no_signal(i == _current_cam)


func _refresh_label() -> void:
	cam_label.text = "CAM %d" % (_current_cam + 1)
	cam_label.visible = true


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

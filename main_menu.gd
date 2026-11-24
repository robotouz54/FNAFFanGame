extends Control

const GAME_SCENE := "res://main.tscn"

const FLAG_EN = preload("res://png/flag_en.png")
const FLAG_TR = preload("res://png/flag_tr.png")
const BTN_NORMAL = preload("res://png/btn_normal.png")
const BTN_HOVER = preload("res://png/btn_hover.png")
const BTN_PRESSED = preload("res://png/btn_pressed.png")

@export_group("Yazı")
## Boş bırakırsan Godot'un varsayılan fontu kullanılır
@export var custom_font: Font
@export var title_size: int = 112
@export var button_size: int = 32
@export var loading_size: int = 40
@export var percent_size: int = 28

@export_group("Butonlar")
@export var button_min_size: Vector2 = Vector2(200, 64)
@export var button_margin: int = 6
@export var flag_size: Vector2 = Vector2(72, 48)

@export_group("Yükleme")
## Çubuğun kalınlığı (piksel)
@export var bar_thickness: float = 6.0
## Çubuğun boş kısmının rengi, alfayı 0 yaparsan görünmez olur
@export var bar_track_color: Color = Color(1, 1, 1, 0.12)
## Yüzde yazısının sağ kenara uzaklığı
@export var percent_margin: float = 24.0
## Yüzde yazısı ile çubuk arasındaki boşluk
@export var percent_gap: float = 10.0
## Ortadaki "LOADING" yazısı görünsün mü
@export var show_loading_title: bool = true
## Çubuğun saniyede en fazla kaç yüzde ilerleyeceği (ani sıçramaları yumuşatır)
@export var bar_speed: float = 120.0
## %100'e ulaştıktan sonra oyuna geçmeden önceki bekleme (saniye)
@export var finish_delay: float = 0.3

@onready var background: ColorRect = $Background
@onready var menu_page: Control = $MenuPage
@onready var menu_vbox: BoxContainer = $MenuPage/VBox
@onready var title_label: Label = $MenuPage/VBox/TitleLabel
@onready var buttons_row: BoxContainer = $MenuPage/VBox/Buttons
@onready var btn_no: Button = $MenuPage/VBox/Buttons/BtnNo
@onready var btn_yes: Button = $MenuPage/VBox/Buttons/BtnYes
@onready var loading_page: Control = $LoadingPage
@onready var loading_vbox: BoxContainer = $LoadingPage/VBox
@onready var loading_label: Label = $LoadingPage/VBox/LoadingLabel
@onready var load_progress: ProgressBar = $LoadingPage/VBox/LoadProgress
@onready var percent_label: Label = $LoadingPage/VBox/PercentLabel
@onready var lang_button: TextureButton = $LangButton
@onready var hover_audio: AudioStreamPlayer2D = $SFX/Hover
@onready var click_audio: AudioStreamPlayer2D = $SFX/Click

var _lang: String = "en"
var _loading: bool = false
var _load_done: bool = false
var _shown: float = 0.0
var _last_pct: int = -1
var _progress: Array = []
var _flag_en_tex: Texture2D
var _flag_tr_tex: Texture2D


func _ready() -> void:
	# Yerleşimi koddan garantiye al
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for c: Control in [background, menu_page, loading_page]:
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = Color.BLACK

	menu_page.visible = true

	# Metinler çeviri anahtarı olarak girilir, Godot seçili dile göre çevirir
	title_label.text = "MENU_READY"
	btn_yes.text = "MENU_YES"
	btn_no.text = "MENU_NO"
	loading_label.text = "LOADING"
	loading_label.visible = show_loading_title

	_ensure_translations()
	_flag_en_tex = _trim_transparent(FLAG_EN)
	_flag_tr_tex = _trim_transparent(FLAG_TR)

	_style_labels()
	_style_buttons()
	_style_progress_bar()
	_style_flag()
	_layout_loading_bar()
	_set_loading_visible(false)

	menu_vbox.add_theme_constant_override("separation", 56)
	buttons_row.add_theme_constant_override("separation", 56)
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	loading_vbox.add_theme_constant_override("separation", 24)

	# Oyun her açılışta İngilizce başlar
	_lang = "en"
	TranslationServer.set_locale(_lang)
	_update_flag()
	_update_percent_label()

	btn_yes.pressed.connect(_play_click_audio)
	btn_yes.pressed.connect(_on_yes_pressed)
	btn_no.pressed.connect(_on_no_pressed)
	lang_button.pressed.connect(_play_click_audio)
	lang_button.pressed.connect(_toggle_language)
	for button: Button in [btn_yes, btn_no]:
		button.mouse_entered.connect(_play_hover_audio)
	lang_button.mouse_entered.connect(_play_hover_audio)

	set_process(false)


## Android'de dokunmayı doğrudan görünür kontrol alanına eşler.
## Normal fare/klavye GUI akışını değiştirmez.
func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	if menu_page.visible:
		if _screen_touch_hits(btn_yes, touch.position):
			_play_click_audio()
			_on_yes_pressed()
			get_viewport().set_input_as_handled()
		elif _screen_touch_hits(btn_no, touch.position):
			_on_no_pressed()
			get_viewport().set_input_as_handled()
		elif lang_button.visible and _screen_touch_hits(lang_button, touch.position):
			_play_click_audio()
			_toggle_language()
			get_viewport().set_input_as_handled()


func _screen_touch_hits(control: Control, viewport_position: Vector2) -> bool:
	if not control or not is_instance_valid(control) or not control.is_visible_in_tree() or control.size == Vector2.ZERO:
		return false
	var local_position := control.get_global_transform_with_canvas().affine_inverse() * viewport_position
	return Rect2(Vector2.ZERO, control.size).has_point(local_position)


# ---------- Çeviri ve görsel hazırlığı ----------

## Proje ayarlarına eklenmemişse çeviri dosyalarını koddan yükler
func _ensure_translations() -> void:
	if TranslationServer.get_loaded_locales().size() > 0:
		return
	for path in ["res://translations/texts.en.translation", "res://translations/texts.tr.translation"]:
		var t := load(path) as Translation
		if t:
			TranslationServer.add_translation(t)
		else:
			push_error("Çeviri dosyası yüklenemedi: " + path)


## Görselin çevresindeki şeffaf boşluğu kırpar
func _trim_transparent(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(used)
	return atlas


# ---------- Görünüm ----------

func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if custom_font:
		label.add_theme_font_override("font", custom_font)


func _style_labels() -> void:
	_style_label(title_label, title_size)
	_style_label(loading_label, loading_size)
	_style_label(percent_label, percent_size)


func _style_buttons() -> void:
	for b: Button in [btn_yes, btn_no]:
		var pressed_style := _make_style(BTN_PRESSED)
		b.add_theme_stylebox_override("normal", _make_style(BTN_NORMAL))
		b.add_theme_stylebox_override("hover", _make_style(BTN_HOVER))
		b.add_theme_stylebox_override("pressed", pressed_style)
		b.add_theme_stylebox_override("hover_pressed", pressed_style)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_font_size_override("font_size", button_size)
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(color_name, Color.WHITE)
		if custom_font:
			b.add_theme_font_override("font", custom_font)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = button_min_size


func _make_style(tex: Texture2D) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = button_margin
	sb.texture_margin_right = button_margin
	sb.texture_margin_top = button_margin
	sb.texture_margin_bottom = button_margin
	return sb


func _style_progress_bar() -> void:
	load_progress.show_percentage = false
	load_progress.min_value = 0.0
	load_progress.max_value = 100.0
	load_progress.value = 0.0
	load_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Çerçevesiz, ince beyaz çubuk
	var bg := StyleBoxFlat.new()
	bg.bg_color = bar_track_color
	bg.set_content_margin_all(0.0)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE
	fill.set_content_margin_all(0.0)

	load_progress.add_theme_stylebox_override("background", bg)
	load_progress.add_theme_stylebox_override("fill", fill)


## Çubuğu ve yüzdeyi VBox'tan çıkarıp ekranın altına bağlar
func _layout_loading_bar() -> void:
	load_progress.reparent(self, false)
	percent_label.reparent(self, false)

	# Çubuk: ekranın en altında, tam genişlikte
	load_progress.custom_minimum_size = Vector2(0.0, bar_thickness)
	load_progress.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 0)

	# Yüzde: çubuğun sağ üstünde
	percent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	percent_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	percent_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	percent_label.offset_right = -percent_margin
	percent_label.offset_bottom = -(bar_thickness + percent_gap)
	percent_label.offset_left = percent_label.offset_right
	percent_label.offset_top = percent_label.offset_bottom


func _set_loading_visible(on: bool) -> void:
	loading_page.visible = on
	load_progress.visible = on
	percent_label.visible = on


func _style_flag() -> void:
	lang_button.ignore_texture_size = true
	lang_button.stretch_mode = TextureButton.STRETCH_SCALE
	lang_button.custom_minimum_size = flag_size
	lang_button.focus_mode = Control.FOCUS_NONE
	lang_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Sağ üst köşede sabit boyutlu kutu
	lang_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lang_button.offset_right = -24.0
	lang_button.offset_left = -24.0 - flag_size.x
	lang_button.offset_top = 24.0
	lang_button.offset_bottom = 24.0 + flag_size.y

	lang_button.modulate = Color(0.85, 0.85, 0.85)
	lang_button.mouse_entered.connect(func() -> void: lang_button.modulate = Color.WHITE)
	lang_button.mouse_exited.connect(func() -> void: lang_button.modulate = Color(0.85, 0.85, 0.85))


# ---------- Dil ----------

func _toggle_language() -> void:
	_lang = "tr" if _lang == "en" else "en"
	TranslationServer.set_locale(_lang)
	_update_flag()
	_last_pct = -1
	_update_percent_label()


func _update_flag() -> void:
	lang_button.texture_normal = _flag_tr_tex if _lang == "tr" else _flag_en_tex


func _percent_text(value: int) -> String:
	var fmt := tr("LOADING_PERCENT")
	if fmt.contains("%d"):
		return fmt % value
	return "%d%%" % value  # çeviri yoksa güvenli yedek


func _update_percent_label() -> void:
	var pct := int(_shown)
	if pct == _last_pct:
		return
	_last_pct = pct
	percent_label.text = _percent_text(pct)


# ---------- Butonlar ----------

func _on_no_pressed() -> void:
	_play_click_audio()
	await click_audio.finished
	get_tree().quit()


func _play_hover_audio() -> void:
	_play_ui_audio(hover_audio)


func _play_click_audio() -> void:
	_play_ui_audio(click_audio)


func _play_ui_audio(player: AudioStreamPlayer2D) -> void:
	if player.stream == null:
		return
	player.stop()
	player.play()


func _on_yes_pressed() -> void:
	if _loading:
		return
	_loading = true
	_load_done = false
	_shown = 0.0
	_last_pct = -1
	load_progress.value = 0.0
	_update_percent_label()

	menu_page.visible = false
	lang_button.visible = false
	_set_loading_visible(true)

	var err := ResourceLoader.load_threaded_request(GAME_SCENE, "", true)
	if err != OK:
		push_warning("Arka plan yüklemesi başlatılamadı; doğrudan yükleme deneniyor: " + GAME_SCENE)
		set_process(false)
		call_deferred("_fallback_load_game_scene")
		return
	set_process(true)


func _cancel_loading() -> void:
	_loading = false
	set_process(false)
	_set_loading_visible(false)
	menu_page.visible = true
	lang_button.visible = true


# ---------- Gerçek yükleme ----------

func _process(delta: float) -> void:
	var target := 100.0

	if not _load_done:
		var status := ResourceLoader.load_threaded_get_status(GAME_SCENE, _progress)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				target = float(_progress[0]) * 100.0
			ResourceLoader.THREAD_LOAD_LOADED:
				_load_done = true
			_:
				push_warning("Arka plan yüklemesi başarısız; doğrudan yükleme deneniyor: " + GAME_SCENE)
				set_process(false)
				call_deferred("_fallback_load_game_scene")
				return

	# Çubuk gerçek ilerlemeyi takip eder, sadece sıçramaları yumuşatır
	_shown = move_toward(_shown, target, bar_speed * delta)
	load_progress.value = _shown
	_update_percent_label()

	if _load_done and _shown >= 100.0:
		set_process(false)
		_finish()


func _finish() -> void:
	await get_tree().create_timer(finish_delay).timeout
	var packed := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	if packed == null:
		push_warning("Arka plan yüklemesi sahneyi vermedi; doğrudan yükleme deneniyor: " + GAME_SCENE)
		_fallback_load_game_scene()
		return
	get_tree().change_scene_to_packed(packed)


func _fallback_load_game_scene() -> void:
	var packed := load(GAME_SCENE) as PackedScene
	if packed:
		get_tree().change_scene_to_packed(packed)
		return
	push_error("Oyun sahnesi yüklenemedi: " + GAME_SCENE)
	_cancel_loading()

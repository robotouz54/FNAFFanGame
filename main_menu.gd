extends Control

const GAME_SCENE := "res://main.tscn"

const FLAG_EN = preload("res://png/flag_en.png")
const FLAG_TR = preload("res://png/flag_tr.png")
const BTN_NORMAL = preload("res://png/btn_normal.png")
const BTN_HOVER = preload("res://png/btn_hover.png")
const BTN_PRESSED = preload("res://png/btn_pressed.png")

@export_group("Yazı")
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
@export var bar_thickness: float = 6.0
@export var bar_track_color: Color = Color(1, 1, 1, 0.12)
@export var percent_margin: float = 24.0
@export var percent_gap: float = 10.0
@export var show_loading_title: bool = true
@export var bar_speed: float = 120.0
@export var finish_delay: float = 0.3

@onready var background: ColorRect = $Background
@onready var menu_page: Control = $MenuPage
@onready var menu_vbox: BoxContainer = $MenuPage/VBox
@onready var title_label: Label = $MenuPage/VBox/TitleLabel
@onready var buttons_row: BoxContainer = $MenuPage/VBox/Buttons
@onready var btn_no: Button = $MenuPage/VBox/Buttons/BtnNo
@onready var btn_yes: Button = $MenuPage/VBox/Buttons/BtnYes
@onready var settings_button: Button = $MenuPage/VBox/SettingsButton
@onready var settings_page: ColorRect = $SettingsPage
@onready var quality_option: OptionButton = $SettingsPage/ContentCenter/SettingsContent/QualityRow/QualityOption
@onready var fps_option: OptionButton = $SettingsPage/ContentCenter/SettingsContent/FpsRow/FpsOption
@onready var motion_blur_check: CheckButton = $SettingsPage/ContentCenter/SettingsContent/MotionBlurCheck
@onready var shadows_check: CheckButton = $SettingsPage/ContentCenter/SettingsContent/ShadowsCheck
@onready var close_settings_button: Button = $SettingsPage/CloseSettingsButton
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
var _last_lang_toggle_msec: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for c: Control in [background, menu_page, loading_page]:
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = Color.BLACK

	menu_page.visible = true

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
	_setup_settings_controls()
	_style_settings_controls()
	_style_progress_bar()
	_style_flag()
	_layout_loading_bar()
	_set_loading_visible(false)

	menu_vbox.add_theme_constant_override("separation", 56)
	buttons_row.add_theme_constant_override("separation", 56)
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	loading_vbox.add_theme_constant_override("separation", 24)

	_lang = "en"
	TranslationServer.set_locale(_lang)
	_update_flag()
	_update_percent_label()

	btn_yes.pressed.connect(_on_yes_pressed)
	btn_no.pressed.connect(_on_no_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	close_settings_button.pressed.connect(_on_settings_close_pressed)
	quality_option.item_selected.connect(_on_quality_selected)
	fps_option.item_selected.connect(_on_fps_selected)
	motion_blur_check.toggled.connect(GameSettings.set_motion_blur_enabled)
	shadows_check.toggled.connect(GameSettings.set_shadows_enabled)
	lang_button.pressed.connect(_on_lang_button_pressed)

	if not OS.has_feature("mobile") and not OS.has_feature("android"):
		for button: Button in [btn_yes, btn_no, settings_button, close_settings_button]:
			button.mouse_entered.connect(_play_hover_audio)
		lang_button.mouse_entered.connect(_play_hover_audio)

	set_process(false)


func _ensure_translations() -> void:
	if TranslationServer.get_loaded_locales().size() > 0:
		return
	for path in ["res://translations/texts.en.translation", "res://translations/texts.tr.translation"]:
		var t := load(path) as Translation
		if t:
			TranslationServer.add_translation(t)
		else:
			push_error("Çeviri dosyası yüklenemedi: " + path)


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
	for b: Button in [btn_yes, btn_no, settings_button]:
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
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = button_min_size


func _setup_settings_controls() -> void:
	for option: String in GameSettings.QUALITY_OPTIONS:
		quality_option.add_item(option)
	quality_option.select(GameSettings.QUALITY_OPTIONS.find(GameSettings.quality))

	for fps: int in GameSettings.FPS_OPTIONS:
		fps_option.add_item(str(fps))
	fps_option.select(GameSettings.FPS_OPTIONS.find(GameSettings.max_fps))
	motion_blur_check.button_pressed = GameSettings.motion_blur_enabled
	shadows_check.button_pressed = GameSettings.shadows_enabled


func _style_settings_controls() -> void:
	for label: Label in [
		$SettingsPage/ContentCenter/SettingsContent/QualityRow/QualityLabel,
		$SettingsPage/ContentCenter/SettingsContent/FpsRow/FpsLabel,
	]:
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.WHITE)
		if custom_font:
			label.add_theme_font_override("font", custom_font)

	for option: OptionButton in [quality_option, fps_option]:
		option.focus_mode = Control.FOCUS_NONE
		option.add_theme_font_size_override("font_size", 24)
		option.add_theme_color_override("font_color", Color.WHITE)
		var option_style := StyleBoxFlat.new()
		option_style.bg_color = Color(0.20, 0.20, 0.20)
		option_style.set_content_margin_all(10.0)
		option.add_theme_stylebox_override("normal", option_style)
		option.add_theme_stylebox_override("hover", option_style)
		option.add_theme_stylebox_override("pressed", option_style)
		if custom_font:
			option.add_theme_font_override("font", custom_font)

	for checkbox: CheckButton in [motion_blur_check, shadows_check]:
		checkbox.focus_mode = Control.FOCUS_NONE
		checkbox.add_theme_font_size_override("font_size", 24)
		checkbox.add_theme_color_override("font_color", Color.WHITE)
		if custom_font:
			checkbox.add_theme_font_override("font", custom_font)

	close_settings_button.focus_mode = Control.FOCUS_NONE
	close_settings_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_settings_button.add_theme_font_size_override("font_size", 64)
	close_settings_button.add_theme_color_override("font_color", Color.WHITE)
	if custom_font:
		close_settings_button.add_theme_font_override("font", custom_font)


func _on_settings_button_pressed() -> void:
	_play_click_audio()
	settings_page.visible = true


func _on_settings_close_pressed() -> void:
	_play_click_audio()
	settings_page.visible = false


func _on_quality_selected(index: int) -> void:
	if index >= 0 and index < GameSettings.QUALITY_OPTIONS.size():
		GameSettings.set_quality(GameSettings.QUALITY_OPTIONS[index])


func _on_fps_selected(index: int) -> void:
	if index >= 0 and index < GameSettings.FPS_OPTIONS.size():
		GameSettings.set_max_fps(GameSettings.FPS_OPTIONS[index])


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

	var bg := StyleBoxFlat.new()
	bg.bg_color = bar_track_color
	bg.set_content_margin_all(0.0)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE
	fill.set_content_margin_all(0.0)

	load_progress.add_theme_stylebox_override("background", bg)
	load_progress.add_theme_stylebox_override("fill", fill)


func _layout_loading_bar() -> void:
	load_progress.reparent(self, false)
	percent_label.reparent(self, false)

	load_progress.custom_minimum_size = Vector2(0.0, bar_thickness)
	load_progress.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 0)

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
	lang_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	lang_button.mouse_filter = Control.MOUSE_FILTER_STOP
	lang_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	lang_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lang_button.offset_right = -24.0
	lang_button.offset_left = -24.0 - flag_size.x
	lang_button.offset_top = 24.0
	lang_button.offset_bottom = 24.0 + flag_size.y

	lang_button.modulate = Color(0.85, 0.85, 0.85)
	if not OS.has_feature("mobile") and not OS.has_feature("android"):
		lang_button.mouse_entered.connect(func() -> void: lang_button.modulate = Color.WHITE)
		lang_button.mouse_exited.connect(func() -> void: lang_button.modulate = Color(0.85, 0.85, 0.85))


func _on_lang_button_pressed() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_lang_toggle_msec < 120:
		return
	_last_lang_toggle_msec = now
	_play_click_audio()
	_toggle_language()


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
	return "%d%%" % value


func _update_percent_label() -> void:
	var pct := int(_shown)
	if pct == _last_pct:
		return
	_last_pct = pct
	percent_label.text = _percent_text(pct)


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
	_play_click_audio()
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

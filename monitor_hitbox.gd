class_name GlowHitbox
extends Area3D

## Fare bu hitbox'a sol tıklayınca yayılır
signal clicked
signal hover_changed(is_hovering: bool)

## "ekran" kutusu
@export var screen: CSGPrimitive3D
## Ekranla birlikte yanan ışıklar
@export var lights: Array[Light3D]
@export var fade_in_time: float = 0.45
@export var fade_out_time: float = 0.85
## Ekran kapalıyken görünecek koyu renk
@export var off_color: Color = Color(0.03, 0.03, 0.035)
## Işıkların en karanlıkta bile sıçrama yapmaması için minimum eşik çarpanı
@export var min_light_factor: float = 0.0

var _glow: float = 0.0
var _over: bool = false       # fare gerçekten hitbox'un üzerinde mi
var _lit: bool = false        # parlama hedefi açık mı
var _in_use: bool = false     # monitör kullanımda: ekran yanık kalır, tıklama kapalı
var _was_pressed: bool = false
var _cursor_hand: bool = false
var _tween: Tween
var _screen_material: StandardMaterial3D
var _base_color: Color
var _base_emission: float
var _light_energies: Array[float] = []


func _ready() -> void:
	if screen:
		var src := screen.material as StandardMaterial3D
		if src:
			_screen_material = src.duplicate() as StandardMaterial3D
		else:
			_screen_material = StandardMaterial3D.new()
		screen.material = _screen_material

		_base_color = _screen_material.albedo_color
		if not _screen_material.emission_enabled:
			_screen_material.emission_enabled = true
			_screen_material.emission = _base_color
		_base_emission = _screen_material.emission_energy_multiplier

	for l in lights:
		if l:
			_light_energies.append(l.light_energy)
			l.visible = true
		else:
			_light_energies.append(0.0)

	_apply_glow(0.0)


func _exit_tree() -> void:
	_set_hand_cursor(false)


## Ekranın açıkken görünen rengi (kamera sistemi kaplaması için)
func get_on_color() -> Color:
	return _base_color


## true iken ekran yanık kalır ve tıklamalar yok sayılır
func set_in_use(value: bool) -> void:
	_in_use = value
	_refresh_glow()
	_refresh_cursor()


func _process(_delta: float) -> void:
	var was_over := _over
	_over = _is_mouse_over_hitbox()
	if _over != was_over:
		hover_changed.emit(_over)
	_refresh_glow()
	_refresh_cursor()

	# Tıklamayı olay yerine doğrudan sorgulayarak algılıyoruz (SubViewport'ta daha güvenilir)
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if pressed and not _was_pressed and _over and not _in_use:
		clicked.emit()
	_was_pressed = pressed


func _refresh_cursor() -> void:
	var want_hand := _over and not _in_use
	_set_hand_cursor(want_hand)


func _set_hand_cursor(enable: bool) -> void:
	if enable == _cursor_hand:
		return
	_cursor_hand = enable
	if enable:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _refresh_glow() -> void:
	var want := _over or _in_use
	if want != _lit:
		_lit = want
		if want:
			_fade_to(1.0, fade_in_time, Tween.EASE_OUT)
		else:
			_fade_to(0.0, fade_out_time, Tween.EASE_IN_OUT)


func _is_mouse_over_hitbox() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var cam := vp.get_camera_3d()
	if cam == null:
		return false

	var container: SubViewportContainer = null
	if vp is SubViewport:
		container = vp.get_parent() as SubViewportContainer

	var mouse_pos: Vector2
	if container:
		var local := container.get_local_mouse_position()
		if not Rect2(Vector2.ZERO, container.size).has_point(local):
			return false
		if container.stretch and container.size.x > 0.0 and container.size.y > 0.0:
			var viewport_size := vp.get_visible_rect().size
			mouse_pos = local * viewport_size / container.size
		else:
			mouse_pos = local / maxf(float(container.stretch_shrink), 1.0)
	else:
		mouse_pos = vp.get_mouse_position()

	var from := cam.project_ray_origin(mouse_pos)
	var to := from + cam.project_ray_normal(mouse_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == self


func _fade_to(target: float, duration: float, ease_type: Tween.EaseType) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(ease_type)

	var remaining := absf(target - _glow)
	var dur := maxf(duration * remaining, 0.01)
	_tween.tween_method(_apply_glow, _glow, target, dur)


func _apply_glow(value: float) -> void:
	_glow = clampf(value, 0.0, 1.0)

	if _screen_material:
		_screen_material.albedo_color = off_color.lerp(_base_color, _glow)
		_screen_material.emission_energy_multiplier = _base_emission * _glow

	var effective_factor := 0.0 if _glow <= 0.0001 else lerpf(min_light_factor, 1.0, _glow)
	for i in lights.size():
		var l := lights[i]
		if l:
			l.visible = effective_factor > 0.0001
			l.light_energy = _light_energies[i] * effective_factor

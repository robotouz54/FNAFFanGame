extends CharacterBody3D

const DEBUG_CODE: Array[Key] = [KEY_D, KEY_E, KEY_B, KEY_U, KEY_G]

@export_group("Hareket")
@export var walk_speed: float = 5.5
@export var sprint_speed: float = 9.5
@export var accel_ground: float = 12.0
@export var decel_ground: float = 10.0
@export var accel_air: float = 3.5
@export var decel_air: float = 1.5
@export var jump_velocity: float = 5.0
@export var fall_gravity_multiplier: float = 1.35

@export_group("Kamera ve Fener")
@export var mouse_sensitivity: float = 0.012
@export var debug_camera: Camera3D
@export var flashlight: SpotLight3D

@export_group("Head Bob & Zıplama Hissi")
@export var bob_enabled: bool = true
@export var walk_bob_freq: float = 9.0
@export var sprint_bob_freq: float = 13.5
@export var walk_bob_amp_y: float = 0.045
@export var sprint_bob_amp_y: float = 0.075
@export var walk_bob_amp_x: float = 0.03
@export var sprint_bob_amp_x: float = 0.055
@export var landing_bob_scale: float = 0.018
@export var jump_tilt_deg: float = 2.2
@export var sprint_fov_boost: float = 5.0

var _debug_mode: bool = false
var _debug_code_index: int = 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _cam_base_pos: Vector3 = Vector3.ZERO
var _cam_base_fov: float = 75.0
var _bob_time: float = 0.0
var _bob_offset: Vector2 = Vector2.ZERO
var _impact_offset_y: float = 0.0
var _jump_pitch_offset: float = 0.0
var _was_on_floor: bool = false


func _ready() -> void:
	if not debug_camera:
		debug_camera = find_child("DebugCamera3D", true, false) as Camera3D
	if not flashlight:
		flashlight = find_child("SpotLight3D", true, false) as SpotLight3D

	if debug_camera:
		_cam_base_pos = debug_camera.position
		_cam_base_fov = debug_camera.fov
		debug_camera.current = false
	if flashlight:
		flashlight.visible = false

	set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _debug_mode:
		if event is InputEventKey and event.pressed and not event.echo:
			_process_debug_code(event.keycode)
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_toggle_flashlight()

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if debug_camera:
			debug_camera.rotate_x(-event.relative.y * mouse_sensitivity)
			debug_camera.rotation.x = clampf(debug_camera.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))


func _process_debug_code(keycode: Key) -> void:
	if keycode == DEBUG_CODE[_debug_code_index]:
		_debug_code_index += 1
		if _debug_code_index >= DEBUG_CODE.size():
			_debug_code_index = 0
			_enter_debug_mode_permanently()
	else:
		# Araya başka tuş girerse sıfırla; basılan tuş 'D' ise ilk harf olarak kabul et
		_debug_code_index = 1 if keycode == DEBUG_CODE[0] else 0


func _enter_debug_mode_permanently() -> void:
	_debug_mode = true
	set_physics_process(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if not debug_camera:
		debug_camera = find_child("DebugCamera3D", true, false) as Camera3D
	if debug_camera:
		_cam_base_pos = debug_camera.position
		_cam_base_fov = debug_camera.fov
		debug_camera.current = true
		debug_camera.make_current()

	if not flashlight:
		flashlight = find_child("SpotLight3D", true, false) as SpotLight3D
	if flashlight:
		flashlight.visible = true

	_was_on_floor = is_on_floor()


func _toggle_flashlight() -> void:
	if not flashlight:
		flashlight = find_child("SpotLight3D", true, false) as SpotLight3D
	if flashlight:
		flashlight.visible = not flashlight.visible


func _physics_process(delta: float) -> void:
	if not _debug_mode:
		return

	var on_floor := is_on_floor()
	var is_sprinting := Input.is_key_pressed(KEY_SHIFT)

	# Yerçekimi (düşerken biraz daha ağır)
	if not on_floor:
		var grav_mult := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
		velocity.y -= _gravity * grav_mult * delta

	# Zıplama
	if Input.is_key_pressed(KEY_SPACE) and on_floor:
		velocity.y = jump_velocity
		_jump_pitch_offset = deg_to_rad(jump_tilt_deg)
		on_floor = false

	# WASD yön girişi
	var input_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vec.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vec.x += 1.0
	input_vec = input_vec.limit_length(1.0)

	var target_speed := sprint_speed if is_sprinting else walk_speed
	var wish_dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
	var target_vel := wish_dir * target_speed

	var rate: float
	if on_floor:
		rate = accel_ground if wish_dir.length_squared() > 0.001 else decel_ground
	else:
		rate = accel_air if wish_dir.length_squared() > 0.001 else decel_air

	var blend := clampf(rate * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, target_vel.x, blend)
	velocity.z = lerpf(velocity.z, target_vel.z, blend)

	var pre_land_vy := velocity.y
	move_and_slide()

	# Yere iniş sarsıntısı
	if not _was_on_floor and is_on_floor() and pre_land_vy < -1.5:
		_impact_offset_y = -clampf(absf(pre_land_vy) * landing_bob_scale, 0.0, 0.22)

	_was_on_floor = is_on_floor()
	_update_camera_motion(delta, is_sprinting)


func _update_camera_motion(delta: float, is_sprinting: bool) -> void:
	if not debug_camera or not is_instance_valid(debug_camera):
		return

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var moving_on_floor := is_on_floor() and horiz_speed > 0.25

	if bob_enabled and moving_on_floor:
		var freq := sprint_bob_freq if is_sprinting else walk_bob_freq
		var amp_y := sprint_bob_amp_y if is_sprinting else walk_bob_amp_y
		var amp_x := sprint_bob_amp_x if is_sprinting else walk_bob_amp_x
		_bob_time += delta * freq * clampf(horiz_speed / maxf(walk_speed, 0.1), 0.5, 1.4)
		_bob_offset.y = sin(_bob_time * 2.0) * amp_y
		_bob_offset.x = cos(_bob_time) * amp_x
	else:
		_bob_time = 0.0
		_bob_offset = _bob_offset.lerp(Vector2.ZERO, clampf(10.0 * delta, 0.0, 1.0))

	# İniş sarsıntısını yumuşakça toparla
	_impact_offset_y = lerpf(_impact_offset_y, 0.0, clampf(12.0 * delta, 0.0, 1.0))

	# Pozisyonu baz konum + bob + iniş darbesi olarak uygula
	debug_camera.position = _cam_base_pos + Vector3(_bob_offset.x, _bob_offset.y + _impact_offset_y, 0.0)

	# Zıplama anındaki hafif pitch sallanmasını geri al
	if absf(_jump_pitch_offset) > 0.0001:
		var step := lerpf(_jump_pitch_offset, 0.0, clampf(8.0 * delta, 0.0, 1.0))
		var diff := step - _jump_pitch_offset
		debug_camera.rotate_x(diff)
		debug_camera.rotation.x = clampf(debug_camera.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
		_jump_pitch_offset = step

	# Koşarken hafif FOV genişlemesi
	var active_sprint := is_sprinting and horiz_speed > 1.0
	var target_fov := _cam_base_fov + (sprint_fov_boost if active_sprint else 0.0)
	debug_camera.fov = lerpf(debug_camera.fov, target_fov, clampf(8.0 * delta, 0.0, 1.0))

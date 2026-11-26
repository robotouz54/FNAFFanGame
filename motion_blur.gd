extends SubViewportContainer

@export_range(0.0, 1.0, 0.01) var intensity: float = 0.20

const SHUTTER_DURATION: float = 0.08
const MAX_BLUR_DISTANCE: float = 0.12
const ROTATION_SCALE: float = 0.75
const TRANSLATION_SCALE: float = 0.2

@onready var _render_viewport: SubViewport = $SubViewport

var _previous_camera: Camera3D
var _transform_history: Array[Transform3D] = []
var _history_times: Array[float] = []
var _shader_material: ShaderMaterial
var _motion_blur_enabled: bool = true


func _ready() -> void:
	_shader_material = material as ShaderMaterial
	if _shader_material == null:
		push_error("Motion blur requires a ShaderMaterial on its SubViewportContainer.")
	set_process(_motion_blur_enabled)


func set_motion_blur_enabled(enabled: bool) -> void:
	_motion_blur_enabled = enabled
	set_process(enabled)
	if not enabled:
		_previous_camera = null
		_transform_history.clear()
		_history_times.clear()
		if _shader_material != null:
			_shader_material.set_shader_parameter("motion_vector", Vector2.ZERO)


func _process(_delta: float) -> void:
	if not _motion_blur_enabled or _shader_material == null:
		return

	var camera := _render_viewport.get_camera_3d()
	if camera == null:
		_previous_camera = null
		_transform_history.clear()
		_history_times.clear()
		_shader_material.set_shader_parameter("motion_vector", Vector2.ZERO)
		return

	var now := float(Time.get_ticks_msec()) / 1000.0
	if camera != _previous_camera:
		_previous_camera = camera
		_transform_history.clear()
		_history_times.clear()
		_transform_history.append(camera.global_transform)
		_history_times.append(now)
		_shader_material.set_shader_parameter("motion_vector", Vector2.ZERO)
		return

	_transform_history.append(camera.global_transform)
	_history_times.append(now)
	var cutoff := now - SHUTTER_DURATION
	while _history_times.size() > 2 and _history_times[1] < cutoff:
		_history_times.pop_front()
		_transform_history.pop_front()

	var previous_transform := _transform_history[0]
	var previous_basis := previous_transform.basis.orthonormalized()
	var current_basis := camera.global_basis.orthonormalized()
	var rotation_delta := (previous_basis.inverse() * current_basis).get_euler()
	var translation_delta := previous_basis.inverse() * (camera.global_position - previous_transform.origin)
	var motion_vector := Vector2(
		-rotation_delta.y * ROTATION_SCALE - translation_delta.x * TRANSLATION_SCALE,
		rotation_delta.x * ROTATION_SCALE + translation_delta.y * TRANSLATION_SCALE
	)
	motion_vector = motion_vector.limit_length(MAX_BLUR_DISTANCE) * clampf(intensity, 0.0, 1.0)
	_shader_material.set_shader_parameter("motion_vector", motion_vector)

class_name PlayerCamera
extends Camera3D

signal zoom_finished
signal return_finished

@export_group("Sallanma")
@export var pitch_deg: float = 0.35
@export var yaw_deg: float = 0.5
@export var roll_deg: float = 0.15
@export var position_amount: float = 0.006
@export var speed: float = 0.4

@export_group("Kenar Kaydırma")
@export var max_turn_deg: float = 45.0
@export_range(0.02, 0.4) var edge_enter: float = 0.10
@export_range(0.02, 0.5) var edge_exit: float = 0.18
@export var turn_time: float = 1.6
@export var return_time: float = 1.6
@export var confine_mouse: bool = false

var _base_rotation: Vector3
var _base_position: Vector3
var _base_fov: float
var _noise := FastNoiseLite.new()
var _t: float = 0.0

var _zone: int = 0          # -1 = sol, 0 = orta, 1 = sağ
var _pan_yaw: float = 0.0   # radyan
var _pan_tween: Tween

# Zoom durumu
var _locked: bool = false
var _move_tween: Tween
var _move_start: Transform3D
var _move_target: Transform3D
var _move_start_fov: float
var _move_target_fov: float


func _ready() -> void:
	_base_rotation = rotation
	_base_position = position
	_base_fov = fov
	_noise.seed = randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	if confine_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED


func _process(delta: float) -> void:
	if _locked:
		return  # zoom sırasında sallanma ve kaydırma kapalı

	_update_zone()

	_t += delta * speed
	var pitch := _noise.get_noise_1d(_t) * pitch_deg
	var yaw := _noise.get_noise_1d(_t + 100.0) * yaw_deg
	var roll := _noise.get_noise_1d(_t + 200.0) * roll_deg

	rotation = _base_rotation + Vector3(
		deg_to_rad(pitch),
		deg_to_rad(yaw) + _pan_yaw,
		deg_to_rad(roll)
	)

	var offset := Vector3(
		_noise.get_noise_1d(_t + 300.0),
		_noise.get_noise_1d(_t + 400.0),
		0.0
	) * position_amount
	position = _base_position + offset


# ---------- Zoom ----------

## Kamerayı verilen global konuma/FOV'a yumuşakça götürür.
func zoom_to(target: Transform3D, target_fov: float, duration: float) -> void:
	_locked = true
	if _pan_tween:
		_pan_tween.kill()
	_start_move(target, target_fov, duration, _on_zoom_done)


## Kamerayı ilk (orta) konumuna geri götürür.
func return_to_base(duration: float) -> void:
	var parent := get_parent_node_3d()
	var parent_xf := parent.global_transform if parent else Transform3D.IDENTITY
	var base_local := Transform3D(Basis.from_euler(_base_rotation), _base_position)
	_start_move(parent_xf * base_local, _base_fov, duration, _on_return_done)


func _start_move(target: Transform3D, target_fov: float, duration: float, on_done: Callable) -> void:
	if _move_tween:
		_move_tween.kill()
	_move_start = global_transform
	_move_target = target
	_move_start_fov = fov
	_move_target_fov = target_fov
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_method(_apply_move, 0.0, 1.0, duration)
	_move_tween.finished.connect(on_done)


func _apply_move(w: float) -> void:
	global_transform = _move_start.interpolate_with(_move_target, w)
	fov = lerpf(_move_start_fov, _move_target_fov, w)


func _on_zoom_done() -> void:
	zoom_finished.emit()


func _on_return_done() -> void:
	_locked = false
	_zone = 0
	_pan_yaw = 0.0
	fov = _base_fov
	return_finished.emit()


# ---------- Kenar kaydırma ----------

func _update_zone() -> void:
	var x := _get_mouse_x_ratio()
	var new_zone := _zone

	match _zone:
		0:
			if x > 1.0 - edge_enter:
				new_zone = 1
			elif x < edge_enter:
				new_zone = -1
		1:
			if x < 1.0 - edge_exit:
				new_zone = 0
		-1:
			if x > edge_exit:
				new_zone = 0

	if new_zone != _zone:
		_zone = new_zone
		_turn_to(-float(_zone) * deg_to_rad(max_turn_deg))


func _turn_to(target: float) -> void:
	if _pan_tween:
		_pan_tween.kill()

	var max_rad := maxf(absf(deg_to_rad(max_turn_deg)), 0.0001)
	var base_time := return_time if is_zero_approx(target) else turn_time
	var duration := base_time * absf(target - _pan_yaw) / max_rad

	_pan_tween = create_tween()
	_pan_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pan_tween.tween_property(self, "_pan_yaw", target, duration)


func _get_mouse_x_ratio() -> float:
	var vp := get_viewport()
	var container: SubViewportContainer = null
	if vp is SubViewport:
		container = vp.get_parent() as SubViewportContainer

	if container and container.size.x > 0.0:
		return container.get_local_mouse_position().x / container.size.x
	return vp.get_mouse_position().x / vp.get_visible_rect().size.x

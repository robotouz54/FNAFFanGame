class_name DoorSystem
extends Node3D

signal door_broken

## Kapının uçuş hızı
@export var break_speed: float = 6.0
## Yukarı doğru ek hız
@export var break_lift: float = 0.5
## Dönme hızı
@export var break_spin: float = 5.0
## Kırıldıktan sonra düşüşü azaltır; kapının karşı duvara ulaşmasını kolaylaştırır
@export_range(0.1, 1.0) var break_gravity_scale: float = 1.0
## Vuruşta kapının titreme miktarı (metre)
@export var hit_shake: float = 0.03

var is_broken: bool = false

var _stages: Array[Node3D] = []
var _body: RigidBody3D
var _stage3_frame: CSGCombiner3D
var _base_pos: Vector3
var _shake_tween: Tween


func _ready() -> void:
	_base_pos = position
	for i in range(3):
		_stages.append(get_node_or_null("Stage%d" % i) as Node3D)

	_body = get_node_or_null("DoorBody") as RigidBody3D
	_stage3_frame = get_node_or_null("kapicevreStage3") as CSGCombiner3D
	if _stage3_frame:
		_stage3_frame.visible = false
	if _body:
		_body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		_body.freeze = true
		_body.continuous_cd = true
		_body.can_sleep = false
		_body.visible = false

	set_stage(0)


## 0 = sağlam, 1 ve 2 = giderek daha eğri
func set_stage(index: int) -> void:
	for k in range(_stages.size()):
		if _stages[k]:
			_stages[k].visible = (k == index)
	if _stage3_frame:
		_stage3_frame.visible = is_broken


## Vuruş: kapıyı bir aşama büker ve titretir
func hit(hit_number: int) -> void:
	set_stage(mini(hit_number, 2))
	if _shake_tween:
		_shake_tween.kill()
	position = _base_pos
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "position", _base_pos + Vector3(hit_shake, 0.0, 0.0), 0.04)
	_shake_tween.tween_property(self, "position", _base_pos, 0.12)


## Son darbe: kapı fizik motoruyla uçar
func break_door(direction: Vector3) -> void:
	if is_broken:
		return
	is_broken = true

	if _shake_tween:
		_shake_tween.kill()
	position = _base_pos

	for s in _stages:
		if s:
			s.visible = false

	if _stage3_frame:
		_stage3_frame.visible = true

	if _body:
		_body.visible = true
		_body.freeze = false
		_body.sleeping = false
		_body.gravity_scale = break_gravity_scale
		_body.linear_damp = 0.25
		_body.angular_damp = 0.2
		var d := direction.normalized() if direction.length() > 0.001 else Vector3.FORWARD
		_body.linear_velocity = Vector3.ZERO
		_body.linear_velocity = d * break_speed + Vector3.UP * break_lift
		_body.angular_velocity = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * break_spin

	door_broken.emit()

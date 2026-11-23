extends Control

const EFFECT_DURATION: float = 0.9

var _origin: Vector2 = Vector2.ZERO
var _progress: float = -1.0


func play_wave(origin: Vector2) -> void:
	_origin = origin
	_progress = 0.0
	set_process(true)
	queue_redraw()


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_progress += delta / EFFECT_DURATION
	if _progress >= 1.0:
		_progress = -1.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _progress < 0.0:
		return

	var radius := _three_stage_value(_progress, 5.0, 16.0, 32.0)
	var distance := _three_stage_value(_progress, 5.0, 58.0, 142.0)
	var alpha := lerpf(0.95, 0.0, _progress)
	var line_width := _three_stage_value(_progress, 2.8, 2.2, 1.4)
	var directions: Array[Vector2] = [
		Vector2(-0.72, -0.69).normalized(),
		Vector2(0.0, -1.0),
		Vector2(0.72, -0.69).normalized(),
	]
	var source_offsets: Array[float] = [-34.0, 0.0, 34.0]
	for i in range(directions.size()):
		var direction: Vector2 = directions[i]
		var center := _origin + Vector2(source_offsets[i], -2.0) + direction * distance
		var base_angle := direction.angle()
		var points := PackedVector2Array()
		for point_index in range(19):
			var angle := base_angle - 0.9 + 1.8 * float(point_index) / 18.0
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_polyline(points, Color(1.0, 1.0, 1.0, alpha), line_width, true)


func _three_stage_value(progress: float, small: float, medium: float, large: float) -> float:
	if progress < 0.5:
		var first_half := progress * 2.0
		first_half = first_half * first_half * (3.0 - 2.0 * first_half)
		return lerpf(small, medium, first_half)
	var second_half := (progress - 0.5) * 2.0
	second_half = second_half * second_half * (3.0 - 2.0 * second_half)
	return lerpf(medium, large, second_half)

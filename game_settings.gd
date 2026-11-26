extends Node

const SETTINGS_PATH := "user://settings.cfg"
const QUALITY_OPTIONS := ["default", "medium", "low", "potato", "i respect that"]
const FPS_OPTIONS := [24, 30, 45, 60]
const QUALITY_SHRINK := {
	"default": 3,
	"medium": 4,
	"low": 5,
	"potato": 6,
	"i respect that": 7,
}
const QUALITY_SCALE := {
	"default": 1.0,
	"medium": 0.95,
	"low": 0.90,
	"potato": 0.85,
	"i respect that": 0.75,
}
const QUALITY_SHADOW_ATLAS := {
	"medium": 2048,
	"low": 1024,
	"potato": 512,
	"i respect that": 256,
}

var quality: String = "default"
var max_fps: int = 60
var motion_blur_enabled: bool = true
var shadows_enabled: bool = true

var _default_shadow_atlas_size: int
var _light_shadow_defaults: Dictionary = {}


func _ready() -> void:
	_default_shadow_atlas_size = int(ProjectSettings.get_setting(
		"rendering/lights_and_shadows/positional_shadow/atlas_size", 4096
	))
	_load_settings()
	get_tree().node_added.connect(_on_node_added)
	_apply_all_light_shadows()
	_apply_settings()


func set_quality(value: String) -> void:
	if not QUALITY_OPTIONS.has(value):
		push_warning("Unknown graphics quality: " + value)
		return
	quality = value
	_save_settings()
	_apply_quality()


func set_max_fps(value: int) -> void:
	if not FPS_OPTIONS.has(value):
		push_warning("Unsupported FPS limit: %d" % value)
		return
	max_fps = value
	Engine.max_fps = max_fps
	_save_settings()


func set_motion_blur_enabled(value: bool) -> void:
	motion_blur_enabled = value
	_apply_motion_blur()
	_save_settings()


func set_shadows_enabled(value: bool) -> void:
	shadows_enabled = value
	_apply_all_light_shadows()
	_save_settings()


func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		push_error("Could not load settings file: %s (error %d)" % [SETTINGS_PATH, err])
		return

	var stored_quality := str(config.get_value("graphics", "quality", quality))
	if QUALITY_OPTIONS.has(stored_quality):
		quality = stored_quality
	var stored_fps := int(config.get_value("graphics", "max_fps", max_fps))
	if FPS_OPTIONS.has(stored_fps):
		max_fps = stored_fps
	motion_blur_enabled = bool(config.get_value("graphics", "motion_blur", motion_blur_enabled))
	shadows_enabled = bool(config.get_value("graphics", "shadows", shadows_enabled))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", quality)
	config.set_value("graphics", "max_fps", max_fps)
	config.set_value("graphics", "motion_blur", motion_blur_enabled)
	config.set_value("graphics", "shadows", shadows_enabled)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_error("Could not save settings file: %s (error %d)" % [SETTINGS_PATH, err])


func _apply_settings() -> void:
	Engine.max_fps = max_fps
	_apply_quality()
	_apply_motion_blur()


func _apply_quality() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		var container := scene.get_node_or_null("SubViewportContainer") as SubViewportContainer
		if container != null:
			container.stretch_shrink = int(QUALITY_SHRINK[quality])
			if container.has_method("set_motion_blur_enabled"):
				container.call("set_motion_blur_enabled", motion_blur_enabled)
			var viewport := container.get_node_or_null("SubViewport") as SubViewport
			if viewport != null:
				viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				viewport.scaling_3d_scale = float(QUALITY_SCALE[quality])
				var shadow_atlas_size := int(QUALITY_SHADOW_ATLAS.get(quality, _default_shadow_atlas_size))
				RenderingServer.viewport_set_positional_shadow_atlas_size(
					viewport.get_viewport_rid(), shadow_atlas_size
				)


func _apply_motion_blur() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var container := scene.get_node_or_null("SubViewportContainer") as SubViewportContainer
	if container != null and container.has_method("set_motion_blur_enabled"):
		container.call("set_motion_blur_enabled", motion_blur_enabled)


func _on_node_added(node: Node) -> void:
	if node is Light3D:
		var light := node as Light3D
		_light_shadow_defaults[light.get_instance_id()] = light.shadow_enabled
		_apply_light_shadow(light)
	elif node is SubViewport or node.name == "SubViewportContainer":
		call_deferred("_apply_scene_settings")


func _apply_scene_settings() -> void:
	_apply_quality()
	_apply_motion_blur()


func _apply_all_light_shadows() -> void:
	var root := get_tree().root
	for node: Node in root.find_children("*", "Light3D", true, false):
		_apply_light_shadow(node as Light3D)


func _apply_light_shadow(light: Light3D) -> void:
	if not is_instance_valid(light):
		return
	var instance_id := light.get_instance_id()
	if not _light_shadow_defaults.has(instance_id):
		_light_shadow_defaults[instance_id] = light.shadow_enabled
	light.shadow_enabled = bool(_light_shadow_defaults[instance_id]) and shadows_enabled

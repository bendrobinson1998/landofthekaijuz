class_name CameraSettings
extends Resource

@export var zoom: Vector2 = Vector2(3, 3)
@export var position_smoothing_enabled: bool = true
@export var position_smoothing_speed: float = 5.0
@export var process_callback: int = 0
@export var enabled: bool = true

# Camera limits
@export var limit_left: int = -1000
@export var limit_top: int = -1000
@export var limit_right: int = 1000
@export var limit_bottom: int = 1000

func _init():
	# Set default values
	zoom = Vector2(3, 3)
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0
	process_callback = 0
	enabled = true
	limit_left = -1000
	limit_top = -1000
	limit_right = 1000
	limit_bottom = 1000

func copy_from_camera(camera: Camera2D) -> void:
	"""Copy settings from an existing camera"""
	if not camera:
		return
	
	zoom = camera.zoom
	position_smoothing_enabled = camera.position_smoothing_enabled
	position_smoothing_speed = camera.position_smoothing_speed
	process_callback = camera.process_callback
	enabled = camera.enabled
	limit_left = camera.limit_left
	limit_top = camera.limit_top
	limit_right = camera.limit_right
	limit_bottom = camera.limit_bottom

func apply_to_camera(camera: Camera2D) -> void:
	"""Apply these settings to a camera"""
	if not camera:
		return
	
	camera.zoom = zoom
	camera.position_smoothing_enabled = position_smoothing_enabled
	camera.position_smoothing_speed = position_smoothing_speed
	camera.process_callback = process_callback
	camera.enabled = enabled
	camera.limit_left = limit_left
	camera.limit_top = limit_top
	camera.limit_right = limit_right
	camera.limit_bottom = limit_bottom

func to_dict() -> Dictionary:
	"""Convert to dictionary for network transmission"""
	return {
		"zoom": zoom,
		"position_smoothing_enabled": position_smoothing_enabled,
		"position_smoothing_speed": position_smoothing_speed,
		"process_callback": process_callback,
		"enabled": enabled,
		"limit_left": limit_left,
		"limit_top": limit_top,
		"limit_right": limit_right,
		"limit_bottom": limit_bottom
	}

func from_dict(data: Dictionary) -> void:
	"""Load from dictionary (from network transmission)"""
	if data.has("zoom"):
		zoom = data["zoom"]
	if data.has("position_smoothing_enabled"):
		position_smoothing_enabled = data["position_smoothing_enabled"]
	if data.has("position_smoothing_speed"):
		position_smoothing_speed = data["position_smoothing_speed"]
	if data.has("process_callback"):
		process_callback = data["process_callback"]
	if data.has("enabled"):
		enabled = data["enabled"]
	if data.has("limit_left"):
		limit_left = data["limit_left"]
	if data.has("limit_top"):
		limit_top = data["limit_top"]
	if data.has("limit_right"):
		limit_right = data["limit_right"]
	if data.has("limit_bottom"):
		limit_bottom = data["limit_bottom"]

func equals(other: CameraSettings) -> bool:
	"""Compare with another CameraSettings instance"""
	if not other:
		return false
	
	return (zoom == other.zoom and
			position_smoothing_enabled == other.position_smoothing_enabled and
			position_smoothing_speed == other.position_smoothing_speed and
			process_callback == other.process_callback and
			enabled == other.enabled and
			limit_left == other.limit_left and
			limit_top == other.limit_top and
			limit_right == other.limit_right and
			limit_bottom == other.limit_bottom)
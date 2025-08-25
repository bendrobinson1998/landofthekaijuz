class_name DayNightSystem
extends Node2D

@export var day_color: Color = Color.WHITE
@export var night_color: Color = Color(0.2, 0.3, 0.6, 1.0)
@export var transition_duration: float = 2.0
@export var enable_smooth_transitions: bool = true

var lighting_overlay: ColorRect
var is_transitioning: bool = false
var target_color: Color
var start_color: Color
var transition_timer: float = 0.0

signal day_night_transition_started(is_becoming_day: bool)
signal day_night_transition_completed(is_becoming_day: bool)

func _ready():
	_setup_lighting_overlay()
	_connect_to_time_manager()

func _setup_lighting_overlay():
	lighting_overlay = ColorRect.new()
	lighting_overlay.name = "DayNightOverlay"
	lighting_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	lighting_overlay.anchors_preset = Control.PRESET_FULL_RECT
	lighting_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lighting_overlay.color = Color.TRANSPARENT
	
	lighting_overlay.z_index = 100
	
	add_child(lighting_overlay)
	
	if TimeManager:
		_update_lighting_immediate()

func _connect_to_time_manager():
	if not TimeManager:
		return
	
	TimeManager.day_night_cycle_changed.connect(_on_day_night_cycle_changed)
	TimeManager.hour_changed.connect(_on_hour_changed)

func _process(delta):
	if is_transitioning:
		_process_transition(delta)

func _process_transition(delta: float):
	if not is_transitioning:
		return
	
	transition_timer += delta
	var progress = transition_timer / transition_duration
	
	if progress >= 1.0:
		progress = 1.0
		is_transitioning = false
		day_night_transition_completed.emit(TimeManager.is_day_time)
	
	var current_color = start_color.lerp(target_color, _smooth_step(progress))
	_apply_lighting_color(current_color)

func _smooth_step(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func _on_day_night_cycle_changed(is_day: bool):
	if enable_smooth_transitions:
		_start_transition(is_day)
	else:
		_update_lighting_immediate()

func _on_hour_changed(hour: int):
	if not TimeManager.is_day_time and hour >= 22:
		_apply_deeper_night_effect()

func _start_transition(is_becoming_day: bool):
	if not lighting_overlay:
		return
	
	start_color = lighting_overlay.color
	target_color = day_color if is_becoming_day else night_color
	
	is_transitioning = true
	transition_timer = 0.0
	
	day_night_transition_started.emit(is_becoming_day)

func _update_lighting_immediate():
	if not lighting_overlay or not TimeManager:
		return
	
	var current_color = day_color if TimeManager.is_day_time else night_color
	_apply_lighting_color(current_color)

func _apply_lighting_color(color: Color):
	if lighting_overlay:
		lighting_overlay.color = color

func _apply_deeper_night_effect():
	if TimeManager.is_day_time:
		return
	
	var deeper_night_color = night_color.darkened(0.2)
	
	if enable_smooth_transitions:
		start_color = lighting_overlay.color if lighting_overlay else night_color
		target_color = deeper_night_color
		is_transitioning = true
		transition_timer = 0.0
	else:
		_apply_lighting_color(deeper_night_color)

func get_current_lighting_intensity() -> float:
	if not TimeManager:
		return 1.0
	
	if TimeManager.is_day_time:
		return 1.0
	else:
		var night_progress = _calculate_night_progress()
		return lerp(0.8, 0.3, night_progress)

func _calculate_night_progress() -> float:
	if not TimeManager or TimeManager.is_day_time:
		return 0.0
	
	var hour = TimeManager.current_hour
	var minute = TimeManager.current_minute
	
	if hour >= 21:
		var minutes_into_night = (hour - 21) * 60 + minute
		var total_night_minutes = 9 * 60
		return float(minutes_into_night) / float(total_night_minutes)
	elif hour < 6:
		var minutes_into_night = (hour + 3) * 60 + minute
		var total_night_minutes = 9 * 60
		return float(minutes_into_night) / float(total_night_minutes)
	
	return 0.0

func set_day_color(color: Color):
	day_color = color
	if TimeManager and TimeManager.is_day_time and not is_transitioning:
		_apply_lighting_color(day_color)

func set_night_color(color: Color):
	night_color = color
	if TimeManager and not TimeManager.is_day_time and not is_transitioning:
		_apply_lighting_color(night_color)

func set_transition_duration(duration: float):
	transition_duration = max(0.1, duration)

func enable_transitions(enabled: bool):
	enable_smooth_transitions = enabled

func force_immediate_update():
	is_transitioning = false
	_update_lighting_immediate()

func get_lighting_overlay() -> ColorRect:
	return lighting_overlay

func is_in_transition() -> bool:
	return is_transitioning
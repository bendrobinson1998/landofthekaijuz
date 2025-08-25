extends Node

signal time_changed(hour: int, minute: int)
signal hour_changed(hour: int)
signal day_changed(day: int)
signal day_night_cycle_changed(is_day: bool)

const MINUTES_PER_DAY = 1440
const STARTING_HOUR = 8
const STARTING_MINUTE = 15
const DAY_START_HOUR = 6
const NIGHT_START_HOUR = 21

var current_day: int = 1
var current_hour: int = STARTING_HOUR
var current_minute: int = STARTING_MINUTE
var current_seconds: float = 0.0

var is_day_time: bool = true
var is_paused: bool = false

var _last_emitted_hour: int = -1
var _last_emitted_day: int = -1
var _last_emitted_day_night: bool = true

func _ready():
	_initialize_time()
	_update_day_night_state()

func _process(delta):
	if is_paused:
		return
	
	_advance_time(delta)

func _initialize_time():
	current_day = 1
	current_hour = STARTING_HOUR
	current_minute = STARTING_MINUTE
	current_seconds = 0.0
	_update_day_night_state()

func _advance_time(delta: float):
	current_seconds += delta
	
	if current_seconds >= 1.0:
		var minutes_to_add = int(current_seconds)
		current_seconds -= minutes_to_add
		
		current_minute += minutes_to_add
		
		var hour_changed = false
		var day_changed = false
		
		while current_minute >= 60:
			current_minute -= 60
			current_hour += 1
			hour_changed = true
			
			if current_hour >= 24:
				current_hour = 0
				current_day += 1
				day_changed = true
		
		_emit_time_signals(hour_changed, day_changed)

func _emit_time_signals(hour_has_changed: bool, day_has_changed: bool):
	time_changed.emit(current_hour, current_minute)
	
	if hour_has_changed and _last_emitted_hour != current_hour:
		_last_emitted_hour = current_hour
		hour_changed.emit(current_hour)
		_update_day_night_state()
	
	if day_has_changed and _last_emitted_day != current_day:
		_last_emitted_day = current_day
		day_changed.emit(current_day)

func _update_day_night_state():
	var new_is_day = current_hour >= DAY_START_HOUR and current_hour < NIGHT_START_HOUR
	
	if new_is_day != is_day_time:
		is_day_time = new_is_day
		_last_emitted_day_night = is_day_time
		day_night_cycle_changed.emit(is_day_time)

func get_current_time_string(format_24h: bool = true) -> String:
	if format_24h:
		return "%02d:%02d" % [current_hour, current_minute]
	else:
		var display_hour = current_hour
		var am_pm = "AM"
		
		if current_hour == 0:
			display_hour = 12
		elif current_hour > 12:
			display_hour = current_hour - 12
			am_pm = "PM"
		elif current_hour == 12:
			am_pm = "PM"
		
		return "%d:%02d %s" % [display_hour, current_minute, am_pm]

func get_current_day_string() -> String:
	return "Day %d" % current_day

func get_time_period() -> String:
	if current_hour >= 6 and current_hour < 12:
		return "Morning"
	elif current_hour >= 12 and current_hour < 17:
		return "Afternoon"
	elif current_hour >= 17 and current_hour < 21:
		return "Evening"
	else:
		return "Night"

func get_day_progress() -> float:
	var total_minutes = current_hour * 60 + current_minute
	return float(total_minutes) / float(MINUTES_PER_DAY)

func get_daylight_progress() -> float:
	if not is_day_time:
		return 0.0
	
	var day_start_minutes = DAY_START_HOUR * 60
	var night_start_minutes = NIGHT_START_HOUR * 60
	var current_minutes = current_hour * 60 + current_minute
	
	if current_minutes < day_start_minutes:
		return 0.0
	elif current_minutes >= night_start_minutes:
		return 1.0
	
	var day_duration = night_start_minutes - day_start_minutes
	var elapsed_day_time = current_minutes - day_start_minutes
	
	return float(elapsed_day_time) / float(day_duration)

func set_time(day: int, hour: int, minute: int):
	if day < 1 or hour < 0 or hour > 23 or minute < 0 or minute > 59:
		return
	
	current_day = day
	current_hour = hour
	current_minute = minute
	current_seconds = 0.0
	
	_update_day_night_state()
	_emit_time_signals(true, true)

func add_time(hours: int = 0, minutes: int = 0):
	var total_minutes = hours * 60 + minutes
	
	current_minute += total_minutes
	
	var hour_changed = false
	var day_changed = false
	
	while current_minute >= 60:
		current_minute -= 60
		current_hour += 1
		hour_changed = true
		
		if current_hour >= 24:
			current_hour = 0
			current_day += 1
			day_changed = true
	
	while current_minute < 0:
		current_minute += 60
		current_hour -= 1
		hour_changed = true
		
		if current_hour < 0:
			current_hour = 23
			current_day = max(1, current_day - 1)
			day_changed = true
	
	_update_day_night_state()
	_emit_time_signals(hour_changed, day_changed)

func pause_time():
	is_paused = true

func resume_time():
	is_paused = false

func is_time_paused() -> bool:
	return is_paused

func get_save_data() -> Dictionary:
	return {
		"current_day": current_day,
		"current_hour": current_hour,
		"current_minute": current_minute,
		"current_seconds": current_seconds,
		"is_paused": is_paused
	}

func load_save_data(data: Dictionary):
	if not data or data.is_empty():
		_initialize_time()
		return
	
	current_day = data.get("current_day", 1)
	current_hour = data.get("current_hour", STARTING_HOUR)
	current_minute = data.get("current_minute", STARTING_MINUTE)
	current_seconds = data.get("current_seconds", 0.0)
	is_paused = data.get("is_paused", false)
	
	_update_day_night_state()
	_emit_time_signals(true, true)

func get_total_minutes_elapsed() -> int:
	return (current_day - 1) * MINUTES_PER_DAY + current_hour * 60 + current_minute

func is_between_hours(start_hour: int, end_hour: int) -> bool:
	if start_hour <= end_hour:
		return current_hour >= start_hour and current_hour < end_hour
	else:
		return current_hour >= start_hour or current_hour < end_hour

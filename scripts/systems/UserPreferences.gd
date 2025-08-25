extends Node

signal ui_scale_changed(new_scale: float)
signal settings_loaded()
signal settings_saved()

const SETTINGS_FILE = "user://settings.cfg"
const DEFAULT_UI_SCALE = 1.0
const VALID_UI_SCALES = [1.0, 1.5, 2.0, 2.5, 3.0]

var config: ConfigFile

var ui_scale: float = DEFAULT_UI_SCALE:
	set(value):
		if value != ui_scale and value in VALID_UI_SCALES:
			ui_scale = value
			ui_scale_changed.emit(ui_scale)
			save_settings()
	get:
		return ui_scale

var master_volume: float = 0.5
var sfx_volume: float = 0.5
var music_volume: float = 0.5
var fullscreen: bool = false
var vsync: bool = true
var resolution: String = "1920x1080"
var mouse_sensitivity: float = 1.0

func _ready():
	config = ConfigFile.new()
	load_settings()

func load_settings():
	"""Load settings from config file"""
	var err = config.load(SETTINGS_FILE)
	
	if err != OK:
		print("UserPreferences: No settings file found, using defaults")
		save_settings()
		return
	
	# Load UI settings
	ui_scale = config.get_value("ui", "scale", DEFAULT_UI_SCALE)
	if ui_scale not in VALID_UI_SCALES:
		ui_scale = DEFAULT_UI_SCALE
	
	# Load audio settings
	master_volume = config.get_value("audio", "master_volume", 0.5)
	sfx_volume = config.get_value("audio", "sfx_volume", 0.5)
	music_volume = config.get_value("audio", "music_volume", 0.5)
	
	# Load video settings
	fullscreen = config.get_value("video", "fullscreen", false)
	vsync = config.get_value("video", "vsync", true)
	resolution = config.get_value("video", "resolution", "1920x1080")
	
	# Load control settings
	mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", 1.0)
	
	settings_loaded.emit()
	print("UserPreferences: Settings loaded successfully")

func save_settings():
	"""Save settings to config file"""
	# Save UI settings
	config.set_value("ui", "scale", ui_scale)
	
	# Save audio settings
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	
	# Save video settings
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "resolution", resolution)
	
	# Save control settings
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	
	var err = config.save(SETTINGS_FILE)
	if err == OK:
		settings_saved.emit()
		print("UserPreferences: Settings saved successfully")
	else:
		push_error("UserPreferences: Failed to save settings")

func set_ui_scale(scale: float):
	"""Set the UI scale if it's valid"""
	if scale in VALID_UI_SCALES:
		ui_scale = scale

func get_ui_scale() -> float:
	"""Get the current UI scale"""
	return ui_scale

func get_ui_scale_percentage() -> String:
	"""Get the UI scale as a percentage string"""
	return str(int(ui_scale * 100)) + "%"

func get_valid_ui_scales() -> Array:
	"""Get list of valid UI scale values"""
	return VALID_UI_SCALES

func get_valid_ui_scale_percentages() -> Array[String]:
	"""Get list of valid UI scale values as percentage strings"""
	var percentages: Array[String] = []
	for scale in VALID_UI_SCALES:
		percentages.append(str(int(scale * 100)) + "%")
	return percentages

func reset_to_defaults():
	"""Reset all settings to default values"""
	ui_scale = DEFAULT_UI_SCALE
	master_volume = 0.5
	sfx_volume = 0.5
	music_volume = 0.5
	fullscreen = false
	vsync = true
	resolution = "1920x1080"
	mouse_sensitivity = 1.0
	save_settings()

func apply_video_settings():
	"""Apply video settings to the game"""
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# Parse resolution
	var res_parts = resolution.split("x")
	if res_parts.size() == 2:
		var width = int(res_parts[0])
		var height = int(res_parts[1])
		DisplayServer.window_set_size(Vector2i(width, height))
	
	# VSync is set in project settings, would need different approach
	# ProjectSettings.set_setting("display/window/vsync/use_vsync", vsync)

func apply_audio_settings():
	"""Apply audio settings to the game"""
	var master_bus = AudioServer.get_bus_index("Master")
	var sfx_bus = AudioServer.get_bus_index("SFX") if AudioServer.get_bus_index("SFX") >= 0 else -1
	var music_bus = AudioServer.get_bus_index("Music") if AudioServer.get_bus_index("Music") >= 0 else -1
	
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_volume))
	
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume))
	
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))
extends Node

signal scene_changed(new_scene: String)
signal game_paused(is_paused: bool)

var current_scene: Node = null
var player_data: Dictionary = {}
var game_settings: Dictionary = {}
var spawn_points: Array[SpawnPoint] = []
var default_spawn_point: SpawnPoint = null
var target_spawn_point_id: String = ""
var game_start_time: float = 0.0

# Legacy support - actual autosave handled by SaveManager

func _ready():
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	
	# Track game start time
	game_start_time = Time.get_ticks_msec() / 1000.0
	
	# Initialize default player data
	player_data = {
		"position": Vector2.ZERO,
		"level": 1,
		"health": 100,
		"energy": 100
	}
	
	# Initialize default game settings
	game_settings = {
		"master_volume": 0.8,
		"sfx_volume": 0.8,
		"music_volume": 0.6,
		"auto_save": true,
		"autosave_interval": 300.0  # 5 minutes
	}
	
	# SaveManager handles autosave now

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game_settings.auto_save and SaveManager.current_world_name:
			SaveManager.save_current_world()
		get_tree().quit()

func change_scene_to(scene_path: String):
	call_deferred("_deferred_change_scene", scene_path)

func _deferred_change_scene(scene_path: String):
	current_scene.free()
	
	var new_scene = load(scene_path)
	current_scene = new_scene.instantiate()
	
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	
	# Handle spawn point positioning after scene loads
	_handle_spawn_point_positioning()
	
	# Trigger autosave on scene change (entering/exiting buildings)
	if game_settings.auto_save and SaveManager.current_world_name:
		SaveManager.trigger_autosave()
	
	scene_changed.emit(scene_path)

func pause_game():
	get_tree().paused = true
	game_paused.emit(true)

func unpause_game():
	get_tree().paused = false
	game_paused.emit(false)

func save_game() -> bool:
	"""Legacy save function - delegates to SaveManager"""
	if SaveManager.current_world_name:
		return SaveManager.save_current_world()
	else:
		push_warning("GameManager: No current world to save")
		return false

func save_game_to_path(file_path: String) -> bool:
	"""Legacy save function - delegates to SaveManager"""
	return save_game()

func _get_save_file_path() -> String:
	"""Legacy function - SaveManager handles paths now"""
	if SaveManager.current_world_name:
		return SaveManager._get_save_file_path(SaveManager.current_world_name)
	else:
		return "user://saves/default_world/savegame.save"

func load_game() -> bool:
	"""Legacy load function - prints warning"""
	push_warning("GameManager.load_game() is deprecated - use SaveManager.load_world() instead")
	return false

func load_game_from_path(file_path: String) -> bool:
	"""Legacy load function - delegates to SaveManager"""
	push_warning("GameManager.load_game_from_path() is deprecated - use SaveManager.load_world() instead")
	return false

func _load_and_parse_save_file(file_path: String) -> Dictionary:
	"""Load and parse a save file with error handling, returns null on failure"""
	var save_file = FileAccess.open(file_path, FileAccess.READ)
	if save_file == null:
		return {}
	
	var save_text = save_file.get_as_text()
	save_file.close()
	
	# Check for empty or corrupted file content
	if save_text.is_empty():
		return {}
	
	# Attempt to parse JSON
	var json = JSON.new()
	var parse_result = json.parse(save_text)
	
	if parse_result != OK:
		return {}
	
	var save_data = json.get_data()
	if typeof(save_data) != TYPE_DICTIONARY:
		return {}
	
	return save_data

func _validate_save_data(save_data: Dictionary) -> bool:
	"""Validate save data structure and content"""
	if save_data.is_empty():
		return false
	
	# Check for required fields
	var required_fields = ["player_data", "game_settings", "timestamp"]
	for field in required_fields:
		if not save_data.has(field):
			return false
	
	# Validate save version compatibility
	var save_version = save_data.get("save_version", 0)
	if save_version > 1:
		return false
	
	# Validate timestamp
	var timestamp = save_data.get("timestamp", 0)
	if timestamp <= 0:
	
	return true

func _load_pending_world_data():
	"""Load world data that was deferred during save file loading"""
	if _pending_world_data.is_empty():
		return
	
	
	# Wait a few frames to ensure the scene is fully initialized
	for i in range(3):
		await get_tree().process_frame
	
	# Try to find the chunk manager now
	var chunk_manager = _find_chunk_manager()
	if chunk_manager and chunk_manager.has_method("load_world_save_data"):
		chunk_manager.load_world_save_data(_pending_world_data)
		_pending_world_data.clear()
	else:
		# Retry after 1 second
		await get_tree().create_timer(1.0).timeout
		
		chunk_manager = _find_chunk_manager()
		if chunk_manager and chunk_manager.has_method("load_world_save_data"):
			chunk_manager.load_world_save_data(_pending_world_data)
			_pending_world_data.clear()
		else:
			# Keep the pending data for potential later retry

func get_pending_world_data() -> Dictionary:
	"""Get pending world data for immediate loading"""
	return _pending_world_data.duplicate()

func clear_pending_world_data():
	"""Clear pending world data after it's been loaded"""
	_pending_world_data.clear()

func register_spawn_point(spawn_point: SpawnPoint):
	if spawn_point not in spawn_points:
		spawn_points.append(spawn_point)
		
		if spawn_point.is_default and not default_spawn_point:
			default_spawn_point = spawn_point

func get_spawn_point(spawn_id: String) -> SpawnPoint:
	for spawn_point in spawn_points:
		if spawn_point.spawn_id == spawn_id:
			return spawn_point
	return null

func get_available_spawn_points() -> Array[SpawnPoint]:
	var available = []
	for spawn_point in spawn_points:
		if spawn_point.can_spawn():
			available.append(spawn_point)
	return available

func spawn_player_at(spawn_id: String = "") -> Node:
	var spawn_point: SpawnPoint
	
	if spawn_id.is_empty():
		# Use default spawn point
		spawn_point = default_spawn_point
	else:
		spawn_point = get_spawn_point(spawn_id)
	
	if not spawn_point:
		return null
	
	return spawn_point.spawn_player()

func get_playtime() -> float:
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - game_start_time

func get_formatted_playtime() -> String:
	var playtime = get_playtime()
	var hours = int(playtime) / 3600
	var minutes = (int(playtime) % 3600) / 60
	var seconds = int(playtime) % 60
	
	if hours > 0:
		return "%d hours, %d minutes, %d seconds" % [hours, minutes, seconds]
	elif minutes > 0:
		return "%d minutes, %d seconds" % [minutes, seconds]
	else:
		return "%d seconds" % seconds

func set_target_spawn_point(spawn_id: String):
	target_spawn_point_id = spawn_id

func _handle_spawn_point_positioning():
	if target_spawn_point_id.is_empty():
		return
	
	# Wait a frame for the scene to fully initialize
	await get_tree().process_frame
	
	# Find the player in the new scene
	var player = _find_player_in_scene()
	if not player:
		target_spawn_point_id = ""
		return
	
	# Find the target spawn point
	var spawn_point = get_spawn_point(target_spawn_point_id)
	if not spawn_point:
		target_spawn_point_id = ""
		return
	
	# Position the player at the spawn point
	player.global_position = spawn_point.global_position
	
	# Clear the target spawn point
	target_spawn_point_id = ""

func _find_player_in_scene() -> Node:
	# Look for player node by name
	var player = current_scene.find_child("Player", true, false)
	if player:
		return player
	
	# Look for any node with "Player" in the name
	return current_scene.find_child("*Player*", true, false)

func quit_game():
	if game_settings.auto_save:
		save_game()
	get_tree().quit()

func _get_world_data() -> Dictionary:
	"""Get world data from the current scene's chunk manager"""
	var world_data = {}
	
	# Find the ChunkManager in the current scene
	var chunk_manager = _find_chunk_manager()
	if chunk_manager and chunk_manager.has_method("get_world_save_data"):
		world_data = chunk_manager.get_world_save_data()
	else:
	
	return world_data

func _set_world_data(world_data: Dictionary):
	"""Set world data to the current scene's chunk manager"""
	if world_data.is_empty():
		return
		
	# Find the ChunkManager in the current scene
	var chunk_manager = _find_chunk_manager()
	if chunk_manager and chunk_manager.has_method("load_world_save_data"):
		chunk_manager.load_world_save_data(world_data)
	else:

func _find_chunk_manager() -> Node:
	"""Find the ChunkManager in the current scene"""
	if not current_scene:
		return null
	
	# Look for ChunkManager by name
	var chunk_manager = current_scene.find_child("ChunkManager", true, false)
	if chunk_manager:
		return chunk_manager
	
	# Look for any node with ChunkManager class
	var all_nodes = current_scene.find_children("*", "ChunkManager", true, false)
	if all_nodes.size() > 0:
		return all_nodes[0]
	
	# No fallback needed - ChunkManager only
	
	return null

# Autosave System
func _setup_autosave_system():
	"""Initialize the autosave timer system"""
	autosave_timer = Timer.new()
	autosave_timer.wait_time = autosave_interval
	autosave_timer.timeout.connect(_on_autosave_timer_timeout)
	autosave_timer.autostart = false
	add_child(autosave_timer)

func start_autosave():
	"""Start the autosave timer"""
	if game_settings.auto_save and autosave_timer:
		autosave_interval = game_settings.get("autosave_interval", 300.0)
		autosave_timer.wait_time = autosave_interval
		autosave_timer.start()

func stop_autosave():
	"""Stop the autosave timer"""
	if autosave_timer:
		autosave_timer.stop()

func trigger_autosave():
	"""Manually trigger an autosave"""
	if game_settings.auto_save:
		save_game()
		last_autosave_time = Time.get_unix_time_from_system()

func _update_world_metadata(save_file_path: String):
	"""Update world metadata file when game is saved"""
	var world_name = player_data.get("world_name", "")
	if world_name.is_empty():
		return
	
	var metadata_path = "user://saves/" + world_name + "/world_metadata.json"
	var world_data = {
		"world_name": world_name,
		"world_seed": player_data.get("world_seed", -1),
		"last_played_timestamp": Time.get_unix_time_from_system(),
		"playtime": get_playtime()
	}
	
	# Try to load existing metadata to preserve creation timestamp
	if FileAccess.file_exists(metadata_path):
		var existing_file = FileAccess.open(metadata_path, FileAccess.READ)
		if existing_file:
			var json = JSON.new()
			if json.parse(existing_file.get_as_text()) == OK:
				var existing_data = json.get_data()
				world_data["creation_timestamp"] = existing_data.get("creation_timestamp", Time.get_unix_time_from_system())
			existing_file.close()
	else:
		world_data["creation_timestamp"] = Time.get_unix_time_from_system()
	
	# Save updated metadata
	var metadata_file = FileAccess.open(metadata_path, FileAccess.WRITE)
	if metadata_file:
		metadata_file.store_string(JSON.stringify(world_data))
		metadata_file.close()

func _on_autosave_timer_timeout():
	"""Called when autosave timer expires"""
	trigger_autosave()

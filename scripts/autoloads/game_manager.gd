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
		"energy": 100,
		"username": "Player"
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
	
	# Initialize chat system with default username
	_update_chat_username()

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
	
	# Update chat system with current username
	_update_chat_username()
	
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
	return false

func load_game_from_path(file_path: String) -> bool:
	"""Legacy load function - delegates to SaveManager"""
	return false

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

func _update_chat_username():
	# Ensure ChatManager uses the current username from player_data
	if player_data.has("username") and not player_data["username"].is_empty():
		ChatManager.set_local_player_name(player_data["username"])
	else:
		ChatManager.set_local_player_name("Player")

func quit_game():
	if game_settings.auto_save and SaveManager.current_world_name:
		SaveManager.save_current_world()
	get_tree().quit()

# Legacy functions that are no longer needed - just kept for compatibility
func _get_world_data() -> Dictionary:
	"""Legacy function - SaveManager handles world data collection"""
	return {}

func _find_chunk_manager() -> Node:
	"""Legacy function - find ChunkManager in scene"""
	var scene_root = get_tree().current_scene
	if not scene_root:
		return null
	
	# Look for ChunkManager by name
	var chunk_manager = scene_root.find_child("ChunkManager", true, false)
	if chunk_manager:
		return chunk_manager
	
	# Look for any node with ChunkManager class
	var all_nodes = scene_root.find_children("*", "ChunkManager", true, false)
	if all_nodes.size() > 0:
		return all_nodes[0]
	
	# No fallback needed - ChunkManager only
	
	return null

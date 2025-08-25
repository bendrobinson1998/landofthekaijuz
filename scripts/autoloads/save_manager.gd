extends Node

signal save_completed(success: bool, save_path: String)
signal load_completed(success: bool, save_path: String)

const SAVE_VERSION: int = 1
const SAVE_EXTENSION: String = ".lkz"
const METADATA_EXTENSION: String = ".meta"

var current_world_name: String = ""
var current_world_seed: int = -1
var is_autosave_enabled: bool = true
var autosave_interval: float = 300.0

var _autosave_timer: Timer

# Factory functions for save data structures
func create_world_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"world_name": "",
		"world_seed": -1,
		"player_data": {},
		"world_data": {},
		"inventory_data": [],
		"skill_data": {},
		"time_data": {},
		"timestamp": Time.get_unix_time_from_system(),
		"playtime": 0.0
	}

func create_world_metadata() -> Dictionary:
	var current_time = Time.get_unix_time_from_system()
	return {
		"world_name": "",
		"world_seed": -1,
		"username": "",
		"creation_timestamp": current_time,
		"last_played_timestamp": current_time,
		"playtime": 0.0,
		"save_version": SAVE_VERSION,
		"has_save_file": false
	}

func is_save_data_valid(save_data: Dictionary) -> bool:
	return save_data.has("world_name") and not save_data["world_name"].is_empty() \
		and save_data.has("world_seed") and save_data["world_seed"] != -1 \
		and save_data.has("version") and save_data["version"] > 0

func _ready():
	_setup_autosave_timer()
	
	# Ensure saves directory exists
	_ensure_saves_directory()

func _setup_autosave_timer():
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = autosave_interval
	_autosave_timer.timeout.connect(_on_autosave_timer_timeout)
	_autosave_timer.autostart = false
	add_child(_autosave_timer)

func _ensure_saves_directory():
	var dir = DirAccess.open("user://")
	if not dir:
		return
	
	if not dir.dir_exists("saves"):
		var result = dir.make_dir("saves")

	

func create_new_world(world_name: String, world_seed: int = -1, username: String = "Player") -> bool:
	
	if world_name.is_empty():
		return false
	
	# Generate random seed if not provided
	if world_seed == -1:
		world_seed = randi()
	
	# Set current world info
	current_world_name = world_name
	current_world_seed = world_seed
	
	# Ensure saves directory exists first
	_ensure_saves_directory()
	
	# Create world directory
	var world_dir = "user://saves/" + world_name + "/"
	
	var dir = DirAccess.open("user://saves/")
	if not dir:
		return false
	
	if not dir.dir_exists(world_name):
		var result = dir.make_dir(world_name)
		if result != OK:
			return false
	
	
	# Create and save metadata
	var metadata = create_world_metadata()
	metadata["world_name"] = world_name
	metadata["world_seed"] = world_seed
	metadata["username"] = username
	metadata["has_save_file"] = false
	
	if not _save_world_metadata(metadata):
		return false
	
	
	# Set up GameManager with new world data
	GameManager.player_data["world_name"] = world_name
	GameManager.player_data["world_seed"] = world_seed
	GameManager.player_data["username"] = username
	
	return true

func save_current_world() -> bool:
	if current_world_name.is_empty():
		return false
	
	var save_data = create_world_save_data()
	save_data["world_name"] = current_world_name
	save_data["world_seed"] = current_world_seed
	save_data["player_data"] = GameManager.player_data.duplicate()
	save_data["playtime"] = GameManager.get_playtime()
	
	# Collect world data from systems
	save_data["world_data"] = _collect_world_data()
	
	# Collect inventory data
	if InventoryManager and InventoryManager.has_method("get_inventory_data"):
		save_data["inventory_data"] = InventoryManager.get_inventory_data()
	
	# Collect skill data
	if SkillManager and SkillManager.has_method("get_skill_data"):
		save_data["skill_data"] = SkillManager.get_skill_data()
	
	# Collect time data
	if TimeManager and TimeManager.has_method("get_save_data"):
		save_data["time_data"] = TimeManager.get_save_data()
	
	var save_path = _get_save_file_path(current_world_name)
	var success = _save_world_data(save_data, save_path)
	
	if success:
		# Update metadata
		var metadata = _load_world_metadata(current_world_name)
		if metadata:
			metadata["last_played_timestamp"] = Time.get_unix_time_from_system()
			metadata["playtime"] = save_data["playtime"]
			metadata["has_save_file"] = true
			_save_world_metadata(metadata)
	
	save_completed.emit(success, save_path)
	return success

func load_world(world_name: String) -> bool:
	if world_name.is_empty():
		return false
	
	var metadata = _load_world_metadata(world_name)
	if not metadata:
		return false
	
	# Set current world info
	current_world_name = world_name
	current_world_seed = metadata["world_seed"]
	
	# Set up GameManager with world data
	GameManager.player_data["world_name"] = world_name
	GameManager.player_data["world_seed"] = metadata["world_seed"]
	GameManager.player_data["username"] = metadata.get("username", "Player")
	
	var success = false
	
	# Load save file if it exists
	if metadata["has_save_file"]:
		var save_path = _get_save_file_path(world_name)
		var save_data = _load_world_data(save_path)
		if save_data and is_save_data_valid(save_data):
			success = _apply_save_data(save_data)
		else:
				success = true
	else:
		# New world with just metadata
		success = true
	
	if success:
		# Update last played timestamp
		metadata["last_played_timestamp"] = Time.get_unix_time_from_system()
		_save_world_metadata(metadata)
	
	load_completed.emit(success, _get_save_file_path(world_name))
	return success

func get_available_worlds() -> Array[Dictionary]:
	var worlds: Array[Dictionary] = []
	
	# Ensure saves directory exists first
	_ensure_saves_directory()
	
	var saves_dir = DirAccess.open("user://saves/")
	if not saves_dir:
		return worlds
	
	saves_dir.list_dir_begin()
	var dir_name = saves_dir.get_next()
	var directories_found = 0
	
	
	while dir_name != "":
		if saves_dir.current_is_dir():
			directories_found += 1
			var metadata = _load_world_metadata(dir_name)
			if metadata:
				# Convert to dictionary for easier access
				var world_dict = {
					"world_name": metadata.world_name,
					"world_seed": metadata.world_seed,
					"username": metadata.get("username", "Player"),
					"creation_timestamp": metadata.creation_timestamp,
					"last_played_timestamp": metadata.last_played_timestamp,
					"playtime": metadata.playtime,
					"has_save_file": metadata.has_save_file,
					"save_version": metadata.save_version
				}
				worlds.append(world_dict)
			
		
		dir_name = saves_dir.get_next()
	
	
	saves_dir.list_dir_end()
	
	# Sort by last played timestamp (newest first)
	worlds.sort_custom(func(a: Dictionary, b: Dictionary): return a.get("last_played_timestamp", 0) > b.get("last_played_timestamp", 0))
	
	return worlds

func delete_world(world_name: String) -> bool:
	if world_name.is_empty():
		return false
	
	var world_dir = "user://saves/" + world_name + "/"
	var dir = DirAccess.open(world_dir)
	if not dir:
		return false
	
	# Remove all files in the world directory
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Remove the directory itself
	var parent_dir = DirAccess.open("user://saves/")
	var result = parent_dir.remove(world_name)
	
	if result == OK:
		return true
	else:
		return false

func start_autosave():
	if is_autosave_enabled and _autosave_timer:
		_autosave_timer.start()

func stop_autosave():
	if _autosave_timer:
		_autosave_timer.stop()

func trigger_autosave():
	if is_autosave_enabled and not current_world_name.is_empty():
		save_current_world()

func _on_autosave_timer_timeout():
	trigger_autosave()

func _collect_world_data() -> Dictionary:
	var world_data = {}
	
	# Collect from ChunkManager
	var chunk_manager = _find_chunk_manager()
	if chunk_manager and chunk_manager.has_method("get_world_save_data"):
		world_data = chunk_manager.get_world_save_data()
		
	
	return world_data

func _apply_save_data(save_data: Dictionary) -> bool:
	# Apply player data
	if save_data.has("player_data") and not save_data["player_data"].is_empty():
		GameManager.player_data = save_data["player_data"].duplicate()
	
	# Store world data for loading after scene is ready
	if save_data.has("world_data") and not save_data["world_data"].is_empty():
		_store_world_data_for_loading(save_data["world_data"])
	
	# Apply inventory data
	if save_data.has("inventory_data") and not save_data["inventory_data"].is_empty() and InventoryManager and InventoryManager.has_method("load_inventory_data"):
		InventoryManager.load_inventory_data(save_data["inventory_data"])
	
	# Apply skill data
	if save_data.has("skill_data") and not save_data["skill_data"].is_empty() and SkillManager and SkillManager.has_method("load_skill_data"):
		SkillManager.load_skill_data(save_data["skill_data"])
	
	# Apply time data
	if save_data.has("time_data") and not save_data["time_data"].is_empty() and TimeManager and TimeManager.has_method("load_save_data"):
		TimeManager.load_save_data(save_data["time_data"])
	
	return true

func _store_world_data_for_loading(world_data: Dictionary):
	# Signal that world data is ready for loading
	call_deferred("_load_world_data_to_scene", world_data)

func _load_world_data_to_scene(world_data: Dictionary):
	# Wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	var chunk_manager = _find_chunk_manager()
	if chunk_manager and chunk_manager.has_method("load_world_save_data"):
		chunk_manager.load_world_save_data(world_data)
	

func _find_chunk_manager() -> Node:
	var scene_root = get_tree().current_scene
	if not scene_root:
		return null
	
	var chunk_manager = scene_root.find_child("ChunkManager", true, false)
	if chunk_manager:
		return chunk_manager
	
	# Look for any node with ChunkManager class
	var all_nodes = scene_root.find_children("*", "ChunkManager", true, false)
	if all_nodes.size() > 0:
		return all_nodes[0]
	
	return null

func _save_world_data(save_data: Dictionary, file_path: String) -> bool:
	var temp_path = file_path + ".tmp"
	
	# Save to temporary file first
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		return false
	
	# Store as dictionary (more reliable than custom objects)
	file.store_var(save_data)
	file.close()
	
	# Verify the temporary file
	var verify_file = FileAccess.open(temp_path, FileAccess.READ)
	if not verify_file:
		return false
	
	var loaded_data = verify_file.get_var()
	verify_file.close()
	
	if not loaded_data or not loaded_data is Dictionary:
		DirAccess.open("user://").remove(temp_path)
		return false
	
	# Move temp file to final location (atomic operation)
	var dir = DirAccess.open("user://")
	if dir.file_exists(file_path):
		dir.remove(file_path)
	
	var result = dir.rename(temp_path, file_path)
	if result != OK:
		dir.remove(temp_path)
		return false
	
	return true

func _load_world_data(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	var data = file.get_var()
	file.close()
	
	if not data or not data is Dictionary:
		return {}
	
	if not is_save_data_valid(data):
		return {}
	
	return data

func _save_world_metadata(metadata: Dictionary) -> bool:
	if not metadata or metadata.is_empty():
		return false
	
	# Validate metadata before saving
	if not metadata.has("world_name") or metadata["world_name"].is_empty():
		return false
	
	var metadata_path = _get_metadata_file_path(metadata["world_name"])
	
	var temp_path = metadata_path + ".tmp"
	
	# Save to temporary file first
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		return false
	
	# Convert to JSON for better reliability and debugging
	var json_string = JSON.stringify(metadata)
	file.store_string(json_string)
	var write_error = file.get_error()
	file.close()
	
	if write_error != OK:
		DirAccess.open("user://").remove(temp_path)
		return false
	
	# Verify the temporary file was written correctly
	var temp_file_size = FileAccess.get_file_as_bytes(temp_path).size()
	
	if temp_file_size == 0:
		DirAccess.open("user://").remove(temp_path)
		return false
	
	# Test read the temporary file to ensure it's valid
	var verify_file = FileAccess.open(temp_path, FileAccess.READ)
	if not verify_file:
		DirAccess.open("user://").remove(temp_path)
		return false
	
	var verify_json = verify_file.get_as_text()
	verify_file.close()
	
	var json_parser = JSON.new()
	var parse_result = json_parser.parse(verify_json)
	if parse_result != OK:
		DirAccess.open("user://").remove(temp_path)
		return false
	
	var verify_data = json_parser.get_data()
	if not verify_data or not verify_data is Dictionary:
		DirAccess.open("user://").remove(temp_path)
		return false
	
	# Move temp file to final location (atomic operation)
	var dir = DirAccess.open("user://")
	if dir.file_exists(metadata_path):
		dir.remove(metadata_path)
	
	var result = dir.rename(temp_path, metadata_path)
	if result != OK:
		dir.remove(temp_path)
		return false
	
	
	# Final verification
	var final_file_size = FileAccess.get_file_as_bytes(metadata_path).size()
	
	if final_file_size == 0:
		return false
	
	return true

func _load_world_metadata(world_name: String) -> Dictionary:
	var metadata_path = _get_metadata_file_path(world_name)
	
	if not FileAccess.file_exists(metadata_path):
		# Check if there's an old JSON metadata file (for migration)
		var old_json_path = "user://saves/" + world_name + "/world_metadata.json"
		if FileAccess.file_exists(old_json_path):
			return _migrate_old_json_metadata(world_name, old_json_path)
		return {}
	
	
	# Check file size first
	var file_size = FileAccess.get_file_as_bytes(metadata_path).size()
	
	if file_size == 0:
		return {}
	
	var file = FileAccess.open(metadata_path, FileAccess.READ)
	if not file:
		return {}
	
	var file_error = file.get_error()
	
	# Check if we can read from the file
	var file_length = file.get_length()
	
	# Read JSON data
	var json_text = file.get_as_text()
	var read_error = file.get_error()
	file.close()
	
	if json_text.is_empty():
		return {}
	
	# Parse JSON
	var json_parser = JSON.new()
	var parse_result = json_parser.parse(json_text)
	if parse_result != OK:
		# Try to recover by recreating metadata with basic info
		var recovered_metadata = create_world_metadata()
		recovered_metadata["world_name"] = world_name
		recovered_metadata["world_seed"] = -1  # Will need to be set elsewhere
		recovered_metadata["username"] = "Player"  # Default username for recovered worlds
		if _save_world_metadata(recovered_metadata):
			return recovered_metadata
		return {}
	
	var metadata = json_parser.get_data()
	if not metadata or not metadata is Dictionary:
		return {}
	
	
	return metadata

func _migrate_old_json_metadata(world_name: String, json_path: String) -> Dictionary:
	
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_text) != OK:
		return {}
	
	var json_data = json.get_data()
	
	# Create new metadata from old JSON
	var metadata = create_world_metadata()
	metadata["world_name"] = json_data.get("world_name", world_name)
	metadata["world_seed"] = json_data.get("world_seed", -1)
	metadata["username"] = json_data.get("username", "Player")  # Default for migrated worlds
	metadata["creation_timestamp"] = json_data.get("creation_timestamp", Time.get_unix_time_from_system())
	metadata["last_played_timestamp"] = json_data.get("last_played_timestamp", metadata["creation_timestamp"])
	metadata["playtime"] = json_data.get("playtime", 0.0)
	metadata["has_save_file"] = false  # Will be updated when save is created
	
	# Save as new binary format
	if _save_world_metadata(metadata):
		return metadata
	else:
		return {}

func _get_save_file_path(world_name: String) -> String:
	return "user://saves/" + world_name + "/world" + SAVE_EXTENSION

func _get_metadata_file_path(world_name: String) -> String:
	return "user://saves/" + world_name + "/metadata" + METADATA_EXTENSION

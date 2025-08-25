class_name ChunkManager
extends Node2D

@export_group("Chunk Settings")
@export var chunk_size: int = 256
@export var load_radius: int = 2
@export var predictive_distance: int = 2
@export var unload_delay: float = 2.0

@export_group("Performance Settings")
@export var chunks_per_frame: int = 1
@export var objects_per_frame: int = 10

@onready var ground_layer: TileMapLayer
@onready var obstacle_layer: TileMapLayer
@onready var decoration_layer: TileMapLayer
@onready var elevation_layer: TileMapLayer
@onready var elevation_decoration_layer: TileMapLayer

var camera: Camera2D
var player: CharacterBody2D

var loaded_chunks: Dictionary = {}
var chunk_unload_timers: Dictionary = {}
var registered_spawners: Array[ChunkObject] = []

var obstacle_positions: Dictionary = {}
var decoration_positions: Dictionary = {}
var elevation_decoration_positions: Dictionary = {}

var world_seed: int = -1

var _camera_found_logged: bool = false
var _player_found_logged: bool = false

signal chunk_loaded(chunk_coord: Vector2i)
signal chunk_unloaded(chunk_coord: Vector2i)

class ChunkData:
	var chunk_coord: Vector2i
	var object_data: Dictionary = {}
	var is_processed: bool = false
	var is_loaded: bool = false
	var valid_tiles: Array[Dictionary] = []
	
	var is_modified: bool = false
	var generation_version: int = 1
	var last_saved_timestamp: float = 0.0
	
	func _init(coord: Vector2i):
		chunk_coord = coord
		last_saved_timestamp = Time.get_unix_time_from_system()
	
	func mark_modified():
		is_modified = true
		last_saved_timestamp = Time.get_unix_time_from_system()
	
	func set_object_data(spawner_name: String, data: Array):
		object_data[spawner_name] = data
		mark_modified()
	
	func get_object_data(spawner_name: String) -> Array:
		return object_data.get(spawner_name, [])
	
	func get_save_data() -> Dictionary:
		if not is_modified:
			return {}
		
		return {
			"chunk_coord": {"x": chunk_coord.x, "y": chunk_coord.y},
			"object_data": object_data,
			"generation_version": generation_version,
			"last_saved_timestamp": last_saved_timestamp
		}
	
	func load_save_data(save_data: Dictionary):
		if save_data.is_empty():
			return
		
		is_modified = true
		generation_version = save_data.get("generation_version", 1)
		last_saved_timestamp = save_data.get("last_saved_timestamp", 0.0)
		object_data = save_data.get("object_data", {})

func _ready():
	_find_tile_layers()
	call_deferred("_build_spatial_lookups")
	
	# Sync with SaveManager's current world seed
	call_deferred("_sync_with_save_manager")


func register_spawner(spawner: ChunkObject):
	if not spawner in registered_spawners:
		registered_spawners.append(spawner)
		spawner.chunk_manager = self
		
		# IMPORTANT: Sync world seed with newly registered spawner
		if world_seed != -1 and spawner.has_method("set_world_seed"):
			spawner.set_world_seed(world_seed)

func unregister_spawner(spawner: ChunkObject):
	registered_spawners.erase(spawner)

func _find_tile_layers():
	var main_world = get_parent()
	if main_world:
		ground_layer = main_world.get_node_or_null("GroundLayer")
		obstacle_layer = main_world.get_node_or_null("ObstacleLayer")
		decoration_layer = main_world.get_node_or_null("DecorationLayer")
		elevation_layer = main_world.get_node_or_null("ElevationLayer")
		elevation_decoration_layer = main_world.get_node_or_null("ElevationDecorationLayer")

func _build_spatial_lookups():
	obstacle_positions.clear()
	decoration_positions.clear()
	elevation_decoration_positions.clear()
	
	if obstacle_layer:
		var obstacle_cells = obstacle_layer.get_used_cells()
		for pos in obstacle_cells:
			obstacle_positions[pos] = true
	
	if decoration_layer:
		var decoration_cells = decoration_layer.get_used_cells()
		for pos in decoration_cells:
			decoration_positions[pos] = true
	
	if elevation_decoration_layer:
		var elevation_decoration_cells = elevation_decoration_layer.get_used_cells()
		for pos in elevation_decoration_cells:
			elevation_decoration_positions[pos] = true

func _find_camera_and_player():
	var scene_root = get_tree().current_scene
	if not scene_root:
		return
	
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			player = scene_root.find_child("Player", true, true)
			if not player:
				# Use custom helper to find CharacterBody2D nodes
				var character_bodies = _get_nodes_of_type_recursive(scene_root, "CharacterBody2D")
				for body in character_bodies:
					if body.has_method("is_moving"):
						player = body
						break
	
	if not camera:
		if player:
			camera = player.find_child("Camera2D", true, true)
		
		if not camera:
			camera = scene_root.find_child("Camera2D", true, true)
			
			if camera and not player and camera.get_parent():
				var camera_parent = camera.get_parent()
				if camera_parent.has_method("is_moving"):
					player = camera_parent
	
	if camera and not _camera_found_logged:
		_camera_found_logged = true
		
	if player and not _player_found_logged:
		_player_found_logged = true

func _process(delta):
	if not player or not camera:
		_find_camera_and_player()
	
	_update_chunk_loading()
	_update_unload_timers(delta)

func _update_chunk_loading():
	var camera_pos: Vector2
	
	if camera:
		camera_pos = camera.global_position
	else:
		var viewport = get_viewport()
		if viewport:
			camera_pos = viewport.get_camera_2d().global_position if viewport.get_camera_2d() else Vector2.ZERO
		else:
			camera_pos = Vector2.ZERO
	
	var camera_chunk = world_to_chunk_coord(camera_pos)
	
	var chunks_to_load = _get_chunks_to_load(camera_chunk)
	var chunks_to_unload = _get_chunks_to_unload(camera_chunk)
	
	for chunk_coord in chunks_to_unload:
		if not chunk_coord in chunk_unload_timers:
			chunk_unload_timers[chunk_coord] = unload_delay
	
	for chunk_coord in chunks_to_load:
		if chunk_coord in chunk_unload_timers:
			chunk_unload_timers.erase(chunk_coord)
	
	var loaded_this_frame = 0
	for chunk_coord in chunks_to_load:
		if loaded_this_frame >= chunks_per_frame:
			break
		
		if not chunk_coord in loaded_chunks:
			_load_chunk_async(chunk_coord)
			loaded_this_frame += 1

func _get_chunks_to_load(camera_chunk: Vector2i) -> Array[Vector2i]:
	var chunks: Array[Vector2i] = []
	
	for x in range(-load_radius, load_radius + 1):
		for y in range(-load_radius, load_radius + 1):
			chunks.append(camera_chunk + Vector2i(x, y))
	
	if player and player.has_method("is_moving") and player.is_moving():
		if player.velocity.length() > 5.0:
			var movement_dir = player.velocity.normalized()
			var movement_chunk_offset = Vector2i(
				round(movement_dir.x * predictive_distance),
				round(movement_dir.y * predictive_distance)
			)
			
			var predicted_center = camera_chunk + movement_chunk_offset
			for x in range(-1, 2):
				for y in range(-1, 2):
					var predicted_chunk = predicted_center + Vector2i(x, y)
					if not predicted_chunk in chunks:
						chunks.append(predicted_chunk)
	
	return chunks

func _get_chunks_to_unload(camera_chunk: Vector2i) -> Array[Vector2i]:
	var chunks_to_unload: Array[Vector2i] = []
	var max_distance = load_radius + predictive_distance + 1
	
	for chunk_coord in loaded_chunks.keys():
		var distance = _chunk_distance(camera_chunk, chunk_coord)
		if distance > max_distance:
			chunks_to_unload.append(chunk_coord)
	
	return chunks_to_unload

func _chunk_distance(chunk1: Vector2i, chunk2: Vector2i) -> int:
	return max(abs(chunk1.x - chunk2.x), abs(chunk1.y - chunk2.y))

func _update_unload_timers(delta: float):
	var chunks_to_remove: Array[Vector2i] = []
	
	for chunk_coord in chunk_unload_timers.keys():
		chunk_unload_timers[chunk_coord] -= delta
		if chunk_unload_timers[chunk_coord] <= 0:
			chunks_to_remove.append(chunk_coord)
	
	for chunk_coord in chunks_to_remove:
		chunk_unload_timers.erase(chunk_coord)
		_unload_chunk(chunk_coord)

func _load_chunk_async(chunk_coord: Vector2i):
	var chunk_data: ChunkData
	
	# Check if chunk data already exists (from save file loading)
	if chunk_coord in loaded_chunks:
		chunk_data = loaded_chunks[chunk_coord]
	else:
		# Create new chunk data
		chunk_data = ChunkData.new(chunk_coord)
		loaded_chunks[chunk_coord] = chunk_data
	
	_process_chunk_async(chunk_data)

func _process_chunk_async(chunk_data: ChunkData):
	if chunk_data.is_processed:
		_instantiate_chunk_objects(chunk_data)
		return
	
	var chunk_world_rect = chunk_to_world_rect(chunk_data.chunk_coord)
	chunk_data.valid_tiles = find_valid_grass_in_chunk(chunk_world_rect)
	
	# Only process spawners if any are registered (currently disabled for no random generation)
	if registered_spawners.size() > 0:
		for spawner in registered_spawners:
			if spawner:
				spawner.generate_for_chunk(chunk_data)
	
	chunk_data.is_processed = true
	
	call_deferred("_instantiate_chunk_objects", chunk_data)

func _instantiate_chunk_objects(chunk_data: ChunkData):
	if chunk_data.is_loaded:
		return
	
	# Only instantiate objects if spawners are registered (currently disabled for no random generation)
	if registered_spawners.size() > 0:
		for spawner in registered_spawners:
			if spawner:
				spawner.instantiate_for_chunk(chunk_data)
	
	chunk_data.is_loaded = true
	chunk_loaded.emit(chunk_data.chunk_coord)
	
	# Debug logging removed
	pass

func _unload_chunk(chunk_coord: Vector2i):
	if not chunk_coord in loaded_chunks:
		return
	
	var chunk_data = loaded_chunks[chunk_coord]
	
	# Only cleanup spawners if any are registered (currently disabled for no random generation)
	if registered_spawners.size() > 0:
		for spawner in registered_spawners:
			if spawner:
				spawner.cleanup_for_chunk(chunk_data)
	
	if chunk_coord in loaded_chunks:
		loaded_chunks[chunk_coord].is_loaded = false
	
	chunk_unloaded.emit(chunk_coord)

func world_to_chunk_coord(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.y / chunk_size))
	)

func chunk_to_world_rect(chunk_coord: Vector2i) -> Rect2:
	var world_pos = Vector2(chunk_coord.x * chunk_size, chunk_coord.y * chunk_size)
	return Rect2(world_pos, Vector2(chunk_size, chunk_size))

	


func find_valid_grass_in_chunk(chunk_rect: Rect2) -> Array[Dictionary]:
	var valid_positions: Array[Dictionary] = []
	
	if not ground_layer:
		return valid_positions
	
	var start_tile = ground_layer.local_to_map(chunk_rect.position)
	var end_tile = ground_layer.local_to_map(chunk_rect.position + chunk_rect.size)
	
	for x in range(start_tile.x, end_tile.x + 1):
		for y in range(start_tile.y, end_tile.y + 1):
			var tile_pos = Vector2i(x, y)
			
			if is_grass_middle_tile(tile_pos):
				if not obstacle_positions.has(tile_pos) and not decoration_positions.has(tile_pos) and not elevation_decoration_positions.has(tile_pos):
					var world_pos = ground_layer.map_to_local(tile_pos)
					valid_positions.append({
						"tile_pos": tile_pos,
						"world_pos": world_pos
					})
	
	return valid_positions

func is_grass_middle_tile(cell_pos: Vector2i) -> bool:
	if not ground_layer:
		return false
		
	var source_id = ground_layer.get_cell_source_id(cell_pos)
	var atlas_coords = ground_layer.get_cell_atlas_coords(cell_pos)
	
	if source_id < 0:
		return false
	
	var tile_set = ground_layer.tile_set
	if not tile_set:
		return false
	
	var source = tile_set.get_source(source_id)
	if not source or not source is TileSetAtlasSource:
		return false
	
	var atlas_source = source as TileSetAtlasSource
	var texture = atlas_source.texture
	
	if texture and texture.resource_path.contains("Grass_1_Middle"):
		return true
	
	if source_id == 0 and atlas_coords == Vector2i(0, 0):
		if texture and texture.resource_path.ends_with("Grass_1_Middle.png"):
			return true
	
	return false

func get_tile_distance(pos1: Vector2i, pos2: Vector2i) -> float:
	var dx = pos1.x - pos2.x
	var dy = pos1.y - pos2.y
	return sqrt(dx * dx + dy * dy)

func is_position_occupied(world_pos: Vector2, radius: float) -> bool:
	# Check existing spawned objects
	for spawner in registered_spawners:
		if spawner and spawner.is_position_occupied(world_pos, radius):
			return true
	
	return false

func clear_all_objects():
	# DISABLED: Random tree and flower generation
	# for chunk_coord in loaded_chunks.keys():
	# 	_unload_chunk(chunk_coord)
	# 
	# loaded_chunks.clear()
	# chunk_unload_timers.clear()
	pass

func get_debug_info() -> Dictionary:
	var info = {
		"loaded_chunks": loaded_chunks.size(),
		"chunks_pending_unload": chunk_unload_timers.size(),
		"registered_spawners": registered_spawners.size()
	}
	
	for spawner in registered_spawners:
		if spawner:
			info[spawner.get_spawner_name()] = spawner.get_debug_info()
	
	return info

func get_world_save_data() -> Dictionary:
	var save_data = {
		"world_seed": world_seed,
		"chunk_modifications": {},
		"generation_version": 1
	}
	
	var modified_chunks = 0
	for chunk_coord in loaded_chunks.keys():
		var chunk_data = loaded_chunks[chunk_coord]
		var chunk_save_data = chunk_data.get_save_data()
		if not chunk_save_data.is_empty():
			var coord_key = str(chunk_coord.x) + "," + str(chunk_coord.y)
			save_data.chunk_modifications[coord_key] = chunk_save_data
			modified_chunks += 1
	
	
	return save_data

func load_world_save_data(save_data: Dictionary):
	if save_data.is_empty():
		return
	
	# Load world seed and propagate to spawners
	var saved_seed = save_data.get("world_seed", -1)
	if saved_seed != -1:
		world_seed = saved_seed
		# Propagate seed to spawners WITHOUT clearing chunks (since we're about to load them)
		for spawner in registered_spawners:
			if spawner and spawner.has_method("set_world_seed"):
				spawner.set_world_seed(saved_seed)
	
	var chunk_modifications = save_data.get("chunk_modifications", {})
	var loaded_modifications = 0
	for coord_key in chunk_modifications.keys():
		var coord_parts = coord_key.split(",")
		var chunk_coord = Vector2i(int(coord_parts[0]), int(coord_parts[1]))
		
		if not chunk_coord in loaded_chunks:
			loaded_chunks[chunk_coord] = ChunkData.new(chunk_coord)
		
		var chunk_data = loaded_chunks[chunk_coord]
		chunk_data.load_save_data(chunk_modifications[coord_key])
		loaded_modifications += 1
	
	
	# Instantiate objects for loaded chunks
	for chunk_coord in chunk_modifications.keys():
		var coord_parts = chunk_coord.split(",")
		var coord = Vector2i(int(coord_parts[0]), int(coord_parts[1]))
		var chunk_data = loaded_chunks[coord]
		
		# Mark chunk as processed so it doesn't regenerate
		chunk_data.is_processed = true
		
		# Instantiate the saved objects
		_instantiate_chunk_objects(chunk_data)
	
	# Validate consistency after loading
	var validation = validate_terrain_consistency()
	# Validation logging removed
	pass

func set_world_seed(new_seed: int):
	"""Set world seed and propagate to all registered spawners"""
	if world_seed == new_seed:
		return  # No change needed
	
	world_seed = new_seed
	for spawner in registered_spawners:
		if spawner and spawner.has_method("set_world_seed"):
			spawner.set_world_seed(new_seed)
	
	# Clear existing chunks to force regeneration with new seed
	if new_seed != -1:
		clear_all_objects()

func get_world_seed() -> int:
	"""Get the current world seed"""
	return world_seed

func validate_terrain_consistency() -> Dictionary:
	"""Validate that terrain generation is consistent"""
	var validation_result = {
		"is_valid": true,
		"errors": [],
		"warnings": [],
		"info": {}
	}
	
	# Check if world seed is set
	if world_seed == -1:
		validation_result.warnings.append("World seed not set - terrain may not be deterministic")
	else:
		validation_result.info["world_seed"] = world_seed
	
	# Check spawner consistency
	var spawner_seeds = {}
	for spawner in registered_spawners:
		if spawner and spawner.has_method("get_world_seed"):
			var spawner_seed = spawner.get_world_seed()
			spawner_seeds[spawner.get_spawner_name()] = spawner_seed
			
			if spawner_seed != world_seed:
				validation_result.errors.append("Spawner " + spawner.get_spawner_name() + " has mismatched seed: " + str(spawner_seed) + " vs " + str(world_seed))
				validation_result.is_valid = false
	
	validation_result.info["spawner_seeds"] = spawner_seeds
	validation_result.info["loaded_chunks"] = loaded_chunks.size()
	validation_result.info["registered_spawners"] = registered_spawners.size()
	
	return validation_result


func regenerate_terrain():
	"""Clear and regenerate all terrain objects"""
	
	# DISABLED: Random tree and flower generation
	# Clear all loaded chunks
	# for chunk_coord in loaded_chunks.keys():
	# 	_unload_chunk(chunk_coord)
	pass
	
	# Clear chunk data but preserve modifications
	var preserved_modifications = {}
	for chunk_coord in loaded_chunks.keys():
		var chunk_data = loaded_chunks[chunk_coord]
		if chunk_data.is_modified:
			preserved_modifications[chunk_coord] = chunk_data.get_save_data()
	
	loaded_chunks.clear()
	chunk_unload_timers.clear()
	
	# Restore modifications
	for chunk_coord in preserved_modifications.keys():
		var chunk_data = ChunkData.new(chunk_coord)
		chunk_data.load_save_data(preserved_modifications[chunk_coord])
		loaded_chunks[chunk_coord] = chunk_data
	






func _get_nodes_of_type_recursive(node: Node, target_class: String) -> Array[Node]:
	"""Recursively collect all nodes of the specified class type"""
	var result: Array[Node] = []
	
	# Check if current node matches the class name
	if node.get_class() == target_class or node.is_class(target_class):
		result.append(node)
	
	# Check children recursively
	for child in node.get_children():
		result.append_array(_get_nodes_of_type_recursive(child, target_class))
	
	return result




func _sync_with_save_manager():
	"""Sync world seed with SaveManager if available"""
	if SaveManager and SaveManager.current_world_seed != -1:
		var save_manager_seed = SaveManager.current_world_seed
		if world_seed != save_manager_seed:
			set_world_seed(save_manager_seed)  # This will set is_ready_for_generation = true

extends Node

signal path_data_saved(chunk_coord: Vector2i, data: Dictionary)
signal path_data_loaded(chunk_coord: Vector2i, data: Dictionary)

var chunk_manager: ChunkManager
var ground_layer: TileMapLayer

const PATH_DATA_KEY: String = "paths"

func _ready() -> void:
	name = "PathModificationData"
	call_deferred("_initialize")

func _initialize() -> void:
	_find_dependencies()
	_connect_signals()

func _find_dependencies() -> void:
	var main_world = get_tree().get_first_node_in_group("main_world")
	if main_world:
		chunk_manager = main_world.get_node("ChunkManager")
		ground_layer = main_world.get_node("GroundLayer")
	
	if not chunk_manager:
		push_warning("PathModificationData: ChunkManager not found")
	if not ground_layer:
		push_warning("PathModificationData: GroundLayer not found")

func _connect_signals() -> void:
	if chunk_manager:
		chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
		chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)

func record_path_placement(world_position: Vector2, terrain_type: int) -> void:
	if not chunk_manager or not ground_layer:
		return
	
	var map_position = ground_layer.local_to_map(world_position)
	var chunk_coord = _world_to_chunk_coord(world_position)
	
	_ensure_chunk_exists(chunk_coord)
	
	var chunk_data = chunk_manager.loaded_chunks.get(chunk_coord)
	if not chunk_data:
		return
	
	# Get or create path data for this chunk
	var path_data = chunk_data.object_data.get(PATH_DATA_KEY, {})
	
	# Store the path modification
	var tile_key = str(map_position.x) + "," + str(map_position.y)
	path_data[tile_key] = {
		"position": {"x": map_position.x, "y": map_position.y},
		"terrain_type": terrain_type,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Update the chunk data
	chunk_data.object_data[PATH_DATA_KEY] = path_data
	chunk_data.is_modified = true

func get_path_data_for_chunk(chunk_coord: Vector2i) -> Dictionary:
	if not chunk_manager:
		return {}
	
	var chunk_data = chunk_manager.loaded_chunks.get(chunk_coord)
	if not chunk_data:
		return {}
	
	return chunk_data.object_data.get(PATH_DATA_KEY, {})

func apply_path_data_to_chunk(chunk_coord: Vector2i) -> void:
	if not ground_layer:
		return
	
	var path_data = get_path_data_for_chunk(chunk_coord)
	
	for tile_key in path_data.keys():
		var tile_info = path_data[tile_key]
		var map_position = Vector2i(tile_info.position.x, tile_info.position.y)
		var terrain_type = tile_info.terrain_type
		
		# Apply the path modification using Better Terrain
		BetterTerrain.set_cell(ground_layer, map_position, terrain_type)
	
	# Update the terrain for all modified cells at once
	# Skip terrain updates in editor mode to avoid interfering with Better Terrain editor
	if Engine.is_editor_hint():
		return
	
	if path_data.size() > 0:
		var modified_positions = []
		for tile_key in path_data.keys():
			var tile_info = path_data[tile_key]
			modified_positions.append(Vector2i(tile_info.position.x, tile_info.position.y))
		
		# Update cells without expanding to surrounding cells to avoid editor interference
		BetterTerrain.update_terrain_cells(ground_layer, modified_positions, false)

func _world_to_chunk_coord(world_position: Vector2) -> Vector2i:
	if not chunk_manager:
		return Vector2i.ZERO
	
	var chunk_size = chunk_manager.chunk_size
	return Vector2i(
		int(floor(world_position.x / chunk_size)),
		int(floor(world_position.y / chunk_size))
	)

func _ensure_chunk_exists(chunk_coord: Vector2i) -> void:
	if not chunk_manager:
		return
	
	if not chunk_manager.loaded_chunks.has(chunk_coord):
		# Create new chunk data
		var chunk_data = chunk_manager.ChunkData.new(chunk_coord)
		chunk_manager.loaded_chunks[chunk_coord] = chunk_data

func _on_chunk_loaded(chunk_coord: Vector2i) -> void:
	# Apply any saved path modifications to this chunk
	call_deferred("apply_path_data_to_chunk", chunk_coord)
	
	var path_data = get_path_data_for_chunk(chunk_coord)
	if path_data.size() > 0:
		path_data_loaded.emit(chunk_coord, path_data)

func _on_chunk_unloaded(chunk_coord: Vector2i) -> void:
	# Path data is automatically saved as part of chunk data
	var path_data = get_path_data_for_chunk(chunk_coord)
	if path_data.size() > 0:
		path_data_saved.emit(chunk_coord, path_data)

func get_path_count_in_chunk(chunk_coord: Vector2i) -> int:
	var path_data = get_path_data_for_chunk(chunk_coord)
	return path_data.size()

func get_total_path_count() -> int:
	if not chunk_manager:
		return 0
	
	var total = 0
	for chunk_coord in chunk_manager.loaded_chunks.keys():
		total += get_path_count_in_chunk(chunk_coord)
	
	return total

func clear_all_paths() -> void:
	if not chunk_manager:
		return
	
	for chunk_coord in chunk_manager.loaded_chunks.keys():
		var chunk_data = chunk_manager.loaded_chunks[chunk_coord]
		if chunk_data.object_data.has(PATH_DATA_KEY):
			chunk_data.object_data.erase(PATH_DATA_KEY)
			chunk_data.is_modified = true

func remove_path_at_position(world_position: Vector2) -> bool:
	if not chunk_manager or not ground_layer:
		return false
	
	var map_position = ground_layer.local_to_map(world_position)
	var chunk_coord = _world_to_chunk_coord(world_position)
	
	var chunk_data = chunk_manager.loaded_chunks.get(chunk_coord)
	if not chunk_data:
		return false
	
	var path_data = chunk_data.object_data.get(PATH_DATA_KEY, {})
	var tile_key = str(map_position.x) + "," + str(map_position.y)
	
	if path_data.has(tile_key):
		path_data.erase(tile_key)
		chunk_data.object_data[PATH_DATA_KEY] = path_data
		chunk_data.is_modified = true
		return true
	
	return false

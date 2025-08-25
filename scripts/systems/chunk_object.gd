class_name ChunkObject
extends Node

@export_group("Spawner Settings")
@export var spawner_name: String = ""
@export var density: float = 0.05
@export var min_spacing: int = 5
@export var exclusion_radius: float = 8.0
@export var objects_per_frame: int = 5
@export var enabled: bool = true

var chunk_manager: ChunkManager
var object_pools: Dictionary = {}
var active_objects: Dictionary = {}

func _ready():
	if spawner_name.is_empty():
		spawner_name = get_script().get_path().get_file().get_basename()
	
	call_deferred("_register_with_chunk_manager")

func _register_with_chunk_manager():
	var manager = get_tree().get_first_node_in_group("chunk_managers")
	if not manager:
		var parent = get_parent()
		while parent:
			if parent.has_method("register_spawner"):
				manager = parent
				break
			parent = parent.get_parent()
	
	if manager:
		manager.register_spawner(self)

func get_spawner_name() -> String:
	return spawner_name

func generate_for_chunk(chunk_data) -> void:
	if not enabled:
		return
	
	var existing_data = chunk_data.get_object_data(spawner_name)
	if existing_data.size() > 0:
		# For flower spawner, check if we need to regenerate due to collision detection fix
		if spawner_name == "flowers" and chunk_data.generation_version < 2:
			chunk_data.generation_version = 2
			chunk_data.set_object_data(spawner_name, [])  # Clear existing data
		else:
			return
	
	var selected_positions = _select_positions_for_chunk(chunk_data)
	chunk_data.set_object_data(spawner_name, selected_positions)

func _select_positions_for_chunk(chunk_data) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	var valid_positions = chunk_data.valid_tiles.duplicate()
	
	if valid_positions.is_empty():
		return selected
	
	var target_count = min(int(valid_positions.size() * density), get_max_objects_per_chunk())
	valid_positions.shuffle()
	
	var attempts = 0
	var max_attempts = valid_positions.size() * 2
	
	for pos_data in valid_positions:
		if selected.size() >= target_count or attempts >= max_attempts:
			break
		
		if _is_position_valid_for_spawning(pos_data, selected, chunk_data):
			selected.append(pos_data)
		
		attempts += 1
	
	return selected

func _is_position_valid_for_spawning(pos_data: Dictionary, existing_positions: Array[Dictionary], chunk_data) -> bool:
	var tile_pos = pos_data.tile_pos
	var world_pos = pos_data.world_pos
	
	for existing_data in existing_positions:
		var distance = chunk_manager.get_tile_distance(tile_pos, existing_data.tile_pos)
		if distance < min_spacing:
			return false
	
	if chunk_manager and chunk_manager.is_position_occupied(world_pos, exclusion_radius):
		return false
	
	var current_chunk = chunk_manager.world_to_chunk_coord(world_pos)
	
	for x in range(-1, 2):
		for y in range(-1, 2):
			var neighbor_chunk = current_chunk + Vector2i(x, y)
			if neighbor_chunk in chunk_manager.loaded_chunks:
				var neighbor_data = chunk_manager.loaded_chunks[neighbor_chunk]
				if neighbor_data.is_processed:
					var neighbor_objects = neighbor_data.get_object_data(spawner_name)
					for obj_data in neighbor_objects:
						var distance = chunk_manager.get_tile_distance(tile_pos, obj_data.tile_pos)
						if distance < min_spacing:
							return false
	
	return true

func instantiate_for_chunk(chunk_data) -> void:
	if not enabled:
		return
	
	var chunk_coord = chunk_data.chunk_coord
	var object_data = chunk_data.get_object_data(spawner_name)
	
	if object_data.is_empty():
		return
	
	var objects_for_chunk: Array[Node] = []
	var objects_created = 0
	
	for obj_data in object_data:
		if objects_created >= objects_per_frame:
			call_deferred("_continue_chunk_instantiation", chunk_data, objects_for_chunk.size())
			return
		
		var instance = _create_object_instance(obj_data)
		if instance:
			_configure_object(instance, obj_data)
			chunk_manager.add_child(instance)
			objects_for_chunk.append(instance)
			objects_created += 1
	
	active_objects[chunk_coord] = objects_for_chunk

func _continue_chunk_instantiation(chunk_data, start_index: int):
	if not chunk_data.chunk_coord in chunk_manager.loaded_chunks:
		return
	
	var chunk_coord = chunk_data.chunk_coord
	var objects_for_chunk = active_objects.get(chunk_coord, [])
	var object_data = chunk_data.get_object_data(spawner_name)
	var objects_created = 0
	
	for i in range(start_index, object_data.size()):
		if objects_created >= objects_per_frame:
			call_deferred("_continue_chunk_instantiation", chunk_data, i)
			return
		
		var obj_data = object_data[i]
		var instance = _create_object_instance(obj_data)
		if instance:
			_configure_object(instance, obj_data)
			chunk_manager.add_child(instance)
			objects_for_chunk.append(instance)
			objects_created += 1
	
	active_objects[chunk_coord] = objects_for_chunk

func cleanup_for_chunk(chunk_data) -> void:
	var chunk_coord = chunk_data.chunk_coord
	
	if chunk_coord in active_objects:
		for obj in active_objects[chunk_coord]:
			_return_to_pool(obj)
		active_objects.erase(chunk_coord)

func _create_object_instance(object_data: Dictionary) -> Node:
	# Override in derived classes
	return null

func _configure_object(instance: Node, object_data: Dictionary) -> void:
	# Basic configuration - set position
	if "world_pos" in object_data:
		if instance.has_method("set_global_position"):
			instance.global_position = object_data.world_pos
		elif "global_position" in instance:
			instance.global_position = object_data.world_pos

func _return_to_pool(obj: Node):
	if obj.get_parent():
		obj.get_parent().remove_child(obj)
	
	var pool_key = _get_pool_key(obj)
	if not pool_key in object_pools:
		object_pools[pool_key] = []
	
	_reset_object_for_pool(obj)
	object_pools[pool_key].append(obj)

func _get_from_pool(pool_key: String) -> Node:
	if pool_key in object_pools and object_pools[pool_key].size() > 0:
		var obj = object_pools[pool_key].pop_back()
		_restore_object_from_pool(obj)
		return obj
	return null

func _get_pool_key(obj: Node) -> String:
	return "default"

func _reset_object_for_pool(obj: Node):
	# Override in derived classes for cleanup
	pass

func _restore_object_from_pool(obj: Node):
	# Override in derived classes for restoration
	pass

func get_max_objects_per_chunk() -> int:
	return 100

func is_position_occupied(world_pos: Vector2, radius: float) -> bool:
	for chunk_objects in active_objects.values():
		for obj in chunk_objects:
			if "global_position" in obj:
				if obj.global_position.distance_to(world_pos) < radius:
					return true
	return false

func get_debug_info() -> Dictionary:
	var total_active = 0
	for chunk_objects in active_objects.values():
		total_active += chunk_objects.size()
	
	var total_pooled = 0
	for pool in object_pools.values():
		total_pooled += pool.size()
	
	return {
		"active_objects": total_active,
		"pooled_objects": total_pooled,
		"active_chunks": active_objects.size(),
		"density": density,
		"enabled": enabled
	}

func clear_all_objects():
	for chunk_coord in active_objects.keys():
		for obj in active_objects[chunk_coord]:
			_return_to_pool(obj)
	
	active_objects.clear()


func remove_object_at_position(world_pos: Vector2) -> bool:
	if not chunk_manager:
		return false
	
	var chunk_coord = chunk_manager.world_to_chunk_coord(world_pos)
	
	if not chunk_coord in chunk_manager.loaded_chunks:
		return false
	
	var chunk_data = chunk_manager.loaded_chunks[chunk_coord]
	
	if chunk_coord in active_objects:
		var objects_in_chunk = active_objects[chunk_coord]
		for i in range(objects_in_chunk.size() - 1, -1, -1):
			var obj = objects_in_chunk[i]
			if "global_position" in obj and obj.global_position.distance_to(world_pos) < 8.0:
				_return_to_pool(obj)
				objects_in_chunk.remove_at(i)
				break
	
	var object_data = chunk_data.get_object_data(spawner_name)
	for i in range(object_data.size() - 1, -1, -1):
		var obj_data = object_data[i]
		if obj_data.has("world_pos") and obj_data.world_pos.distance_to(world_pos) < 8.0:
			object_data.remove_at(i)
			chunk_data.set_object_data(spawner_name, object_data)
			return true
	
	return false
extends Node

# Test to verify that newly explored chunks get marked as modified and saved

func _ready():
	await get_tree().create_timer(3.0).timeout  # Wait for world to load
	
	# Find chunk manager
	var chunk_manager = get_tree().get_first_node_in_group("chunk_managers")
	if not chunk_manager:
		return
	
	
	# Check current save data
	var initial_save_data = chunk_manager.get_world_save_data()
	var initial_modified = initial_save_data.get("chunk_modifications", {}).size()
	
	# Wait a bit more for player movement and new chunks
	await get_tree().create_timer(5.0).timeout
	
	
	# Check modified chunks after exploration
	var final_save_data = chunk_manager.get_world_save_data()
	var final_modified = final_save_data.get("chunk_modifications", {}).size()
	
	if final_modified > initial_modified:
		pass
	else:
		pass
	
	for coord in chunk_manager.loaded_chunks.keys():
		var chunk_data = chunk_manager.loaded_chunks[coord] 
		var is_modified = chunk_data.is_modified if chunk_data.has_method("is_modified") or "is_modified" in chunk_data else "unknown"
	

extends Node

# Test script to verify terrain seed fix
func _ready():
	
	# Wait a bit for the scene to initialize
	await get_tree().create_timer(1.0).timeout
	
	# Find the chunk manager
	var chunk_manager = get_tree().get_first_node_in_group("chunk_managers")
	if not chunk_manager:
		return
	
	
	# Test terrain consistency
	var world_manager = get_tree().get_first_node_in_group("world_managers")
	if world_manager and world_manager.has_method("test_terrain_consistency"):
		var results = world_manager.test_terrain_consistency()
		
		if results.success:
			pass
		else:
			pass
		
		if results.errors.size() > 0:
			for error in results.errors:
				pass
		
		if results.warnings.size() > 0:
			for warning in results.warnings:
				pass
	

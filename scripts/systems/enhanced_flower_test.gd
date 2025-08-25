extends Node

@export var auto_test_on_ready: bool = false

func _ready():
 
	
	if auto_test_on_ready:
		call_deferred("run_auto_test")

func _input(event):
	if event.is_action_pressed("ui_accept"):  # F1 equivalent
		test_debug_info()
	elif event.is_action_pressed("ui_cancel"):  # F2 equivalent  
		test_regeneration()
	elif event.is_action_pressed("ui_select"):  # F3 equivalent
		test_toggle_coherence()
	elif event.is_action_pressed("ui_home"):  # F4 equivalent
		test_toggle_rotation()
	elif event.is_action_pressed("ui_end"):  # F5 equivalent
		test_clear_cache()

func test_debug_info():
	
	var world_manager = get_tree().get_first_node_in_group("world_managers")
	if not world_manager:
		return
	
	var chunk_manager = world_manager.chunk_manager
	if not chunk_manager:
		return
	
	var flower_spawner = null
	for spawner in chunk_manager.registered_spawners:
		if spawner.get_spawner_name() == "flowers":
			flower_spawner = spawner
			break
	
	if not flower_spawner:
		return
	
	
	# Test TreeCollisionHelper
	var collision_data = TreeCollisionHelper.get_tree_collision_data("res://scenes/environment/Tree1.tscn")
	if collision_data:
	else:
	
	# Test distance calculation
	var test_distance = TreeCollisionHelper.get_distance_to_tree(
		Vector2(100, 100), Vector2(50, 50), "res://scenes/environment/Tree1.tscn"
	)
	
	# Show flower spawner settings
	
	# Show cache stats
	
	var debug_info = flower_spawner.get_debug_info()
	

func test_regeneration():
	
	var world_manager = get_tree().get_first_node_in_group("world_managers")
	if world_manager and world_manager.chunk_manager:
		world_manager.chunk_manager.clear_all_objects()
	else:

func test_toggle_coherence():
	var flower_spawner = _find_flower_spawner()
	if flower_spawner:
		flower_spawner.patch_coherence = !flower_spawner.patch_coherence
	else:

func test_toggle_rotation():
	var flower_spawner = _find_flower_spawner()
	if flower_spawner:
		flower_spawner.rotation_enabled = !flower_spawner.rotation_enabled
	else:

func test_clear_cache():
	TreeCollisionHelper.clear_caches()

func run_auto_test():
	await get_tree().process_frame
	
	test_debug_info()
	
	test_regeneration()
	
	await get_tree().create_timer(2.0).timeout
	
	test_toggle_coherence()
	test_toggle_rotation()
	
	await get_tree().create_timer(1.0).timeout
	
	test_regeneration()

func _find_flower_spawner():
	var world_manager = get_tree().get_first_node_in_group("world_managers")
	if not world_manager or not world_manager.chunk_manager:
		return null
	
	for spawner in world_manager.chunk_manager.registered_spawners:
		if spawner.get_spawner_name() == "flowers":
			return spawner
	
	return null

func create_performance_report() -> Dictionary:
	var report = {}
	
	var flower_spawner = _find_flower_spawner()
	if flower_spawner:
		report["flower_debug"] = flower_spawner.get_debug_info()
	
	report["cache_stats"] = {
		"collision_cache_size": TreeCollisionHelper.collision_cache.size(),
		"distance_cache_size": TreeCollisionHelper.distance_cache.size(),
		"cache_clear_counter": TreeCollisionHelper.cache_clear_counter
	}
	
	return report
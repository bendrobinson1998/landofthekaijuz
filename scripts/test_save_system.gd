extends Node

# Test script for the new save system
# This can be attached to any node and run in debug mode

func _ready():
	test_save_system()

func test_save_system():
	
	# Test 1: Create a new world
	var test_world_name = "TestWorld_" + str(Time.get_unix_time_from_system())
	var test_seed = 12345
	
	var create_success = SaveManager.create_new_world(test_world_name, test_seed, "TestPlayer")
	if create_success:
	else:
		return
	
	# Test 2: Save the world
	# Set some player data
	GameManager.player_data["position"] = Vector2(100, 200)
	GameManager.player_data["level"] = 5
	GameManager.player_data["health"] = 75
	
	var save_success = SaveManager.save_current_world()
	if save_success:
	else:
		return
	
	# Test 3: List available worlds
	var worlds = SaveManager.get_available_worlds()
	for world in worlds:
	
	# Test 4: Load the world
	# Clear current data first
	GameManager.player_data = {"position": Vector2.ZERO, "level": 1, "health": 100}
	SaveManager.current_world_name = ""
	SaveManager.current_world_seed = -1
	
	var load_success = SaveManager.load_world(test_world_name)
	if load_success:
	else:
		return
	
	# Test 5: Verify data integrity
	var position_correct = GameManager.player_data.get("position", Vector2.ZERO) == Vector2(100, 200)
	var level_correct = GameManager.player_data.get("level", 1) == 5
	var health_correct = GameManager.player_data.get("health", 100) == 75
	
	if position_correct and level_correct and health_correct:
	else:
	
	# Test 6: Clean up test world
	var delete_success = SaveManager.delete_world(test_world_name)
	if delete_success:
	else:
	

func test_chunk_manager_integration():
	
	# Find chunk manager
	var chunk_manager = get_tree().get_first_node_in_group("chunk_managers")
	if not chunk_manager:
		return
	
	
	# Test seed synchronization
	if SaveManager.current_world_seed != -1:
		var cm_seed = chunk_manager.get_world_seed()
		if cm_seed == SaveManager.current_world_seed:
		else:
	
	# Test world data collection
	var world_data = chunk_manager.get_world_save_data()
	

func _input(event):
	# Press F9 to run the test
	if event.is_action_pressed("ui_accept") and Input.is_action_pressed("ui_cancel"):
		test_save_system()
		test_chunk_manager_integration()
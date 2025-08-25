extends Node

# Quick test script to verify save system is working
func _ready():
	
	# Test 1: Create metadata dictionary
	var metadata = SaveManager.create_world_metadata()
	metadata["world_name"] = "TestWorld"
	metadata["world_seed"] = 12345
	
	# Test 2: Create save data dictionary
	var save_data = SaveManager.create_world_save_data()
	save_data["world_name"] = "TestWorld"
	save_data["world_seed"] = 12345
	save_data["player_data"] = {"position": Vector2(100, 200)}
	
	# Test 3: Validate save data
	var is_valid = SaveManager.is_save_data_valid(save_data)
	
	# Test 4: Create a new world
	var test_world_name = "FixedTestWorld_" + str(Time.get_unix_time_from_system())
	var success = SaveManager.create_new_world(test_world_name, 99999, "FixTestPlayer")
	
	# Test 5: List worlds
	var worlds = SaveManager.get_available_worlds()
	for world in worlds:
		pass
	
	# Test 6: Clean up test world
	if SaveManager.current_world_name == test_world_name:
		SaveManager.delete_world(test_world_name)
	

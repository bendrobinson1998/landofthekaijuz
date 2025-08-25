extends Node

func _ready():
	test_time_system()

func test_time_system():
	print("=== Time System Integration Test ===")
	
	# Test 1: Check if TimeManager exists and is working
	print("Test 1: TimeManager availability")
	if TimeManager:
		print("✓ TimeManager is available")
		print("  Current time: ", TimeManager.get_current_time_string())
		print("  Current day: ", TimeManager.get_current_day_string())
		print("  Is day time: ", TimeManager.is_day_time)
		print("  Time period: ", TimeManager.get_time_period())
	else:
		print("✗ TimeManager not found")
		return
	
	# Test 2: Test time progression
	print("\nTest 2: Time progression")
	var initial_minute = TimeManager.current_minute
	print("  Initial minute: ", initial_minute)
	
	# Wait a moment and check if time is advancing
	await get_tree().create_timer(2.0).timeout
	print("  After 2 seconds, minute is: ", TimeManager.current_minute)
	
	if TimeManager.current_minute != initial_minute:
		print("✓ Time is progressing correctly")
	else:
		print("✗ Time is not progressing")
	
	# Test 3: Test time manipulation
	print("\nTest 3: Time manipulation")
	var old_hour = TimeManager.current_hour
	TimeManager.set_time(1, 12, 30)
	print("  Set time to Day 1, 12:30")
	print("  New time: ", TimeManager.get_current_time_string())
	print("  Is day time: ", TimeManager.is_day_time)
	
	if TimeManager.current_hour == 12:
		print("✓ Time setting works correctly")
	else:
		print("✗ Time setting failed")
	
	# Test 4: Test day/night transition
	print("\nTest 4: Day/night cycle")
	TimeManager.set_time(1, 21, 0)  # Set to night time
	print("  Set time to 21:00 (9 PM)")
	print("  Is day time: ", TimeManager.is_day_time)
	print("  Time period: ", TimeManager.get_time_period())
	
	if not TimeManager.is_day_time:
		print("✓ Night time detection works")
	else:
		print("✗ Night time detection failed")
	
	# Test 5: Test save/load data structure
	print("\nTest 5: Save/load data structure")
	var save_data = TimeManager.get_save_data()
	print("  Save data keys: ", save_data.keys())
	
	if save_data.has("current_day") and save_data.has("current_hour") and save_data.has("current_minute"):
		print("✓ Save data structure is correct")
	else:
		print("✗ Save data structure is missing required keys")
	
	# Test load
	TimeManager.set_time(1, 8, 15)  # Reset to starting time
	TimeManager.load_save_data(save_data)
	print("  After loading save data:")
	print("    Time: ", TimeManager.get_current_time_string())
	print("    Day: ", TimeManager.get_current_day_string())
	
	# Test 6: Test time utilities
	print("\nTest 6: Time utilities")
	var progress = TimeManager.get_day_progress()
	print("  Day progress (0.0 to 1.0): ", progress)
	
	var is_between = TimeManager.is_between_hours(20, 6)  # Night hours
	print("  Is between 20:00-06:00: ", is_between)
	
	if progress >= 0.0 and progress <= 1.0:
		print("✓ Day progress calculation works")
	else:
		print("✗ Day progress calculation failed")
	
	print("\n=== Time System Test Complete ===")
	print("Time system is ready for use!")
	print("- Time starts at 8:15 AM on Day 1")
	print("- 1 real second = 1 in-game minute") 
	print("- Day lasts 15 real minutes (6 AM - 9 PM)")
	print("- Night lasts 9 real minutes (9 PM - 6 AM)")
	print("- Full day cycle = 24 real minutes")
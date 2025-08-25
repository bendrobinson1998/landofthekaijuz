extends Node

# Test script for tree respawn functionality
# Attach this to a scene to test the tree respawn system

@export var test_tree_scene: PackedScene = preload("res://scenes/environment/Tree1.tscn")
@export var test_position: Vector2 = Vector2(100, 100)

var test_tree: Node2D

func _ready():
	print("=== TREE RESPAWN TEST ===")
	print("Press '1' to create test tree")
	print("Press '2' to simulate full harvest (convert to stump)")
	print("Press '3' to force respawn")
	print("Press '4' to check tree state")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_create_test_tree()
			KEY_2:
				_harvest_tree()
			KEY_3:
				_force_respawn()
			KEY_4:
				_check_tree_state()

func _create_test_tree():
	if test_tree:
		test_tree.queue_free()
	
	test_tree = test_tree_scene.instantiate()
	add_child(test_tree)
	test_tree.global_position = test_position
	print("Test tree created at ", test_position)

func _harvest_tree():
	if not test_tree:
		print("No test tree exists! Press '1' to create one.")
		return
	
	var tree_interactable = test_tree.find_child("TreeInteractable")
	if tree_interactable and tree_interactable.has_method("_on_harvest_depleted"):
		print("Simulating full harvest...")
		tree_interactable._on_harvest_depleted()
	else:
		print("TreeInteractable not found or method missing!")

func _force_respawn():
	if not test_tree:
		print("No test tree exists! Press '1' to create one.")
		return
	
	var tree_interactable = test_tree.find_child("TreeInteractable")
	if tree_interactable and tree_interactable.has_method("_on_respawn_timer_timeout"):
		print("Forcing tree respawn...")
		tree_interactable._on_respawn_timer_timeout()
	else:
		print("TreeInteractable not found or method missing!")

func _check_tree_state():
	if not test_tree:
		print("No test tree exists! Press '1' to create one.")
		return
	
	var tree_interactable = test_tree.find_child("TreeInteractable")
	if tree_interactable:
		print("=== TREE STATE DEBUG ===")
		print("Tree state: ", tree_interactable.current_state)
		print("Resources remaining: ", tree_interactable.total_resources_remaining)
		print("Monitoring enabled: ", tree_interactable.monitoring)
		print("Interaction prompt: ", tree_interactable.interaction_prompt_text)
		
		# Check stump coordinates
		if tree_interactable.has_method("_get_stump_coordinates_for_tree_type"):
			var stump_coords = tree_interactable._get_stump_coordinates_for_tree_type()
			print("Stump coordinates: ", stump_coords)
		
		# Check sprite region
		var sprite = tree_interactable.find_child("Sprite2D")
		if sprite:
			print("Current sprite region: ", sprite.region_rect)
			print("Current sprite offset: ", sprite.offset)
		
		if tree_interactable.respawn_timer:
			print("Timer active: ", not tree_interactable.respawn_timer.is_stopped())
			print("Time left: ", tree_interactable.respawn_timer.time_left)
		print("========================")
	else:
		print("TreeInteractable not found!")
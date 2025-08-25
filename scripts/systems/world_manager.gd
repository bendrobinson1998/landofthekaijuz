class_name WorldManager
extends Node2D

@export var spawn_point: Vector2 = Vector2.ZERO
@export var world_bounds: Rect2 = Rect2(-1000, -1000, 2000, 2000)

@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D
@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera: Camera2D = $Player/Camera2D
@onready var house_door: Area2D = $Area2D
var chunk_manager: ChunkManager
# DISABLED: Random tree and flower generation
# var tree_spawner: TreeSpawner
# var flower_spawner: FlowerSpawner
var path_placement_manager: Node
var edit_mode_visual_feedback: Node2D
var path_modification_data: Node
var terrain_configurator: Node
var day_night_system: DayNightSystem

var player: PlayerController
var is_initialized: bool = false

# Multiplayer components
var enet_server: ENETServer
var server_connector: ServerConnector
var players_manager: PlayersManager
var multiplayer_spawner: MultiplayerSpawner

func _ready():
	add_to_group("world_managers")
	add_to_group("main_world")
	
	# Setup multiplayer if needed
	_setup_multiplayer()
	
	_initialize_world()

func _initialize_world():
	# Set up the new chunk management system
	_setup_chunk_system()
	
	# Set up path placement system
	_setup_path_system()
	
	# Set up day/night system
	_setup_day_night_system()
	
	# Initialize chunk manager system with world seed from GameManager
	if chunk_manager and GameManager.player_data.has("world_seed"):
		var world_seed = GameManager.player_data.world_seed
		chunk_manager.set_world_seed(world_seed)
		
		# Load world data from SaveManager if available
		if SaveManager.current_world_name:
			_load_world_data_from_save_manager()
	
	# Set up navigation
	if NavigationManager and navigation_region:
		NavigationManager.setup_navigation_region(navigation_region)
		
		# Create navigation polygon from tilemap if it exists
		# Note: NavigationManager.create_navigation_polygon_from_tilemap expects a TileMap, not TileMapLayer
		# Since we're using TileMapLayer nodes in Godot 4.4, we need to find the parent TileMap or skip this
		var parent_tilemap = ground_layer.get_parent() if ground_layer else null
		if parent_tilemap and parent_tilemap is TileMap:
			var nav_poly = NavigationManager.create_navigation_polygon_from_tilemap(parent_tilemap)
			navigation_region.navigation_polygon = nav_poly
	
	# Set up house door as interactable
	_setup_house_door()
	
	# Spawn player - handle both single-player and multiplayer
	_handle_player_spawning()
	
	# Set camera limits based on world bounds (single-player only)
	# In multiplayer mode, camera setup is handled when host player spawns
	if camera:
		_setup_camera_limits()
	elif GameManager.player_data.get("is_host", false):
		# For multiplayer host, camera setup will be handled in _setup_host_camera
		print("WorldManager: Multiplayer host mode - camera setup will be handled after player spawn")
	
	# Start autosave system now that world is loaded
	SaveManager.start_autosave()
	
	# Ensure ChunkManager has refreshed static obstacles after all nodes are loaded
	if chunk_manager:
		call_deferred("_ensure_static_obstacles_refreshed")
	
	is_initialized = true

func _spawn_player():
	var player_scene = preload("res://scenes/characters/player/Player.tscn")
	player = player_scene.instantiate()
	
	# Set spawn position
	var spawn_pos = player_spawn.global_position if player_spawn else spawn_point
	player.global_position = spawn_pos
	
	# Add player to scene
	add_child(player)
	
	# Set up camera to follow player
	if camera:
		camera.reparent(player)
		camera.enabled = true

func _setup_camera_limits():
	if not camera:
		return
	
	_setup_camera_limits_for_camera(camera)

func _setup_camera_limits_for_camera(target_camera: Camera2D):
	"""Set up camera limits and configuration for any given camera to match single-player setup"""
	if not target_camera:
		return
	
	# Set world bounds (limits)
	target_camera.limit_left = int(world_bounds.position.x)
	target_camera.limit_top = int(world_bounds.position.y)
	target_camera.limit_right = int(world_bounds.position.x + world_bounds.size.x)
	target_camera.limit_bottom = int(world_bounds.position.y + world_bounds.size.y)
	
	# Apply same configuration as single-player camera
	target_camera.zoom = Vector2(3, 3)  # Match single-player zoom level
	target_camera.process_callback = 0  # Match single-player process callback
	target_camera.position_smoothing_enabled = true
	target_camera.position_smoothing_speed = 5.0
	target_camera.enabled = true

func get_walkable_area() -> Rect2:
	return world_bounds

func is_position_valid(pos: Vector2) -> bool:
	return world_bounds.has_point(pos)

func get_random_walkable_position() -> Vector2:
	# Simple random position within bounds
	# In a real game, you'd check against obstacles
	var random_x = randf_range(world_bounds.position.x, world_bounds.position.x + world_bounds.size.x)
	var random_y = randf_range(world_bounds.position.y, world_bounds.position.y + world_bounds.size.y)
	
	var pos = Vector2(random_x, random_y)
	
	# Use NavigationManager to ensure position is walkable
	if NavigationManager:
		pos = NavigationManager.get_closest_walkable_position(pos)
	
	return pos

func add_obstacle(position: Vector2, size: Vector2):
	# This would add obstacles to the navigation system
	# Implementation depends on your specific needs
	pass

func remove_obstacle(position: Vector2):
	# This would remove obstacles from the navigation system
	# Implementation depends on your specific needs
	pass

func _setup_house_door():
	if house_door:
		# Load the house_door script
		var door_script = load("res://scripts/components/house_door.gd")
		house_door.set_script(door_script)
		
		# Add a door sprite if it doesn't exist (for outline to show on)
		var door_sprite = house_door.find_child("Sprite2D")
		if not door_sprite:
			door_sprite = Sprite2D.new()
			door_sprite.name = "Sprite2D"
			# Load door texture
			var door_texture = load("res://assets/House/Walls/Wood_Door.png")
			if door_texture:
				door_sprite.texture = door_texture
				# Set up the texture region for a single door frame
				door_sprite.region_enabled = true
				door_sprite.region_rect = Rect2(0, 0, 16, 32)
			house_door.add_child(door_sprite)
		
		# Add InteractionPrompt label if it doesn't exist
		var prompt_label = house_door.find_child("InteractionPrompt")
		if not prompt_label:
			prompt_label = Label.new()
			prompt_label.name = "InteractionPrompt"
			prompt_label.text = "Click to enter house"
			prompt_label.visible = false
			prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			prompt_label.position = Vector2(-40, -50)
			prompt_label.size = Vector2(80, 20)
			house_door.add_child(prompt_label)
		
		# Call the ready function to initialize the interactable
		if house_door.has_method("_ready"):
			house_door.call_deferred("_ready")

func _on_area_2d_input_event(viewport, event, shape_idx):
	# This is now handled by InputManager's intersect_point system
	# Legacy method - the Area2D should have Interactable script attached instead
	pass

# Object Management Methods
func regenerate_objects():
	"""Regenerate all objects in the world"""
	# DISABLED: Random tree and flower generation
	# if chunk_manager:
	# 	chunk_manager.clear_all_objects()
	pass

func clear_objects():
	"""Clear all objects from the world"""
	# DISABLED: Random tree and flower generation
	# if chunk_manager:
	# 	chunk_manager.clear_all_objects()
	pass


func get_object_count() -> Dictionary:
	"""Get the number of currently placed objects"""
	var counts = {}
	if chunk_manager:
		var debug_info = chunk_manager.get_debug_info()
		for spawner_name in debug_info:
			if spawner_name in ["trees", "flowers"] and typeof(debug_info[spawner_name]) == TYPE_DICTIONARY:
				counts[spawner_name] = debug_info[spawner_name].get("active_objects", 0)
	return counts

# Legacy methods for backwards compatibility
func regenerate_trees():
	# DISABLED: Random tree and flower generation
	# regenerate_objects()
	pass

func clear_trees():
	# DISABLED: Random tree and flower generation
	# clear_objects()
	pass

func get_tree_count() -> int:
	var counts = get_object_count()
	return counts.get("trees", 0)

func _setup_chunk_system():
	"""Set up the chunk management system"""
	
	# Set up new ChunkManager system (keeping it for potential future use)
	chunk_manager = get_node_or_null("ChunkManager")
	if not chunk_manager:
		chunk_manager = ChunkManager.new()
		chunk_manager.name = "ChunkManager"
		chunk_manager.add_to_group("chunk_managers")
		add_child(chunk_manager)
		
		# DISABLED: Random tree and flower generation
		# tree_spawner = TreeSpawner.new()
		# tree_spawner.name = "TreeSpawner"
		# chunk_manager.add_child(tree_spawner)
		
		# flower_spawner = FlowerSpawner.new()
		# flower_spawner.name = "FlowerSpawner"
		# chunk_manager.add_child(flower_spawner)
		
	else:
		# Use existing chunk manager without spawners
		pass
		# DISABLED: Random tree and flower generation
		# tree_spawner = chunk_manager.get_node_or_null("TreeSpawner")
		# flower_spawner = chunk_manager.get_node_or_null("FlowerSpawner")
		
		# if not tree_spawner:
		# 	tree_spawner = TreeSpawner.new()
		# 	tree_spawner.name = "TreeSpawner"
		# 	chunk_manager.add_child(tree_spawner)
		
		# if not flower_spawner:
		# 	flower_spawner = FlowerSpawner.new()
		# 	flower_spawner.name = "FlowerSpawner"
		# 	chunk_manager.add_child(flower_spawner)
		

func test_terrain_consistency() -> Dictionary:
	"""Test terrain generation consistency - useful for debugging save/load issues"""
	var test_result = {
		"success": true,
		"errors": [],
		"warnings": [],
		"info": {}
	}
	
	if not chunk_manager:
		test_result.errors.append("No ChunkManager found")
		test_result.success = false
		return test_result
	
	# Test ChunkManager validation
	var validation = chunk_manager.validate_terrain_consistency()
	if not validation.is_valid:
		test_result.success = false
		for error in validation.errors:
			test_result.errors.append("ChunkManager: " + error)
	
	for warning in validation.warnings:
		test_result.warnings.append("ChunkManager: " + warning)
	
	test_result.info["chunk_manager"] = validation.info
	
	# Test world seed propagation
	var expected_seed = GameManager.player_data.get("world_seed", -1)
	if expected_seed != -1:
		var chunk_seed = chunk_manager.get_world_seed()
		if chunk_seed != expected_seed:
			test_result.errors.append("World seed mismatch: ChunkManager has " + str(chunk_seed) + ", expected " + str(expected_seed))
			test_result.success = false
		else:
			test_result.info["world_seed_match"] = true
	else:
		test_result.warnings.append("No world seed found in GameManager")
	
	# Test spawner registration
	var spawner_count = 0
	# DISABLED: Random tree and flower generation
	# if tree_spawner:
	# 	spawner_count += 1
	# 	var tree_seed = tree_spawner.get_world_seed()
	# 	if tree_seed != expected_seed and expected_seed != -1:
	# 		test_result.errors.append("TreeSpawner seed mismatch: has " + str(tree_seed) + ", expected " + str(expected_seed))
	# 		test_result.success = false
	# 
	# if flower_spawner:
	# 	spawner_count += 1
	# 	var flower_seed = flower_spawner.get_world_seed()
	# 	if flower_seed != expected_seed and expected_seed != -1:
	# 		test_result.errors.append("FlowerSpawner seed mismatch: has " + str(flower_seed) + ", expected " + str(expected_seed))
	# 		test_result.success = false
	
	test_result.info["spawner_count"] = spawner_count
	test_result.info["expected_spawners"] = 2
	
	if spawner_count < 2:
		test_result.warnings.append("Expected 2 spawners (tree, flower), found " + str(spawner_count))
	
	# Test save data generation
	var world_data = chunk_manager.get_world_save_data() if chunk_manager else {}
	if world_data.is_empty():
		test_result.warnings.append("No world save data generated")
	else:
		test_result.info["save_data_chunks"] = world_data.get("chunk_modifications", {}).size()
		test_result.info["save_data_seed"] = world_data.get("world_seed", "missing")
	
	return test_result

func print_terrain_test_results():
	"""Print terrain consistency test results in a readable format"""
	var results = test_terrain_consistency()
	
	# Debug function - implementation removed
	pass

func regenerate_terrain_with_test():
	"""Regenerate terrain and run consistency test"""
	
	# DISABLED: Random tree and flower generation
	# if chunk_manager:
	# 	chunk_manager.regenerate_terrain()
	# 
	# # Wait a frame for regeneration to complete
	# await get_tree().process_frame
	# 
	# print_terrain_test_results()
	pass

func _ensure_static_obstacles_refreshed():
	"""Ensure ChunkManager has refreshed its static obstacles after world initialization"""
	if chunk_manager and chunk_manager.has_method("refresh_static_obstacles"):
		chunk_manager.refresh_static_obstacles()

func _setup_path_system():
	"""Set up the path placement and visual feedback system"""
	
	# Set up TerrainConfigurator first to configure Better Terrain
	terrain_configurator = get_node_or_null("TerrainConfigurator")
	if not terrain_configurator:
		var terrain_config_script = load("res://scripts/systems/terrain_configurator.gd")
		terrain_configurator = Node.new()
		terrain_configurator.name = "TerrainConfigurator"
		terrain_configurator.set_script(terrain_config_script)
		add_child(terrain_configurator)
	
	# Set up PathModificationData first (required by PathPlacementManager)
	path_modification_data = get_node_or_null("PathModificationData")
	if not path_modification_data:
		var path_data_script = load("res://scripts/systems/path_modification_data.gd")
		path_modification_data = Node.new()
		path_modification_data.name = "PathModificationData"
		path_modification_data.set_script(path_data_script)
		add_child(path_modification_data)
	
	# Set up PathPlacementManager
	path_placement_manager = get_node_or_null("PathPlacementManager")
	if not path_placement_manager:
		var path_placement_script = load("res://scripts/systems/path_placement_manager.gd")
		path_placement_manager = Node.new()
		path_placement_manager.name = "PathPlacementManager"
		path_placement_manager.set_script(path_placement_script)
		add_child(path_placement_manager)
	
	# Set up EditModeVisualFeedback
	edit_mode_visual_feedback = get_node_or_null("EditModeVisualFeedback")
	if not edit_mode_visual_feedback:
		var visual_feedback_script = load("res://scripts/systems/edit_mode_visual_feedback.gd")
		edit_mode_visual_feedback = Node2D.new()
		edit_mode_visual_feedback.name = "EditModeVisualFeedback"
		edit_mode_visual_feedback.set_script(visual_feedback_script)
		add_child(edit_mode_visual_feedback)

func _setup_day_night_system():
	"""Set up the day/night visual system"""
	
	day_night_system = get_node_or_null("DayNightSystem")
	if not day_night_system:
		day_night_system = DayNightSystem.new()
		day_night_system.name = "DayNightSystem"
		add_child(day_night_system)
		
		# Configure day/night colors for a farming game aesthetic
		day_night_system.day_color = Color.TRANSPARENT
		day_night_system.night_color = Color(0.1, 0.2, 0.4, 0.6)
		day_night_system.transition_duration = 3.0
		day_night_system.enable_smooth_transitions = true

func _load_world_data_from_save_manager():
	"""Load world data from SaveManager when ChunkManager is ready"""
	if not chunk_manager:
		return
	
	# SaveManager will handle world data loading through its own deferred system

# Multiplayer functions
func _setup_multiplayer():
	"""Set up multiplayer networking components if needed"""
	
	# Check if this is a multiplayer session
	var is_multiplayer = GameManager.player_data.has("is_host") or GameManager.player_data.has("host_ip")
	
	print("WorldManager: Multiplayer check - is_host: ", GameManager.player_data.get("is_host", "not set"), " host_ip: ", GameManager.player_data.get("host_ip", "not set"), " is_multiplayer: ", is_multiplayer)
	
	if not is_multiplayer:
		# Ensure multiplayer peer is null for single-player
		multiplayer.multiplayer_peer = null
		print("WorldManager: Single-player mode confirmed, multiplayer_peer set to null")
		return  # Single-player mode, no network setup needed
	
	# Create server interface container
	var server_interface = Node.new()
	server_interface.name = "ServerInterface"
	add_child(server_interface)
	
	# Create network components
	enet_server = ENETServer.new()
	enet_server.name = "ENETServer" 
	server_interface.add_child(enet_server)
	
	server_connector = ServerConnector.new()
	server_connector.name = "ServerConnector"
	server_interface.add_child(server_connector)
	
	# Create players manager (used for player tracking, not manual spawning)
	players_manager = PlayersManager.new()
	players_manager.name = "PlayersManager"
	add_child(players_manager)
	
	# Get reference to the MultiplayerSpawner that's already in the scene
	multiplayer_spawner = get_node_or_null("MultiplayerSpawner")
	if not multiplayer_spawner:
		print("WorldManager: ERROR - MultiplayerSpawner not found in scene")
		return
	
	# Note: MultiplayerSpawner setup deferred until after connection is established
	
	# Start hosting or connecting based on player data
	if GameManager.player_data.get("is_host", false):
		_start_hosting()
	else:
		_start_connecting()

func _start_hosting():
	"""Start hosting a multiplayer server"""
	var port = GameManager.player_data.get("port", 7000)
	var max_players = GameManager.player_data.get("max_players", 4)
	
	print("Starting host on port: ", port, " with max players: ", max_players)
	
	if enet_server:
		# Connect to server startup signal to configure MultiplayerSpawner
		if not enet_server.spawn_player_for_host.is_connected(_on_server_started):
			enet_server.spawn_player_for_host.connect(_on_server_started)
		enet_server.start_server(port, max_players)

func _start_connecting():
	"""Connect to a multiplayer server"""
	var host_ip = GameManager.player_data.get("host_ip", "127.0.0.1")
	var port = GameManager.player_data.get("port", 7000)
	
	print("Connecting to host: ", host_ip, ":", port)
	
	if server_connector:
		# Connect to client connection success signal to configure MultiplayerSpawner
		if not multiplayer.connected_to_server.is_connected(_on_client_connected):
			multiplayer.connected_to_server.connect(_on_client_connected)
		server_connector.connect_to_server(host_ip, port)

func _on_server_started():
	"""Called when server has started and is ready - configure MultiplayerSpawner and create initial players"""
	print("WorldManager: Server started successfully, configuring MultiplayerSpawner")
	_setup_automatic_spawning()
	
	# Create initial player instances for MultiplayerSpawner to handle
	call_deferred("_spawn_players_automatically")

func _on_client_connected():
	"""Called when client has connected to server - configure MultiplayerSpawner"""
	print("WorldManager: Client connected successfully, configuring MultiplayerSpawner")
	_setup_automatic_spawning()
	
	# Spawn local client player
	call_deferred("_spawn_players_automatically")

func _setup_automatic_spawning():
	"""Configure automatic MultiplayerSpawner-driven spawning"""
	var local_id = multiplayer.get_unique_id()
	var is_actual_server = multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() == 1
	var role = "SERVER" if is_actual_server else "CLIENT"
	print("WorldManager [", role, " ID:", local_id, "]: Setting up automatic spawning system")
	
	if not multiplayer_spawner:
		print("WorldManager [", role, "]: ERROR - No MultiplayerSpawner found")
		return
	
	print("WorldManager [", role, "]: MultiplayerSpawner spawn_path: ", multiplayer_spawner.spawn_path)
	
	# Detailed debugging of spawner configuration
	print("WorldManager [", role, "]: === SPAWNER CONFIGURATION DEBUG ===")
	print("WorldManager [", role, "]: MultiplayerSpawner object: ", multiplayer_spawner)
	print("WorldManager [", role, "]: MultiplayerSpawner scene file: ", multiplayer_spawner.scene_file_path if "scene_file_path" in multiplayer_spawner else "N/A")
	
	# List ALL properties to find the correct one
	print("WorldManager [", role, "]: Checking all spawner properties...")
	var props = multiplayer_spawner.get_property_list()
	for prop in props:
		if prop.name.contains("spawn") or prop.name.contains("scene"):
			var value = multiplayer_spawner.get(prop.name)
			print("WorldManager [", role, "]:   Property '", prop.name, "' = ", value)
	
	# Check spawnable scenes configuration (using actual Godot 4.4 property name)
	if "_spawnable_scenes" in multiplayer_spawner:
		var scene_count = multiplayer_spawner._spawnable_scenes.size()
		print("WorldManager [", role, "]: MultiplayerSpawner _spawnable_scenes count: ", scene_count)
		
		# Log spawnable scenes if any are configured
		if scene_count > 0:
			var spawnable_scenes = multiplayer_spawner._spawnable_scenes
			for i in range(scene_count):
				if i < spawnable_scenes.size():
					print("WorldManager [", role, "]: Spawnable scene[", i, "]: ", spawnable_scenes[i])
		else:
			print("WorldManager [", role, "]: ERROR - No spawnable scenes configured! MultiplayerSpawner cannot replicate.")
			print("WorldManager [", role, "]: This prevents replication of players to other clients.")
			
			# Try to force refresh the spawner configuration
			print("WorldManager [", role, "]: Attempting to force refresh spawner configuration...")
			
			# Try different approaches to get the spawner to recognize its configuration
			if multiplayer_spawner.has_method("_ready"):
				print("WorldManager [", role, "]: Calling spawner._ready() to force configuration reload")
				multiplayer_spawner._ready()
			
			# Check again after attempted refresh
			var scene_count_after = multiplayer_spawner.get("_spawnable_scene_count") if "_spawnable_scene_count" in multiplayer_spawner else 0
			print("WorldManager [", role, "]: Scene count after refresh attempt: ", scene_count_after)
			
			if scene_count_after > 0:
				print("WorldManager [", role, "]: SUCCESS - Spawner configuration refreshed!")
				var spawnable_scenes = multiplayer_spawner._spawnable_scenes
				for i in range(scene_count_after):
					if i < spawnable_scenes.size():
						print("WorldManager [", role, "]: Spawnable scene[", i, "]: ", spawnable_scenes[i])
			else:
				print("WorldManager [", role, "]: FAILED - Could not refresh spawner configuration.")
	else:
		print("WorldManager [", role, "]: WARNING - Could not find _spawnable_scenes property")
		print("WorldManager [", role, "]: Available MultiplayerSpawner properties:")
		var property_list = multiplayer_spawner.get_property_list()
		for property in property_list:
			if property.name.to_lower().contains("spawn"):
				print("WorldManager [", role, "]:   - ", property.name, " (", property.type, ")")
	
	# Configure MultiplayerSpawner with custom spawn function for player spawning
	multiplayer_spawner.spawn_function = _spawn_player_function
	print("WorldManager [", role, "]: Set up custom spawn function for player spawning")
	
	# Connect to Players container signals to track when players are spawned/replicated
	var players_container = get_node_or_null("Players")
	if players_container:
		print("WorldManager [", role, "]: Found Players container with ", players_container.get_child_count(), " existing children")
		if not players_container.child_entered_tree.is_connected(_on_player_added):
			players_container.child_entered_tree.connect(_on_player_added)
			print("WorldManager [", role, "]: Connected to Players container child_entered_tree signal")
	else:
		print("WorldManager [", role, "]: ERROR - Players container not found")
	
	# On server: Connect to peer connections to create player instances for new clients
	if is_actual_server:
		if not multiplayer.peer_connected.is_connected(_on_peer_connected_automatic):
			multiplayer.peer_connected.connect(_on_peer_connected_automatic)
			print("WorldManager [", role, "]: Connected to peer_connected for automatic spawning")
	
	print("WorldManager [", role, "]: Automatic spawning configured - MultiplayerSpawner will handle replication")

func _spawn_players_automatically():
	"""Spawn initial players using MultiplayerSpawner.spawn()"""
	var is_actual_server = multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() == 1
	var local_peer_id = multiplayer.get_unique_id()
	
	if not multiplayer_spawner:
		print("WorldManager: ERROR - No MultiplayerSpawner available")
		return
	
	if is_actual_server:
		print("WorldManager [SERVER]: Spawning initial host player using MultiplayerSpawner")
		# Server spawns host player (peer ID 1) using MultiplayerSpawner
		_spawn_player_with_spawner(1)
	else:
		print("WorldManager [CLIENT]: Client spawning own player for replication")
		# Each client spawns its own player with authority - MultiplayerSpawner handles replication
		# This is correct - each peer spawns nodes they have authority over
		_spawn_player_with_spawner(local_peer_id)

func _spawn_player_with_spawner(peer_id: int):
	"""Spawn a player using automatic MultiplayerSpawner replication"""
	var role = "SERVER" if multiplayer.get_unique_id() == 1 else "CLIENT"
	print("WorldManager [", role, "]: Spawning player for peer ", peer_id, " using automatic replication")
	
	# Prepare spawn data for the custom spawn function
	var spawn_data = {
		"peer_id": peer_id,
		"spawn_position": player_spawn.global_position if player_spawn else Vector2.ZERO
	}
	
	# Create the MultiplayerClient directly and add it to Players container
	# MultiplayerSpawner will automatically replicate it to other peers
	var player_scene = load("res://scenes/characters/player/MultiplayerClient.tscn")
	if not player_scene:
		print("WorldManager [", role, "]: ERROR - Could not load MultiplayerClient scene")
		return
	
	var spawned_node = player_scene.instantiate()
	if not spawned_node:
		print("WorldManager [", role, "]: ERROR - Could not instantiate MultiplayerClient scene")
		return
	
	# Configure the spawned node with spawn data before adding to tree
	if spawned_node.has_method("set_spawn_data"):
		spawned_node.set_spawn_data(spawn_data)
	
	# Set name before adding to tree
	spawned_node.name = str(peer_id)
	
	# Add to Players container first
	var players_container = get_node_or_null("Players")
	if players_container:
		players_container.add_child(spawned_node)
		print("WorldManager [SERVER]: Successfully added player '", spawned_node.name, "' to Players container")
		
		# CRITICAL: Set authority AFTER adding to tree - this triggers MultiplayerSpawner replication
		spawned_node.set_multiplayer_authority(peer_id)
		print("WorldManager [SERVER]: Set authority for player '", spawned_node.name, "' to peer ", peer_id)
		
		# Set up camera for host player
		if peer_id == 1:
			var player = spawned_node.get_node_or_null("Player")
			if player:
				call_deferred("_setup_host_player_camera", player)
	else:
		print("WorldManager [SERVER]: ERROR - Players container not found")
		spawned_node.queue_free()

func _spawn_player_function(spawn_data: Dictionary) -> Node:
	"""Custom spawn function for MultiplayerSpawner - called on all peers"""
	print("WorldManager: _spawn_player_function called with data: ", spawn_data)
	
	# Load and instantiate the MultiplayerClient scene
	var player_scene = load("res://scenes/characters/player/MultiplayerClient.tscn")
	if not player_scene:
		print("WorldManager: ERROR - Could not load MultiplayerClient scene")
		return null
	
	var player_wrapper = player_scene.instantiate()
	if not player_wrapper:
		print("WorldManager: ERROR - Could not instantiate MultiplayerClient scene")
		return null
	
	# Pass spawn data to MultiplayerClient
	if player_wrapper.has_method("set_spawn_data"):
		player_wrapper.set_spawn_data(spawn_data)
	
	# Set name for identification
	if spawn_data.has("peer_id"):
		player_wrapper.name = str(spawn_data.peer_id)
	
	print("WorldManager: Created player instance for spawn function: ", player_wrapper.name)
	return player_wrapper

func _on_peer_connected_automatic(peer_id: int):
	"""Handle peer connection - spawn player using MultiplayerSpawner"""
	var is_actual_server = multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() == 1
	
	if not is_actual_server:
		print("WorldManager [CLIENT]: Peer ", peer_id, " connected - waiting for MultiplayerSpawner")
		return
	
	print("WorldManager [SERVER]: Peer ", peer_id, " connected - adding delay before spawning player")
	
	# Add small delay to fix Godot 4.4 timing race condition
	# This prevents spawning players in the wrong order
	await get_tree().create_timer(0.1).timeout
	
	print("WorldManager [SERVER]: Spawning player for peer ", peer_id)
	
	# Spawn player for the new client using MultiplayerSpawner
	_spawn_player_with_spawner(peer_id)

func _handle_player_spawning():
	"""Handle player spawning for both single-player and multiplayer"""
	
	# Check if this is multiplayer mode
	var is_multiplayer = GameManager.player_data.has("is_host") or GameManager.player_data.has("host_ip")
	
	if is_multiplayer:
		# Multiplayer mode: PlayersManager handles spawning
		# Players will be spawned via the multiplayer spawner system
		# Remove any existing single-player camera reference
		if camera:
			camera.queue_free()
			camera = null
		return
	
	# Single-player mode: spawn player normally
	if not player:
		_spawn_player()

func _setup_host_player_camera(player_node: Node):
	"""Set up camera for the host player"""
	print("WorldManager: Setting up host player camera...")
	
	# Get the camera from the player
	var player_camera = player_node.get_node_or_null("Camera2D")
	if not player_camera:
		print("WorldManager: ERROR - Camera2D not found in host player")
		return
	
	# Ensure the camera is enabled and current
	player_camera.enabled = true
	player_camera.make_current()
	
	# Apply world bounds and settings using existing method
	_setup_camera_limits_for_camera(player_camera)
	
	# Capture camera settings for synchronization with clients
	print("WorldManager: Host player camera setup - capturing settings for synchronization")
	if CameraManager:
		CameraManager.capture_host_camera_settings(player_camera)
	else:
		print("WorldManager: WARNING - CameraManager not found, camera settings won't be synchronized")
	
	print("WorldManager: Host player camera configured successfully")
	print("WorldManager: Camera limits - Left: ", player_camera.limit_left, " Top: ", player_camera.limit_top, " Right: ", player_camera.limit_right, " Bottom: ", player_camera.limit_bottom)

func _on_player_added(node: Node):
	"""Called when a player is added to the Players container"""
	var local_id = multiplayer.get_unique_id()
	var is_actual_server = multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() == 1
	var role = "SERVER" if is_actual_server else "CLIENT"
	var authority = node.get_multiplayer_authority() if node.has_method("get_multiplayer_authority") else "N/A"
	print("WorldManager [", role, " ID:", local_id, "]: Player added to container: ", node.name, " Authority: ", authority)
	
	# Count total players visible to this peer
	var players_container = get_node_or_null("Players")
	var total_players = players_container.get_child_count() if players_container else 0
	print("WorldManager [", role, " ID:", local_id, "]: Total players now visible: ", total_players)
	
	# If this is a client and the added player has our authority, set up camera
	if not is_actual_server and node.has_method("is_multiplayer_authority") and node.is_multiplayer_authority():
		print("WorldManager [CLIENT]: Local authority player detected, ensuring camera setup")

# DEPRECATED: Removed old automatic spawning callback and setup methods
# These are no longer needed with manual server-side spawning

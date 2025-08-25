class_name InteriorManager
extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera: Camera2D = $Camera2D

var player: Node
var is_initialized: bool = false

func _ready():
	_initialize_interior()

func _initialize_interior():
	# Enable the camera
	if camera:
		camera.enabled = true
		_setup_camera_for_interior()
	
	
	# Wait for GameManager to handle player spawning
	await get_tree().process_frame
	_find_and_setup_player()
	
	is_initialized = true

func _find_and_setup_player():
	# Just spawn the player at center - simpler approach
	_spawn_player()

func _spawn_player():
	# Load the player scene
	var player_scene = preload("res://scenes/characters/player/Player.tscn")
	player = player_scene.instantiate()
	
	# Spawn at center since interior is built around (0,0)
	player.global_position = Vector2.ZERO
	
	# Add player to scene
	add_child(player)
	
	# Move camera to follow player
	if camera:
		camera.reparent(player)
		camera.enabled = true

func _find_player_in_scene() -> Node:
	# Look for player node by name
	var found_player = get_tree().current_scene.find_child("Player", true, false)
	if found_player:
		return found_player
	
	# Look for any node with "Player" in the name
	return get_tree().current_scene.find_child("*Player*", true, false)

func _setup_camera_for_interior():
	if not camera:
		return
	
	# Set camera limits for interior bounds
	# Adjust these values based on your interior size
	camera.limit_left = -200
	camera.limit_top = -200
	camera.limit_right = 200
	camera.limit_bottom = 200
	
	# Enable smooth camera movement
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	
	# Set appropriate zoom for interior view
	camera.zoom = Vector2(4.0, 4.0)  # Zoom in more for interior detail


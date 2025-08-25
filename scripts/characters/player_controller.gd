class_name PlayerController
extends CharacterBody2D

signal movement_started()
signal movement_stopped()
signal reached_destination()

@export var move_speed: float = 40.0
@export var acceleration: float = 400.0
@export var friction: float = 400.0

# Zoom settings
@export var min_zoom: float = 1  # Maximum zoom in (2x closer than default)
@export var max_zoom: float = 3  # Maximum zoom out (2x further than default)
@export var zoom_speed: float = 0.3  # How fast to zoom
@export var zoom_step: float = 0.2   # How much to zoom per scroll

var target_position: Vector2
var path: Array[Vector2] = []
var current_path_index: int = 0
var is_moving_to_target: bool = false
var movement_direction: Vector2 = Vector2.ZERO
var is_jumping: bool = false
var jump_time: float = 0.0
var jump_duration: float = 0.6
var is_chopping: bool = false
var chopping_target: Node2D = null
var pending_interaction_target: Node = null

@onready var sprite: Sprite2D = $Player_Base_animationsSprite
@onready var animation_player: AnimationPlayer = $Player_Base_animationsSprite/Player_Base_animationsSpriteAnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D

enum Direction {
	DOWN,
	DOWN_LEFT,
	LEFT,
	UP_LEFT,
	UP,
	UP_RIGHT,
	RIGHT,
	DOWN_RIGHT
}

var current_direction: Direction = Direction.DOWN

# Simple animation mapping: down for down diagonals, up for up diagonals, flip for left
var animation_mapping = {
	"idle_down": "idle_down",
	"idle_up": "idle_up", 
	"idle_left": "idle_right",       # Flip horizontally
	"idle_right": "idle_right",
	"idle_down_left": "idle_down",   # Use down animation, flip for left
	"idle_down_right": "idle_down",  # Use down animation
	"idle_up_left": "idle_up",       # Use up animation, flip for left
	"idle_up_right": "idle_up",      # Use up animation
	"walk_down": "walk_down",
	"walk_up": "walk_up",
	"walk_left": "walk_right",       # Flip horizontally
	"walk_right": "walk_right",
	"walk_down_left": "walk_down",   # Use down animation, flip for left
	"walk_down_right": "walk_down",  # Use down animation
	"walk_up_left": "walk_up",       # Use up animation, flip for left
	"walk_up_right": "walk_up",      # Use up animation
	"jump_down": "jump_down",
	"jump_up": "jump_up",
	"jump_left": "jump_right",       # Flip horizontally
	"jump_right": "jump_right",
	"jump_down_left": "jump_down",   # Use down animation, flip for left
	"jump_down_right": "jump_down",  # Use down animation
	"jump_up_left": "jump_up",       # Use up animation, flip for left
	"jump_up_right": "jump_up",      # Use up animation
	"chop_down": "chop_down",
	"chop_up": "chop_up",
	"chop_left": "chop_right",        # Flip horizontally
	"chop_right": "chop_right",
	"chop_down_left": "chop_down",    # Use down animation, flip for left
	"chop_down_right": "chop_down",   # Use down animation
	"chop_up_left": "chop_up",        # Use up animation, flip for left
	"chop_up_right": "chop_up"        # Use up animation
}

# Simple flip logic: only flip horizontally for left directions
var flip_directions = {
	"idle_left": true,
	"idle_down_left": true,
	"idle_up_left": true,
	"walk_left": true,
	"walk_down_left": true,
	"walk_up_left": true,
	"jump_left": true,
	"jump_down_left": true,
	"jump_up_left": true,
	"chop_left": true,
	"chop_down_left": true,
	"chop_up_left": true
}

func _ready():
	# Add to player group for easy finding
	add_to_group("player")
	
	# Debug logging for multiplayer spawning tracking
	var local_id = multiplayer.get_unique_id() if multiplayer.multiplayer_peer else "N/A"
	var authority_id = get_multiplayer_authority() if multiplayer.multiplayer_peer else "N/A" 
	var is_actual_server = multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() == 1
	var role = "SERVER" if is_actual_server else "CLIENT" if multiplayer.multiplayer_peer else "SINGLE-PLAYER"
	print("PlayerController [", role, " ID:", local_id, "]: _ready() called - Player authority:", authority_id, " Name:", name)
	
	# Defer camera check to ensure multiplayer authority and replication is properly set
	# Wait longer for multiplayer spawner replication to complete
	call_deferred("_handle_multiplayer_camera_deferred")
	
	# Connect to input manager
	if InputManager:
		InputManager.move_requested.connect(_on_move_requested)
		InputManager.interaction_requested.connect(_on_interaction_requested)
	
	# Connect to chat manager
	if ChatManager:
		ChatManager.message_received.connect(_on_chat_message_received)
	else:
		print("PlayerController: Warning - ChatManager not found, chat bubbles will not appear")
	
	# Connect to camera manager for settings synchronization
	if CameraManager:
		CameraManager.camera_settings_updated.connect(_on_camera_settings_updated)

func _handle_multiplayer_camera_deferred():
	"""Deferred camera setup to wait for multiplayer replication to complete"""
	var local_id = multiplayer.get_unique_id() if multiplayer.multiplayer_peer else "N/A"
	var authority_id = get_multiplayer_authority() if multiplayer.multiplayer_peer else "N/A"
	var is_actual_server = multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() == 1
	var role = "SERVER" if is_actual_server else "CLIENT" if multiplayer.multiplayer_peer else "SINGLE-PLAYER"
	var has_authority = is_multiplayer_authority() if multiplayer.multiplayer_peer else true
	print("PlayerController [", role, " ID:", local_id, "]: _handle_multiplayer_camera_deferred() - Authority:", authority_id, " Name:", name, " Has Authority:", has_authority)
	
	# CRITICAL FIX: Only run camera management on the peer that has authority over this player
	# Use is_multiplayer_authority() instead of comparing IDs directly
	if multiplayer.multiplayer_peer and not is_multiplayer_authority():
		print("PlayerController [", role, " ID:", local_id, "]: Skipping camera management - no authority over this player (authority:", authority_id, ")")
		return
	
	print("PlayerController [", role, " ID:", local_id, "]: Proceeding with camera management - we have authority")
	
	# Wait a bit more for multiplayer replication to settle
	await get_tree().process_frame
	await get_tree().process_frame
	_handle_multiplayer_camera()

func _handle_multiplayer_camera():
	"""Handle camera for multiplayer - only keep camera for local players"""
	var local_peer_id = multiplayer.get_unique_id() if multiplayer.multiplayer_peer else "N/A"
	var player_peer_id = get_multiplayer_authority() if multiplayer.multiplayer_peer else "N/A"
	var is_actual_server = multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() == 1
	var role = "SERVER" if is_actual_server else "CLIENT" if multiplayer.multiplayer_peer else "SINGLE-PLAYER"
	
	print("PlayerController [", role, " ID:", local_peer_id, "]: _handle_multiplayer_camera() - Name:", name, " Authority:", player_peer_id, " Camera:", camera != null)
	
	# Only apply multiplayer camera logic if we're actually in multiplayer mode
	if not multiplayer.multiplayer_peer:
		print("PlayerController [SINGLE-PLAYER]: Keeping camera")
		return
	
	# Handle camera for multiplayer - only keep camera for the actual local player
	# Key insight: Only the player instance that THIS CLIENT has authority over should have a camera
	# Use is_multiplayer_authority() instead of comparing peer IDs directly
	if is_multiplayer_authority() and camera:
		print("PlayerController [", role, " ID:", local_peer_id, "]: Setting up camera for LOCAL player (has authority)")
		# Apply any available camera settings for this local player
		call_deferred("_setup_authority_player_camera")
	elif not is_multiplayer_authority() and camera:
		print("PlayerController [", role, " ID:", local_peer_id, "]: Removing camera for REMOTE player (no authority)")
		camera.queue_free()
		camera = null
	elif not camera:
		print("PlayerController [", role, " ID:", local_peer_id, "]: No camera to configure")

func _input(event):
	# CRITICAL: Only process input if this player has multiplayer authority (in multiplayer mode)
	if multiplayer.multiplayer_peer and not is_multiplayer_authority():
		return
	
	# Handle mouse wheel for zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_apply_zoom(-zoom_step, get_physics_process_delta_time())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_apply_zoom(zoom_step, get_physics_process_delta_time())

func _physics_process(delta):
	# CRITICAL: Only process input if this player has multiplayer authority (in multiplayer mode)
	if multiplayer.multiplayer_peer and not is_multiplayer_authority():
		return
	
	_handle_jump_input()
	if not is_chopping:
		_handle_movement(delta)
	_update_jump_state(delta)
	_update_animation()

func _handle_jump_input():
	if Input.is_action_just_pressed("jump") and not is_jumping:
		_start_jump()


func _apply_zoom(zoom_change: float, delta: float):
	if not camera:
		return
	
	# Calculate new zoom level
	var current_zoom_level = camera.zoom.x  # Assume zoom is uniform
	var new_zoom_level = current_zoom_level + zoom_change
	
	# Clamp to min/max zoom levels
	new_zoom_level = clamp(new_zoom_level, min_zoom, max_zoom)
	
	# Apply smooth zoom
	var target_zoom = Vector2(new_zoom_level, new_zoom_level)
	camera.zoom = camera.zoom.lerp(target_zoom, zoom_speed)
	
	# Update camera settings if we're the host/server
	if CameraManager and (not multiplayer.multiplayer_peer or multiplayer.get_unique_id() == 1):
		_update_camera_manager_settings()

func _update_camera_manager_settings():
	"""Update camera manager with current camera settings (for multiplayer sync)"""
	if not camera or not CameraManager:
		return
	
	CameraManager.capture_host_camera_settings(camera)

func _start_jump():
	is_jumping = true
	jump_time = 0.0

func _update_jump_state(delta):
	if is_jumping:
		jump_time += delta
		if jump_time >= jump_duration:
			is_jumping = false
			jump_time = 0.0

func _handle_movement(delta):
	var input_vector = InputManager.get_movement_vector() if InputManager else Vector2.ZERO
	
	# Handle keyboard movement
	if input_vector != Vector2.ZERO:
		# Stop chopping if player moves
		if is_chopping:
			stop_chopping()
		# Clear pending interaction if player manually moves
		pending_interaction_target = null
		is_moving_to_target = false
		path.clear()
		movement_direction = input_vector
		velocity = velocity.move_toward(movement_direction * move_speed, acceleration * delta)
	
	# Handle pathfinding movement
	elif is_moving_to_target and path.size() > 0:
		_follow_path(delta)
	
	# Apply friction when not moving
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if velocity.length() < 5.0:
			velocity = Vector2.ZERO
			if is_moving_to_target:
				is_moving_to_target = false
				reached_destination.emit()
				# Try to execute pending interaction
				_try_pending_interaction()
	
	# Move the character
	var was_moving = velocity.length() > 0
	move_and_slide()
	
	# Update movement direction for animations
	if velocity.length() > 0:
		movement_direction = velocity.normalized()
		_update_direction()
		
		if not was_moving:
			movement_started.emit()
	elif was_moving:
		movement_stopped.emit()

func _follow_path(delta):
	if current_path_index >= path.size():
		is_moving_to_target = false
		path.clear()
		reached_destination.emit()
		_try_pending_interaction()
		return
	
	var target = path[current_path_index]
	var direction_to_target = (target - global_position).normalized()
	var distance_to_target = global_position.distance_to(target)
	
	# Check if we should stop early for interaction (more forgiving)
	if pending_interaction_target and _is_close_enough_to_interact():
		is_moving_to_target = false
		path.clear()
		reached_destination.emit()
		_try_pending_interaction()
		return
	
	# If close to current waypoint, move to next (reduced for more precision)
	if distance_to_target < 5.0:
		current_path_index += 1
		if current_path_index >= path.size():
			is_moving_to_target = false
			path.clear()
			reached_destination.emit()
			_try_pending_interaction()
			return
	
	# Move towards current waypoint
	movement_direction = direction_to_target
	velocity = velocity.move_toward(direction_to_target * move_speed, acceleration * delta)

func _update_direction():
	var angle = movement_direction.angle()
	var degrees = rad_to_deg(angle)
	
	# Normalize angle to 0-360
	if degrees < 0:
		degrees += 360
	
	# Determine 8-directional facing based on angle
	if degrees >= 337.5 or degrees < 22.5:
		current_direction = Direction.RIGHT
	elif degrees >= 22.5 and degrees < 67.5:
		current_direction = Direction.DOWN_RIGHT
	elif degrees >= 67.5 and degrees < 112.5:
		current_direction = Direction.DOWN
	elif degrees >= 112.5 and degrees < 157.5:
		current_direction = Direction.DOWN_LEFT
	elif degrees >= 157.5 and degrees < 202.5:
		current_direction = Direction.LEFT
	elif degrees >= 202.5 and degrees < 247.5:
		current_direction = Direction.UP_LEFT
	elif degrees >= 247.5 and degrees < 292.5:
		current_direction = Direction.UP
	elif degrees >= 292.5 and degrees < 337.5:
		current_direction = Direction.UP_RIGHT

func _update_animation():
	if not animation_player or not sprite:
		return
	
	var is_moving = velocity.length() > 0
	var direction_name = _get_direction_name(current_direction)
	var animation_key = ""
	
	if is_chopping:
		animation_key = "chop_" + direction_name
	elif is_jumping:
		animation_key = "jump_" + direction_name
	elif is_moving:
		animation_key = "walk_" + direction_name
	else:
		animation_key = "idle_" + direction_name
	
	if animation_key in animation_mapping:
		var anim_name = animation_mapping[animation_key]
		
		# Simple horizontal flipping for left directions
		var should_flip = animation_key in flip_directions and flip_directions[animation_key]
		sprite.flip_h = should_flip
		sprite.flip_v = false  # Keep it simple, no vertical flipping
		
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
			# Debug: Print animation changes for testing
	

func _get_direction_name(dir: Direction) -> String:
	match dir:
		Direction.DOWN:
			return "down"
		Direction.DOWN_LEFT:
			return "down_left"
		Direction.LEFT:
			return "left"
		Direction.UP_LEFT:
			return "up_left"
		Direction.UP:
			return "up"
		Direction.UP_RIGHT:
			return "up_right"
		Direction.RIGHT:
			return "right"
		Direction.DOWN_RIGHT:
			return "down_right"
		_:
			return "down"

func _on_move_requested(world_position: Vector2):
	# Stop chopping if player clicks to move elsewhere
	if is_chopping:
		stop_chopping()
	
	# Clear pending interaction for normal movement
	pending_interaction_target = null
	
	if NavigationManager:
		var player_pos = global_position
		var new_path = NavigationManager.find_path(player_pos, world_position)
		
		if new_path.size() > 0:
			move_to_position_with_path(new_path)
		else:
			# Fallback to direct movement if pathfinding fails
			move_to_position(world_position)

func _on_interaction_requested(interactable: Node, move_position: Vector2):
	# Stop chopping if we're starting a new interaction
	if is_chopping:
		stop_chopping()
	
	# Store the pending interaction
	pending_interaction_target = interactable
	
	
	# Move to the interaction position
	if NavigationManager:
		var player_pos = global_position
		var new_path = NavigationManager.find_path(player_pos, move_position)
		
		if new_path.size() > 0:
			move_to_position_with_path(new_path)
		else:
			# Fallback to direct movement if pathfinding fails
			move_to_position(move_position)
	else:
		move_to_position(move_position)

func move_to_position(target: Vector2):
	target_position = target
	is_moving_to_target = true
	path = [target]
	current_path_index = 0
	movement_started.emit()

func move_to_position_with_path(new_path: Array[Vector2]):
	path = new_path
	current_path_index = 0
	is_moving_to_target = true
	movement_started.emit()

func stop_movement():
	is_moving_to_target = false
	path.clear()
	velocity = Vector2.ZERO

func get_facing_direction() -> Vector2:
	match current_direction:
		Direction.DOWN:
			return Vector2.DOWN
		Direction.DOWN_LEFT:
			return Vector2(-1, 1).normalized()
		Direction.LEFT:
			return Vector2.LEFT
		Direction.UP_LEFT:
			return Vector2(-1, -1).normalized()
		Direction.UP:
			return Vector2.UP
		Direction.UP_RIGHT:
			return Vector2(1, -1).normalized()
		Direction.RIGHT:
			return Vector2.RIGHT
		Direction.DOWN_RIGHT:
			return Vector2(1, 1).normalized()
		_:
			return Vector2.DOWN

func is_moving() -> bool:
	return velocity.length() > 0

# Debug function to test animation mappings
func test_animation(anim_name: String):
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	

# Get all available animations for debugging
func get_available_animations() -> PackedStringArray:
	if animation_player and animation_player.get_animation_library(""):
		return animation_player.get_animation_library("").get_animation_names()
	return PackedStringArray()

# Update animation mapping - call this if you need to adjust mappings
func update_animation_mapping(new_mapping: Dictionary):
	animation_mapping = new_mapping

# Update flip settings for specific directions
func update_flip_direction(direction_key: String, flip_h: bool, flip_v: bool):
	flip_directions[direction_key] = {"h": flip_h, "v": flip_v}

# Get current flip settings
func get_flip_settings() -> Dictionary:
	return flip_directions

func start_chopping(tree: Node2D):
	if is_chopping:
		return
	
	# Stop any movement
	stop_movement()
	
	# Face the tree
	var direction_to_tree = (tree.global_position - global_position).normalized()
	movement_direction = direction_to_tree
	_update_direction()
	
	# Start chopping
	is_chopping = true
	chopping_target = tree
	

func stop_chopping():
	if not is_chopping:
		return
	
	is_chopping = false
	chopping_target = null
	

func face_target(target_pos: Vector2):
	var direction_to_target = (target_pos - global_position).normalized()
	movement_direction = direction_to_target
	_update_direction()

func _try_pending_interaction():
	if not pending_interaction_target:
		return
	
	# Check if the target still exists and has the interact method
	if not is_instance_valid(pending_interaction_target):
		pending_interaction_target = null
		return
	
	if not pending_interaction_target.has_method("try_interact"):
		pending_interaction_target = null
		return
	
	
	# Try to interact
	var success = pending_interaction_target.try_interact()
	
	
	# Clear pending interaction after attempting
	if success:
		pending_interaction_target = null
		if InputManager:
			InputManager.clear_pending_interaction()

func _is_close_enough_to_interact() -> bool:
	if not pending_interaction_target:
		return false
	
	if not is_instance_valid(pending_interaction_target):
		return false
	
	# Check if we're within interaction range (with a more generous buffer)
	var interaction_range = 32.0  # Default interaction range
	if "interaction_range" in pending_interaction_target:
		interaction_range = pending_interaction_target.interaction_range
	
	var distance = global_position.distance_to(pending_interaction_target.global_position)
	return distance <= interaction_range + 15.0  # More generous 15 pixel buffer

func _on_chat_message_received(message: ChatMessage):
	if not message:
		print("PlayerController: Received null chat message")
		return
	
	if message.is_local_player:
		print("PlayerController: Displaying chat bubble for local player message: ", message.message_text)
		display_chat_message(message)
	else:
		print("PlayerController: Ignoring non-local player message: ", message.sender_name)

func display_chat_message(message: ChatMessage):
	if not message or not message.is_valid():
		print("PlayerController: Cannot display invalid message")
		return
	
	# Create chat bubble directly as a child of this player
	var chat_bubble_scene = preload("res://scenes/ui/ChatBubble.tscn")
	if not chat_bubble_scene:
		print("PlayerController: Error - Could not load ChatBubble scene")
		return
	
	var chat_bubble = chat_bubble_scene.instantiate()
	if not chat_bubble:
		print("PlayerController: Error - Could not instantiate ChatBubble")
		return
	
	# Add as child - bubble will follow player automatically
	add_child(chat_bubble)
	chat_bubble.display_message(message)
	
	# Wait for bubble to calculate its size
	await get_tree().process_frame
	
	# Position bubble above player head in local coordinates, centered horizontally
	# Control nodes position from top-left, so offset by half width to center
	var bubble_width = chat_bubble.size.x
	var bubble_height = chat_bubble.size.y
	# Position so the center of the bubble is at (0, -30) relative to player
	chat_bubble.position = Vector2(-bubble_width / 2, -30 - bubble_height / 2)
	
	print("PlayerController: Chat bubble created at position: ", chat_bubble.position, " size: ", chat_bubble.size)
	
	# Connect expiration signal to handle cleanup
	chat_bubble.bubble_expired.connect(_on_chat_bubble_expired)

func _on_chat_bubble_expired(bubble):
	"""Handle chat bubble expiration - remove from player"""
	if bubble and is_instance_valid(bubble):
		bubble.queue_free()

func _on_camera_settings_updated(settings: CameraSettings):
	"""Handle camera settings update from CameraManager"""
	# Only apply settings to cameras we own (authority players)
	if not multiplayer.multiplayer_peer or is_multiplayer_authority():
		apply_camera_settings(settings)
		# Ensure camera is activated after applying settings (deferred to allow authority to stabilize)
		call_deferred("_ensure_camera_activated")

func apply_camera_settings(settings: CameraSettings):
	"""Apply camera settings to this player's camera"""
	if not camera or not settings:
		print("PlayerController: Cannot apply camera settings - camera or settings missing")
		return
	
	print("PlayerController: Applying synchronized camera settings")
	settings.apply_to_camera(camera)
	print("PlayerController: Camera settings applied - Zoom: ", camera.zoom, " Limits: [", camera.limit_left, ",", camera.limit_top, ",", camera.limit_right, ",", camera.limit_bottom, "]")

func get_camera_settings() -> CameraSettings:
	"""Get current camera settings from this player's camera"""
	if not camera:
		return null
	
	var settings = CameraSettings.new()
	settings.copy_from_camera(camera)
	return settings

func _setup_authority_player_camera():
	"""Set up camera for this authority player"""
	if not camera:
		print("PlayerController: No camera to set up for authority player")
		return
	
	print("PlayerController: Setting up camera for authority player")
	print("PlayerController: Initial camera state - enabled: ", camera.enabled, " current: ", camera.is_current())
	
	# Check if we have camera settings from the host
	if CameraManager and CameraManager.has_host_settings():
		print("PlayerController: Applying synchronized camera settings")
		var settings = CameraManager.get_current_settings()
		if settings:
			settings.apply_to_camera(camera)
			print("PlayerController: Camera settings applied - Zoom: ", camera.zoom, " Limits: [", camera.limit_left, ",", camera.limit_top, ",", camera.limit_right, ",", camera.limit_bottom, "]")
	else:
		print("PlayerController: No synchronized settings available - using default camera setup")
	
	# Ensure camera is enabled and current for this authority player
	camera.enabled = true
	camera.make_current()
	
	# Verify setup was successful
	print("PlayerController: Authority player camera setup complete")
	print("PlayerController: Final camera state - enabled: ", camera.enabled, " current: ", camera.is_current(), " zoom: ", camera.zoom)
	
	# Add safety check for camera activation
	call_deferred("_verify_camera_setup")

func _ensure_camera_activated():
	"""Ensure camera is activated for authority players (used as fallback)"""
	if not camera:
		print("PlayerController: No camera to activate")
		return
	
	# Only activate for authority players
	if not multiplayer.multiplayer_peer or is_multiplayer_authority():
		print("PlayerController: Ensuring camera is activated for authority player")
		print("PlayerController: Camera state before activation - enabled: ", camera.enabled, " current: ", camera.is_current())
		
		camera.enabled = true
		camera.make_current()
		
		# Wait a frame for the camera system to process the change
		await get_tree().process_frame
		
		print("PlayerController: Camera activation completed - enabled: ", camera.enabled, " current: ", camera.is_current())
		
		# Additional verification
		if not camera.is_current():
			print("PlayerController: WARNING - Camera failed to become current, retrying...")
			camera.make_current()
			await get_tree().process_frame
			print("PlayerController: Retry result - current: ", camera.is_current())
	else:
		print("PlayerController: Skipping camera activation - not authority player")

func _verify_camera_setup():
	"""Safety check to verify camera is properly set up after deferred operations"""
	if not camera:
		print("PlayerController: VERIFICATION - Camera no longer exists")
		return
	
	if not is_multiplayer_authority():
		print("PlayerController: VERIFICATION - No longer authority player, skipping")
		return
	
	print("PlayerController: VERIFICATION - Camera state check")
	print("  - Enabled: ", camera.enabled)
	print("  - Current: ", camera.is_current())
	print("  - Zoom: ", camera.zoom)
	print("  - Limits: [", camera.limit_left, ",", camera.limit_top, ",", camera.limit_right, ",", camera.limit_bottom, "]")
	
	if not camera.enabled or not camera.is_current():
		print("PlayerController: VERIFICATION - Camera not properly activated, forcing activation")
		camera.enabled = true
		camera.make_current()
		print("PlayerController: VERIFICATION - Forced activation result - enabled: ", camera.enabled, " current: ", camera.is_current())
	else:
		print("PlayerController: VERIFICATION - Camera setup verified successfully")

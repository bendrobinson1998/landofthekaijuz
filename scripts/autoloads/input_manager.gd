extends Node

signal move_requested(target_position: Vector2)
signal interaction_requested(interactable: Node, move_to_position: Vector2)
signal action_pressed(action_name: String)
signal action_released(action_name: String)
signal chat_activation_requested()
signal edit_placement_requested(world_position: Vector2)
signal edit_removal_requested(world_position: Vector2)

var touch_start_position: Vector2 = Vector2.ZERO
var is_touching: bool = false
var touch_threshold: float = 10.0
var pending_interactable: Node = null
var is_chat_active: bool = false

var input_map: Dictionary = {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"interact": KEY_E,
	"inventory": KEY_I,
	"pause": KEY_ESCAPE
}

func _ready():
	set_process_unhandled_input(true)
	
	if ChatManager:
		ChatManager.chat_opened.connect(_on_chat_opened)
		ChatManager.chat_closed.connect(_on_chat_closed)

func _unhandled_input(event):
	_handle_touch_input(event)
	_handle_keyboard_input(event)

func _handle_touch_input(event):
	if is_chat_active:
		return
	
	if event is InputEventScreenTouch:
		if event.pressed:
			is_touching = true
			touch_start_position = event.position
		else:
			if is_touching:
				var touch_distance = touch_start_position.distance_to(event.position)
				
				# Only register as tap if movement was minimal (not a drag)
				if touch_distance < touch_threshold:
					var world_position = _screen_to_world(event.position)
					_handle_world_click(world_position, false)
				
				is_touching = false
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var world_position = _screen_to_world(event.position)
			_handle_world_click(world_position, event.shift_pressed)

func _handle_keyboard_input(event):
	if event is InputEventKey and event.pressed:
		for action_name in input_map.keys():
			if event.keycode == input_map[action_name]:
				action_pressed.emit(action_name)
				get_viewport().set_input_as_handled()
				return
	
	elif event is InputEventKey and not event.pressed:
		for action_name in input_map.keys():
			if event.keycode == input_map[action_name]:
				action_released.emit(action_name)
				return

func get_movement_vector() -> Vector2:
	if is_chat_active:
		return Vector2.ZERO
	
	var movement = Vector2.ZERO
	
	if Input.is_action_pressed("move_up"):
		movement.y -= 1
	if Input.is_action_pressed("move_down"):
		movement.y += 1
	if Input.is_action_pressed("move_left"):
		movement.x -= 1
	if Input.is_action_pressed("move_right"):
		movement.x += 1
	
	return movement.normalized()

func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)

func is_action_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)

func set_input_mapping(action: String, key: int):
	if action in input_map:
		input_map[action] = key

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var camera = get_viewport().get_camera_2d()
	if camera:
		# Convert screen position to world position using camera
		var viewport_size = get_viewport().get_visible_rect().size
		var camera_pos = camera.global_position
		var camera_offset = camera.offset
		var camera_zoom = camera.zoom
		
		# Account for camera transform
		var relative_pos = (screen_pos - viewport_size * 0.5) / camera_zoom
		return camera_pos + camera_offset + relative_pos
	else:
		return screen_pos

func get_world_mouse_position() -> Vector2:
	var camera = get_viewport().get_camera_2d()
	if camera:
		return camera.get_global_mouse_position()
	return get_viewport().get_mouse_position()

func _handle_world_click(world_position: Vector2, shift_pressed: bool = false):
	# Check if we're in edit mode
	if EditModeManager.is_edit_mode():
		if shift_pressed:
			edit_removal_requested.emit(world_position)
		else:
			edit_placement_requested.emit(world_position)
		return
	
	# Clear any previous pending interaction
	pending_interactable = null
	
	# First check if we clicked on any interactable objects
	var interactable = _get_interactable_at_position(world_position)
	
	if interactable:
		# Try to interact with the object
		var interaction_successful = interactable.try_interact()
		
		if interaction_successful:
			# Interaction happened immediately, don't move
			return
		else:
			# Object is too far, store as pending and move towards it
			pending_interactable = interactable
			var move_position = _get_interaction_position(interactable)
			interaction_requested.emit(interactable, move_position)
			return
	
	# No interactable object clicked, proceed with normal movement
	move_requested.emit(world_position)

func _get_interactable_at_position(world_pos: Vector2) -> Node:
	var space = get_tree().current_scene.get_world_2d().direct_space_state
	if not space:
		return null
	
	# Set up physics query parameters
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = world_pos
	parameters.collide_with_areas = true
	parameters.collision_mask = 2  # Interactables are on layer 2
	
	# Get all objects at this position
	var results = space.intersect_point(parameters)
	
	
	# Look for interactable objects (Area2D with Interactable script)
	for result in results:
		var collider = result["collider"]
		
		
		# Check if it's an Interactable or extends Interactable
		if collider.has_method("try_interact"):
			return collider
	
	
	return null

func _get_interaction_position(interactable: Node) -> Vector2:
	# Calculate position near the closest edge of the collision area
	if not interactable:
		return Vector2.ZERO
		
	var player = get_tree().current_scene.find_child("Player", true, false)
	if not player:
		return interactable.global_position
	
	# Get the collision shape bounds
	var collision_bounds = _get_collision_bounds(interactable)
	
	# Find closest point on the collision boundary to player
	var player_pos = player.global_position
	var tree_pos = interactable.global_position
	var closest_edge_point = _get_closest_edge_point(player_pos, tree_pos, collision_bounds)
	
	# Position player just outside the interaction range from the closest edge
	var direction_to_player = (player_pos - closest_edge_point).normalized()
	var interaction_range = interactable.interaction_range if "interaction_range" in interactable else 32.0
	var target_position = closest_edge_point + direction_to_player * (interaction_range - 5.0) # 5px buffer inside range
	
	
	return target_position

func clear_pending_interaction():
	pending_interactable = null

func _get_collision_bounds(interactable: Node) -> Rect2:
	# Get the bounding box of the collision area
	var collision_shape = interactable.find_child("CollisionShape2D")
	var collision_polygon = interactable.find_child("CollisionPolygon2D")
	
	if collision_polygon and collision_polygon.polygon.size() > 0:
		# Calculate bounds from polygon points
		var min_x = INF
		var max_x = -INF
		var min_y = INF
		var max_y = -INF
		
		for point in collision_polygon.polygon:
			min_x = min(min_x, point.x)
			max_x = max(max_x, point.x)
			min_y = min(min_y, point.y)
			max_y = max(max_y, point.y)
		
		return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
	
	elif collision_shape and collision_shape.shape:
		# Get bounds from shape
		var shape = collision_shape.shape
		if shape is RectangleShape2D:
			var rect_shape = shape as RectangleShape2D
			var half_size = rect_shape.size * 0.5
			return Rect2(-half_size, rect_shape.size)
		elif shape is CircleShape2D:
			var circle_shape = shape as CircleShape2D
			var radius = circle_shape.radius
			return Rect2(-radius, -radius, radius * 2, radius * 2)
		elif shape is CapsuleShape2D:
			var capsule_shape = shape as CapsuleShape2D
			var radius = capsule_shape.radius
			var half_height = capsule_shape.height * 0.5
			return Rect2(-radius, -half_height, radius * 2, capsule_shape.height)
	
	# Fallback - return empty rect
	return Rect2()

func _get_closest_edge_point(player_pos: Vector2, tree_pos: Vector2, bounds: Rect2) -> Vector2:
	# Convert bounds to world coordinates
	var world_bounds = Rect2(tree_pos + bounds.position, bounds.size)
	
	# Find closest point on rectangle boundary to player
	var closest_x = clamp(player_pos.x, world_bounds.position.x, world_bounds.position.x + world_bounds.size.x)
	var closest_y = clamp(player_pos.y, world_bounds.position.y, world_bounds.position.y + world_bounds.size.y)
	
	# If player is inside the bounds, find the closest edge
	if world_bounds.has_point(player_pos):
		# Distance to each edge
		var dist_left = abs(player_pos.x - world_bounds.position.x)
		var dist_right = abs(player_pos.x - (world_bounds.position.x + world_bounds.size.x))
		var dist_top = abs(player_pos.y - world_bounds.position.y)
		var dist_bottom = abs(player_pos.y - (world_bounds.position.y + world_bounds.size.y))
		
		var min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom))
		
		if min_dist == dist_left:
			closest_x = world_bounds.position.x
		elif min_dist == dist_right:
			closest_x = world_bounds.position.x + world_bounds.size.x
		elif min_dist == dist_top:
			closest_y = world_bounds.position.y
		else: # dist_bottom
			closest_y = world_bounds.position.y + world_bounds.size.y
	
	return Vector2(closest_x, closest_y)

func _on_chat_opened():
	is_chat_active = true

func _on_chat_closed():
	is_chat_active = false

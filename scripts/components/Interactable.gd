class_name Interactable
extends Area2D

signal interaction_started()
signal interaction_ended()

enum InteractionType {
	CUSTOM,           # Calls _on_interact() - for custom behavior
	SCENE_CHANGE,     # Changes to specified scene
	HARVEST_RESOURCE, # Harvests specified resource (like trees)
	TOGGLE_OBJECT     # Toggles object state (doors, switches, etc.)
}

@export var interaction_prompt_text: String = "Click to interact"
@export var highlight_color: Color = Color.YELLOW
@export var outline_width: float = 2.0
@export var interaction_range: float = 32.0  # Distance player needs to be within to interact

# Action Configuration
@export var interaction_type: InteractionType = InteractionType.CUSTOM
@export var target_scene_path: String = ""  # For SCENE_CHANGE
@export var harvest_item: ItemResource = null  # For HARVEST_RESOURCE
@export var min_harvest_amount: int = 1
@export var max_harvest_amount: int = 1
@export var harvest_interval: float = 0.5  # Time between harvests
@export var requires_continuous_action: bool = false  # Like chopping trees

@onready var interaction_prompt: Label = $InteractionPrompt

var player_in_range: bool = false
var is_highlighted: bool = false
var original_modulate: Color
var outline_material: ShaderMaterial
var target_sprite: Node2D

# Harvest state (for HARVEST_RESOURCE type)
var total_resources_remaining: int = 0
var is_being_harvested: bool = false
var harvest_timer: Timer
var player_harvesting: Node = null

func _ready():
	# Setup collision detection for player interaction
	collision_mask = 1  # Monitor layer 1 where player is located
	monitoring = true   # Enable Area2D monitoring
	
	# Connect mouse and body signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	# Find the sprite to apply outline to (look for common sprite node names)
	target_sprite = find_sprite_node()
	
	if target_sprite:
		original_modulate = target_sprite.modulate
	
	# Hide interaction prompt by default
	if interaction_prompt:
		interaction_prompt.visible = false
		interaction_prompt.text = interaction_prompt_text
	
	_create_outline_shader()
	
	# Setup harvest system if needed
	if interaction_type == InteractionType.HARVEST_RESOURCE:
		_setup_harvest_system()

func find_sprite_node() -> Node2D:
	# Look for common sprite node names
	var potential_names = ["Sprite2D", "AnimatedSprite2D", "TextureRect", "NinePatchRect"]
	
	for name in potential_names:
		var sprite = find_child(name, true, false)
		if sprite and sprite is Node2D:
			return sprite
	
	# If no named sprite found, look for first child that can have a material
	for child in get_children():
		if child.has_method("set_material") or "material" in child:
			return child
	
	return null

func _create_outline_shader():
	var shader = load("res://outline.gdshader")
	if not shader:
		if OS.is_debug_build():
			print("Warning: outline.gdshader not found for ", name, " - highlighting disabled")
		return
	
	outline_material = ShaderMaterial.new()
	outline_material.shader = shader
	
	# Configure the outline parameters
	outline_material.set_shader_parameter("color", highlight_color)
	outline_material.set_shader_parameter("width", outline_width)
	outline_material.set_shader_parameter("pattern", 0)  # diamond pattern
	outline_material.set_shader_parameter("inside", false)  # outside outline
	outline_material.set_shader_parameter("add_margins", false)
	
	if OS.is_debug_build():
		print("Outline shader created for ", name, " targeting sprite: ", target_sprite.name if target_sprite else "none")

func _on_mouse_entered():
	_highlight_object(true)
	_show_interaction_prompt(true)

func _on_mouse_exited():
	_highlight_object(false)
	_show_interaction_prompt(false)

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# This will be handled by the InputManager now
		pass

func _on_body_entered(body):
	if body is PlayerController:
		player_in_range = true

func _on_body_exited(body):
	if body is PlayerController:
		player_in_range = false
		_highlight_object(false)
		_show_interaction_prompt(false)

func _highlight_object(highlight: bool):
	if not target_sprite:
		return
		
	is_highlighted = highlight
	if highlight:
		if target_sprite.has_method("set_material"):
			target_sprite.set_material(outline_material)
		elif "material" in target_sprite:
			target_sprite.material = outline_material
	else:
		if target_sprite.has_method("set_material"):
			target_sprite.set_material(null)
		elif "material" in target_sprite:
			target_sprite.material = null

func _show_interaction_prompt(show: bool):
	if interaction_prompt:
		interaction_prompt.visible = show

# Method called by InputManager when this object is clicked
func try_interact() -> bool:
	# Use edge-based distance calculation instead of center-based
	var player = _find_player()
	if not player:
		return false
		
	# Calculate distance from collision edge to player
	var edge_distance = _get_edge_distance_to_player(player)
	var is_in_range = edge_distance <= interaction_range
	
	if OS.is_debug_build():
		var center_distance = global_position.distance_to(player.global_position)
		print("Interactable.try_interact: edge_distance=", edge_distance, " center_distance=", center_distance, " interaction_range=", interaction_range, " in_range=", is_in_range)
	
	if is_in_range:
		# Player is within interaction range of collision edge
		_on_interact()
		return true
	else:
		# Player needs to move closer
		if OS.is_debug_build():
			print("Interactable: Player not in range, needs to move closer")
		return false

func _find_player() -> PlayerController:
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene.find_child("Player", true, false) as PlayerController
	return null

# Main interaction handler - processes based on interaction_type
func _on_interact():
	interaction_started.emit()
	
	if OS.is_debug_build():
		print("Interactable: Processing ", InteractionType.keys()[interaction_type], " interaction")
	
	match interaction_type:
		InteractionType.SCENE_CHANGE:
			_handle_scene_change()
		InteractionType.HARVEST_RESOURCE:
			_handle_harvest_resource()
		InteractionType.TOGGLE_OBJECT:
			_handle_toggle_object()
		InteractionType.CUSTOM:
			_handle_custom_interaction()

# Virtual method for child classes to override for custom behavior
func _handle_custom_interaction():
	# Override in child classes for specific behavior
	pass

func _handle_scene_change():
	if target_scene_path.is_empty():
		print("Error: No target scene specified for scene change interaction")
		return
	
	if not ResourceLoader.exists(target_scene_path):
		print("Error: Target scene not found: ", target_scene_path)
		return
	
	if OS.is_debug_build():
		print("Interactable: Changing to scene: ", target_scene_path)
	
	get_tree().change_scene_to_file(target_scene_path)

func _handle_harvest_resource():
	if not harvest_item:
		print("Error: No harvest item specified for harvest interaction")
		return
	
	if total_resources_remaining <= 0:
		print("No resources remaining to harvest")
		return
	
	var player = _find_player()
	if not player:
		return
	
	if requires_continuous_action:
		_start_continuous_harvest(player)
	else:
		_perform_single_harvest()

func _handle_toggle_object():
	# Basic toggle - child classes can override for specific behavior
	print("Object toggled!")
	# You can add generic toggle logic here

# Harvest system implementation
func _setup_harvest_system():
	if not harvest_item:
		return
	
	# Initialize resource count
	total_resources_remaining = randi_range(min_harvest_amount, max_harvest_amount)
	
	# Setup harvest timer if needed
	if requires_continuous_action:
		harvest_timer = Timer.new()
		add_child(harvest_timer)
		harvest_timer.wait_time = harvest_interval
		harvest_timer.timeout.connect(_on_harvest_timer_timeout)
	
	if OS.is_debug_build():
		print("Harvest system setup with ", total_resources_remaining, " resources")

func _start_continuous_harvest(player: Node):
	if is_being_harvested or total_resources_remaining <= 0:
		return
	
	is_being_harvested = true
	player_harvesting = player
	
	# Tell player to start the harvest animation/state (if it exists)
	if player.has_method("start_chopping"):
		player.start_chopping(self)
	
	# Start the harvest timer
	if harvest_timer:
		harvest_timer.start()
		# Give first harvest immediately
		_perform_single_harvest()

func _perform_single_harvest():
	if total_resources_remaining <= 0:
		_on_harvest_depleted()
		return
	
	# Try to add to inventory
	var harvest_amount = 1  # Could be made configurable
	var remaining = InventoryManager.add_item(harvest_item, harvest_amount)
	
	if remaining == harvest_amount:
		# Inventory full
		print("Inventory full! Stopping harvest.")
		_stop_harvest()
		return
	
	# Successfully harvested
	var harvested = harvest_amount - remaining
	total_resources_remaining -= harvested
	
	if OS.is_debug_build():
		var item_name = "resource"
		if harvest_item and harvest_item.has_method("get_display_name"):
			item_name = harvest_item.get_display_name()
		elif harvest_item and "name" in harvest_item:
			item_name = harvest_item.name
		elif harvest_item and harvest_item.resource_path != "":
			item_name = harvest_item.resource_path.get_file().get_basename()
		print("Harvested ", harvested, " ", item_name, ". Remaining: ", total_resources_remaining)
	
	# Visual feedback
	_play_harvest_animation()
	
	# Check if depleted
	if total_resources_remaining <= 0:
		_on_harvest_depleted()

func _stop_harvest():
	if not is_being_harvested:
		return
	
	is_being_harvested = false
	if harvest_timer:
		harvest_timer.stop()
	
	# Tell player to stop harvest animation/state
	if player_harvesting and player_harvesting.has_method("stop_chopping"):
		player_harvesting.stop_chopping()
	
	player_harvesting = null

func _on_harvest_timer_timeout():
	if not is_being_harvested or not player_harvesting:
		_stop_harvest()
		return
	
	# Check if player is still close enough
	var distance = global_position.distance_to(player_harvesting.global_position)
	if distance > interaction_range * 1.5:  # Give some leeway
		_stop_harvest()
		return
	
	_perform_single_harvest()

func _on_harvest_depleted():
	print("Resource fully harvested!")
	_stop_harvest()
	
	# Properly disable collision shapes before removing the tree
	_disable_all_collision_shapes()
	
	# Could hide the object, remove it, or change its appearance
	# For now, just remove it like trees do
	queue_free()

func _play_harvest_animation():
	if not target_sprite:
		return
	
	# Simple shake animation
	var tween = create_tween()
	var original_pos = target_sprite.position
	
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	
	# Shake the object
	for i in range(3):
		tween.tween_property(target_sprite, "position", original_pos + Vector2(randf_range(-3, 3), 0), 0.08)
		tween.tween_property(target_sprite, "position", original_pos, 0.08)

func _get_edge_distance_to_player(player: Node) -> float:
	# Calculate distance from closest collision edge to player
	var collision_bounds = _get_collision_bounds()
	
	# Get closest point on collision boundary to player
	var player_pos = player.global_position
	var closest_edge_point = _get_closest_edge_point(player_pos, collision_bounds)
	
	return player_pos.distance_to(closest_edge_point)

func _get_collision_bounds() -> Rect2:
	# Get the bounding box of this interactable's collision area
	var collision_shape = find_child("CollisionShape2D")
	var collision_polygon = find_child("CollisionPolygon2D")
	
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

func _get_closest_edge_point(player_pos: Vector2, bounds: Rect2) -> Vector2:
	# Convert bounds to world coordinates
	var world_bounds = Rect2(global_position + bounds.position, bounds.size)
	
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

func _disable_all_collision_shapes():
	# Disable this Area2D's collision shapes
	var collision_shapes = find_children("", "CollisionShape2D", true, false)
	var collision_polygons = find_children("", "CollisionPolygon2D", true, false)
	
	for shape in collision_shapes:
		shape.set_deferred("disabled", true)
	
	for polygon in collision_polygons:
		polygon.set_deferred("disabled", true)
	
	# Also disable parent StaticBody2D collision shapes if they exist
	var parent_node = get_parent()
	if parent_node and parent_node is StaticBody2D:
		var parent_collision_shapes = parent_node.find_children("", "CollisionShape2D", true, false)
		var parent_collision_polygons = parent_node.find_children("", "CollisionPolygon2D", true, false)
		
		for shape in parent_collision_shapes:
			shape.set_deferred("disabled", true)
		
		for polygon in parent_collision_polygons:
			polygon.set_deferred("disabled", true)

extends Node2D

var reach_circle: Node2D
var preview_tile: Node2D
var grid_overlay: Node2D
var player_controller: Node
var path_placement_manager: Node
var ground_layer: TileMapLayer

func _ready() -> void:
	name = "EditModeVisualFeedback"
	
	call_deferred("_initialize")

func _initialize() -> void:
	_find_dependencies()
	_create_visual_elements()
	_connect_signals()

func _find_dependencies() -> void:
	player_controller = get_tree().get_first_node_in_group("player")
	if not player_controller:
		push_warning("EditModeVisualFeedback: Player controller not found")
	
	var main_world = get_tree().get_first_node_in_group("main_world")
	if main_world:
		path_placement_manager = main_world.get_node_or_null("PathPlacementManager")
		ground_layer = main_world.get_node_or_null("GroundLayer")
	
	if not path_placement_manager:
		push_warning("EditModeVisualFeedback: PathPlacementManager not found")
	
	if not ground_layer:
		push_warning("EditModeVisualFeedback: GroundLayer not found")

func _create_visual_elements() -> void:
	reach_circle = Node2D.new()
	reach_circle.name = "ReachCircle"
	reach_circle.visible = false
	reach_circle.draw.connect(_on_reach_circle_draw)
	add_child(reach_circle)
	
	preview_tile = Node2D.new()
	preview_tile.name = "PreviewTile"
	preview_tile.visible = false
	preview_tile.draw.connect(_on_preview_tile_draw)
	add_child(preview_tile)
	
	grid_overlay = Node2D.new()
	grid_overlay.name = "GridOverlay"
	grid_overlay.visible = false
	grid_overlay.draw.connect(_on_grid_overlay_draw)
	add_child(grid_overlay)

func _connect_signals() -> void:
	if EditModeManager:
		EditModeManager.edit_mode_toggled.connect(_on_edit_mode_toggled)
	
	if InputManager:
		InputManager.edit_placement_requested.connect(_on_placement_requested)
		InputManager.edit_removal_requested.connect(_on_removal_requested)

func _process(_delta: float) -> void:
	if EditModeManager.is_edit_mode() and player_controller:
		_update_reach_circle()
		_update_preview_tile()
		_update_grid_overlay()

func _update_reach_circle() -> void:
	if not reach_circle or not path_placement_manager:
		return
	
	reach_circle.position = player_controller.global_position
	reach_circle.queue_redraw()

func _update_preview_tile() -> void:
	if not preview_tile or not ground_layer:
		return
	
	var mouse_pos = InputManager.get_world_mouse_position()
	# Snap preview tile to grid
	var map_pos = ground_layer.local_to_map(mouse_pos)
	var snapped_world_pos = ground_layer.map_to_local(map_pos)
	preview_tile.position = snapped_world_pos
	
	# Show green if can place, red if can't
	var can_place = path_placement_manager and path_placement_manager.can_place_at_position(mouse_pos)
	preview_tile.modulate = Color.GREEN if can_place else Color.RED
	preview_tile.queue_redraw()

func _on_edit_mode_toggled(enabled: bool) -> void:
	visible = enabled
	
	if reach_circle:
		reach_circle.visible = enabled
	if preview_tile:
		preview_tile.visible = enabled
	if grid_overlay:
		grid_overlay.visible = enabled

func _on_placement_requested(world_position: Vector2) -> void:
	if path_placement_manager:
		var success = path_placement_manager.place_path_at_position(world_position)
		if success:
			_show_placement_effect(world_position, Color.GREEN)
		else:
			_show_placement_effect(world_position, Color.RED)

func _on_removal_requested(world_position: Vector2) -> void:
	if path_placement_manager:
		var success = path_placement_manager.remove_path_at_position(world_position)
		if success:
			_show_placement_effect(world_position, Color.YELLOW)
		else:
			_show_placement_effect(world_position, Color.RED)

func _show_placement_effect(world_position: Vector2, color: Color) -> void:
	var effect = Node2D.new()
	effect.position = world_position
	effect.modulate = color
	add_child(effect)
	
	# Simple fade out effect
	var tween = create_tween()
	tween.parallel().tween_property(effect, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(effect, "scale", Vector2(2.0, 2.0), 0.5)
	tween.tween_callback(effect.queue_free)

func _draw() -> void:
	if not EditModeManager.is_edit_mode() or not path_placement_manager:
		return

# Draw reach circle on reach_circle node
func _on_reach_circle_draw() -> void:
	if path_placement_manager:
		var radius = path_placement_manager.get_reach_radius()
		reach_circle.draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color.CYAN, 2.0, false)

func _update_grid_overlay() -> void:
	if not grid_overlay:
		return
	
	grid_overlay.queue_redraw()

# Draw preview tile on preview_tile node
func _on_preview_tile_draw() -> void:
	var tile_size = _get_tile_size()
	var rect = Rect2(-tile_size/2, -tile_size/2, tile_size, tile_size)
	preview_tile.draw_rect(rect, preview_tile.modulate, false, 2.0)

# Draw grid overlay
func _on_grid_overlay_draw() -> void:
	if not ground_layer or not player_controller:
		return
	
	var tile_size = _get_tile_size()
	var grid_color = Color(1.0, 1.0, 1.0, 0.3)  # Semi-transparent white
	var line_width = 1.0
	
	# Get camera viewport to determine grid bounds
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	# Calculate visible area around camera
	var camera_pos = camera.global_position
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom = camera.zoom
	var visible_size = viewport_size / zoom
	
	# Add padding to draw grid beyond visible area
	var padding = tile_size * 5
	var min_x = camera_pos.x - visible_size.x / 2 - padding
	var max_x = camera_pos.x + visible_size.x / 2 + padding
	var min_y = camera_pos.y - visible_size.y / 2 - padding
	var max_y = camera_pos.y + visible_size.y / 2 + padding
	
	# Snap to tile boundaries
	min_x = floor(min_x / tile_size) * tile_size
	max_x = ceil(max_x / tile_size) * tile_size
	min_y = floor(min_y / tile_size) * tile_size
	max_y = ceil(max_y / tile_size) * tile_size
	
	# Draw vertical lines
	var x = min_x
	while x <= max_x:
		grid_overlay.draw_line(
			Vector2(x, min_y),
			Vector2(x, max_y),
			grid_color,
			line_width
		)
		x += tile_size
	
	# Draw horizontal lines
	var y = min_y
	while y <= max_y:
		grid_overlay.draw_line(
			Vector2(min_x, y),
			Vector2(max_x, y),
			grid_color,
			line_width
		)
		y += tile_size

# Get actual tile size from TileMapLayer or fallback to 16
func _get_tile_size() -> float:
	if ground_layer and ground_layer.tile_set:
		return float(ground_layer.tile_set.tile_size.x)
	return 16.0

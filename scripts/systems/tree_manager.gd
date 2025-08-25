class_name TreeManager
extends Node2D

@export_group("Tree Placement Settings")
@export var tree_density: float = 0.15  # Chance per grass tile (0.0 to 1.0)
@export var min_tree_spacing: int = 2   # Minimum tiles between trees
@export var enable_random_placement: bool = true
@export var placement_seed: int = -1    # -1 for random seed

@export_group("Tree Distribution")
@export var small_tree_weight: float = 0.4
@export var medium_tree_weight: float = 0.4
@export var big_tree_weight: float = 0.2

@export_group("Tree Species Distribution") 
@export var oak_weight: float = 0.4
@export var birch_weight: float = 0.3
@export var spruce_weight: float = 0.2
@export var fruit_weight: float = 0.1

# References to TileMapLayers
@onready var ground_layer: TileMapLayer
@onready var obstacle_layer: TileMapLayer  
@onready var decoration_layer: TileMapLayer
@onready var elevation_layer: TileMapLayer
@onready var elevation_decoration_layer: TileMapLayer

# Tree resources
var tree_textures: Dictionary = {}
var tree_scene: PackedScene
var placed_trees: Array[Vector2] = []

# Optimization data structures
var obstacle_positions: Dictionary = {}  # Vector2i -> bool for O(1) lookup
var decoration_positions: Dictionary = {}  # Vector2i -> bool for O(1) lookup
var elevation_decoration_positions: Dictionary = {}  # Vector2i -> bool for O(1) lookup
var valid_grass_tiles: Array[Vector2i] = []  # Pre-filtered grass positions
var tree_positions_grid: Dictionary = {}  # Vector2i -> bool for spacing checks

# Tree size configurations (collision and offset)
var tree_configs: Dictionary = {
	"Small": {"collision_size": Vector2(12, 6), "sprite_offset": Vector2(0, -12)},
	"Medium": {"collision_size": Vector2(16, 8), "sprite_offset": Vector2(0, -16)},
	"Big": {"collision_size": Vector2(20, 10), "sprite_offset": Vector2(0, -24)}
}

func _ready():
	# Set random seed if specified
	if placement_seed != -1:
		seed(placement_seed)
	
	# Load tree resources
	_load_tree_resources()
	
	# Find TileMapLayer references
	_find_tile_layers()
	
	# Wait a frame to ensure all nodes are ready
	call_deferred("_place_trees")

func _input(event):
	# Debug key bindings
	if event.is_action_pressed("ui_accept"):  # Enter key
		print("Regenerating trees...")
		regenerate_trees()
	elif event.is_action_pressed("ui_cancel"):  # Escape key
		print("Clearing trees...")
		clear_all_trees()

func _load_tree_resources():
	# Load the tree scene template
	tree_scene = preload("res://scenes/environment/Tree1.tscn")
	
	# Define tree texture paths
	var tree_types = [
		"Small_Oak_Tree", "Small_Birch_Tree", "Small_Spruce_Tree", "Small_Fruit_Tree",
		"Medium_Oak_Tree", "Medium_Birch_Tree", "Medium_Spruce_Tree", "Medium_Fruit_Tree",
		"Big_Oak_Tree", "Big_Birch_Tree", "Big_Spruce_tree", "Big_Fruit_Tree"
	]
	
	# Load all tree textures
	for tree_type in tree_types:
		var path = "res://assets/Trees/" + tree_type + ".png"
		var texture = load(path)
		if texture:
			tree_textures[tree_type] = texture
		else:
			print("Warning: Could not load tree texture: ", path)

func _find_tile_layers():
	# Get references to the TileMapLayers
	var main_world = get_parent()
	if main_world:
		ground_layer = main_world.get_node_or_null("GroundLayer")
		obstacle_layer = main_world.get_node_or_null("ObstacleLayer")  
		decoration_layer = main_world.get_node_or_null("DecorationLayer")
		elevation_layer = main_world.get_node_or_null("ElevationLayer")
		elevation_decoration_layer = main_world.get_node_or_null("ElevationDecorationLayer")
	
	if not ground_layer:
		print("Error: GroundLayer not found!")
		return
	if not obstacle_layer:
		print("Warning: ObstacleLayer not found!")
	if not decoration_layer:
		print("Warning: DecorationLayer not found!")
	if not elevation_layer:
		print("Warning: ElevationLayer not found!")
	if not elevation_decoration_layer:
		print("Warning: ElevationDecorationLayer not found!")

func _place_trees():
	if not ground_layer:
		print("TreeManager: Cannot place trees - GroundLayer not found")
		return
	
	print("TreeManager: Starting optimized tree placement...")
	
	# Call async placement function
	_place_trees_async()

func _place_trees_async():
	"""Optimized async tree placement with batching and spatial optimization"""
	var start_time = Time.get_ticks_msec()
	
	# Phase 1: Build spatial lookup tables
	print("TreeManager: Building spatial lookup tables...")
	await _build_spatial_lookups()
	
	# Phase 2: Find valid grass positions
	print("TreeManager: Filtering valid grass positions...")
	await _find_valid_grass_positions()
	
	# Phase 3: Select tree positions with optimized collision detection
	print("TreeManager: Selecting tree positions...")
	var selected_positions = await _select_tree_positions()
	
	# Phase 4: Batch instantiate all trees
	print("TreeManager: Instantiating ", selected_positions.size(), " trees...")
	await _instantiate_trees_batch(selected_positions)
	
	# Performance summary
	var total_time = Time.get_ticks_msec() - start_time
	print("\n=== TREE PLACEMENT SUMMARY ===")
	print("Ground tiles processed: ", ground_layer.get_used_cells().size())
	print("Obstacle positions cached: ", obstacle_positions.size())
	print("Decoration positions cached: ", decoration_positions.size()) 
	print("Elevation decoration positions cached: ", elevation_decoration_positions.size()) 
	print("Valid grass tiles found: ", valid_grass_tiles.size())
	print("Trees successfully placed: ", selected_positions.size())
	print("Total placement time: ", total_time, "ms")
	print("Average time per tree: ", (total_time / float(max(selected_positions.size(), 1))), "ms")
	print("===============================\n")

func _build_spatial_lookups():
	"""Build O(1) lookup tables for obstacles and decorations"""
	obstacle_positions.clear()
	decoration_positions.clear()
	elevation_decoration_positions.clear()
	
	# Cache obstacle positions
	if obstacle_layer:
		var obstacle_cells = obstacle_layer.get_used_cells()
		for pos in obstacle_cells:
			obstacle_positions[pos] = true
	
	# Cache decoration positions  
	if decoration_layer:
		var decoration_cells = decoration_layer.get_used_cells()
		for pos in decoration_cells:
			decoration_positions[pos] = true
	
	# Cache elevation decoration positions
	if elevation_decoration_layer:
		var elevation_decoration_cells = elevation_decoration_layer.get_used_cells()
		for pos in elevation_decoration_cells:
			elevation_decoration_positions[pos] = true
	
	# Yield every 1000 operations to prevent frame drops
	if (obstacle_positions.size() + decoration_positions.size() + elevation_decoration_positions.size()) > 1000:
		await get_tree().process_frame

func _find_valid_grass_positions():
	"""Pre-filter all grass tiles to valid positions"""
	valid_grass_tiles.clear()
	
	var used_cells = ground_layer.get_used_cells()
	var processed = 0
	
	for cell_pos in used_cells:
		if _is_grass_middle_tile(cell_pos):
			if not obstacle_positions.has(cell_pos) and not decoration_positions.has(cell_pos) and not elevation_decoration_positions.has(cell_pos):
				valid_grass_tiles.append(cell_pos)
		
		processed += 1
		# Yield every 500 tiles to maintain responsiveness
		if processed % 500 == 0:
			await get_tree().process_frame

func _select_tree_positions() -> Array[Vector2i]:
	"""Select tree positions using truly random distribution"""
	var selected_positions: Array[Vector2i] = []
	tree_positions_grid.clear()
	
	# Calculate target number of trees based on density
	var target_tree_count = int(valid_grass_tiles.size() * tree_density)
	print("TreeManager: Target tree count: ", target_tree_count, " from ", valid_grass_tiles.size(), " valid positions")
	
	# Create a copy to randomly sample from
	var available_positions = valid_grass_tiles.duplicate()
	available_positions.shuffle()
	
	var attempts = 0
	var max_attempts = available_positions.size() * 2  # Prevent infinite loops
	
	while selected_positions.size() < target_tree_count and attempts < max_attempts:
		if available_positions.is_empty():
			break
		
		# Pick a random position from remaining available positions
		var random_index = randi() % available_positions.size()
		var cell_pos = available_positions[random_index]
		
		# Remove this position from available (so we don't try it again)
		available_positions.remove_at(random_index)
		
		# Check if position is still valid (not too close to other trees)
		if _is_position_valid_for_random_placement(cell_pos, selected_positions):
			selected_positions.append(cell_pos)
			# Mark this position as occupied for spacing checks
			tree_positions_grid[cell_pos] = true
		
		attempts += 1
		
		# Yield every 100 attempts to maintain responsiveness
		if attempts % 100 == 0:
			await get_tree().process_frame
	
	print("TreeManager: Selected ", selected_positions.size(), " positions after ", attempts, " attempts")
	return selected_positions

func _is_position_valid_for_random_placement(cell_pos: Vector2i, existing_positions: Array[Vector2i]) -> bool:
	"""Check if position is valid for random placement with minimum spacing"""
	
	# If no spacing required, always valid
	if min_tree_spacing <= 0:
		return true
	
	# Check distance to all existing trees
	for existing_pos in existing_positions:
		var distance = _get_tile_distance(cell_pos, existing_pos)
		if distance < min_tree_spacing:
			return false
	
	return true

func _get_tile_distance(pos1: Vector2i, pos2: Vector2i) -> float:
	"""Calculate Euclidean distance between two tile positions"""
	var dx = pos1.x - pos2.x
	var dy = pos1.y - pos2.y
	return sqrt(dx * dx + dy * dy)

# Removed old spatial grid functions - using simpler random distribution

func _instantiate_trees_batch(positions: Array[Vector2i]):
	"""Batch instantiate all trees at once for better performance"""
	var trees_to_add: Array[Node2D] = []
	
	for i in range(positions.size()):
		var cell_pos = positions[i]
		var world_pos = ground_layer.map_to_local(cell_pos)
		
		# Create tree instance
		var tree_instance = tree_scene.instantiate()
		tree_instance.global_position = world_pos
		
		# Configure tree
		var tree_info = _get_random_tree_type()
		_configure_tree(tree_instance, tree_info)
		
		trees_to_add.append(tree_instance)
		placed_trees.append(world_pos)
		
		# Yield every 50 instantiations to maintain responsiveness
		if i % 50 == 0:
			await get_tree().process_frame
	
	# Add all trees to scene at once
	for tree in trees_to_add:
		add_child(tree)

func _is_grass_middle_tile(cell_pos: Vector2i) -> bool:
	# Check if this tile is a Grass_1_middle tile
	var source_id = ground_layer.get_cell_source_id(cell_pos)
	var atlas_coords = ground_layer.get_cell_atlas_coords(cell_pos)
	
	# Skip empty cells
	if source_id < 0:
		return false
	
	var tile_set = ground_layer.tile_set
	if not tile_set:
		return false
	
	var source = tile_set.get_source(source_id)
	if not source or not source is TileSetAtlasSource:
		return false
	
	var atlas_source = source as TileSetAtlasSource
	var texture = atlas_source.texture
	
	# Primary check: texture path contains "Grass_1_Middle"
	if texture and texture.resource_path.contains("Grass_1_Middle"):
		return true
	
	# Fallback check: source_id 0 with atlas (0,0) - adjust these values based on your tileset
	# This assumes the first source in your tileset is the Grass_1_Middle texture
	if source_id == 0 and atlas_coords == Vector2i(0, 0):
		if texture and texture.resource_path.ends_with("Grass_1_Middle.png"):
			return true
	
	return false

func _should_place_tree() -> bool:
	if not enable_random_placement:
		return true
	return randf() < tree_density

# Legacy functions removed - using optimized versions instead

func _get_random_tree_type() -> Dictionary:
	# Get all available tree texture names
	var available_trees = tree_textures.keys()
	
	if available_trees.is_empty():
		# Fallback to default if no textures loaded
		return {
			"name": "Medium_Oak_Tree",
			"size": "Medium",
			"species": "Oak"
		}
	
	# Truly random selection from all available trees
	var random_tree_name = available_trees[randi() % available_trees.size()]
	
	# Parse the tree name to extract size and species
	var parts = random_tree_name.split("_")
	var size = "Medium"  # Default
	var species = "Oak"  # Default
	
	if parts.size() >= 2:
		size = parts[0]  # Small, Medium, Big
		if parts.size() >= 3:
			species = parts[1]  # Oak, Birch, Spruce, Fruit
		else:
			species = parts[1].split("_")[0]  # Handle cases like "Spruce_tree"
	
	return {
		"name": random_tree_name,
		"size": size,
		"species": species
	}

func _configure_tree(tree_instance: StaticBody2D, tree_info: Dictionary):
	var sprite = tree_instance.get_node("Sprite2D")
	var collision = tree_instance.get_node("CollisionShape2D")
	
	# Set texture
	var texture = tree_textures.get(tree_info.name)
	if texture:
		sprite.texture = texture
	else:
		print("Warning: Texture not found for ", tree_info.name)
	
	# Configure sprite offset and collision based on tree size
	var config = tree_configs.get(tree_info.size, tree_configs["Medium"])
	sprite.offset = config.sprite_offset
	
	# Update collision shape
	var shape = RectangleShape2D.new()
	shape.size = config.collision_size
	collision.shape = shape
	collision.position = Vector2(0, config.collision_size.y / 2)

# Public methods for external control
func clear_all_trees():
	"""Remove all placed trees and clear optimization data"""
	for child in get_children():
		if child is StaticBody2D:
			child.queue_free()
	placed_trees.clear()
	tree_positions_grid.clear()
	valid_grass_tiles.clear()

func regenerate_trees():
	"""Clear and regenerate all trees using optimized system"""
	clear_all_trees()
	await get_tree().process_frame  # Wait for trees to be removed
	print("TreeManager: Regenerating trees...")
	_place_trees_async()

func add_manual_tree(world_position: Vector2, tree_type: String = ""):
	"""Manually place a tree at a specific world position"""
	var tree_instance = tree_scene.instantiate()
	tree_instance.global_position = world_position
	
	var tree_info: Dictionary
	if tree_type.is_empty():
		tree_info = _get_random_tree_type()
	else:
		# Parse the tree_type string to get size and species
		var parts = tree_type.split("_")
		if parts.size() >= 2:
			tree_info = {"name": tree_type, "size": parts[0], "species": parts[1]}
		else:
			tree_info = _get_random_tree_type()
	
	_configure_tree(tree_instance, tree_info)
	add_child(tree_instance)
	placed_trees.append(world_position)

# Utility method for trees that need to respawn with the same type
func get_tree_texture(tree_name: String) -> Texture2D:
	"""Get texture for a specific tree type"""
	return tree_textures.get(tree_name)

func get_available_tree_types() -> Array:
	"""Get all available tree type names"""
	return tree_textures.keys()
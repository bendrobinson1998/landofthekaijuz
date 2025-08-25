class_name FlowerSpawner
extends ChunkObject

@export_group("Flower Patch Settings")
@export var max_flowers_per_chunk: int = 120
@export var patches_per_chunk_range: Vector2i = Vector2i(2, 5)
@export var tree_avoidance_distance: float = 8.0
@export var background_flower_density: float = 0.02

@export_group("Patch Types")
@export var small_patch_size_range: Vector2i = Vector2i(4, 8)
@export var medium_patch_size_range: Vector2i = Vector2i(12, 20)
@export var large_patch_size_range: Vector2i = Vector2i(25, 40)
@export var patch_density: float = 0.6

@export_group("Randomness")
@export var position_jitter_range: float = 6.0
@export var patch_coherence: bool = true
@export var world_seed: int = -1

var flower_scenes: Array[PackedScene] = []

class FlowerPatch:
	var center: Vector2
	var radius: float
	var flower_count: int
	var patch_type: String  # "small", "medium", "large"
	var preferred_flower_types: Array[int] = []
	var density_falloff: float = 0.7
	
	func _init(c: Vector2, r: float, count: int, type: String):
		center = c
		radius = r
		flower_count = count
		patch_type = type
		
		# Assign 1-3 preferred flower types for coherence
		var type_count = randi_range(1, 3)
		for i in range(type_count):
			var flower_type = randi() % 5  # 0-4 for 5 flower types
			if not flower_type in preferred_flower_types:
				preferred_flower_types.append(flower_type)
	
	func get_density_at_position(pos: Vector2) -> float:
		var distance = center.distance_to(pos)
		if distance > radius:
			return 0.0
		
		# Smooth falloff from center to edge
		var normalized_distance = distance / radius
		return 1.0 - pow(normalized_distance, density_falloff)

func _ready():
	spawner_name = "flowers"
	density = 0.08  # Base density for patch placement, not individual flowers
	min_spacing = 2  # Reduced for tighter clustering
	exclusion_radius = 32.0
	objects_per_frame = 12
	
	_load_flower_resources()
	
	super._ready()

func _load_flower_resources():
	flower_scenes = [
		preload("res://scenes/environment/Flower1.tscn"),
		preload("res://scenes/environment/Flower2.tscn"),
		preload("res://scenes/environment/Flower3.tscn"),
		preload("res://scenes/environment/Flower4.tscn"),
		preload("res://scenes/environment/Flower5.tscn"),
	]

func get_max_objects_per_chunk() -> int:
	return max_flowers_per_chunk

func _select_positions_for_chunk(chunk_data) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	var valid_positions = chunk_data.valid_tiles.duplicate()
	
	if valid_positions.is_empty():
		return selected
	
	# Get tree positions for avoidance
	var tree_positions = []
	var tree_data = chunk_data.get_object_data("trees")
	for tree_info in tree_data:
		tree_positions.append(tree_info.world_pos)
	
	# Also check neighboring chunks for trees
	var chunk_coord = chunk_data.chunk_coord
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var neighbor_chunk = chunk_coord + Vector2i(x, y)
			if neighbor_chunk in chunk_manager.loaded_chunks:
				var neighbor_data = chunk_manager.loaded_chunks[neighbor_chunk]
				if neighbor_data.is_processed:
					var neighbor_trees = neighbor_data.get_object_data("trees")
					for tree_info in neighbor_trees:
						tree_positions.append(tree_info.world_pos)
	
	# Get static bodies (houses, etc.) from the scene 
	var static_bodies = _get_static_bodies_from_scene()
	
	# Generate flower patches
	var patches = _generate_flower_patches(chunk_data, tree_positions, static_bodies, valid_positions)
	
	# Place flowers in patches
	for patch in patches:
		var patch_flowers = _place_flowers_in_patch(patch, valid_positions, tree_positions, static_bodies)
		selected.append_array(patch_flowers)
	
	# Add scattered background flowers
	var background_flowers = _place_background_flowers(valid_positions, tree_positions, static_bodies, patches)
	selected.append_array(background_flowers)
	
	return selected

func _get_static_bodies_from_scene() -> Array[StaticBody2D]:
	"""Get all StaticBody2D objects from the scene that are on collision layer 4"""
	var static_bodies: Array[StaticBody2D] = []
	var scene_root = get_tree().current_scene
	if scene_root:
		_collect_static_bodies_recursive(scene_root, static_bodies)
	return static_bodies

func _collect_static_bodies_recursive(node: Node, static_bodies: Array[StaticBody2D]):
	"""Recursively collect StaticBody2D objects on collision layer 4"""
	if node is StaticBody2D:
		var static_body = node as StaticBody2D
		if static_body.get_collision_layer_value(3):  # Layer 4 (bit index 3)
			static_bodies.append(static_body)
	
	for child in node.get_children():
		_collect_static_bodies_recursive(child, static_bodies)

func _generate_flower_patches(chunk_data, tree_positions: Array, static_bodies: Array[StaticBody2D], valid_positions: Array[Dictionary]) -> Array[FlowerPatch]:
	var patches: Array[FlowerPatch] = []
	var chunk_rect = chunk_manager.chunk_to_world_rect(chunk_data.chunk_coord)
	
	# Use chunk coordinates and world seed for deterministic randomness
	var chunk_seed = hash(Vector2i(chunk_data.chunk_coord.x, chunk_data.chunk_coord.y))
	if world_seed != -1:
		chunk_seed = hash(str(world_seed) + str(chunk_seed))
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk_seed
	
	var patch_count = rng.randi_range(patches_per_chunk_range.x, patches_per_chunk_range.y)
	
	var max_attempts = patch_count * 10
	var attempts = 0
	
	while patches.size() < patch_count and attempts < max_attempts:
		attempts += 1
		
		# Random position within chunk
		var patch_center = Vector2(
			rng.randf_range(chunk_rect.position.x + 32, chunk_rect.position.x + chunk_rect.size.x - 32),
			rng.randf_range(chunk_rect.position.y + 32, chunk_rect.position.y + chunk_rect.size.y - 32)
		)
		
		# Check if patch center is clear of trees
		var min_tree_distance = INF
		for tree_pos in tree_positions:
			var distance = TreeCollisionHelper.get_distance_to_tree(patch_center, tree_pos, "res://scenes/environment/Tree1.tscn")
			min_tree_distance = min(min_tree_distance, distance)
		
		if min_tree_distance < tree_avoidance_distance + 20:  # Need extra space for patch
			continue
		
		# Check static obstacles using TreeCollisionHelper (more precise than ChunkManager)
		if not TreeCollisionHelper.is_position_clear_of_static_bodies(patch_center, exclusion_radius + 20, static_bodies):
			continue
		
		# Check spacing from other patches
		var too_close = false
		for existing_patch in patches:
			if patch_center.distance_to(existing_patch.center) < existing_patch.radius + 30:
				too_close = true
				break
		
		if too_close:
			continue
		
		# Determine patch type and size
		var patch_type_roll = rng.randf()
		var patch_type: String
		var size_range: Vector2i
		var radius: float
		
		if patch_type_roll < 0.5:  # 50% small patches
			patch_type = "small"
			size_range = small_patch_size_range
			radius = rng.randf_range(15, 25)
		elif patch_type_roll < 0.85:  # 35% medium patches
			patch_type = "medium"
			size_range = medium_patch_size_range
			radius = rng.randf_range(25, 40)
		else:  # 15% large patches
			patch_type = "large"
			size_range = large_patch_size_range
			radius = rng.randf_range(40, 60)
		
		var flower_count = rng.randi_range(size_range.x, size_range.y)
		var patch = FlowerPatch.new(patch_center, radius, flower_count, patch_type)
		patches.append(patch)
	
	return patches

func _place_flowers_in_patch(patch: FlowerPatch, valid_positions: Array[Dictionary], tree_positions: Array, static_bodies: Array[StaticBody2D]) -> Array[Dictionary]:
	var patch_flowers: Array[Dictionary] = []
	var patch_seed = hash(Vector2i(int(patch.center.x), int(patch.center.y)))
	if world_seed != -1:
		patch_seed = hash(str(world_seed) + str(patch_seed))
	var rng = RandomNumberGenerator.new()
	rng.seed = patch_seed
	
	# Filter valid positions to those within patch radius
	var patch_candidates: Array[Dictionary] = []
	for pos_data in valid_positions:
		var distance = patch.center.distance_to(pos_data.world_pos)
		if distance <= patch.radius:
			patch_candidates.append(pos_data)
	
	if patch_candidates.is_empty():
		return patch_flowers
	
	var attempts = 0
	var max_attempts = patch.flower_count * 3
	
	while patch_flowers.size() < patch.flower_count and attempts < max_attempts:
		attempts += 1
		
		# Select random position within patch
		var pos_data = patch_candidates[rng.randi() % patch_candidates.size()]
		var world_pos = pos_data.world_pos
		
		# Add position jitter
		var jitter = Vector2(
			rng.randf_range(-position_jitter_range, position_jitter_range),
			rng.randf_range(-position_jitter_range, position_jitter_range)
		)
		world_pos += jitter
		
		# Check tree avoidance with precise collision
		var clear_of_trees = true
		for tree_pos in tree_positions:
			var distance = TreeCollisionHelper.get_distance_to_tree(world_pos, tree_pos, "res://scenes/environment/Tree1.tscn")
			if distance < tree_avoidance_distance:
				clear_of_trees = false
				break
		
		if not clear_of_trees:
			continue
		
		# Check static obstacles using TreeCollisionHelper (more precise)
		if not TreeCollisionHelper.is_position_clear_of_static_bodies(world_pos, exclusion_radius, static_bodies):
			continue
		
		# Check spacing from other flowers in this patch
		var too_close = false
		for existing_flower in patch_flowers:
			if world_pos.distance_to(existing_flower.world_pos) < min_spacing * 8:  # Tile spacing to world spacing
				too_close = true
				break
		
		if too_close:
			continue
		
		# Apply patch density falloff
		var patch_density_at_pos = patch.get_density_at_position(world_pos)
		if rng.randf() > patch_density_at_pos * patch_density:
			continue
		
		# Select flower type (prefer patch coherence)
		var flower_type = 0
		if patch_coherence and patch.preferred_flower_types.size() > 0:
			flower_type = patch.preferred_flower_types[rng.randi() % patch.preferred_flower_types.size()]
		else:
			flower_type = rng.randi() % flower_scenes.size()
		
		# Create flower data
		var flower_data = {
			"world_pos": world_pos,
			"tile_pos": chunk_manager.ground_layer.local_to_map(world_pos) if chunk_manager.ground_layer else Vector2i(world_pos / 16),
			"flower_type": flower_type,
			"patch_id": hash(patch.center),
			"jitter": jitter
		}
		
		patch_flowers.append(flower_data)
	
	return patch_flowers

func _place_background_flowers(valid_positions: Array[Dictionary], tree_positions: Array, static_bodies: Array[StaticBody2D], patches: Array[FlowerPatch]) -> Array[Dictionary]:
	var background_flowers: Array[Dictionary] = []
	var target_count = int(valid_positions.size() * background_flower_density)
	
	# Shuffle for randomness
	valid_positions.shuffle()
	
	var attempts = 0
	var max_attempts = target_count * 3
	
	for pos_data in valid_positions:
		if background_flowers.size() >= target_count or attempts >= max_attempts:
			break
		
		attempts += 1
		var world_pos = pos_data.world_pos
		
		# Skip if too close to patches
		var too_close_to_patch = false
		for patch in patches:
			if world_pos.distance_to(patch.center) < patch.radius + 15:
				too_close_to_patch = true
				break
		
		if too_close_to_patch:
			continue
		
		# Check tree avoidance
		var clear_of_trees = TreeCollisionHelper.is_position_clear_of_trees(
			world_pos, tree_avoidance_distance, tree_positions
		)
		
		if not clear_of_trees:
			continue
		
		# Check static obstacles using TreeCollisionHelper (more precise)
		if not TreeCollisionHelper.is_position_clear_of_static_bodies(world_pos, exclusion_radius, static_bodies):
			continue
		
		# Add small position jitter
		var jitter = Vector2(
			randf_range(-position_jitter_range * 0.5, position_jitter_range * 0.5),
			randf_range(-position_jitter_range * 0.5, position_jitter_range * 0.5)
		)
		world_pos += jitter
		
		var flower_data = {
			"world_pos": world_pos,
			"tile_pos": pos_data.tile_pos,
			"flower_type": randi() % flower_scenes.size(),
			"patch_id": -1,  # Background flower
			"jitter": jitter
		}
		
		background_flowers.append(flower_data)
	
	return background_flowers

func _create_object_instance(object_data: Dictionary) -> Node:
	var flower_instance = _get_from_pool("flower")
	
	if not flower_instance:
		var flower_type = object_data.get("flower_type", 0)
		var scene_index = clamp(flower_type, 0, flower_scenes.size() - 1)
		flower_instance = flower_scenes[scene_index].instantiate()
	
	return flower_instance

func _configure_object(instance: Node, object_data: Dictionary) -> void:
	super._configure_object(instance, object_data)

func _get_pool_key(obj: Node) -> String:
	return "flower"

func set_world_seed(new_seed: int):
	"""Set the world seed for consistent flower generation"""
	world_seed = new_seed
	if world_seed != -1:
		seed(world_seed)

func get_world_seed() -> int:
	"""Get the current world seed"""
	return world_seed
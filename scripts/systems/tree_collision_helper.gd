class_name TreeCollisionHelper
extends RefCounted

static var collision_cache: Dictionary = {}
static var distance_cache: Dictionary = {}
static var cache_max_size: int = 1000
static var cache_clear_counter: int = 0

class TreeCollisionData:
	var polygon_points: PackedVector2Array
	var bounding_box: Rect2
	var center: Vector2
	var max_radius: float
	
	func _init(points: PackedVector2Array):
		polygon_points = points
		_calculate_bounds()
	
	func _calculate_bounds():
		if polygon_points.size() == 0:
			return
		
		var min_x = polygon_points[0].x
		var max_x = polygon_points[0].x
		var min_y = polygon_points[0].y
		var max_y = polygon_points[0].y
		
		for point in polygon_points:
			min_x = min(min_x, point.x)
			max_x = max(max_x, point.x)
			min_y = min(min_y, point.y)
			max_y = max(max_y, point.y)
		
		bounding_box = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
		center = bounding_box.get_center()
		max_radius = max(bounding_box.size.x, bounding_box.size.y) * 0.5
	
	func get_distance_to_edge(world_pos: Vector2, tree_world_pos: Vector2) -> float:
		var relative_pos = world_pos - tree_world_pos
		
		# Quick bounding box check first
		var expanded_box = bounding_box.grow(20)
		if not expanded_box.has_point(relative_pos):
			return relative_pos.distance_to(bounding_box.get_center())
		
		# Find closest distance to polygon edge
		var min_distance = INF
		
		for i in range(polygon_points.size()):
			var p1 = polygon_points[i]
			var p2 = polygon_points[(i + 1) % polygon_points.size()]
			var distance = _point_to_line_distance(relative_pos, p1, p2)
			min_distance = min(min_distance, distance)
		
		# Check if point is inside polygon (negative distance)
		if _is_point_inside_polygon(relative_pos):
			return -min_distance
		
		return min_distance
	
	func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
		var line_vec = line_end - line_start
		var point_vec = point - line_start
		
		var line_length_sq = line_vec.length_squared()
		if line_length_sq < 0.0001:
			return point_vec.length()
		
		var t = point_vec.dot(line_vec) / line_length_sq
		t = clamp(t, 0.0, 1.0)
		
		var closest_point = line_start + t * line_vec
		return point.distance_to(closest_point)
	
	func _is_point_inside_polygon(point: Vector2) -> bool:
		var inside = false
		var j = polygon_points.size() - 1
		
		for i in range(polygon_points.size()):
			var pi = polygon_points[i]
			var pj = polygon_points[j]
			
			if ((pi.y > point.y) != (pj.y > point.y)) and \
			   (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x):
				inside = !inside
			j = i
		
		return inside

static func get_tree_collision_data(tree_scene_path: String) -> TreeCollisionData:
	if tree_scene_path in collision_cache:
		return collision_cache[tree_scene_path]
	
	var scene = load(tree_scene_path)
	if not scene:
		return null
	
	var instance = scene.instantiate()
	var collision_data = _extract_collision_from_tree(instance)
	instance.queue_free()
	
	collision_cache[tree_scene_path] = collision_data
	return collision_data

static func _extract_collision_from_tree(tree_node: Node) -> TreeCollisionData:
	# Check main collision shape (StaticBody2D collision)
	var main_collision = tree_node.get_node_or_null("CollisionPolygon2D")
	if main_collision and main_collision is CollisionPolygon2D:
		var polygon = main_collision.polygon
		if polygon.size() > 0:
			return TreeCollisionData.new(polygon)
	
	# Fallback: check TreeInteractable collision
	var tree_interactable = tree_node.get_node_or_null("TreeInteractable")
	if tree_interactable:
		var interactable_collision = tree_interactable.get_node_or_null("CollisionPolygon2D")
		if interactable_collision and interactable_collision is CollisionPolygon2D:
			var polygon = interactable_collision.polygon
			if polygon.size() > 0:
				return TreeCollisionData.new(polygon)
	
	# Fallback: create approximate collision based on sprite bounds
	var sprite = _find_sprite_in_tree(tree_node)
	if sprite and sprite.texture:
		var texture_size = sprite.texture.get_size()
		if sprite.region_enabled:
			texture_size = sprite.region_rect.size
		
		# Create simple rectangular collision
		var half_size = texture_size * 0.5
		var rect_polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y)
		])
		return TreeCollisionData.new(rect_polygon)
	
	# Ultimate fallback: 20x20 square
	var default_polygon = PackedVector2Array([
		Vector2(-10, -10), Vector2(10, -10),
		Vector2(10, 10), Vector2(-10, 10)
	])
	return TreeCollisionData.new(default_polygon)

static func _find_sprite_in_tree(node: Node) -> Sprite2D:
	if node is Sprite2D:
		return node
	
	for child in node.get_children():
		var sprite = _find_sprite_in_tree(child)
		if sprite:
			return sprite
	
	return null

static func get_distance_to_tree(flower_world_pos: Vector2, tree_world_pos: Vector2, tree_scene_path: String) -> float:
	# Create cache key for distance calculation
	var cache_key = str(int(flower_world_pos.x)) + "," + str(int(flower_world_pos.y)) + ":" + str(int(tree_world_pos.x)) + "," + str(int(tree_world_pos.y))
	
	if cache_key in distance_cache:
		return distance_cache[cache_key]
	
	var collision_data = get_tree_collision_data(tree_scene_path)
	var distance: float
	
	if not collision_data:
		# Fallback to simple distance
		distance = flower_world_pos.distance_to(tree_world_pos)
	else:
		distance = collision_data.get_distance_to_edge(flower_world_pos, tree_world_pos)
	
	# Cache the result (with size management)
	_manage_cache_size()
	distance_cache[cache_key] = distance
	
	return distance

static func is_position_clear_of_trees(world_pos: Vector2, min_distance: float, tree_positions: Array, tree_scene_paths: Array = []) -> bool:
	for i in range(tree_positions.size()):
		var tree_pos = tree_positions[i]
		var tree_path = tree_scene_paths[i] if i < tree_scene_paths.size() else "res://scenes/environment/Tree1.tscn"
		
		var distance = get_distance_to_tree(world_pos, tree_pos, tree_path)
		if distance < min_distance:
			return false
	
	return true

static func get_tree_avoidance_zones(trees_data: Array) -> Array[Dictionary]:
	var zones = []
	
	for tree_data in trees_data:
		var world_pos = tree_data.get("world_pos", Vector2.ZERO)
		var tree_type = tree_data.get("tree_type", "")
		var scene_path = "res://scenes/environment/Tree1.tscn"  # Default tree
		
		var collision_data = get_tree_collision_data(scene_path)
		if collision_data:
			zones.append({
				"world_pos": world_pos,
				"collision_data": collision_data,
				"scene_path": scene_path
			})
	
	return zones

static func _manage_cache_size():
	cache_clear_counter += 1
	
	# Clear cache every 1000 operations to prevent memory buildup
	if cache_clear_counter >= cache_max_size:
		distance_cache.clear()
		cache_clear_counter = 0
		
		# Also clear collision cache if it gets too large
		if collision_cache.size() > 50:
			collision_cache.clear()

static func clear_caches():
	collision_cache.clear()
	distance_cache.clear()
	cache_clear_counter = 0

static func get_static_body_collision_data(body: StaticBody2D) -> TreeCollisionData:
	"""Get collision data for any StaticBody2D (house, tree, etc.)"""
	var body_path = body.scene_file_path
	if body_path.is_empty():
		body_path = str(body.get_instance_id())
	
	if body_path in collision_cache:
		return collision_cache[body_path]
	
	var collision_data = _extract_collision_from_static_body(body)
	collision_cache[body_path] = collision_data
	return collision_data

static func _extract_collision_from_static_body(body: StaticBody2D) -> TreeCollisionData:
	"""Extract collision data from any StaticBody2D"""
	# Check for CollisionPolygon2D first (most precise)
	for child in body.get_children():
		if child is CollisionPolygon2D:
			var collision_polygon = child as CollisionPolygon2D
			if collision_polygon.polygon.size() > 0:
				# Transform polygon to world coordinates relative to body
				var transformed_polygon = PackedVector2Array()
				for point in collision_polygon.polygon:
					var world_point = collision_polygon.transform * point
					transformed_polygon.append(world_point)
				return TreeCollisionData.new(transformed_polygon)
	
	# Fallback to CollisionShape2D
	for child in body.get_children():
		if child is CollisionShape2D:
			var collision_shape = child as CollisionShape2D
			if collision_shape.shape:
				return _create_collision_from_shape(collision_shape)
	
	# Ultimate fallback: create approximate bounds from sprites
	var sprite = _find_sprite_in_static_body(body)
	if sprite and sprite.texture:
		var texture_size = sprite.texture.get_size()
		if sprite.region_enabled:
			texture_size = sprite.region_rect.size
		
		var half_size = texture_size * 0.5
		var rect_polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y)
		])
		return TreeCollisionData.new(rect_polygon)
	
	# Final fallback: small square
	var default_polygon = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16),
		Vector2(16, 16), Vector2(-16, 16)
	])
	return TreeCollisionData.new(default_polygon)

static func _create_collision_from_shape(collision_shape: CollisionShape2D) -> TreeCollisionData:
	"""Create collision data from a CollisionShape2D"""
	var shape = collision_shape.shape
	var transform = collision_shape.transform
	
	if shape is RectangleShape2D:
		var rect_shape = shape as RectangleShape2D
		var half_size = rect_shape.size * 0.5
		var rect_polygon = PackedVector2Array([
			transform * Vector2(-half_size.x, -half_size.y),
			transform * Vector2(half_size.x, -half_size.y),
			transform * Vector2(half_size.x, half_size.y),
			transform * Vector2(-half_size.x, half_size.y)
		])
		return TreeCollisionData.new(rect_polygon)
	
	elif shape is CircleShape2D:
		var circle_shape = shape as CircleShape2D
		var radius = circle_shape.radius
		# Approximate circle with octagon
		var octagon = PackedVector2Array()
		for i in range(8):
			var angle = i * PI / 4
			var point = Vector2(cos(angle), sin(angle)) * radius
			octagon.append(transform * point)
		return TreeCollisionData.new(octagon)
	
	# Fallback for unknown shape types
	var bounds = shape.get_rect()
	var rect_polygon = PackedVector2Array([
		transform * Vector2(bounds.position.x, bounds.position.y),
		transform * Vector2(bounds.position.x + bounds.size.x, bounds.position.y),
		transform * Vector2(bounds.position.x + bounds.size.x, bounds.position.y + bounds.size.y),
		transform * Vector2(bounds.position.x, bounds.position.y + bounds.size.y)
	])
	return TreeCollisionData.new(rect_polygon)

static func _find_sprite_in_static_body(body: StaticBody2D) -> Sprite2D:
	"""Find a Sprite2D in a StaticBody2D"""
	for child in body.get_children():
		if child is Sprite2D:
			return child as Sprite2D
		
		# Check nested nodes (like in doors)
		for grandchild in child.get_children():
			if grandchild is Sprite2D:
				return grandchild as Sprite2D
	
	return null

static func get_distance_to_static_body(query_pos: Vector2, body: StaticBody2D) -> float:
	"""Get distance from a position to any StaticBody2D"""
	var collision_data = get_static_body_collision_data(body)
	if not collision_data:
		return query_pos.distance_to(body.global_position)
	
	return collision_data.get_distance_to_edge(query_pos, body.global_position)

static func is_position_clear_of_static_bodies(world_pos: Vector2, min_distance: float, bodies: Array[StaticBody2D]) -> bool:
	"""Check if a position is clear of an array of StaticBody2D objects"""
	for body in bodies:
		# Use the same collision layer check as ChunkManager (layer 4)
		if body.get_collision_layer_value(3):  # Layer 4 (bit index 3)
			var distance = get_distance_to_static_body(world_pos, body)
			if distance < min_distance:
				return false
	
	return true

static func is_position_clear_of_all_obstacles(world_pos: Vector2, min_distance: float, tree_positions: Array, static_bodies: Array[StaticBody2D], tree_scene_path: String = "res://scenes/environment/Tree1.tscn") -> bool:
	"""Check if a position is clear of both trees and static bodies"""
	# Check trees first (using existing working logic)
	if not is_position_clear_of_trees(world_pos, min_distance, tree_positions, [tree_scene_path]):
		return false
	
	# Check static bodies (houses, etc.)
	if not is_position_clear_of_static_bodies(world_pos, min_distance, static_bodies):
		return false
	
	return true

static func get_distance_to_nearest_obstacle(world_pos: Vector2, tree_positions: Array, static_bodies: Array[StaticBody2D], tree_scene_path: String = "res://scenes/environment/Tree1.tscn") -> float:
	"""Get the distance to the nearest obstacle (tree or static body)"""
	var min_distance = INF
	
	# Check trees
	for tree_pos in tree_positions:
		var distance = get_distance_to_tree(world_pos, tree_pos, tree_scene_path)
		min_distance = min(min_distance, distance)
	
	# Check static bodies
	for body in static_bodies:
		if body.get_collision_layer_value(3):  # Layer 4 (bit index 3)
			var distance = get_distance_to_static_body(world_pos, body)
			min_distance = min(min_distance, distance)
	
	return min_distance
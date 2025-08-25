extends Node

signal path_found(path: Array[Vector2])
signal path_failed()

var navigation_map: RID
var navigation_region: NavigationRegion2D
var tile_size: int = 32

func _ready():
	# Create a 2D navigation map
	navigation_map = NavigationServer2D.map_create()
	NavigationServer2D.map_set_active(navigation_map, true)

func setup_navigation_region(region: NavigationRegion2D):
	navigation_region = region
	if region and region.navigation_polygon:
		var region_rid = region.get_navigation_map()
		NavigationServer2D.region_set_map(region_rid, navigation_map)

func find_path(start_pos: Vector2, end_pos: Vector2) -> Array[Vector2]:
	if not navigation_region:
		return []
	
	var path = NavigationServer2D.map_get_path(
		navigation_map,
		start_pos,
		end_pos,
		true
	)
	
	if path.size() > 0:
		path_found.emit(path)
		return path
	else:
		path_failed.emit()
		return []

func find_path_async(start_pos: Vector2, end_pos: Vector2):
	# Use call_deferred to avoid blocking the main thread
	call_deferred("_find_path_deferred", start_pos, end_pos)

func _find_path_deferred(start_pos: Vector2, end_pos: Vector2):
	var path = find_path(start_pos, end_pos)
	return path

func is_position_walkable(position: Vector2) -> bool:
	if not navigation_region or not navigation_region.navigation_polygon:
		return false
	
	# Check if the position is within the navigation polygon
	var nav_poly = navigation_region.navigation_polygon
	for i in range(nav_poly.get_polygon_count()):
		var polygon = nav_poly.get_polygon(i)
		var points = []
		for vertex_idx in polygon:
			points.append(nav_poly.get_vertex(vertex_idx))
		
		if Geometry2D.is_point_in_polygon(position, points):
			return true
	
	return false

func get_closest_walkable_position(position: Vector2) -> Vector2:
	if not navigation_region:
		return position
	
	var closest_point = NavigationServer2D.map_get_closest_point(navigation_map, position)
	return closest_point

func create_navigation_polygon_from_tilemap(tilemap: TileMap, source_id: int = 0, walkable_tiles: Array[int] = []) -> NavigationPolygon:
	var nav_poly = NavigationPolygon.new()
	var used_rect = tilemap.get_used_rect()
	
	# Create a simple rectangular navigation polygon
	# In a real implementation, you'd want to exclude obstacle tiles
	var points = PackedVector2Array()
	
	var top_left = Vector2(used_rect.position.x * tile_size, used_rect.position.y * tile_size)
	var bottom_right = Vector2((used_rect.position.x + used_rect.size.x) * tile_size, 
							   (used_rect.position.y + used_rect.size.y) * tile_size)
	
	points.append(top_left)
	points.append(Vector2(bottom_right.x, top_left.y))
	points.append(bottom_right)
	points.append(Vector2(top_left.x, bottom_right.y))
	
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_poly.vertices = points
	
	return nav_poly

func debug_draw_path(path: Array[Vector2], canvas_item: CanvasItem):
	if path.size() < 2:
		return
	
	for i in range(path.size() - 1):
		canvas_item.draw_line(path[i], path[i + 1], Color.RED, 2.0)
	
	# Draw waypoints
	for point in path:
		canvas_item.draw_circle(point, 4.0, Color.YELLOW)
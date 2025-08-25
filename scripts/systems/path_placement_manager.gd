extends Node

signal path_placed(coord: Vector2i)
signal path_removed(coord: Vector2i)

const GRASS_TERRAIN_ID: int = 0
const PATH_TERRAIN_ID: int = 1

var player_controller: Node
var ground_layer: TileMapLayer
var path_modification_data: Node
var placement_reach: float = 32.0

func _ready() -> void:
	name = "PathPlacementManager"
	
	call_deferred("_initialize")

func _initialize() -> void:
	_find_dependencies()

func _find_dependencies() -> void:
	player_controller = get_tree().get_first_node_in_group("player")
	if not player_controller:
		push_warning("PathPlacementManager: Player controller not found")
		return
	
	var main_world = get_tree().get_first_node_in_group("main_world")
	if main_world:
		ground_layer = main_world.get_node("GroundLayer")
		if not ground_layer:
			push_warning("PathPlacementManager: GroundLayer not found in MainWorld")
		
		path_modification_data = main_world.get_node("PathModificationData")
		if not path_modification_data:
			push_warning("PathPlacementManager: PathModificationData not found in MainWorld")
	else:
		push_warning("PathPlacementManager: MainWorld not found")

func can_place_at_position(world_position: Vector2) -> bool:
	if not ground_layer or not player_controller:
		return false
	
	var player_position = player_controller.global_position
	var distance = world_position.distance_to(player_position)
	
	return distance <= placement_reach

func place_path_at_position(world_position: Vector2) -> bool:
	if not can_place_at_position(world_position):
		return false
	
	# Skip terrain updates in editor mode to avoid interfering with Better Terrain editor
	if Engine.is_editor_hint():
		return false
	
	var map_position = ground_layer.local_to_map(world_position)
	var current_terrain = get_terrain_at_coord(map_position)
	
	# Set to path terrain
	BetterTerrain.set_cell(ground_layer, map_position, PATH_TERRAIN_ID)
	# Update only this cell to trigger autotiling without affecting surrounding cells
	BetterTerrain.update_terrain_cell(ground_layer, map_position, false)
	
	# Record the path modification for persistence
	if path_modification_data:
		path_modification_data.record_path_placement(world_position, PATH_TERRAIN_ID)
	
	path_placed.emit(map_position)
	return true

func remove_path_at_position(world_position: Vector2) -> bool:
	if not can_place_at_position(world_position):
		return false
	
	# Skip terrain updates in editor mode to avoid interfering with Better Terrain editor
	if Engine.is_editor_hint():
		return false
	
	var map_position = ground_layer.local_to_map(world_position)
	
	if get_terrain_at_coord(map_position) != PATH_TERRAIN_ID:
		return false
	
	BetterTerrain.set_cell(ground_layer, map_position, GRASS_TERRAIN_ID)
	# Update only this cell to trigger autotiling without affecting surrounding cells
	BetterTerrain.update_terrain_cell(ground_layer, map_position, false)
	
	# Record the path removal for persistence
	if path_modification_data:
		path_modification_data.remove_path_at_position(world_position)
	
	path_removed.emit(map_position)
	return true

func get_terrain_at_coord(coord: Vector2i) -> int:
	if not ground_layer:
		return -1
	
	return BetterTerrain.get_cell(ground_layer, coord)

func get_terrain_at_position(world_position: Vector2) -> int:
	if not ground_layer:
		return -1
	
	var map_position = ground_layer.local_to_map(world_position)
	return get_terrain_at_coord(map_position)

func get_reach_radius() -> float:
	return placement_reach

func set_reach_radius(radius: float) -> void:
	placement_reach = radius

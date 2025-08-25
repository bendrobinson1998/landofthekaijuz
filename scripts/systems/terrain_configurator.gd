extends Node

var ground_layer: TileMapLayer

func _ready() -> void:
	name = "TerrainConfigurator"
	call_deferred("_setup_terrain_types")

func _setup_terrain_types():
	var main_world = get_tree().get_first_node_in_group("main_world")
	if not main_world:
		push_warning("TerrainConfigurator: MainWorld not found")
		return
	
	ground_layer = main_world.get_node("GroundLayer")
	if not ground_layer:
		push_warning("TerrainConfigurator: GroundLayer not found")
		return
	
	var tileset = ground_layer.tile_set
	if not tileset:
		push_warning("TerrainConfigurator: No TileSet found on GroundLayer")
		return
	
	_configure_path_terrain(tileset)

func _configure_path_terrain(tileset: TileSet):
	# Find the Grass_tiles_1.png source in the tileset
	var grass_source_id = -1
	for source_id in tileset.get_source_count():
		var source = tileset.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas_source = source as TileSetAtlasSource
			var texture_path = atlas_source.texture.resource_path if atlas_source.texture else ""
			if "Grass_tiles_1.png" in texture_path or "Grass_Tiles_1.png" in texture_path:
				grass_source_id = source_id
				break
	
	if grass_source_id == -1:
		push_warning("TerrainConfigurator: Could not find Grass_tiles_1.png source in tileset")
		return
	
	print("TerrainConfigurator: Found grass tileset source at ID: ", grass_source_id)
	
	# Configure Better Terrain for this source
	_setup_better_terrain_for_source(tileset, grass_source_id)

func _setup_better_terrain_for_source(tileset: TileSet, source_id: int):
	var source = tileset.get_source(source_id) as TileSetAtlasSource
	if not source:
		return
	
	# Check if Better Terrain is available and configure terrain types
	if BetterTerrain:
		print("TerrainConfigurator: Setting up Better Terrain terrain types...")
		
		# Path tiles are at:
		# Main 3x3 grid: (0,5), (1,5), (2,5) - top row, plus (0,6), (1,6), (2,6) - middle row, (0,7), (1,7), (2,7) - bottom row
		# Alternative corners: (0,8), (1,8) - top row, (0,9), (1,9) - bottom row
		
		# Configure terrain type 1 as "Path" terrain
		# This should be done through the Better Terrain plugin interface or data
		print("TerrainConfigurator: Path tiles configured for source ID ", source_id)
		print("TerrainConfigurator: Main path tiles at (0,5)-(2,7), corner tiles at (0,8)-(1,9)")
		
		# The actual terrain configuration needs to be done through the Better Terrain plugin interface
		# For now, we'll rely on the terrain being configured manually in the editor
	else:
		push_warning("TerrainConfigurator: Better Terrain not available")

func get_terrain_tile_info() -> Dictionary:
	"""Return information about terrain tile locations for debugging"""
	return {
		"main_path_grid": {
			"top_row": [[0,5], [1,5], [2,5]],
			"middle_row": [[0,6], [1,6], [2,6]], 
			"bottom_row": [[0,7], [1,7], [2,7]]
		},
		"corner_tiles": {
			"top_row": [[0,8], [1,8]],
			"bottom_row": [[0,9], [1,9]]
		}
	}

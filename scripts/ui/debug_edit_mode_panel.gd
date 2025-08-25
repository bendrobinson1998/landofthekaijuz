extends Control

@onready var status_label: Label = $StatusLabel
@onready var terrain_info_label: Label = $TerrainInfoLabel
@onready var test_button: Button = $TestButton

var update_timer: Timer

func _ready():
	name = "DebugEditModePanel"
	
	# Create UI elements if they don't exist
	if not status_label:
		status_label = Label.new()
		status_label.name = "StatusLabel"
		status_label.position = Vector2(10, 10)
		status_label.size = Vector2(300, 100)
		add_child(status_label)
	
	if not terrain_info_label:
		terrain_info_label = Label.new()
		terrain_info_label.name = "TerrainInfoLabel"
		terrain_info_label.position = Vector2(10, 120)
		terrain_info_label.size = Vector2(300, 100)
		add_child(terrain_info_label)
	
	if not test_button:
		test_button = Button.new()
		test_button.name = "TestButton"
		test_button.text = "Test Path Placement"
		test_button.position = Vector2(10, 230)
		test_button.size = Vector2(150, 30)
		test_button.pressed.connect(_on_test_button_pressed)
		add_child(test_button)
	
	# Set up update timer
	update_timer = Timer.new()
	update_timer.timeout.connect(_update_display)
	update_timer.wait_time = 0.5
	update_timer.autostart = true
	add_child(update_timer)
	
	# Set panel properties
	size = Vector2(320, 280)
	position = Vector2(10, 10)
	
	# Make this panel visible only in debug/development
	modulate = Color(1, 1, 1, 0.9)
	
	_update_display()

func _update_display():
	_update_status_label()
	_update_terrain_info()

func _update_status_label():
	if not status_label:
		return
	
	var status_text = "=== Edit Mode Debug ===\n"
	
	# Edit mode status
	if EditModeManager:
		status_text += "Edit Mode: " + ("ON" if EditModeManager.is_edit_mode() else "OFF") + "\n"
		status_text += "Current Tool: " + EditModeManager.get_tool_name(EditModeManager.get_current_tool()) + "\n"
	else:
		status_text += "EditModeManager: NOT FOUND\n"
	
	# Better Terrain status
	if BetterTerrain:
		status_text += "Better Terrain: Available\n"
	else:
		status_text += "Better Terrain: NOT FOUND\n"
	
	# Path system status
	var main_world = get_tree().get_first_node_in_group("main_world")
	if main_world:
		var path_manager = main_world.get_node_or_null("PathPlacementManager")
		var path_data = main_world.get_node_or_null("PathModificationData")
		
		status_text += "PathPlacementManager: " + ("Found" if path_manager else "NOT FOUND") + "\n"
		status_text += "PathModificationData: " + ("Found" if path_data else "NOT FOUND") + "\n"
	else:
		status_text += "MainWorld: NOT FOUND\n"
	
	status_label.text = status_text

func _update_terrain_info():
	if not terrain_info_label:
		return
	
	var info_text = "=== Terrain Info ===\n"
	
	var main_world = get_tree().get_first_node_in_group("main_world")
	if main_world:
		var ground_layer = main_world.get_node_or_null("GroundLayer")
		if ground_layer and ground_layer.tile_set:
			var tileset = ground_layer.tile_set
			info_text += "TileSet Sources: " + str(tileset.get_source_count()) + "\n"
			
			# Find grass source
			for source_id in tileset.get_source_count():
				var source = tileset.get_source(source_id)
				if source is TileSetAtlasSource:
					var atlas_source = source as TileSetAtlasSource
					if atlas_source.texture:
						var texture_name = atlas_source.texture.resource_path.get_file()
						if "Grass" in texture_name:
							info_text += "Grass Source " + str(source_id) + ": " + texture_name + "\n"
		else:
			info_text += "No TileSet found\n"
		
		# Path modification count
		var path_data = main_world.get_node_or_null("PathModificationData")
		if path_data and path_data.has_method("get_total_path_count"):
			info_text += "Total Paths: " + str(path_data.get_total_path_count()) + "\n"
	
	terrain_info_label.text = info_text

func _on_test_button_pressed():
	print("Debug: Testing path placement system")
	
	var main_world = get_tree().get_first_node_in_group("main_world")
	if not main_world:
		print("Debug: MainWorld not found")
		return
	
	var path_manager = main_world.get_node_or_null("PathPlacementManager")
	if not path_manager:
		print("Debug: PathPlacementManager not found")
		return
	
	# Test placement at a fixed position near the player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var test_position = player.global_position + Vector2(32, 0)
		print("Debug: Testing path placement at ", test_position)
		
		var success = path_manager.place_path_at_position(test_position)
		print("Debug: Path placement result: ", success)
	else:
		print("Debug: Player not found for testing")

func _input(event):
	# Toggle debug panel with F12
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		visible = !visible
		if visible:
			print("Debug Edit Mode Panel: Opened")
		else:
			print("Debug Edit Mode Panel: Closed")

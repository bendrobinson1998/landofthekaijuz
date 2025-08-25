class_name UITileMapLayer
extends TileMapLayer

enum PanelStyle {
	DARK_WOOD,		# Brown wooden panel style
	LIGHT_WOOD,		# Lighter wood panel style  
	STONE,			# Stone/grey panel style
	METAL			# Metallic panel style
}

enum ButtonState {
	NORMAL,
	HOVERED,
	PRESSED,
	DISABLED
}

@export var panel_style: PanelStyle = PanelStyle.DARK_WOOD
@export var auto_resize: bool = true
@export var min_size: Vector2i = Vector2i(3, 3)  # Minimum 3x3 for proper 9-patch

var ui_tileset: TileSet
var current_size: Vector2i

func _ready():
	# Load the UI tileset
	ui_tileset = load("res://scenes/ui/core/UITileSet.tres")
	if ui_tileset:
		tile_set = ui_tileset
		# Set a reasonable tile size (16x16 is common for UI)
		if tile_set.tile_size == Vector2i.ZERO:
			tile_set.tile_size = Vector2i(16, 16)
	else:
		# Make tilemap invisible when tileset fails so fallback backgrounds show
		visible = false

func draw_panel(pos: Vector2i, size: Vector2i, style: PanelStyle = panel_style):
	"""Draw a 9-patch style panel at the given position and size"""
	
	# Re-enable panel drawing
	visible = true
	
	if size.x < min_size.x or size.y < min_size.y:
		size = Vector2i(max(size.x, min_size.x), max(size.y, min_size.y))
	
	current_size = size
	var atlas_coords = _get_panel_atlas_coords(style)
	
	# Clear the area first
	_clear_area(pos, size)
	
	# Draw corners (always 1x1)
	set_cell(pos, 0, atlas_coords.top_left)  # Top-left
	set_cell(pos + Vector2i(size.x - 1, 0), 0, atlas_coords.top_right)  # Top-right
	set_cell(pos + Vector2i(0, size.y - 1), 0, atlas_coords.bottom_left)  # Bottom-left
	set_cell(pos + Vector2i(size.x - 1, size.y - 1), 0, atlas_coords.bottom_right)  # Bottom-right
	
	# Draw edges
	for x in range(1, size.x - 1):
		set_cell(pos + Vector2i(x, 0), 0, atlas_coords.top_edge)  # Top edge
		set_cell(pos + Vector2i(x, size.y - 1), 0, atlas_coords.bottom_edge)  # Bottom edge
	
	for y in range(1, size.y - 1):
		set_cell(pos + Vector2i(0, y), 0, atlas_coords.left_edge)  # Left edge
		set_cell(pos + Vector2i(size.x - 1, y), 0, atlas_coords.right_edge)  # Right edge
	
	# Fill the center
	for x in range(1, size.x - 1):
		for y in range(1, size.y - 1):
			set_cell(pos + Vector2i(x, y), 0, atlas_coords.center)

func draw_button(pos: Vector2i, size: Vector2i, state: ButtonState = ButtonState.NORMAL):
	"""Draw a button with the specified state"""
	var atlas_coords = _get_button_atlas_coords(state)
	
	# Fill the entire button area with the tile
	for x in range(size.x):
		for y in range(size.y):
			set_cell(pos + Vector2i(x, y), 0, atlas_coords)

func _clear_area(pos: Vector2i, size: Vector2i):
	"""Clear all tiles in the specified area"""
	for x in range(size.x):
		for y in range(size.y):
			erase_cell(pos + Vector2i(x, y))

func _get_panel_atlas_coords(style: PanelStyle) -> Dictionary:
	"""Get the atlas coordinates for panel pieces based on style"""
	# Use dark wood coordinates for all styles since that's what we have available
	var base_offset = Vector2i(0, 0)
	
	# All panel styles now use the working dark wood nine-patch tiles
	# This ensures consistent rendering across all UI panels
	
	return {
		"top_left": base_offset,
		"top_right": base_offset + Vector2i(2, 0),
		"top_edge": base_offset + Vector2i(1, 0),
		"bottom_left": base_offset + Vector2i(0, 2),
		"bottom_right": base_offset + Vector2i(2, 2),
		"bottom_edge": base_offset + Vector2i(1, 2),
		"left_edge": base_offset + Vector2i(0, 1),
		"right_edge": base_offset + Vector2i(2, 1),
		"center": base_offset + Vector2i(1, 1)
	}

func _get_button_atlas_coords(state: ButtonState) -> Vector2i:
	"""Get atlas coordinates for button based on state"""
	match state:
		ButtonState.NORMAL:
			return Vector2i(30, 1)  # Use your inventory button tile
		ButtonState.HOVERED:
			return Vector2i(30, 1)  # Same tile for now - we can add hover states later
		ButtonState.PRESSED:
			return Vector2i(30, 1)  # Same tile for now - we can add pressed states later
		ButtonState.DISABLED:
			return Vector2i(30, 1)  # Same tile for now - we can add disabled states later
		_:
			return Vector2i(30, 1)

func resize_panel(new_size: Vector2i):
	"""Resize the current panel"""
	if current_size == Vector2i.ZERO:
		return
	
	draw_panel(Vector2i.ZERO, new_size, panel_style)
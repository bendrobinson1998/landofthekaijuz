class_name UIRegion
extends Control

enum RegionPosition {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	MIDDLE_LEFT,
	MIDDLE_CENTER,
	MIDDLE_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT
}

@export var region_position: RegionPosition = RegionPosition.BOTTOM_LEFT
@export var region_margin: Vector2i = Vector2i(16, 16)  # Margin from screen edges
@export var region_padding: Vector2i = Vector2i(8, 8)   # Internal padding
@export var auto_position: bool = true

var ui_tilemap_layer: UITileMapLayer
var content_container: Control

func _ready():
	# Create the TileMapLayer for this region
	ui_tilemap_layer = UITileMapLayer.new()
	add_child(ui_tilemap_layer)
	
	# Create a container for content (buttons, labels, etc.)
	content_container = Control.new()
	content_container.name = "ContentContainer"
	add_child(content_container)
	
	if auto_position:
		_position_region()
	
	# Connect to viewport size changes for responsive design
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _position_region():
	"""Position this region based on its assigned screen position"""
	var viewport_size = get_viewport().size
	var region_size = size
	
	match region_position:
		RegionPosition.TOP_LEFT:
			position = Vector2(region_margin.x, region_margin.y)
			
		RegionPosition.TOP_CENTER:
			position = Vector2((viewport_size.x - region_size.x) / 2, region_margin.y)
			
		RegionPosition.TOP_RIGHT:
			position = Vector2(viewport_size.x - region_size.x - region_margin.x, region_margin.y)
			
		RegionPosition.MIDDLE_LEFT:
			position = Vector2(region_margin.x, (viewport_size.y - region_size.y) / 2)
			
		RegionPosition.MIDDLE_CENTER:
			position = Vector2((viewport_size.x - region_size.x) / 2, (viewport_size.y - region_size.y) / 2)
			
		RegionPosition.MIDDLE_RIGHT:
			position = Vector2(viewport_size.x - region_size.x - region_margin.x, (viewport_size.y - region_size.y) / 2)
			
		RegionPosition.BOTTOM_LEFT:
			position = Vector2(region_margin.x, viewport_size.y - region_size.y - region_margin.y)
			
		RegionPosition.BOTTOM_CENTER:
			position = Vector2((viewport_size.x - region_size.x) / 2, viewport_size.y - region_size.y - region_margin.y)
			
		RegionPosition.BOTTOM_RIGHT:
			position = Vector2(viewport_size.x - region_size.x - region_margin.x, viewport_size.y - region_size.y - region_margin.y)

func _on_viewport_size_changed():
	"""Handle viewport size changes for responsive positioning"""
	if auto_position:
		_position_region()

func set_region_size(new_size: Vector2i):
	"""Set the size of this region and update the background panel"""
	size = Vector2(new_size)
	
	if ui_tilemap_layer:
		ui_tilemap_layer.draw_panel(Vector2i.ZERO, new_size / ui_tilemap_layer.tile_set.tile_size)
	
	if content_container:
		content_container.position = Vector2(region_padding)
		content_container.size = Vector2(new_size) - Vector2(region_padding * 2)
	
	if auto_position:
		_position_region()

func add_content(content: Control):
	"""Add content to this region's content container"""
	if content_container:
		content_container.add_child(content)

func remove_content(content: Control):
	"""Remove content from this region"""
	if content_container and content.get_parent() == content_container:
		content_container.remove_child(content)

func set_panel_style(style: UITileMapLayer.PanelStyle):
	"""Change the panel style for this region"""
	if ui_tilemap_layer:
		ui_tilemap_layer.panel_style = style
		# Redraw with current size
		var tile_size = ui_tilemap_layer.tile_set.tile_size
		ui_tilemap_layer.draw_panel(Vector2i.ZERO, Vector2i(size) / tile_size, style)

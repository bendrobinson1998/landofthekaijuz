class_name InventoryUI
extends ScalableUIPanel

@onready var background: Control = $Background
@onready var inventory_panel: Control = $Background/InventoryPanel
@onready var grid_container: GridContainer = $Background/InventoryPanel/MarginContainer/VBoxContainer/GridContainer
@onready var margin_container: MarginContainer = $Background/InventoryPanel/MarginContainer

var ui_tilemap: UITileMapLayer

var slot_scene = preload("res://scenes/ui/InventorySlot.tscn")
var inventory_slots: Array[InventorySlotUI] = []

func _ready():
	# Call parent _ready first for scaling setup
	super()
	
	# Ensure inventory UI is below control panel
	z_index = 10
	
	# Start hidden, will be shown if needed
	visible = false
	_update_responsive_margins()
	_setup_inventory_grid()
	_connect_to_inventory_manager()
	
	# Setup UI tilemap after layout is ready
	call_deferred("_setup_ui_tilemap")

func _setup_ui_tilemap():
	# Create the UI tilemap for background styling
	ui_tilemap = UITileMapLayer.new()
	ui_tilemap.name = "UITileMap"
	ui_tilemap.panel_style = UITileMapLayer.PanelStyle.DARK_WOOD
	ui_tilemap.position = Vector2.ZERO
	ui_tilemap.z_index = -1  # Put tilemap behind other content
	background.add_child(ui_tilemap)
	
	# Calculate tilemap size dynamically based on actual panel dimensions
	var tilemap_size = _calculate_background_size()
	ui_tilemap.draw_panel(Vector2i.ZERO, tilemap_size, UITileMapLayer.PanelStyle.DARK_WOOD)

func _calculate_background_size() -> Vector2i:
	# Calculate the required tilemap size based on actual panel dimensions
	# This ensures the background texture fits the panel fluidly
	
	const TILE_SIZE = 16  # UI tileset uses 16x16 tiles
	
	# Get actual panel size (accounting for current scale)
	var panel_size = background.size
	if panel_size.x <= 0 or panel_size.y <= 0:
		# Fallback to design dimensions if size not yet calculated
		panel_size = Vector2(374, 638)  # From scene offset calculations
	
	# Calculate tiles needed to cover the panel area
	var tiles_width = max(3, ceili(panel_size.x / TILE_SIZE))  # Minimum 3 for 9-patch
	var tiles_height = max(3, ceili(panel_size.y / TILE_SIZE))  # Minimum 3 for 9-patch
	
	print("InventoryUI: Panel size: ", panel_size, " -> Tilemap size: ", Vector2i(tiles_width, tiles_height))
	return Vector2i(tiles_width, tiles_height)

func _setup_inventory_grid():
	# Clear existing children
	for child in grid_container.get_children():
		child.queue_free()
	
	inventory_slots.clear()
	
	# Create 28 slots (7x4 grid)
	for i in range(InventoryManager.INVENTORY_SIZE):
		var slot = slot_scene.instantiate() as InventorySlotUI
		slot.slot_index = i
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
		grid_container.add_child(slot)
		inventory_slots.append(slot)

func _connect_to_inventory_manager():
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		InventoryManager.inventory_opened.connect(_on_inventory_opened)
		InventoryManager.inventory_closed.connect(_on_inventory_closed)
		_on_inventory_changed()

func _on_inventory_changed():
	if not InventoryManager:
		return
	
	# Update all slots
	for i in range(inventory_slots.size()):
		var slot_data = InventoryManager.get_slot(i)
		if slot_data:
			inventory_slots[i].update_slot(slot_data)

func _on_inventory_opened():
	print("InventoryUI: _on_inventory_opened called")
	visible = true
	print("InventoryUI: Inventory UI should now be visible")

func _on_inventory_closed():
	print("InventoryUI: _on_inventory_closed called")
	visible = false
	print("InventoryUI: Inventory UI should now be hidden")

func _on_slot_clicked(index: int):
	print("Slot clicked: ", index)
	# Future: Handle item movement, usage, etc.

func _on_slot_hovered(index: int):
	var slot_data = InventoryManager.get_slot(index)
	if slot_data and not slot_data.is_empty():
		# Future: Show item tooltip
		pass


func _update_responsive_margins():
	"""Update margins based on panel size for better mobile compatibility"""
	if not margin_container:
		return
	
	# Keep consistent 22px margins for equal spacing
	var base_margin = 22
	margin_container.add_theme_constant_override("margin_left", base_margin)
	margin_container.add_theme_constant_override("margin_top", base_margin) 
	margin_container.add_theme_constant_override("margin_right", base_margin)
	margin_container.add_theme_constant_override("margin_bottom", base_margin)

func _on_scale_applied(ui_scale: float):
	"""Update responsive elements when scale changes"""
	_update_responsive_margins()
	# Redraw background with new size after scale change
	if ui_tilemap:
		var tilemap_size = _calculate_background_size()
		ui_tilemap.draw_panel(Vector2i.ZERO, tilemap_size, UITileMapLayer.PanelStyle.DARK_WOOD)

func _get_anchor_based_pivot() -> Vector2:
	"""Override to use bottom-center pivot for inventory panel to prevent overlap when scaling"""
	return Vector2(size.x / 2.0, size.y)

func _input(event: InputEvent):
	if event.is_action_pressed("toggle_inventory"):
		InventoryManager.toggle_inventory()
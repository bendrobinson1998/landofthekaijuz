class_name InventorySlotUI
extends PanelContainer

signal slot_clicked(index: int)
signal slot_hovered(index: int)

@export var slot_index: int = 0

@onready var item_icon: TextureRect = $MarginContainer/ItemIcon
@onready var quantity_label: Label = $MarginContainer/QuantityLabel

var slot_data

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	# Set up slot
	custom_minimum_size = Vector2(66, 66)
	
	# Make the PanelContainer background transparent
	# Create a transparent StyleBoxFlat for the background
	var transparent_style = StyleBoxFlat.new()
	transparent_style.bg_color = Color.TRANSPARENT
	add_theme_stylebox_override("panel", transparent_style)


func update_slot(data):
	slot_data = data
	
	if data and not data.is_empty():
		item_icon.visible = true
		
		# Use AtlasTexture if a region is specified, otherwise use texture directly
		if data.item.item_icon_region != Rect2(0, 0, 16, 16):
			var atlas_texture = AtlasTexture.new()
			atlas_texture.atlas = data.item.item_icon
			atlas_texture.region = data.item.item_icon_region
			item_icon.texture = atlas_texture
		else:
			item_icon.texture = data.item.item_icon
		
		# Update quantity label
		if data.quantity > 1:
			quantity_label.visible = true
			quantity_label.text = str(data.quantity)
		else:
			quantity_label.visible = false
	else:
		# Empty slot
		item_icon.visible = false
		quantity_label.visible = false

func _on_mouse_entered():
	# Simple hover effect - slightly brighten the item icon
	if item_icon and item_icon.visible:
		item_icon.modulate = Color(1.2, 1.2, 1.2, 1.0)
	slot_hovered.emit(slot_index)

func _on_mouse_exited():
	# Reset item icon brightness
	if item_icon and item_icon.visible:
		item_icon.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(slot_index)

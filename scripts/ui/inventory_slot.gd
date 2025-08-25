class_name InventorySlotUI
extends PanelContainer

signal slot_clicked(index: int)
signal slot_hovered(index: int)

@export var slot_index: int = 0

@onready var item_icon: TextureRect = $MarginContainer/ItemIcon
@onready var quantity_label: Label = $MarginContainer/QuantityLabel

var slot_data
var normal_style: StyleBoxTexture
var hover_style: StyleBoxTexture

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	# Set up default appearance
	custom_minimum_size = Vector2(66, 66)
	
	# Get style boxes from theme
	normal_style = get_theme_stylebox("panel")
	_create_hover_style()

func _create_hover_style():
	# Create a simple hover style using AtlasTexture for the specific region
	var main_texture = load("res://assets/ui/Modern_UI_Style_1.png")
	if main_texture:
		var atlas_texture = AtlasTexture.new()
		atlas_texture.atlas = main_texture
		atlas_texture.region = Rect2(592, 0, 16, 16)  # Atlas coord (37,0) * 16
		
		hover_style = StyleBoxTexture.new()
		hover_style.texture = atlas_texture
		hover_style.texture_margin_left = 4.0
		hover_style.texture_margin_top = 4.0
		hover_style.texture_margin_right = 4.0
		hover_style.texture_margin_bottom = 4.0

func update_slot(data):
	slot_data = data
	
	if data and not data.is_empty():
		item_icon.visible = true
		item_icon.texture = data.item.item_icon
		
		# Use region if specified
		if data.item.item_icon_region != Rect2(0, 0, 16, 16):
			item_icon.texture = AtlasTexture.new()
			item_icon.texture.atlas = data.item.item_icon
			item_icon.texture.region = data.item.item_icon_region
		
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
	if hover_style:
		add_theme_stylebox_override("panel", hover_style)
	slot_hovered.emit(slot_index)

func _on_mouse_exited():
	if normal_style:
		add_theme_stylebox_override("panel", normal_style)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(slot_index)

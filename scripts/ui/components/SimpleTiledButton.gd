class_name SimpleTiledButton
extends Button

@export var button_size: Vector2i = Vector2i(48, 48)

var texture_rect: TextureRect
var ui_atlas: AtlasTexture
var ui_texture: Texture2D
var normal_atlas_x: int
var normal_atlas_y: int
var pressed_atlas_x: int = 40
var pressed_atlas_y: int = 1
var tile_size: int = 16
var is_active: bool = false

signal button_hovered()
signal button_unhovered()

func _ready():
	# Allow button to work even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set the button size
	custom_minimum_size = button_size
	size = button_size
	
	# Create completely transparent button style - no borders or backgrounds
	var style_transparent = StyleBoxEmpty.new()  # StyleBoxEmpty removes all styling including focus borders
	
	add_theme_stylebox_override("normal", style_transparent)
	add_theme_stylebox_override("hover", style_transparent)
	add_theme_stylebox_override("pressed", style_transparent)
	add_theme_stylebox_override("focus", style_transparent)  # Remove focus border
	
	# Create texture rect for the tile icon
	texture_rect = TextureRect.new()
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let button handle mouse events
	texture_rect.anchors_preset = Control.PRESET_FULL_RECT  # Fill the entire button
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(texture_rect)
	
	# Connect signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	
	print("SimpleTiledButton: Created and ready for input - Position: ", position, " Size: ", size)
	print("SimpleTiledButton: Mouse filter: ", mouse_filter, " Disabled: ", disabled)

func _on_mouse_entered():
	button_hovered.emit()
	print("SimpleTiledButton: Mouse entered button: ", name)

func _on_mouse_exited():
	button_unhovered.emit()
	print("SimpleTiledButton: Mouse exited")

func _on_button_down():
	print("SimpleTiledButton: Button down: ", name, " - Global pos: ", global_position)
	print("SimpleTiledButton: Button rect: ", get_global_rect())
	print("SimpleTiledButton: Button has focus: ", has_focus())
	print("SimpleTiledButton: Button is_inside_tree: ", is_inside_tree())
	_update_texture_for_state(true)

func _on_button_up():
	print("SimpleTiledButton: Button up: ", name)
	_update_texture_for_state(false)

func _update_texture_for_state(pressed: bool):
	if not ui_texture or not texture_rect:
		return
	
	# Show pressed/active state if either actively pressed or button is in active state
	var show_active = pressed or is_active
	var atlas_x = pressed_atlas_x if show_active else normal_atlas_x
	var atlas_y = pressed_atlas_y if show_active else normal_atlas_y
	
	ui_atlas.region = Rect2(atlas_x * tile_size, atlas_y * tile_size, tile_size, tile_size)
	texture_rect.texture = ui_atlas

func set_button_size(new_size: Vector2i):
	button_size = new_size
	custom_minimum_size = new_size
	size = new_size
	if texture_rect:
		texture_rect.size = new_size

func set_ui_tile(ui_texture: Texture2D, atlas_x: int, atlas_y: int, tile_size: int = 16):
	"""Set the button to use a specific tile from a UI atlas"""
	print("SimpleTiledButton: set_ui_tile called with texture: ", ui_texture != null, " position: (", atlas_x, ", ", atlas_y, ")")
	
	if not texture_rect:
		return
	
	if not ui_texture:
		return
	
	# Store texture and coordinates for state changes
	self.ui_texture = ui_texture
	self.normal_atlas_x = atlas_x
	self.normal_atlas_y = atlas_y
	self.tile_size = tile_size
	
	# Create AtlasTexture for the specific tile
	ui_atlas = AtlasTexture.new()
	ui_atlas.atlas = ui_texture
	ui_atlas.region = Rect2(atlas_x * tile_size, atlas_y * tile_size, tile_size, tile_size)
	
	print("SimpleTiledButton: Created AtlasTexture with region: ", ui_atlas.region)
	print("SimpleTiledButton: Original texture size: ", ui_texture.get_size())
	
	# Apply to texture rect
	texture_rect.texture = ui_atlas
	print("SimpleTiledButton: Applied texture to TextureRect")
	print("SimpleTiledButton: TextureRect position: ", texture_rect.position)
	print("SimpleTiledButton: TextureRect size: ", texture_rect.size)
	print("SimpleTiledButton: TextureRect anchors: ", Vector4(texture_rect.anchor_left, texture_rect.anchor_top, texture_rect.anchor_right, texture_rect.anchor_bottom))
	
	# Force texture rect to be visible and on top
	texture_rect.visible = true
	texture_rect.z_index = 1
	texture_rect.modulate = Color.WHITE  # Ensure it's not transparent
	
	print("SimpleTiledButton: Texture setup complete - visible: ", texture_rect.visible, " z_index: ", texture_rect.z_index)

func set_active(active: bool):
	"""Set the button's active state (for toggle behavior)"""
	is_active = active
	_update_texture_for_state(false)  # Update texture based on new active state


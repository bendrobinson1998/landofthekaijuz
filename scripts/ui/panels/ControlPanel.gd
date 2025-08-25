class_name ControlPanel
extends ScalableUIPanel

@export var default_size: Vector2i = Vector2i(240, 120)  # Much larger for testing
@export var button_spacing: int = 8
@export var button_size: Vector2i = Vector2i(48, 48)  # Square button for 16x16 tile

@onready var button_container: HBoxContainer

var inventory_button: SimpleTiledButton
var skill_tree_button: SimpleTiledButton
var edit_mode_button: SimpleTiledButton
var settings_button: SimpleTiledButton

signal inventory_button_pressed()
signal skill_tree_button_pressed()
signal edit_mode_button_pressed()
signal settings_button_pressed()

func _ready():
	# Call parent _ready first for scaling setup
	super()
	
	print("ControlPanel: Starting _ready()")
	
	# Allow UI to work even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set mouse filter to allow button clicks - use STOP to ensure this panel handles events
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Ensure panel is on top layer for UI interaction - use very high z-index
	z_index = 1000
	
	# Create UI elements - Godot anchors handle positioning
	_create_ui_elements()
	
	# Connect to inventory signals to update button active state
	InventoryManager.inventory_opened.connect(_on_inventory_opened)
	InventoryManager.inventory_closed.connect(_on_inventory_closed)
	
	# Connect to edit mode manager signals
	EditModeManager.edit_mode_toggled.connect(_on_edit_mode_toggled)
	
	print("ControlPanel: Setup complete, anchored at bottom-right")
	print("ControlPanel: Position: ", position, " Size: ", size)
	print("ControlPanel: Global position: ", global_position)
	print("ControlPanel: Mouse filter: ", mouse_filter)
	print("ControlPanel: Z-index: ", z_index)

func _create_ui_elements():
	"""Create the button container and inventory button"""
	# Create button container for organizing buttons
	button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.add_theme_constant_override("separation", button_spacing)
	button_container.position = Vector2(8, 8)
	button_container.size = Vector2(default_size.x - 16, default_size.y - 16)
	button_container.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow buttons to receive events
	button_container.z_index = 1  # Ensure buttons are above the panel background
	add_child(button_container)
	
	# Create inventory button
	_create_inventory_button()
	
	# Create skill tree button
	_create_skill_tree_button()
	
	# Create edit mode button
	_create_edit_mode_button()
	
	# Create settings button
	_create_settings_button()

func _create_inventory_button():
	"""Create the tiled inventory button"""
	inventory_button = SimpleTiledButton.new()
	inventory_button.name = "InventoryButton"
	inventory_button.set_button_size(button_size)
	inventory_button.text = ""  # No text - just the icon
	inventory_button.tooltip_text = "Open Inventory (I)"
	inventory_button.z_index = 1001  # Ensure button is on top
	# Prevent container from stretching the button
	inventory_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inventory_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Connect button signals - using built-in Button.pressed signal
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	inventory_button.button_hovered.connect(_on_inventory_button_hovered)
	inventory_button.button_unhovered.connect(_on_inventory_button_unhovered)
	
	button_container.add_child(inventory_button)
	
	# Use call_deferred to set the tile after the button is fully ready
	call_deferred("_set_inventory_button_tile")
	call_deferred("_debug_button_info", inventory_button)

func _create_skill_tree_button():
	"""Create the tiled skill tree button"""
	skill_tree_button = SimpleTiledButton.new()
	skill_tree_button.name = "SkillTreeButton"
	skill_tree_button.set_button_size(button_size)
	skill_tree_button.text = ""  # No text - just the icon
	skill_tree_button.tooltip_text = "Open Skills (K)"
	skill_tree_button.z_index = 1001  # Ensure button is on top
	# Prevent container from stretching the button
	skill_tree_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skill_tree_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Connect button signals
	skill_tree_button.pressed.connect(_on_skill_tree_button_pressed)
	skill_tree_button.button_hovered.connect(_on_skill_tree_button_hovered)
	skill_tree_button.button_unhovered.connect(_on_skill_tree_button_unhovered)
	
	button_container.add_child(skill_tree_button)
	
	# Use call_deferred to set the tile after the button is fully ready
	call_deferred("_set_skill_tree_button_tile")

func _create_edit_mode_button():
	"""Create the tiled edit mode button"""
	edit_mode_button = SimpleTiledButton.new()
	edit_mode_button.name = "EditModeButton"
	edit_mode_button.set_button_size(button_size)
	edit_mode_button.text = ""  # No text - just the icon
	edit_mode_button.tooltip_text = "Toggle Edit Mode"
	edit_mode_button.z_index = 1001  # Ensure button is on top
	# Prevent container from stretching the button
	edit_mode_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	edit_mode_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Connect button signals
	edit_mode_button.pressed.connect(_on_edit_mode_button_pressed)
	edit_mode_button.button_hovered.connect(_on_edit_mode_button_hovered)
	edit_mode_button.button_unhovered.connect(_on_edit_mode_button_unhovered)
	
	button_container.add_child(edit_mode_button)
	
	# Use call_deferred to set the tile after the button is fully ready
	call_deferred("_set_edit_mode_button_tile")

func _set_inventory_button_tile():
	"""Set the inventory button tile after it's fully ready"""
	print("ControlPanel: _set_inventory_button_tile called")
	
	# Check if button exists first
	if not inventory_button:
		return
	
	# Load your UI texture and set the tile (30, 1)
	var ui_texture = load("res://assets/ui/Modern_UI_Style_1.png") as Texture2D
	if ui_texture:
		print("ControlPanel: UI texture loaded successfully, size: ", ui_texture.get_size())
		inventory_button.set_ui_tile(ui_texture, 30, 1, 16)

func _set_skill_tree_button_tile():
	"""Set the skill tree button tile after it's fully ready"""
	print("ControlPanel: _set_skill_tree_button_tile called")
	
	# Check if button exists first
	if not skill_tree_button:
		return
	
	# Load your UI texture and set the tile (29, 4) for normal, (39, 4) for pressed
	var ui_texture = load("res://assets/ui/Modern_UI_Style_1.png") as Texture2D
	if ui_texture:
		print("ControlPanel: UI texture loaded successfully for skill tree button")
		skill_tree_button.set_ui_tile(ui_texture, 29, 4, 16)
		# Update the pressed state coordinates
		skill_tree_button.pressed_atlas_x = 39
		skill_tree_button.pressed_atlas_y = 4

func _set_edit_mode_button_tile():
	"""Set the edit mode button tile after it's fully ready"""
	print("ControlPanel: _set_edit_mode_button_tile called")
	
	# Check if button exists first
	if not edit_mode_button:
		return
	
	# Load your UI texture and set the tile for edit/build icon
	var ui_texture = load("res://assets/ui/Modern_UI_Style_1.png") as Texture2D
	if ui_texture:
		print("ControlPanel: UI texture loaded successfully for edit mode button")
		edit_mode_button.set_ui_tile(ui_texture, 28, 5, 16)  # Using hammer/tool icon
		# Update the pressed state coordinates
		edit_mode_button.pressed_atlas_x = 38
		edit_mode_button.pressed_atlas_y = 5

func _create_settings_button():
	"""Create the tiled settings button"""
	settings_button = SimpleTiledButton.new()
	settings_button.name = "SettingsButton"
	settings_button.set_button_size(button_size)
	settings_button.text = ""  # No text - just the icon
	settings_button.tooltip_text = "Open Settings"
	settings_button.z_index = 1001  # Ensure button is on top
	# Prevent container from stretching the button
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Connect button signals
	settings_button.pressed.connect(_on_settings_button_pressed)
	settings_button.button_hovered.connect(_on_settings_button_hovered)
	settings_button.button_unhovered.connect(_on_settings_button_unhovered)
	
	button_container.add_child(settings_button)
	
	# Use call_deferred to set the tile after the button is fully ready
	call_deferred("_set_settings_button_tile")

func _set_settings_button_tile():
	"""Set the settings button tile after it's fully ready"""
	print("ControlPanel: _set_settings_button_tile called")
	
	# Check if button exists first
	if not settings_button:
		return
	
	# Load your UI texture and set the tile for settings/gear icon
	var ui_texture = load("res://assets/ui/Modern_UI_Style_1.png") as Texture2D
	if ui_texture:
		print("ControlPanel: UI texture loaded successfully for settings button")
		settings_button.set_ui_tile(ui_texture, 32, 4, 16)  # Using gear icon
		# Update the pressed state coordinates
		settings_button.pressed_atlas_x = 42
		settings_button.pressed_atlas_y = 4

func _on_inventory_button_pressed():
	"""Handle inventory button press"""
	print("ControlPanel: Inventory button pressed!")
	print("ControlPanel: Emitting inventory_button_pressed signal...")
	inventory_button_pressed.emit()
	print("ControlPanel: Signal emitted successfully")
	# Signal is handled by InGameUIManager - don't call toggle_inventory directly here

func _on_inventory_button_hovered():
	"""Handle inventory button hover"""
	# Could show tooltip or play sound effect
	pass

func _on_inventory_button_unhovered():
	"""Handle inventory button unhover"""
	# Could hide tooltip
	pass

func _on_skill_tree_button_pressed():
	"""Handle skill tree button press"""
	print("ControlPanel: Skill tree button pressed!")
	print("ControlPanel: Emitting skill_tree_button_pressed signal...")
	skill_tree_button_pressed.emit()
	print("ControlPanel: Signal emitted successfully")
	# Signal is handled by InGameUIManager

func _on_skill_tree_button_hovered():
	"""Handle skill tree button hover"""
	# Could show tooltip or play sound effect
	pass

func _on_skill_tree_button_unhovered():
	"""Handle skill tree button unhover"""
	# Could hide tooltip
	pass

func _on_edit_mode_button_pressed():
	"""Handle edit mode button press"""
	print("ControlPanel: Edit mode button pressed!")
	print("ControlPanel: Emitting edit_mode_button_pressed signal...")
	edit_mode_button_pressed.emit()
	print("ControlPanel: Signal emitted successfully")

func _on_edit_mode_button_hovered():
	"""Handle edit mode button hover"""
	# Could show tooltip or play sound effect
	pass

func _on_edit_mode_button_unhovered():
	"""Handle edit mode button unhover"""
	# Could hide tooltip
	pass

func _on_inventory_opened():
	"""Handle inventory opening - set button to active state"""
	if inventory_button:
		inventory_button.set_active(true)

func _on_inventory_closed():
	"""Handle inventory closing - set button to normal state"""
	if inventory_button:
		inventory_button.set_active(false)

func _on_skill_panel_opened():
	"""Handle skill panel opening - set button to active state"""
	if skill_tree_button:
		skill_tree_button.set_active(true)

func _on_skill_panel_closed():
	"""Handle skill panel closing - set button to normal state"""
	if skill_tree_button:
		skill_tree_button.set_active(false)

func _on_edit_mode_toggled(enabled: bool):
	"""Handle edit mode toggle - set button to appropriate state"""
	if edit_mode_button:
		edit_mode_button.set_active(enabled)

func _on_settings_button_pressed():
	"""Handle settings button press"""
	print("ControlPanel: Settings button pressed!")
	print("ControlPanel: Emitting settings_button_pressed signal...")
	settings_button_pressed.emit()
	print("ControlPanel: Signal emitted successfully")

func _on_settings_button_hovered():
	"""Handle settings button hover"""
	# Could show tooltip or play sound effect
	pass

func _on_settings_button_unhovered():
	"""Handle settings button unhover"""
	# Could hide tooltip
	pass

func add_control_button(button: SimpleTiledButton):
	"""Add a new control button to the panel"""
	if button_container:
		button_container.add_child(button)
		_resize_panel_for_buttons()

func remove_control_button(button: SimpleTiledButton):
	"""Remove a control button from the panel"""
	if button_container and button.get_parent() == button_container:
		button_container.remove_child(button)
		_resize_panel_for_buttons()

func _resize_panel_for_buttons():
	"""Resize the panel based on the number of buttons"""
	var button_count = button_container.get_child_count()
	var new_width = (button_size.x * button_count) + (button_spacing * (button_count - 1)) + 16
	var new_size = Vector2i(max(new_width, 60), default_size.y)
	
	# Update the control size (let anchors handle positioning)
	size = Vector2(new_size)
	
	if button_container:
		button_container.size.x = new_size.x - 16

func _debug_button_info(button: SimpleTiledButton):
	"""Debug button positioning info"""
	print("ControlPanel: Button '", button.name, "' - Position: ", button.position, " Size: ", button.size)
	print("ControlPanel: Button global position: ", button.global_position)
	print("ControlPanel: Button mouse filter: ", button.mouse_filter)
	print("ControlPanel: Button disabled: ", button.disabled)
	print("ControlPanel: Button z_index: ", button.z_index)
	print("ControlPanel: Button get_rect(): ", button.get_rect())
	print("ControlPanel: Button get_global_rect(): ", button.get_global_rect())
	print("ControlPanel: Button visible: ", button.visible)
	print("ControlPanel: Button parent: ", button.get_parent().name if button.get_parent() else "None")

func _get_anchor_based_pivot() -> Vector2:
	"""Override to use bottom-right pivot for control panel to maintain button click areas"""
	# Since control panel is anchored to bottom-right, use bottom-right pivot
	return Vector2(size.x, size.y)

func _on_scale_applied(ui_scale: float):
	"""Handle scaling applied to maintain button functionality"""
	print("ControlPanel: Scale applied: ", ui_scale, " - Current size: ", size)
	
	# After scaling, ensure all buttons are still properly positioned and clickable
	if button_container:
		print("ControlPanel: Button container position after scale: ", button_container.position)
		print("ControlPanel: Button container size after scale: ", button_container.size)
		
		# Debug all button positions after scaling
		for i in button_container.get_child_count():
			var button = button_container.get_child(i)
			if button is SimpleTiledButton:
				print("ControlPanel: Button ", button.name, " post-scale - Pos: ", button.position, " GlobalPos: ", button.global_position, " Rect: ", button.get_global_rect())

func set_inventory_button_enabled(enabled: bool):
	"""Enable/disable the inventory button"""
	if inventory_button:
		inventory_button.disabled = not enabled

func get_button_count() -> int:
	"""Get the current number of buttons in the panel"""
	return button_container.get_child_count() if button_container else 0

func debug_button_states():
	"""Debug all button states and properties - call this to troubleshoot"""
	print("ControlPanel: === DEBUG BUTTON STATES ===")
	print("ControlPanel: Panel position: ", position, " size: ", size, " global_position: ", global_position)
	print("ControlPanel: Panel mouse_filter: ", mouse_filter, " z_index: ", z_index)
	print("ControlPanel: Panel visible: ", visible, " scale: ", scale)
	
	if button_container:
		print("ControlPanel: Container position: ", button_container.position, " size: ", button_container.size)
		print("ControlPanel: Container mouse_filter: ", button_container.mouse_filter)
		
		var buttons = [inventory_button, skill_tree_button, edit_mode_button, settings_button]
		var button_names = ["Inventory", "SkillTree", "EditMode", "Settings"]
		
		for i in range(buttons.size()):
			var button = buttons[i]
			var name = button_names[i]
			
			if button:
				print("ControlPanel: ", name, " button - Pos: ", button.position, " GlobalPos: ", button.global_position)
				print("ControlPanel: ", name, " button - Size: ", button.size, " Rect: ", button.get_global_rect())
				print("ControlPanel: ", name, " button - MouseFilter: ", button.mouse_filter, " Disabled: ", button.disabled)
				print("ControlPanel: ", name, " button - Visible: ", button.visible, " Z-Index: ", button.z_index)
				print("ControlPanel: ", name, " button - Has texture: ", button.ui_texture != null)
			else:
				print("ControlPanel: ", name, " button - NOT FOUND!")
	else:
		print("ControlPanel: Button container NOT FOUND!")
	
	print("ControlPanel: === END DEBUG STATES ===")

# Add a test function that can be called manually
func test_button_clicks():
	"""Test all button click handlers manually"""
	print("ControlPanel: Testing all button click handlers...")
	
	if inventory_button:
		print("ControlPanel: Testing inventory button...")
		_on_inventory_button_pressed()
	
	if skill_tree_button:
		print("ControlPanel: Testing skill tree button...")  
		_on_skill_tree_button_pressed()
	
	if edit_mode_button:
		print("ControlPanel: Testing edit mode button...")
		_on_edit_mode_button_pressed()
	
	if settings_button:
		print("ControlPanel: Testing settings button...")
		_on_settings_button_pressed()

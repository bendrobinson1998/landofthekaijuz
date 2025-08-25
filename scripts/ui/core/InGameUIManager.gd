extends Control

@onready var dialogue_panel: DialoguePanel = $DialoguePanel
@onready var control_panel: ControlPanel = $ControlPanel
@onready var persistent_dialog_box: PersistentDialogBox = $PersistentDialogBox
@onready var chat_input_panel: ChatInputPanel = $ChatInputPanel
@onready var chat_bubble_container: HBoxContainer = $ChatBubbleContainer
var skill_panel: Control
var inventory_ui: Control
var debug_edit_panel: Control
var settings_panel: Control

var current_ui_scale: float = 1.0

func _ready():
	
	# Allow UI to work even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect to UserPreferences for UI scale changes
	if UserPreferences:
		UserPreferences.ui_scale_changed.connect(_on_ui_scale_changed)
		# Apply initial UI scale after all panels are loaded
		call_deferred("_apply_initial_ui_scale")
	
	
	# Load and instantiate skill panel
	var skill_panel_scene = preload("res://scenes/ui/panels/SkillPanel.tscn")
	skill_panel = skill_panel_scene.instantiate()
	add_child(skill_panel)
	
	# Load and instantiate inventory UI
	var inventory_scene = preload("res://scenes/ui/InventoryUI.tscn")
	inventory_ui = inventory_scene.instantiate()
	add_child(inventory_ui)
	
	# Load and instantiate settings panel
	var settings_panel_scene = preload("res://scenes/ui/panels/SettingsPanel.tscn")
	settings_panel = settings_panel_scene.instantiate()
	add_child(settings_panel)
	
	# Create debug edit mode panel for testing
	var debug_script = load("res://scripts/ui/debug_edit_mode_panel.gd")
	debug_edit_panel = Control.new()
	debug_edit_panel.name = "DebugEditModePanel"
	debug_edit_panel.set_script(debug_script)
	add_child(debug_edit_panel)
	
	# Connect skill panel signals to control panel
	if skill_panel and control_panel:
		skill_panel.panel_opened.connect(control_panel._on_skill_panel_opened)
		skill_panel.panel_closed.connect(control_panel._on_skill_panel_closed)
	
	# Hide both panels initially (we'll open inventory by default later)
	if skill_panel:
		skill_panel.visible = false
	if inventory_ui:
		inventory_ui.visible = false
	if settings_panel:
		settings_panel.visible = false
	
	# Debug panel starts hidden
	if debug_edit_panel:
		debug_edit_panel.visible = false
	
	# Godot anchors handle positioning automatically - no need to force sizing
	
	# Wait for UIManager to be ready
	await get_tree().process_frame
	
	# Register the dialogue and control panels with UIManager
	# Note: The panels themselves are the UI regions for this implementation
	if dialogue_panel:
		UIManager.register_ui_region("dialogue", null)  # We'll use the panel directly
	
	if control_panel:
		UIManager.register_ui_region("control", null)  # We'll use the panel directly
	
	if persistent_dialog_box:
		UIManager.register_ui_region("persistent_dialog", null)  # We'll use the box directly
	
	if chat_input_panel:
		UIManager.register_ui_region("chat_input", null)  # We'll use the panel directly
	
	# Connect control panel signals
	if control_panel:
		print("InGameUIManager: Connecting control panel signals...")
		control_panel.inventory_button_pressed.connect(_on_inventory_button_pressed)
		print("InGameUIManager: inventory_button_pressed signal connected")
		control_panel.skill_tree_button_pressed.connect(_on_skill_tree_button_pressed)
		print("InGameUIManager: skill_tree_button_pressed signal connected")
		control_panel.edit_mode_button_pressed.connect(_on_edit_mode_button_pressed)
		print("InGameUIManager: edit_mode_button_pressed signal connected")
		control_panel.settings_button_pressed.connect(_on_settings_button_pressed)
		print("InGameUIManager: settings_button_pressed signal connected")
		print("InGameUIManager: All control panel signals connected successfully")
	else:
		print("InGameUIManager: ERROR - control_panel not found for signal connection!")
	
	
	# Open inventory by default
	if InventoryManager:
		InventoryManager.open_inventory()
	


func _on_inventory_button_pressed():
	"""Handle inventory button press from the control panel"""
	print("InGameUIManager: Received inventory button press signal")
	if InventoryManager:
		print("InGameUIManager: InventoryManager found, toggling inventory...")
		# Close skill panel if open (tab-like behavior)
		if skill_panel and skill_panel.is_visible_state:
			print("InGameUIManager: Closing skill panel first")
			skill_panel.toggle_visibility()
		InventoryManager.toggle_inventory()
		print("InGameUIManager: Inventory toggle completed")
	else:
		print("InGameUIManager: ERROR - InventoryManager not found!")

func _on_skill_tree_button_pressed():
	"""Handle skill tree button press from the control panel"""
	if skill_panel:
		# Close inventory if open (tab-like behavior)
		if InventoryManager and InventoryManager.is_inventory_open:
			InventoryManager.close_inventory()
		skill_panel.toggle_visibility()

func _on_edit_mode_button_pressed():
	"""Handle edit mode button press from the control panel"""
	EditModeManager.toggle_edit_mode()
	
	# Show edit mode notification
	var mode_text = "Edit Mode ON" if EditModeManager.is_edit_mode() else "Edit Mode OFF"
	show_persistent_notification(mode_text, 2.0)

func _on_settings_button_pressed():
	"""Handle settings button press from the control panel"""
	if settings_panel:
		settings_panel.toggle_visibility()

func show_dialogue(text: String, speaker: String = ""):
	"""Show dialogue through the dialogue panel"""
	if dialogue_panel:
		dialogue_panel.show_dialogue(text, speaker)

func hide_dialogue():
	"""Hide the dialogue panel"""
	if dialogue_panel:
		dialogue_panel.hide_dialogue()

# Expose commonly used functions for external access
func set_inventory_button_enabled(enabled: bool):
	"""Enable/disable the inventory button"""
	if control_panel:
		control_panel.set_inventory_button_enabled(enabled)

func add_control_button(button: SimpleTiledButton):
	"""Add a new button to the control panel"""
	if control_panel:
		control_panel.add_control_button(button)

func remove_control_button(button: SimpleTiledButton):
	"""Remove a button from the control panel"""
	if control_panel:
		control_panel.remove_control_button(button)

# Persistent Dialog Box functions
func show_persistent_notification(message: String, duration: float = 3.0):
	"""Display a notification in the persistent dialog box"""
	if persistent_dialog_box:
		persistent_dialog_box.display_notification(message, duration)

func show_persistent_dialogue(text: String, speaker: String = ""):
	"""Display dialogue in the persistent dialog box"""
	if persistent_dialog_box:
		persistent_dialog_box.display_dialogue(text, speaker)

func show_persistent_input(prompt: String = "Enter command:"):
	"""Show input prompt in the persistent dialog box"""
	if persistent_dialog_box:
		persistent_dialog_box.show_input_prompt(prompt)

func switch_to_notification_mode():
	"""Switch persistent dialog box to notification mode"""
	if persistent_dialog_box:
		persistent_dialog_box.show_notification_section()

func resize_persistent_dialog(new_size: Vector2i):
	"""Resize the persistent dialog box"""
	if persistent_dialog_box:
		persistent_dialog_box.resize_dialog_box(new_size)

# Chat bubble functions - now handled directly by player nodes
# This function is deprecated as bubbles are now attached directly to players
	


# Chat bubble expiration now handled by individual player nodes

# Test function - can be removed later
func _input(event: InputEvent):
	"""Handle global UI input"""
	if event.is_action_pressed("ui_cancel"):  # Escape key
		# Toggle settings panel with ESC
		if settings_panel:
			settings_panel.toggle_visibility()
	elif event.is_action_pressed("ui_select"):  # Space key - test dialogue
		show_dialogue("Hello! This is a test of the new UI system. It uses tiled panels for a consistent look!", "System")
	elif event.is_action_pressed("ui_home"):  # Home key - test persistent dialog
		show_persistent_notification("Test notification in persistent dialog box!")
	elif event.is_action_pressed("ui_end"):  # End key - test persistent dialogue
		show_persistent_dialogue("This is a test dialogue in the persistent dialog box!", "NPC")

func _on_ui_scale_changed(new_scale: float):
	"""Handle UI scale changes from UserPreferences - now delegates to individual panels"""
	current_ui_scale = new_scale
	
	# Apply scale to all scalable UI panels
	_apply_ui_scale_to_panels(new_scale)
	
	print("InGameUIManager: Applied UI scale: ", new_scale, "x")

func _apply_ui_scale_to_panels(ui_scale: float):
	"""Apply UI scale to individual panels instead of root control"""
	var scalable_panels = [
		dialogue_panel,
		control_panel, 
		persistent_dialog_box,
		chat_input_panel,
		skill_panel,
		inventory_ui,
		settings_panel
	]
	
	for panel in scalable_panels:
		if panel and panel.has_method("apply_ui_scale"):
			panel.apply_ui_scale(ui_scale)

func _apply_initial_ui_scale():
	"""Apply initial UI scale after all panels are loaded"""
	if UserPreferences:
		_apply_ui_scale_to_panels(UserPreferences.get_ui_scale())

func get_current_ui_scale() -> float:
	"""Get the current UI scale"""
	return current_ui_scale

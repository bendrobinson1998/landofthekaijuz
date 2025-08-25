extends Node

signal ui_region_registered(region_name: String, region: UIRegion)
signal ui_region_unregistered(region_name: String)
signal dialogue_started(dialogue_text: String)
signal dialogue_ended()

var ui_regions: Dictionary = {}
var current_dialogue: String = ""
var is_dialogue_active: bool = false

# UI Region references for quick access
var dialogue_region: UIRegion
var control_region: UIRegion

func _ready():
	name = "UIManager"
	set_process_mode(Node.PROCESS_MODE_ALWAYS)  # Always process, even when paused

func register_ui_region(region_name: String, region: UIRegion):
	"""Register a UI region with the manager"""
	ui_regions[region_name] = region
	ui_region_registered.emit(region_name, region)
	
	# Store references to commonly used regions
	match region_name:
		"dialogue":
			dialogue_region = region
		"control":
			control_region = region
	
	print("UIManager: Registered UI region '", region_name, "'")

func unregister_ui_region(region_name: String):
	"""Unregister a UI region"""
	if ui_regions.has(region_name):
		ui_regions.erase(region_name)
		ui_region_unregistered.emit(region_name)
		print("UIManager: Unregistered UI region '", region_name, "'")

func get_ui_region(region_name: String) -> UIRegion:
	"""Get a UI region by name"""
	return ui_regions.get(region_name)

func show_dialogue(text: String, speaker_name: String = ""):
	"""Show dialogue in the dialogue region"""
	if not dialogue_region:
		return
	
	current_dialogue = text
	is_dialogue_active = true
	dialogue_started.emit(text)
	
	# The actual dialogue display will be handled by the DialoguePanel
	var dialogue_panel = dialogue_region.get_node("ContentContainer").get_child(0)
	if dialogue_panel and dialogue_panel.has_method("show_dialogue"):
		dialogue_panel.show_dialogue(text, speaker_name)

func hide_dialogue():
	"""Hide the current dialogue"""
	if not is_dialogue_active:
		return
	
	is_dialogue_active = false
	current_dialogue = ""
	dialogue_ended.emit()
	
	if dialogue_region:
		var dialogue_panel = dialogue_region.get_node("ContentContainer").get_child(0)
		if dialogue_panel and dialogue_panel.has_method("hide_dialogue"):
			dialogue_panel.hide_dialogue()

func toggle_inventory():
	"""Toggle the inventory UI (delegates to InventoryManager)"""
	if InventoryManager:
		InventoryManager.toggle_inventory()

func update_control_panel():
	"""Update the control panel (useful for adding/removing buttons)"""
	if control_region:
		# This can be expanded when adding more control buttons
		pass

func set_ui_theme(theme_name: String):
	"""Set the UI theme for all regions"""
	var style: UITileMapLayer.PanelStyle
	
	match theme_name:
		"dark_wood":
			style = UITileMapLayer.PanelStyle.DARK_WOOD
		"light_wood":
			style = UITileMapLayer.PanelStyle.LIGHT_WOOD
		"stone":
			style = UITileMapLayer.PanelStyle.STONE
		"metal":
			style = UITileMapLayer.PanelStyle.METAL
		_:
			style = UITileMapLayer.PanelStyle.DARK_WOOD
	
	for region in ui_regions.values():
		if region.has_method("set_panel_style"):
			region.set_panel_style(style)

func get_dialogue_active() -> bool:
	"""Check if dialogue is currently active"""
	return is_dialogue_active

func get_current_dialogue() -> String:
	"""Get the current dialogue text"""
	return current_dialogue
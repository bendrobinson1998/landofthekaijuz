class_name SettingsPanel
extends ScalableUIPanel

@export var panel_size: Vector2i = Vector2i(600, 400)
@export var panel_style: UITileMapLayer.PanelStyle = UITileMapLayer.PanelStyle.DARK_WOOD
@export var content_margin: int = 16

@onready var ui_tilemap: UITileMapLayer
@onready var content_area: Control
@onready var close_button: SimpleTiledButton
@onready var scroll_container: ScrollContainer
@onready var settings_container: VBoxContainer

var is_visible_state: bool = false

signal panel_opened()
signal panel_closed()

func _ready():
	# Call parent _ready first for scaling setup
	super()
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_setup_positioning()
	_create_ui_elements()
	_create_content_sections()
	
	visible = false
	is_visible_state = false
	
	print("SettingsPanel: Ready complete, child count: ", get_child_count())
	if content_area:
		print("SettingsPanel: Content area child count: ", content_area.get_child_count())
	if settings_container:
		print("SettingsPanel: Settings container child count: ", settings_container.get_child_count())
	
	# Force layout and rendering update for Godot 4.4 dynamic UI bug
	call_deferred("_force_layout_update")

func _setup_positioning():
	"""Set up the positioning for center of screen"""
	anchors_preset = Control.PRESET_CENTER
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	
	custom_minimum_size = Vector2(panel_size.x, panel_size.y)
	size = Vector2(panel_size.x, panel_size.y)
	
	offset_left = -panel_size.x / 2
	offset_top = -panel_size.y / 2
	offset_right = panel_size.x / 2
	offset_bottom = panel_size.y / 2
	
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

func _create_ui_elements():
	"""Create the UI tilemap layer and background for styling"""
	var background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.2, 0.15, 0.1, 0.95)
	background.anchors_preset = Control.PRESET_FULL_RECT
	add_child(background)
	
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color(0.6, 0.4, 0.2, 1.0)
	border.anchors_preset = Control.PRESET_FULL_RECT
	border.offset_left = 2
	border.offset_top = 2
	border.offset_right = -2
	border.offset_bottom = -2
	add_child(border)
	
	var inner_bg = ColorRect.new()
	inner_bg.name = "InnerBackground"
	inner_bg.color = Color(0.15, 0.1, 0.05, 0.98)
	inner_bg.anchors_preset = Control.PRESET_FULL_RECT
	inner_bg.offset_left = 4
	inner_bg.offset_top = 4
	inner_bg.offset_right = -4
	inner_bg.offset_bottom = -4
	add_child(inner_bg)
	
	ui_tilemap = UITileMapLayer.new()
	ui_tilemap.name = "UITileMap"
	ui_tilemap.panel_style = panel_style
	ui_tilemap.position = Vector2.ZERO
	ui_tilemap.z_index = -1  # Put tilemap behind other content
	add_child(ui_tilemap)
	
	var tile_size = Vector2i(16, 16)
	var tilemap_size = Vector2i(
		(panel_size.x + tile_size.x - 1) / tile_size.x,
		(panel_size.y + tile_size.y - 1) / tile_size.y
	)
	
	ui_tilemap.draw_panel(Vector2i.ZERO, tilemap_size, panel_style)
	
	# Temporarily disable tilemap to see if it's covering content
	ui_tilemap.visible = false
	background.visible = true
	
	# Create header first
	_create_header()
	
	# Then create content area below header
	content_area = Control.new()
	content_area.name = "ContentArea"
	content_area.anchors_preset = Control.PRESET_FULL_RECT
	content_area.offset_left = content_margin
	content_area.offset_top = 50  # Space for header
	content_area.offset_right = -content_margin
	content_area.offset_bottom = -content_margin
	content_area.mouse_filter = Control.MOUSE_FILTER_PASS
	content_area.z_index = 1  # Ensure content is above background
	add_child(content_area)

func _create_header():
	"""Create the header with title and close button"""
	var header = Control.new()
	header.name = "Header"
	header.anchors_preset = Control.PRESET_TOP_WIDE
	header.offset_bottom = 40
	header.z_index = 2  # Ensure header is on top
	add_child(header)
	
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Settings"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.anchors_preset = Control.PRESET_CENTER
	header.add_child(title_label)
	
	close_button = SimpleTiledButton.new()
	close_button.name = "CloseButton"
	close_button.set_button_size(Vector2i(24, 24))
	close_button.position = Vector2(panel_size.x - 32, 8)
	close_button.tooltip_text = "Close Settings (ESC)"
	close_button.pressed.connect(_on_close_button_pressed)
	header.add_child(close_button)
	
	call_deferred("_set_close_button_tile")

func _set_close_button_tile():
	"""Set the close button tile after it's ready"""
	if not close_button:
		return
	
	var ui_texture = load("res://assets/ui/Modern_UI_Style_1.png") as Texture2D
	if ui_texture:
		close_button.set_ui_tile(ui_texture, 25, 2, 16)
		close_button.pressed_atlas_x = 35
		close_button.pressed_atlas_y = 2

func _create_content_sections():
	"""Create settings container directly (no scroll for now)"""
	# Add a background behind the content for visibility
	var content_bg = ColorRect.new()
	content_bg.color = Color(0.05, 0.05, 0.05, 0.5)
	content_bg.anchors_preset = Control.PRESET_FULL_RECT
	content_area.add_child(content_bg)
	
	settings_container = VBoxContainer.new()
	settings_container.name = "SettingsContainer"
	settings_container.add_theme_constant_override("separation", 15)
	settings_container.anchors_preset = Control.PRESET_FULL_RECT
	settings_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Force visibility and ensure proper rendering for Godot 4.4 bug
	settings_container.visible = true
	settings_container.modulate = Color.WHITE
	
	content_area.add_child(settings_container)
	
	_add_video_settings()
	_add_separator()
	_add_audio_settings()
	_add_separator()
	_add_control_settings()
	_add_separator()
	_add_general_settings()

func _add_separator():
	"""Add a visual separator between sections"""
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 10)
	settings_container.add_child(separator)

func _add_section_header(text: String):
	"""Add a section header label"""
	var header = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	settings_container.add_child(header)

func _add_video_settings():
	"""Add video settings section"""
	_add_section_header("Video Settings")
	
	# UI Scale setting
	var ui_scale_label = Label.new()
	ui_scale_label.text = "UI Scale"
	ui_scale_label.add_theme_font_size_override("font_size", 12)
	ui_scale_label.add_theme_color_override("font_color", Color.WHITE)
	settings_container.add_child(ui_scale_label)
	
	var ui_scale_container = HBoxContainer.new()
	ui_scale_container.add_theme_constant_override("separation", 10)
	settings_container.add_child(ui_scale_container)
	
	var ui_scale_option = OptionButton.new()
	ui_scale_option.name = "UIScaleOption"
	var scale_percentages = UserPreferences.get_valid_ui_scale_percentages()
	for percentage in scale_percentages:
		ui_scale_option.add_item(percentage)
	
	# Set current scale
	var current_scale = UserPreferences.get_ui_scale()
	var current_index = UserPreferences.VALID_UI_SCALES.find(current_scale)
	if current_index >= 0:
		ui_scale_option.selected = current_index
	
	ui_scale_option.item_selected.connect(_on_ui_scale_selected)
	ui_scale_container.add_child(ui_scale_option)
	
	var ui_scale_preview = Label.new()
	ui_scale_preview.name = "UIScalePreview"
	ui_scale_preview.text = "Current: " + UserPreferences.get_ui_scale_percentage()
	ui_scale_preview.add_theme_font_size_override("font_size", 10)
	ui_scale_preview.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	ui_scale_container.add_child(ui_scale_preview)
	
	var fullscreen_check = CheckBox.new()
	fullscreen_check.text = "Fullscreen"
	fullscreen_check.add_theme_font_size_override("font_size", 12)
	fullscreen_check.add_theme_color_override("font_color", Color.WHITE)
	fullscreen_check.button_pressed = UserPreferences.fullscreen
	fullscreen_check.toggled.connect(func(pressed): UserPreferences.fullscreen = pressed)
	settings_container.add_child(fullscreen_check)
	
	var vsync_check = CheckBox.new()
	vsync_check.text = "VSync"
	vsync_check.add_theme_font_size_override("font_size", 12)
	vsync_check.add_theme_color_override("font_color", Color.WHITE)
	vsync_check.button_pressed = UserPreferences.vsync
	vsync_check.toggled.connect(func(pressed): UserPreferences.vsync = pressed)
	settings_container.add_child(vsync_check)
	
	var resolution_label = Label.new()
	resolution_label.text = "Resolution"
	resolution_label.add_theme_font_size_override("font_size", 12)
	resolution_label.add_theme_color_override("font_color", Color.WHITE)
	settings_container.add_child(resolution_label)
	
	var resolution_option = OptionButton.new()
	resolution_option.add_item("1920x1080")
	resolution_option.add_item("1366x768")
	resolution_option.add_item("1280x720")
	
	# Set current resolution
	var res_index = 0
	match UserPreferences.resolution:
		"1366x768": res_index = 1
		"1280x720": res_index = 2
	resolution_option.selected = res_index
	resolution_option.item_selected.connect(func(index): 
		var resolutions = ["1920x1080", "1366x768", "1280x720"]
		UserPreferences.resolution = resolutions[index]
	)
	settings_container.add_child(resolution_option)

func _add_audio_settings():
	"""Add audio settings section"""
	_add_section_header("Audio Settings")
	
	var master_label = Label.new()
	master_label.text = "Master Volume"
	master_label.add_theme_font_size_override("font_size", 12)
	master_label.add_theme_color_override("font_color", Color.WHITE)
	settings_container.add_child(master_label)
	
	var master_slider = HSlider.new()
	master_slider.min_value = 0
	master_slider.max_value = 1
	master_slider.step = 0.05
	master_slider.value = UserPreferences.master_volume
	master_slider.custom_minimum_size.x = 200
	master_slider.value_changed.connect(func(value): 
		UserPreferences.master_volume = value
		UserPreferences.apply_audio_settings()
	)
	settings_container.add_child(master_slider)
	
	var sfx_label = Label.new()
	sfx_label.text = "Sound Effects Volume"
	sfx_label.add_theme_font_size_override("font_size", 12)
	sfx_label.add_theme_color_override("font_color", Color.WHITE)
	settings_container.add_child(sfx_label)
	
	var sfx_slider = HSlider.new()
	sfx_slider.min_value = 0
	sfx_slider.max_value = 1
	sfx_slider.step = 0.05
	sfx_slider.value = UserPreferences.sfx_volume
	sfx_slider.custom_minimum_size.x = 200
	sfx_slider.value_changed.connect(func(value): 
		UserPreferences.sfx_volume = value
		UserPreferences.apply_audio_settings()
	)
	settings_container.add_child(sfx_slider)
	
	var music_label = Label.new()
	music_label.text = "Music Volume"
	music_label.add_theme_font_size_override("font_size", 12)
	music_label.add_theme_color_override("font_color", Color.WHITE)
	settings_container.add_child(music_label)
	
	var music_slider = HSlider.new()
	music_slider.min_value = 0
	music_slider.max_value = 1
	music_slider.step = 0.05
	music_slider.value = UserPreferences.music_volume
	music_slider.custom_minimum_size.x = 200
	music_slider.value_changed.connect(func(value): 
		UserPreferences.music_volume = value
		UserPreferences.apply_audio_settings()
	)
	settings_container.add_child(music_slider)

func _add_control_settings():
	"""Add control settings section"""
	_add_section_header("Control Settings")
	
	var controls_label = Label.new()
	controls_label.text = "Key bindings will be added here"
	controls_label.add_theme_font_size_override("font_size", 12)
	controls_label.add_theme_color_override("font_color", Color.WHITE)
	settings_container.add_child(controls_label)
	
	var sensitivity_label = Label.new()
	sensitivity_label.text = "Mouse Sensitivity"
	sensitivity_label.add_theme_font_size_override("font_size", 12)
	sensitivity_label.add_theme_color_override("font_color", Color.WHITE)
	settings_container.add_child(sensitivity_label)
	
	var sensitivity_slider = HSlider.new()
	sensitivity_slider.min_value = 0.1
	sensitivity_slider.max_value = 2.0
	sensitivity_slider.value = UserPreferences.mouse_sensitivity
	sensitivity_slider.step = 0.1
	sensitivity_slider.custom_minimum_size.x = 200
	sensitivity_slider.value_changed.connect(func(value): 
		UserPreferences.mouse_sensitivity = value
		UserPreferences.save_settings()
	)
	settings_container.add_child(sensitivity_slider)

func _add_general_settings():
	"""Add general settings section"""
	_add_section_header("General Settings")
	
	var placeholder = Label.new()
	placeholder.text = "General settings will be added here"
	placeholder.add_theme_font_size_override("font_size", 12)
	placeholder.add_theme_color_override("font_color", Color.WHITE)
	settings_container.add_child(placeholder)

func _on_close_button_pressed():
	"""Handle close button press"""
	toggle_visibility()

func toggle_visibility():
	"""Toggle the visibility of the settings panel"""
	if is_visible_state:
		hide_panel()
	else:
		show_panel()

func show_panel():
	"""Show the settings panel"""
	visible = true
	is_visible_state = true
	panel_opened.emit()
	
	# Don't pause the entire tree, just pause the game world
	# The UI should remain interactive
	# get_tree().paused = true

func hide_panel():
	"""Hide the settings panel"""
	visible = false
	is_visible_state = false
	panel_closed.emit()
	
	# get_tree().paused = false

func _force_layout_update():
	"""Force layout and visibility update for Godot 4.4 dynamic UI rendering bug"""
	if settings_container:
		settings_container.queue_sort()
		settings_container.notification(NOTIFICATION_RESIZED)
		# Force all children to be visible
		for child in settings_container.get_children():
			child.visible = true
			child.modulate = Color.WHITE

func _input(event: InputEvent):
	"""Handle input events"""
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()

func _on_ui_scale_selected(index: int):
	"""Handle UI scale selection"""
	var scales = UserPreferences.VALID_UI_SCALES
	if index >= 0 and index < scales.size():
		var new_scale = scales[index]
		UserPreferences.set_ui_scale(new_scale)
		
		# Update preview text - find it in the settings container
		if settings_container:
			for child in settings_container.get_children():
				if child is HBoxContainer:
					var preview_label = child.get_node_or_null("UIScalePreview")
					if preview_label:
						preview_label.text = "Current: " + UserPreferences.get_ui_scale_percentage()
						break
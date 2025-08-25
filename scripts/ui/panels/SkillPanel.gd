extends ScalableUIPanel

signal panel_opened()
signal panel_closed()

@onready var background: Control = $Background
@onready var margin_container: MarginContainer = $MarginContainer
@onready var woodcutting_level_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/WoodcuttingContainer/LevelLabel
@onready var woodcutting_xp_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/WoodcuttingContainer/XPLabel
@onready var woodcutting_progress_bar: ProgressBar = $MarginContainer/ScrollContainer/VBoxContainer/WoodcuttingContainer/ProgressBar

var ui_tilemap: UITileMapLayer
var is_visible_state: bool = false

func _ready():
	# Call parent _ready first for scaling setup
	super()
	
	# Create and setup the UI tilemap
	_setup_ui_tilemap()
	
	# Connect to skill manager signals
	SkillManager.skill_level_up.connect(_on_skill_level_up)
	SkillManager.skill_xp_gained.connect(_on_skill_xp_gained)
	
	# Hide panel initially
	visible = false
	
	# Update responsive elements
	_update_responsive_margins()
	
	# Update display
	_update_skill_display()

func _calculate_background_size() -> Vector2i:
	# Calculate the required tilemap size based on actual panel dimensions
	# This ensures the background texture fits the panel fluidly
	
	const TILE_SIZE = 16  # UI tileset uses 16x16 tiles
	
	# Get actual panel size (accounting for current scale)
	var panel_size = background.size if background else size
	if panel_size.x <= 0 or panel_size.y <= 0:
		# Fallback to design dimensions if size not yet calculated
		panel_size = Vector2(374, 638)  # Updated panel dimensions
	
	# Calculate tiles needed to cover the panel area
	var tiles_width = max(3, ceili(panel_size.x / TILE_SIZE))  # Minimum 3 for 9-patch
	var tiles_height = max(3, ceili(panel_size.y / TILE_SIZE))  # Minimum 3 for 9-patch
	
	return Vector2i(tiles_width, tiles_height)

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

func _input(event):
	# Toggle skill panel with 'K' key (like OSRS skills tab)
	if event.is_action_pressed("toggle_skills"):
		toggle_visibility()

func _update_responsive_margins():
	"""Update margins based on panel size for better mobile compatibility"""
	if not margin_container:
		return
	
	# Keep consistent 22px margins for equal spacing (matches inventory)
	var base_margin = 22
	margin_container.add_theme_constant_override("margin_left", base_margin)
	margin_container.add_theme_constant_override("margin_top", base_margin) 
	margin_container.add_theme_constant_override("margin_right", base_margin)
	margin_container.add_theme_constant_override("margin_bottom", base_margin)

func _on_scale_applied(ui_scale: float):
	"""Update responsive elements when scale changes"""
	_update_responsive_margins()

func _get_anchor_based_pivot() -> Vector2:
	"""Override to use bottom-center pivot for skill panel to prevent overlap when scaling"""
	return Vector2(size.x / 2.0, size.y)

func toggle_visibility():
	is_visible_state = !is_visible_state
	visible = is_visible_state
	
	if visible:
		_update_skill_display()
		panel_opened.emit()
	else:
		panel_closed.emit()

func _update_skill_display():
	var woodcutting_skill = SkillManager.get_skill(Skill.SkillType.WOODCUTTING)
	if not woodcutting_skill:
		return
	
	
	# Check if UI elements are properly initialized
	if not woodcutting_level_label:
		return
	if not woodcutting_xp_label:
		return
	if not woodcutting_progress_bar:
		return
	
	# Update level
	woodcutting_level_label.text = "Level: " + str(woodcutting_skill.current_level)
	
	# Update XP
	var xp_text = str(woodcutting_skill.current_xp)
	if woodcutting_skill.current_level < 99:
		var xp_needed = woodcutting_skill.get_xp_needed_for_next_level()
		xp_text += " (" + str(xp_needed) + " to next)"
	
	woodcutting_xp_label.text = "XP: " + xp_text
	
	# Update progress bar
	if woodcutting_skill.current_level < 99:
		var progress = woodcutting_skill.get_progress_percentage()
		woodcutting_progress_bar.value = progress
		woodcutting_progress_bar.visible = true
	else:
		woodcutting_progress_bar.visible = false

func _on_skill_level_up(skill: Skill, old_level: int, new_level: int):
	if skill.skill_type == Skill.SkillType.WOODCUTTING:
		_update_skill_display()
		
		# Show a level-up animation/notification
		_show_level_up_notification(skill, old_level, new_level)

func _on_skill_xp_gained(skill: Skill, amount: int):
	if skill.skill_type == Skill.SkillType.WOODCUTTING:
			# Always update the display, regardless of visibility
		_update_skill_display()
		
		# Only show XP notification if panel is visible
		if visible:
			_show_xp_notification(skill, amount)

func _show_level_up_notification(skill: Skill, old_level: int, new_level: int):
	# Create a temporary label for level up notification
	var notification = Label.new()
	notification.text = "Woodcutting Level Up! " + str(old_level) + " → " + str(new_level)
	notification.add_theme_color_override("font_color", Color.YELLOW)
	notification.position = Vector2(50, 50)
	notification.z_index = 100
	
	add_child(notification)
	
	# Animate the notification
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "position:y", notification.position.y - 50, 2.0)
	tween.tween_property(notification, "modulate:a", 0.0, 2.0)
	
	# Remove notification after animation
	tween.tween_callback(notification.queue_free).set_delay(2.0)

func _show_xp_notification(skill: Skill, amount: int):
	# Create a temporary label for XP gain
	var notification = Label.new()
	notification.text = "+" + str(amount) + " XP"
	notification.add_theme_color_override("font_color", Color.CYAN)
	notification.position = Vector2(100, 100)
	notification.z_index = 100
	
	add_child(notification)
	
	# Animate the notification
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "position:y", notification.position.y - 30, 1.5)
	tween.tween_property(notification, "modulate:a", 0.0, 1.5)
	
	# Remove notification after animation
	tween.tween_callback(notification.queue_free).set_delay(1.5)
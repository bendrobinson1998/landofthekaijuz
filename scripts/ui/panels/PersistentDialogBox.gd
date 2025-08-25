class_name PersistentDialogBox
extends ScalableUIPanel

@export var box_size: Vector2i = Vector2i(800, 240)
@export var margin_from_edge: Vector2i = Vector2i(16, 16)
@export var panel_style: UITileMapLayer.PanelStyle = UITileMapLayer.PanelStyle.DARK_WOOD

@onready var ui_tilemap: UITileMapLayer
@onready var content_area: Control
@onready var input_section: Control
@onready var notification_section: Control
@onready var dialogue_section: Control
@onready var chat_container: VBoxContainer
@onready var scroll_container: ScrollContainer

var is_initialized: bool = false
var max_chat_messages: int = 50

signal input_submitted(text: String)
signal notification_displayed(message: String)
signal dialogue_shown(text: String, speaker: String)

func _ready():
	# Call parent _ready first for scaling setup
	super()
	
	# Set up the control properties
	_setup_positioning()
	_create_ui_elements()
	_setup_content_sections()
	
	# Always visible and process input
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect to ChatManager
	_connect_chat_signals()
	
	# Load existing chat history
	_load_existing_chat_history()
	
	is_initialized = true
	
	# Make sure the chat section is visible (after initialization)
	show_notification_section()

func _setup_positioning():
	"""Set up the positioning for bottom-left corner"""
	# Anchor to bottom-left
	anchors_preset = Control.PRESET_BOTTOM_LEFT
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	
	# Set size explicitly
	custom_minimum_size = Vector2(box_size.x, box_size.y)
	size = Vector2(box_size.x, box_size.y)
	
	# Position to extend higher than control panel for better alignment
	offset_left = margin_from_edge.x
	offset_top = -box_size.y - margin_from_edge.y
	offset_right = box_size.x + margin_from_edge.x
	offset_bottom = -margin_from_edge.y
	
	# Set growth direction
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	

func _create_ui_elements():
	"""Create the UI tilemap layer for styling"""
	# Create a fallback background first
	var background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.2, 0.15, 0.1, 0.9)  # Dark brown with transparency
	background.anchors_preset = Control.PRESET_FULL_RECT
	add_child(background)
	
	# Add a border for better visibility
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color(0.6, 0.4, 0.2, 1.0)  # Lighter brown border
	border.anchors_preset = Control.PRESET_FULL_RECT
	border.offset_left = 2
	border.offset_top = 2
	border.offset_right = -2
	border.offset_bottom = -2
	add_child(border)
	
	# Inner background
	var inner_bg = ColorRect.new()
	inner_bg.name = "InnerBackground"
	inner_bg.color = Color(0.15, 0.1, 0.05, 0.95)  # Darker inner background
	inner_bg.anchors_preset = Control.PRESET_FULL_RECT
	inner_bg.offset_left = 2
	inner_bg.offset_top = 2
	inner_bg.offset_right = -2
	inner_bg.offset_bottom = -2
	add_child(inner_bg)
	
	# Create the tilemap layer for background styling
	ui_tilemap = UITileMapLayer.new()
	ui_tilemap.name = "UITileMap"
	ui_tilemap.panel_style = panel_style
	ui_tilemap.position = Vector2.ZERO
	add_child(ui_tilemap)
	
	# Draw the panel background using the tilemap
	# Calculate tilemap size based on box size and tile size (16x16)
	var tile_size = Vector2i(16, 16)  # Standard UI tile size
	var tilemap_size = Vector2i(
		(box_size.x + tile_size.x - 1) / tile_size.x,  # Ceiling division
		(box_size.y + tile_size.y - 1) / tile_size.y
	)
	
	ui_tilemap.draw_panel(Vector2i.ZERO, tilemap_size, panel_style)
	
	# If tilemap fails to load, hide it and use the fallback background
	if not ui_tilemap.visible:
		background.visible = true
	else:
		background.visible = false
	
	# Create main content area
	content_area = Control.new()
	content_area.name = "ContentArea"
	content_area.anchors_preset = Control.PRESET_FULL_RECT
	content_area.offset_left = 8
	content_area.offset_top = 8
	content_area.offset_right = -8
	content_area.offset_bottom = -8
	# Force the content area size
	content_area.size = Vector2(784, 224)  # 800-16 by 240-16
	content_area.custom_minimum_size = Vector2(784, 224)
	add_child(content_area)
	

func _setup_content_sections():
	"""Set up the three main content sections"""
	# Input section (top area)
	input_section = Control.new()
	input_section.name = "InputSection"
	input_section.anchors_preset = Control.PRESET_TOP_WIDE
	input_section.offset_bottom = 60
	input_section.visible = false  # Hidden by default
	content_area.add_child(input_section)
	
	# Add placeholder label for input section
	var input_label = Label.new()
	input_label.text = "Input Section (Future)"
	input_label.add_theme_font_size_override("font_size", 10)
	input_label.add_theme_color_override("font_color", Color.WHITE)
	input_label.anchors_preset = Control.PRESET_CENTER
	input_section.add_child(input_label)
	
	# Chat section (middle area) - replaces notification section
	notification_section = Control.new()
	notification_section.name = "ChatSection"
	# Use anchor-based layout that scales with parent
	notification_section.anchor_left = 0.0
	notification_section.anchor_right = 1.0
	notification_section.anchor_top = 0.0
	notification_section.anchor_bottom = 1.0
	notification_section.offset_top = 15
	notification_section.offset_bottom = -58  # Account for 48px input panel + 10px margin
	# Remove hardcoded sizes - let it scale with anchors
	notification_section.visible = true  # Visible by default
	content_area.add_child(notification_section)
	
	# Create ScrollContainer for proper scrolling
	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	# Set anchors manually instead of using PRESET_FULL_RECT to avoid sizing conflicts
	scroll_container.anchor_left = 0.0
	scroll_container.anchor_top = 0.0
	scroll_container.anchor_right = 1.0
	scroll_container.anchor_bottom = 1.0
	# Use margins instead of offsets for proper sizing
	scroll_container.offset_left = 24
	scroll_container.offset_top = 8
	scroll_container.offset_right = -24  # Match input alignment
	scroll_container.offset_bottom = -8
	# Set minimum size for NotificationSection accounting for input panel
	# Width: 784 - 24 (left) - 24 (right) = 736px, Height: 151px - 8px margins = 143px
	scroll_container.custom_minimum_size = Vector2(736, 143)
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.follow_focus = true
	
	# DEBUG: Add visible background to ScrollContainer
	var scroll_bg = ColorRect.new()
	scroll_bg.name = "DEBUG_ScrollBG"
	scroll_bg.color = Color.BLUE.lerp(Color.TRANSPARENT, 0.7)  # Semi-transparent blue
	scroll_bg.anchors_preset = Control.PRESET_FULL_RECT
	scroll_container.add_child(scroll_bg)
	
	notification_section.add_child(scroll_container)
	
	# Create VBoxContainer inside ScrollContainer
	chat_container = VBoxContainer.new()
	chat_container.name = "ChatContainer"
	chat_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_container.size_flags_vertical = Control.SIZE_SHRINK_END
	chat_container.alignment = BoxContainer.ALIGNMENT_END  # Align to bottom for chat
	chat_container.add_theme_constant_override("separation", 2)  # Small gap between messages
	
	# DEBUG: Add visible background to VBoxContainer
	var chat_bg = ColorRect.new()
	chat_bg.name = "DEBUG_ChatBG"
	chat_bg.color = Color.RED.lerp(Color.TRANSPARENT, 0.7)  # Semi-transparent red
	chat_bg.anchors_preset = Control.PRESET_FULL_RECT
	chat_container.add_child(chat_bg)
	
	scroll_container.add_child(chat_container)
	
	# Force layout calculation after adding to parent
	call_deferred("_force_container_layout_update")
	call_deferred("_debug_containers", "After initial setup")
	
	# Dialogue section (bottom area)
	dialogue_section = Control.new()
	dialogue_section.name = "DialogueSection"
	dialogue_section.anchors_preset = Control.PRESET_BOTTOM_WIDE
	dialogue_section.offset_top = -60
	dialogue_section.visible = false  # Hidden by default
	content_area.add_child(dialogue_section)
	
	# Add placeholder label for dialogue
	var dialogue_label = Label.new()
	dialogue_label.text = "NPC Dialogue (Future)"
	dialogue_label.add_theme_font_size_override("font_size", 10)
	dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	dialogue_label.anchors_preset = Control.PRESET_CENTER
	dialogue_section.add_child(dialogue_label)
	

# Future functionality methods

func show_input_section():
	"""Show the input section and hide others"""
	if not is_initialized:
		return
	
	input_section.visible = true
	notification_section.visible = false
	dialogue_section.visible = false

func show_notification_section():
	"""Show the notification section and hide others"""
	if not is_initialized:
		return
	
	input_section.visible = false
	notification_section.visible = true
	dialogue_section.visible = false

func show_dialogue_section():
	"""Show the dialogue section and hide others"""
	if not is_initialized:
		return
	
	input_section.visible = false
	notification_section.visible = false
	dialogue_section.visible = true

func display_notification(message: String, duration: float = 3.0):
	"""Display a skill notification (future implementation)"""
	show_notification_section()
	notification_displayed.emit(message)
	
	# TODO: Implement notification queue and auto-hide

func display_dialogue(text: String, speaker: String = ""):
	"""Display NPC dialogue (future implementation)"""
	show_dialogue_section()
	dialogue_shown.emit(text, speaker)
	
	# TODO: Implement full dialogue system integration

func show_input_prompt(prompt: String = "Enter command:"):
	"""Show input prompt (future implementation)"""
	show_input_section()
	
	# TODO: Implement input field and processing

func _on_scale_applied(ui_scale: float):
	"""Recalculate layout after UI scaling is applied"""
	# For bottom-left anchored panels, ensure pivot is at bottom-left
	# so scaling occurs upward and rightward from the anchor point
	pivot_offset = Vector2(0, size.y)
	
	# The scaling has already been applied to the panel, but we need to ensure
	# the internal layout still works correctly with the scaled sizes
	# Force a layout update to recalculate positions and sizes
	if is_initialized:
		call_deferred("_force_layout_recalculation")

func _force_layout_recalculation():
	"""Force recalculation of internal layout after scaling"""
	# Force layout updates using the correct Godot 4.4 methods
	if content_area:
		content_area.set_anchors_and_offsets_preset(content_area.anchors_preset)
		content_area.notification(NOTIFICATION_RESIZED)
	
	# Update scroll container and chat container layout
	if scroll_container:
		scroll_container.notification(NOTIFICATION_RESIZED)
	if chat_container:
		chat_container.notification(NOTIFICATION_RESIZED)

func _force_container_layout_update():
	"""Force the scroll and chat containers to recalculate their layout"""
	if scroll_container and chat_container and notification_section:
		# Force layout recalculation using proper Godot 4.4 methods
		scroll_container.notification(NOTIFICATION_RESIZED)
		chat_container.notification(NOTIFICATION_RESIZED)
		notification_section.notification(NOTIFICATION_RESIZED)
		content_area.notification(NOTIFICATION_RESIZED)

func resize_dialog_box(new_size: Vector2i):
	"""Resize the dialog box"""
	box_size = new_size
	_setup_positioning()
	
	if ui_tilemap and is_initialized:
		# Recalculate and redraw the panel
		var tile_size = Vector2i(16, 16)
		var tilemap_size = Vector2i(
			(box_size.x + tile_size.x - 1) / tile_size.x,
			(box_size.y + tile_size.y - 1) / tile_size.y
		)
		ui_tilemap.draw_panel(Vector2i.ZERO, tilemap_size, panel_style)
	

func set_margin_from_edge(new_margin: Vector2i):
	"""Set the margin from the screen edge"""
	margin_from_edge = new_margin
	_setup_positioning()

func _input(event: InputEvent):
	"""Handle input for chat scrolling and section switching"""
	if not visible:
		return
	
	# Mouse wheel scrolling on chat area - ScrollContainer handles this automatically
	# We only need to check if we're in the right area and let the ScrollContainer handle the scrolling
	if event is InputEventMouseButton and notification_section.visible:
		var mouse_pos = get_global_mouse_position()
		var chat_rect = Rect2(notification_section.global_position, notification_section.size)
		
		if chat_rect.has_point(mouse_pos):
			# Let the ScrollContainer handle mouse wheel events naturally
			pass
	
	# Keyboard scrolling
	if event.is_action_pressed("ui_page_up"):
		scroll_chat(-3)  # Scroll up faster
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_down"):
		scroll_chat(3)   # Scroll down faster
		get_viewport().set_input_as_handled()
	
	# Section switching (keeping existing functionality)
	elif event.is_action_pressed("ui_up") and not event.shift_pressed:
		show_input_section()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") and not event.shift_pressed:
		show_dialogue_section()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		show_notification_section()
		get_viewport().set_input_as_handled()

# Chat-related methods
func _connect_chat_signals():
	"""Connect to ChatManager signals"""
	if ChatManager:
		ChatManager.message_received.connect(_on_chat_message_received)

func _on_chat_message_received(message: ChatMessage):
	"""Handle incoming chat messages"""
	if not is_initialized or not chat_container:
		return
	
	_add_chat_message(message.get_formatted_message())

func _add_chat_message(text: String):
	"""Add a message to the chat display and auto-scroll to bottom"""
	print("DEBUG: Adding chat message: ", text)
	_add_chat_message_no_scroll(text)
	# Auto-scroll to bottom to show newest message
	call_deferred("_scroll_to_bottom")
	call_deferred("_debug_containers", "After adding message")

func _add_chat_message_no_scroll(text: String):
	"""Add a message to the chat display without scrolling"""
	if not chat_container:
		print("DEBUG: chat_container is NULL!")
		return
	
	print("DEBUG: chat_container exists, adding message")
	
	
	# Create message label
	var message_label = Label.new()
	message_label.text = text
	message_label.add_theme_font_size_override("font_size", 25)
	message_label.add_theme_color_override("font_color", Color.BLACK)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Enable smart word wrapping
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Add some padding/margin (no left margin to match input alignment)
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 0)  # Match input alignment
	margin_container.add_theme_constant_override("margin_right", 4)
	margin_container.add_theme_constant_override("margin_top", 2)
	margin_container.add_theme_constant_override("margin_bottom", 2)
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.add_child(message_label)
	
	# Add to chat container at the end (bottom) to ensure new messages appear at bottom
	chat_container.add_child(margin_container)
	chat_container.move_child(margin_container, -1)  # Move to the end to ensure bottom position
	
	print("DEBUG: Message added. Chat container now has ", chat_container.get_child_count(), " children")
	
	
	# Remove old messages if we exceed the limit
	_cleanup_old_messages()

func _cleanup_old_messages():
	"""Remove old messages if we exceed the maximum"""
	if chat_container.get_child_count() > max_chat_messages:
		var excess_count = chat_container.get_child_count() - max_chat_messages
		for i in range(excess_count):
			# Remove from the top (index 0) which contains the oldest messages
			# since new messages are added at the bottom
			var child = chat_container.get_child(0)
			chat_container.remove_child(child)
			child.queue_free()


func add_system_message(text: String):
	"""Add a system message (not from ChatManager)"""
	_add_chat_message(text)

func scroll_chat(direction: int):
	"""Scroll chat messages up (negative) or down (positive)"""
	if not scroll_container:
		return
	
	# Use ScrollContainer's native scrolling
	var scroll_step = 30  # Pixels to scroll per step
	var current_scroll = scroll_container.scroll_vertical
	scroll_container.scroll_vertical = current_scroll + (direction * scroll_step)

func _load_existing_chat_history():
	"""Load any existing chat messages from ChatManager"""
	if ChatManager and chat_container:
		var recent_messages = ChatManager.get_recent_messages(20)  # Load last 20 messages
		for message in recent_messages:
			# Add messages without scrolling for each one (optimization)
			_add_chat_message_no_scroll(message.get_formatted_message())
		
		# Scroll to bottom to show newest messages
		call_deferred("_scroll_to_bottom")

func _scroll_to_bottom():
	"""Scroll the chat to the bottom"""
	if scroll_container:
		# Force layout update first
		scroll_container.notification(NOTIFICATION_RESIZED)
		await get_tree().process_frame
		# Then scroll to bottom
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
		_debug_containers("After scroll to bottom")

# DEBUG FUNCTIONS
func _debug_containers(context: String = ""):
	"""Debug function to print container information"""
	print("=== DEBUG CONTAINERS ", context, " ===")
	
	if notification_section:
		print("NotificationSection: pos=", notification_section.position, " size=", notification_section.size, " visible=", notification_section.visible)
	else:
		print("NotificationSection: NULL")
	
	if scroll_container:
		print("ScrollContainer: pos=", scroll_container.position, " size=", scroll_container.size, " visible=", scroll_container.visible)
		print("ScrollContainer: scroll_vertical=", scroll_container.scroll_vertical, " max_scroll=", scroll_container.get_v_scroll_bar().max_value)
		print("ScrollContainer: content_size=", scroll_container.get_v_scroll_bar().page)
	else:
		print("ScrollContainer: NULL")
	
	if chat_container:
		print("ChatContainer: pos=", chat_container.position, " size=", chat_container.size, " visible=", chat_container.visible)
		print("ChatContainer: children=", chat_container.get_child_count(), " custom_min_size=", chat_container.custom_minimum_size)
		for i in range(chat_container.get_child_count()):
			var child = chat_container.get_child(i)
			if child.name.begins_with("DEBUG_"):
				continue
			print("  Child ", i, ": ", child.name, " size=", child.size, " visible=", child.visible)
	else:
		print("ChatContainer: NULL")
	
	print("=== END DEBUG ===\n")

class_name ChatInputPanel
extends ScalableUIPanel

@export var panel_height: int = 48
@export var margin_from_edge: Vector2i = Vector2i(16, 16)
@export var panel_style: UITileMapLayer.PanelStyle = UITileMapLayer.PanelStyle.DARK_WOOD

@onready var ui_tilemap: UITileMapLayer
@onready var text_input: LineEdit
@onready var placeholder_label: Label

var is_chat_active: bool = false
var placeholder_text: String = "Press Enter to chat"

signal message_submitted(message: String)
signal chat_activated()
signal chat_deactivated()

func _ready():
	# Call parent _ready first for scaling setup
	super()
	
	_setup_positioning()
	_create_ui_elements()
	_setup_input_field()
	_connect_signals()
	
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	

func _setup_positioning():
	# Debug logging for chat input positioning
	print("=== CHAT INPUT DEBUG ===")
	print("Chat input panel size: ", size)
	print("Screen size: ", get_viewport().size)
	print("Margin from edge: ", margin_from_edge)
	print("Panel height: ", panel_height)
	print("========================")
	
	# Match the persistent dialogue box positioning (bottom-left anchored, fixed width)
	anchors_preset = Control.PRESET_BOTTOM_LEFT
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	
	# Set explicit size to match persistent dialogue box (800 width)
	custom_minimum_size = Vector2(800, panel_height)
	size = Vector2(800, panel_height)
	
	offset_left = margin_from_edge.x
	offset_top = -panel_height - margin_from_edge.y
	offset_right = 800 + margin_from_edge.x
	offset_bottom = -margin_from_edge.y
	
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	# Debug logging after positioning
	call_deferred("_debug_final_positioning")

func _create_ui_elements():
	# No background styling - just transparent
	pass

func _setup_input_field():
	var input_container = Control.new()
	input_container.name = "InputContainer"
	# Explicitly set anchors instead of using preset
	input_container.anchor_left = 0.0
	input_container.anchor_top = 0.0
	input_container.anchor_right = 1.0
	input_container.anchor_bottom = 1.0
	input_container.offset_left = 24
	input_container.offset_top = 8
	input_container.offset_right = -24  # Fix: should be negative for right margin
	input_container.offset_bottom = -24
	add_child(input_container)
	
	text_input = LineEdit.new()
	text_input.name = "TextInput"
	# Explicitly set anchors instead of using preset
	text_input.anchor_left = 0.0
	text_input.anchor_top = 0.0
	text_input.anchor_right = 1.0
	text_input.anchor_bottom = 1.0
	text_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_input.placeholder_text = ""
	text_input.add_theme_font_size_override("font_size", 25)
	text_input.add_theme_color_override("font_color", Color.BLACK)
	text_input.add_theme_color_override("font_placeholder_color", Color.BLACK)
	# Remove all background styling
	text_input.add_theme_color_override("font_color_normal", Color.BLACK)
	text_input.add_theme_color_override("background_color", Color.TRANSPARENT)
	text_input.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	text_input.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	text_input.add_theme_stylebox_override("read_only", StyleBoxEmpty.new())
	text_input.editable = true
	text_input.context_menu_enabled = true
	text_input.virtual_keyboard_enabled = true
	text_input.clear_button_enabled = false
	text_input.visible = false
	input_container.add_child(text_input)
	
	placeholder_label = Label.new()
	placeholder_label.name = "PlaceholderLabel"
	placeholder_label.text = placeholder_text
	# Explicitly set anchors instead of using preset
	placeholder_label.anchor_left = 0.0
	placeholder_label.anchor_top = 0.0
	placeholder_label.anchor_right = 1.0
	placeholder_label.anchor_bottom = 1.0
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder_label.add_theme_font_size_override("font_size", 25)
	placeholder_label.add_theme_color_override("font_color", Color.BLACK)
	placeholder_label.offset_left = 4
	input_container.add_child(placeholder_label)

func _connect_signals():
	if ChatManager:
		ChatManager.chat_opened.connect(_on_chat_opened)
		ChatManager.chat_closed.connect(_on_chat_closed)
	
	if text_input:
		text_input.text_submitted.connect(_on_text_submitted)

func _input(event: InputEvent):
	if event.is_action_pressed("open_chat") and not is_chat_active:
		activate_chat()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and is_chat_active:
		deactivate_chat()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and is_chat_active:
		# Handle Enter key specifically for sending chat
		if text_input and text_input.has_focus():
			_on_text_submitted(text_input.text)
			get_viewport().set_input_as_handled()

func activate_chat():
	if is_chat_active:
		return
	
	is_chat_active = true
	placeholder_label.visible = false
	text_input.visible = true
	text_input.grab_focus()
	text_input.text = ""
	
	
	if ChatManager:
		ChatManager.open_chat()
	
	chat_activated.emit()

func deactivate_chat():
	if not is_chat_active:
		return
	
	is_chat_active = false
	placeholder_label.visible = true
	text_input.visible = false
	text_input.release_focus()
	text_input.text = ""
	
	if ChatManager:
		ChatManager.close_chat()
	
	chat_deactivated.emit()

func _on_text_submitted(text: String):
	
	if text.strip_edges().is_empty():
		deactivate_chat()
		return
	
	var clean_message = text.strip_edges()
	message_submitted.emit(clean_message)
	
	if ChatManager:
		ChatManager.send_message(clean_message)
	
	deactivate_chat()

func _on_chat_opened():
	pass

func _on_chat_closed():
	pass

func set_placeholder_text(text: String):
	placeholder_text = text
	if placeholder_label:
		placeholder_label.text = text

func is_active() -> bool:
	return is_chat_active

func _debug_final_positioning():
	"""Debug function to check final positioning and child dimensions"""
	print("=== CHAT INPUT FINAL POSITION ===")
	print("ChatInputPanel size: ", size)
	print("ChatInputPanel position: ", position)
	print("ChatInputPanel global position: ", global_position)
	print("ChatInputPanel rect: ", get_rect())
	print("")
	
	# Debug InputContainer
	var input_container = get_node_or_null("InputContainer")
	if input_container:
		print("--- InputContainer ---")
		print("InputContainer size: ", input_container.size)
		print("InputContainer position: ", input_container.position)
		print("InputContainer rect: ", input_container.get_rect())
		print("InputContainer offsets - L:", input_container.offset_left, " T:", input_container.offset_top, " R:", input_container.offset_right, " B:", input_container.offset_bottom)
		print("InputContainer anchors - L:", input_container.anchor_left, " T:", input_container.anchor_top, " R:", input_container.anchor_right, " B:", input_container.anchor_bottom)
		print("")
		
		# Debug TextInput
		var text_input_node = input_container.get_node_or_null("TextInput")
		if text_input_node:
			print("--- TextInput ---")
			print("TextInput size: ", text_input_node.size)
			print("TextInput position: ", text_input_node.position)
			print("TextInput rect: ", text_input_node.get_rect())
			print("TextInput anchors - L:", text_input_node.anchor_left, " T:", text_input_node.anchor_top, " R:", text_input_node.anchor_right, " B:", text_input_node.anchor_bottom)
			print("")
		
		# Debug PlaceholderLabel
		var placeholder_node = input_container.get_node_or_null("PlaceholderLabel")
		if placeholder_node:
			print("--- PlaceholderLabel ---")
			print("PlaceholderLabel size: ", placeholder_node.size)
			print("PlaceholderLabel position: ", placeholder_node.position)
			print("PlaceholderLabel rect: ", placeholder_node.get_rect())
			print("PlaceholderLabel anchors - L:", placeholder_node.anchor_left, " T:", placeholder_node.anchor_top, " R:", placeholder_node.anchor_right, " B:", placeholder_node.anchor_bottom)
			print("")
	
	print("================================")

func _on_scale_applied(ui_scale: float):
	"""Override scaling behavior to prevent chat input from disappearing"""
	# For bottom-anchored panels, we need to adjust the pivot to prevent
	# the panel from scaling downward off-screen
	# Set pivot to bottom-left (0, size.y) so it scales upward from the bottom edge
	pivot_offset = Vector2(0, size.y)

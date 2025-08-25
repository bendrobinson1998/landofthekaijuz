class_name TiledButton
extends Control

@export var button_size: Vector2i = Vector2i(48, 48)
@export var button_text: String = ""
@export var button_enabled: bool = true

var button_state: UITileMapLayer.ButtonState = UITileMapLayer.ButtonState.NORMAL
var ui_tilemap_layer: UITileMapLayer
var text_label: Label
var is_hovered: bool = false
var is_pressed: bool = false

signal button_pressed()
signal button_hovered()
signal button_unhovered()

func _init():
	# Initialize basic properties
	set_process_mode(Node.PROCESS_MODE_INHERIT)

func _ready():
	# Set the control size
	size = button_size
	
	# Create a simple colored background for now
	var background = ColorRect.new()
	background.color = Color(1.0, 0.0, 1.0, 1.0)  # Bright magenta so we can see it
	background.size = size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	
	# Create text label if needed
	if button_text != "":
		_create_text_label()
	
	# Setup input handling - STOP to capture mouse clicks
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	print("TiledButton: Created with size ", size, " at position ", position)
	print("TiledButton: mouse_filter = ", mouse_filter)
	print("TiledButton: Global position = ", global_position)

func _create_text_label():
	"""Create the text label for the button"""
	text_label = Label.new()
	text_label.text = button_text
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.size = size
	text_label.add_theme_font_size_override("font_size", 10)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let mouse events pass through
	add_child(text_label)

func _update_button_visual():
	"""Update the button's visual state"""
	# Simple color changes for now
	var background = get_child(0) as ColorRect
	if background:
		match button_state:
			UITileMapLayer.ButtonState.NORMAL:
				background.color = Color(0.5, 0.5, 0.5, 1.0)  # Gray
			UITileMapLayer.ButtonState.HOVERED:
				background.color = Color(0.7, 0.7, 0.7, 1.0)  # Light gray
			UITileMapLayer.ButtonState.PRESSED:
				background.color = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray
			UITileMapLayer.ButtonState.DISABLED:
				background.color = Color(0.2, 0.2, 0.2, 0.5)  # Very dark gray

func _gui_input(event: InputEvent):
	"""Handle input events for the button"""
	if not button_enabled:
		return
	
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				print("TiledButton: Mouse pressed")
				_on_button_pressed()
			else:
				print("TiledButton: Mouse released")
				_on_button_released()
	
	elif event is InputEventMouseMotion:
		# This will be handled by mouse_entered/exited signals
		pass

func _on_mouse_entered():
	"""Handle mouse entering the button area"""
	print("TiledButton: Mouse entered!")
	if not button_enabled:
		return
	
	is_hovered = true
	button_state = UITileMapLayer.ButtonState.HOVERED
	_update_button_visual()
	button_hovered.emit()

func _on_mouse_exited():
	"""Handle mouse exiting the button area"""
	print("TiledButton: Mouse exited!")
	if not button_enabled:
		return
	
	is_hovered = false
	is_pressed = false
	button_state = UITileMapLayer.ButtonState.NORMAL
	_update_button_visual()
	button_unhovered.emit()

func _on_button_pressed():
	"""Handle button press"""
	if not button_enabled:
		return
	
	is_pressed = true
	button_state = UITileMapLayer.ButtonState.PRESSED
	_update_button_visual()

func _on_button_released():
	"""Handle button release"""
	if not button_enabled:
		return
	
	is_pressed = false
	
	if is_hovered:
		button_state = UITileMapLayer.ButtonState.HOVERED
	else:
		button_state = UITileMapLayer.ButtonState.NORMAL
	
	_update_button_visual()
	
	# Emit pressed signal if mouse is still over button
	if is_hovered:
		button_pressed.emit()

func set_button_text(text: String):
	"""Set the button text"""
	button_text = text
	if text_label:
		text_label.text = text
	elif text != "":
		_create_text_label()


func set_button_enabled(enabled: bool):
	"""Enable/disable the button"""
	button_enabled = enabled
	
	if button_enabled:
		button_state = UITileMapLayer.ButtonState.NORMAL
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		button_state = UITileMapLayer.ButtonState.DISABLED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		is_hovered = false
		is_pressed = false
	
	_update_button_visual()

func set_button_size(new_size: Vector2i):
	"""Change the button size"""
	button_size = new_size
	size = new_size
	
	if text_label:
		text_label.size = size
	
	_update_button_visual()

func get_is_enabled() -> bool:
	"""Check if button is enabled"""
	return button_enabled

func get_is_hovered() -> bool:
	"""Check if button is hovered"""
	return is_hovered

func get_is_pressed() -> bool:
	"""Check if button is pressed"""
	return is_pressed

# Connect mouse signals when ready
func _notification(what: int):
	if what == NOTIFICATION_READY:
		if not mouse_entered.is_connected(_on_mouse_entered):
			mouse_entered.connect(_on_mouse_entered)
		if not mouse_exited.is_connected(_on_mouse_exited):
			mouse_exited.connect(_on_mouse_exited)

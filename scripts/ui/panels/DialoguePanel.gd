class_name DialoguePanel
extends ScalableUIPanel

@export var default_size: Vector2i = Vector2i(800, 240)  # Much larger for testing
@export var text_margin: Vector2i = Vector2i(16, 16)
@export var typing_speed: float = 0.05  # Time between characters when typing text

@onready var speaker_label: Label
@onready var dialogue_label: Label
@onready var continue_button: Button

var current_text: String = ""
var current_speaker: String = ""
var is_typing: bool = false
var typing_tween: Tween

signal dialogue_finished()
signal dialogue_continue_requested()

func _ready():
	# Call parent _ready first for scaling setup
	super()
	
	# Create visual elements - Godot anchors handle positioning
	_create_ui_elements()
	
	# Start visible for testing
	visible = true

func _create_ui_elements():
	"""Create the labels and button for the dialogue"""
	# Use this control as the content area directly
	
	# Speaker label (optional, shows character name)
	speaker_label = Label.new()
	speaker_label.name = "SpeakerLabel"
	speaker_label.add_theme_font_size_override("font_size", 14)
	speaker_label.add_theme_color_override("font_color", Color.WHITE)
	speaker_label.position = Vector2(text_margin.x, text_margin.y)
	speaker_label.visible = false
	add_child(speaker_label)
	
	# Main dialogue text
	dialogue_label = Label.new()
	dialogue_label.name = "DialogueLabel"
	dialogue_label.add_theme_font_size_override("font_size", 12)
	dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dialogue_label.position = Vector2(text_margin.x, text_margin.y + 20)
	dialogue_label.size = Vector2(default_size.x - text_margin.x * 2, default_size.y - text_margin.y * 2 - 40)
	add_child(dialogue_label)
	
	# Continue button
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "Continue"
	continue_button.size = Vector2(80, 24)
	continue_button.position = Vector2(default_size.x - 80 - text_margin.x, default_size.y - 24 - text_margin.y)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = false
	add_child(continue_button)

func show_dialogue(text: String, speaker_name: String = ""):
	"""Show dialogue with optional speaker name"""
	current_text = text
	current_speaker = speaker_name
	
	# Setup speaker label
	if speaker_name != "":
		speaker_label.text = speaker_name + ":"
		speaker_label.visible = true
		dialogue_label.position.y = text_margin.y + 20
		dialogue_label.size.y = default_size.y - text_margin.y * 2 - 44
	else:
		speaker_label.visible = false
		dialogue_label.position.y = text_margin.y
		dialogue_label.size.y = default_size.y - text_margin.y * 2 - 24
	
	# Show the dialogue panel
	visible = true
	
	# Start typing animation
	_start_typing_animation()

func hide_dialogue():
	"""Hide the dialogue panel"""
	visible = false
	is_typing = false
	continue_button.visible = false
	
	if typing_tween:
		typing_tween.kill()
	
	dialogue_finished.emit()

func _start_typing_animation():
	"""Start the typing animation for the dialogue text"""
	if typing_tween:
		typing_tween.kill()
	
	is_typing = true
	dialogue_label.text = ""
	continue_button.visible = false
	
	typing_tween = create_tween()
	
	# Type out each character with proper Godot 4.4 syntax
	for i in range(current_text.length()):
		typing_tween.tween_callback(_type_character.bind(i))
		typing_tween.tween_interval(typing_speed)
	
	# When finished typing
	typing_tween.tween_callback(_on_typing_finished)

func _type_character(index: int):
	"""Add a character to the dialogue label"""
	if index < current_text.length():
		dialogue_label.text = current_text.substr(0, index + 1)

func _on_typing_finished():
	"""Called when typing animation is complete"""
	is_typing = false
	continue_button.visible = true

func _on_continue_pressed():
	"""Handle continue button press"""
	if is_typing:
		# Skip typing animation
		if typing_tween:
			typing_tween.kill()
		dialogue_label.text = current_text
		_on_typing_finished()
	else:
		# Continue to next dialogue or close
		dialogue_continue_requested.emit()
		hide_dialogue()

func _input(event: InputEvent):
	"""Handle input events for dialogue interaction"""
	if not visible:
		return
	
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()

func resize_dialogue_panel(new_size: Vector2i):
	"""Resize the dialogue panel"""
	default_size = new_size
	size = Vector2(new_size)
	position = Vector2(16, -new_size.y - 16.0)  # Update position for new size
	
	# Update label sizes
	if dialogue_label:
		dialogue_label.size = Vector2(new_size.x - text_margin.x * 2, new_size.y - text_margin.y * 2 - 40)
	
	if continue_button:
		continue_button.position = Vector2(new_size.x - 80 - text_margin.x, new_size.y - 24 - text_margin.y)

func set_typing_speed(speed: float):
	"""Set the typing animation speed"""
	typing_speed = max(0.01, speed)  # Minimum speed limit

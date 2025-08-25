class_name ChatBubble
extends Control

@export var message_lifetime: float = 5.0
@export var fade_duration: float = 1.0
@export var bounce_height: float = 10.0
@export var bounce_duration: float = 0.5

@onready var message_label: Label

var message: ChatMessage
var is_fading: bool = false

signal bubble_expired(bubble: ChatBubble)

func _ready():
	_setup_bubble()
	_start_display_timer()

func _setup_bubble():
	# Don't use preset - we'll position manually
	custom_minimum_size = Vector2(80, 32)
	
	# Create simple background
	var color_bg = ColorRect.new()
	color_bg.name = "ColorBackground"
	color_bg.color = Color(0.2, 0.2, 0.3, 0.9)
	color_bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(color_bg)
	
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color(0.8, 0.8, 0.9, 1.0)
	border.anchors_preset = Control.PRESET_FULL_RECT
	border.offset_left = 1
	border.offset_top = 1
	border.offset_right = -1
	border.offset_bottom = -1
	add_child(border)
	
	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.anchors_preset = Control.PRESET_FULL_RECT
	message_label.offset_left = 8
	message_label.offset_top = 4
	message_label.offset_right = -8
	message_label.offset_bottom = -4
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	message_label.add_theme_font_size_override("font_size", 12)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	message_label.add_theme_constant_override("shadow_offset_x", 1)
	message_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(message_label)
	
	# Remove AnimationPlayer - we'll use Tween instead

func display_message(chat_message: ChatMessage):
	message = chat_message
	
	if message_label:
		message_label.text = message.message_text
	
	_fit_to_content()
	
	# Don't center horizontally here - let the parent container handle positioning
	# The PlayerController will position bubbles horizontally
	
	# Start with small scale for bounce-in effect
	scale = Vector2.ZERO
	
	# Create bounce-in animation using Tween
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, bounce_duration)

func _fit_to_content():
	if not message_label:
		return
	
	# Get the actual text size from the label
	var text_size = message_label.get_theme_font("font").get_string_size(message_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var padding = Vector2(16, 8)
	var max_width = 400
	var min_width = 80
	
	# Use actual text width instead of estimation
	var width = clamp(text_size.x + padding.x, min_width, max_width)
	var height = 32  # Fixed height for now
	
	custom_minimum_size = Vector2(width, height)
	size = Vector2(width, height)

func _start_display_timer():
	await get_tree().create_timer(message_lifetime).timeout
	
	if not is_fading:
		start_fade_out()

func start_fade_out():
	if is_fading:
		return
	
	is_fading = true
	
	# Use Godot 4.4 Tween instead of AnimationPlayer for simpler fade
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	await tween.finished
	
	bubble_expired.emit(self)
	queue_free()

func set_message_lifetime(lifetime: float):
	message_lifetime = lifetime

func get_message() -> ChatMessage:
	return message
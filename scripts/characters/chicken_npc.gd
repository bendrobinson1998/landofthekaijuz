class_name ChickenNPC
extends Area2D

signal interaction_started()
signal interaction_ended()

@export var interaction_prompt_text: String = "Click to talk"
@export var npc_name: String = "Chicken"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var interaction_prompt: Label = $InteractionPrompt

var player_in_range: bool = false
var dialogue_active: bool = false
var dialogue_ui: Control = null
var is_highlighted: bool = false
var original_modulate: Color
var outline_material: ShaderMaterial

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	if interaction_prompt:
		interaction_prompt.visible = false
	
	_create_outline_shader()
	
	if animated_sprite:
		original_modulate = animated_sprite.modulate
		if animated_sprite.sprite_frames:
			# Start with idle animation if it exists
			if animated_sprite.sprite_frames.has_animation("idle"):
				animated_sprite.play("idle")
			else:
				# Play default animation if available
				var animations = animated_sprite.sprite_frames.get_animation_names()
				if animations.size() > 0:
					animated_sprite.play(animations[0])

func _on_mouse_entered():
	if not dialogue_active:
		_highlight_npc(true)

func _on_mouse_exited():
	_highlight_npc(false)

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not dialogue_active:
			_start_dialogue()

func _create_outline_shader():
	var shader = load("res://outline.gdshader")
	outline_material = ShaderMaterial.new()
	outline_material.shader = shader
	
	# Configure the outline parameters
	outline_material.set_shader_parameter("color", Color.YELLOW)
	outline_material.set_shader_parameter("width", 2.0)
	outline_material.set_shader_parameter("pattern", 0)  # diamond pattern
	outline_material.set_shader_parameter("inside", false)  # outside outline
	outline_material.set_shader_parameter("add_margins", false)

func _highlight_npc(highlight: bool):
	if not animated_sprite:
		return
		
	is_highlighted = highlight
	if highlight:
		animated_sprite.material = outline_material
	else:
		animated_sprite.material = null

func _on_body_entered(body):
	if body is PlayerController:
		player_in_range = true

func _on_body_exited(body):
	if body is PlayerController:
		player_in_range = false
		_highlight_npc(false)
		if dialogue_active:
			_end_dialogue()

func _start_dialogue():
	if dialogue_active:
		return
	
	dialogue_active = true
	interaction_started.emit()
	
	if not dialogue_ui:
		_create_dialogue_ui()
	
	dialogue_ui.visible = true
	_update_dialogue_content()
	
	# Send greeting message to chat system
	if ChatManager:
		ChatManager.send_npc_message("Hello there! What would you like to know?", npc_name)

func _end_dialogue():
	if not dialogue_active:
		return
	
	dialogue_active = false
	interaction_ended.emit()
	
	if dialogue_ui:
		dialogue_ui.visible = false

func _create_dialogue_ui():
	var dialogue_scene = load("res://scenes/ui/ChickenDialogue.tscn")
	if dialogue_scene:
		dialogue_ui = dialogue_scene.instantiate()
		get_tree().current_scene.add_child(dialogue_ui)
		
		if dialogue_ui.has_node("Panel/VBoxContainer/CheckPlaytimeButton"):
			dialogue_ui.get_node("Panel/VBoxContainer/CheckPlaytimeButton").pressed.connect(_on_check_playtime)
		
		if dialogue_ui.has_node("Panel/VBoxContainer/ExitButton"):
			dialogue_ui.get_node("Panel/VBoxContainer/ExitButton").pressed.connect(_end_dialogue)
	else:
		_create_basic_dialogue()

func _create_basic_dialogue():
	dialogue_ui = Control.new()
	dialogue_ui.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 300)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dialogue_ui.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = npc_name
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.text = "What would you like to know?"
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)
	
	var playtime_button = Button.new()
	playtime_button.text = "Check Playtime"
	playtime_button.pressed.connect(_on_check_playtime)
	vbox.add_child(playtime_button)
	
	var exit_button = Button.new()
	exit_button.text = "Exit"
	exit_button.pressed.connect(_end_dialogue)
	vbox.add_child(exit_button)
	
	get_tree().current_scene.add_child(dialogue_ui)

func _update_dialogue_content():
	if not dialogue_ui:
		return
	
	var info_label = dialogue_ui.find_child("InfoLabel", true, false)
	if info_label and info_label is Label:
		info_label.text = "What would you like to know?"

func _on_check_playtime():
	var playtime_text = GameManager.get_formatted_playtime()
	
	var info_label = dialogue_ui.find_child("InfoLabel", true, false)
	if info_label and info_label is Label:
		info_label.text = "You've been playing for:\n" + playtime_text
	
	# Send message to chat system
	if ChatManager:
		ChatManager.send_npc_message("You've been playing for: " + playtime_text, npc_name)

func get_playtime() -> float:
	return GameManager.get_playtime()

# Method called by InputManager when this NPC is clicked
func try_interact() -> bool:
	# Check if player is in range
	if not player_in_range:
		return false  # Player needs to move closer
	
	# Player is in range, start dialogue immediately
	if not dialogue_active:
		_start_dialogue()
	return true
class_name LumberjackJack
extends CharacterBody2D

signal interaction_started()
signal interaction_ended()

@export var npc_name: String = "Lumberjack Jack"
@export var roam_center: Vector2 = Vector2.ZERO
@export var roam_radius: float = 100.0
@export var move_speed: float = 50.0
@export var idle_time_min: float = 3.0
@export var idle_time_max: float = 6.0

@onready var sprite: Sprite2D = $Lumberjack_JackSprite
@onready var animation_player: AnimationPlayer = $Lumberjack_JackSprite/Lumberjack_JackSpriteAnimationPlayer
# Collision shape is handled automatically by CharacterBody2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var roam_timer: Timer = $RoamTimer
@onready var idle_timer: Timer = $IdleTimer

enum State {
	IDLE,
	MOVING,
	TALKING
}

enum Direction {
	DOWN = 0,
	RIGHT = 1,
	UP = 2
}

var current_state: State = State.IDLE
var current_direction: Direction = Direction.DOWN
var target_position: Vector2
var is_idle_period: bool = false
var player_in_range: bool = false
var dialogue_active: bool = false
var dialogue_ui: Control = null
var is_highlighted: bool = false
var original_modulate: Color
var outline_material: ShaderMaterial

# Woodcutting dialogue responses
var dialogue_responses = {
	"overview": "Woodcutting is one of the most peaceful skills in the land! You can cut trees to gather logs for building, crafting, and trading. Different trees give different types of wood and experience.",
	"level_info": "Let me check your woodcutting progress...",
	"level_up_tips": "To improve your woodcutting, you'll need to practice! Start with regular trees - they're easier to cut. As you get stronger, try oak trees for better experience. Don't forget to bring a good axe!",
	"tree_types": "Around here you'll find several types of trees. Regular trees are good for beginners, oak trees give more experience, and if you're skilled enough, you might find some rare birch or spruce trees in the deeper forest areas.",
	"greeting": "Well hello there! I'm Jack, been cutting trees in these parts for more years than I can count. What brings you to talk with an old lumberjack like me?"
}

func _ready():
	# Set initial position as roam center if not set
	if roam_center == Vector2.ZERO:
		roam_center = global_position
	
	# Connect signals with null checks
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
		interaction_area.mouse_entered.connect(_on_interaction_area_mouse_entered)
		interaction_area.mouse_exited.connect(_on_interaction_area_mouse_exited)
		interaction_area.input_event.connect(_on_interaction_area_input_event)
	
	if roam_timer:
		roam_timer.timeout.connect(_on_roam_timer_timeout)
	if idle_timer:
		idle_timer.timeout.connect(_on_idle_timer_timeout)
	
	# Navigation setup
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.target_reached.connect(_on_target_reached)
	
	# Visual setup
	if interaction_prompt:
		interaction_prompt.visible = false
	
	_create_outline_shader()
	
	if sprite:
		original_modulate = sprite.modulate
		sprite.flip_h = false  # Start facing right (not flipped)
	
	# Start with idle animation
	if animation_player:
		animation_player.play("idle_down")
	
	# Start roaming
	_start_new_roam_cycle()

func _physics_process(delta):
	if current_state == State.MOVING and not dialogue_active:
		_handle_movement()
	
	# Update sprite direction based on movement
	if velocity.length() > 0:
		_update_direction_from_velocity()
		_update_sprite_animation()
	else:
		# Update animation for idle state
		_update_sprite_animation()

func _handle_movement():
	if not navigation_agent or navigation_agent.is_navigation_finished():
		return
	
	var current_agent_position = global_position
	var next_path_position = navigation_agent.get_next_path_position()
	
	var new_velocity = current_agent_position.direction_to(next_path_position) * move_speed
	navigation_agent.set_velocity(new_velocity)

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()
	
	# Check for collisions with player and pause movement to prevent sticking
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# If we collided with the player, pause movement
		if collider is PlayerController:
			velocity = Vector2.ZERO
			current_state = State.IDLE
			_start_collision_recovery()
			break

func _on_target_reached():
	velocity = Vector2.ZERO
	current_state = State.IDLE
	_update_sprite_animation()  # Switch to idle animation
	_start_idle_period()

func _update_direction_from_velocity():
	if velocity.x > 0:
		current_direction = Direction.RIGHT
		sprite.flip_h = false
	elif velocity.x < 0:
		current_direction = Direction.RIGHT  # Use right animation but flip sprite
		sprite.flip_h = true
	elif velocity.y < 0:
		current_direction = Direction.UP
	elif velocity.y > 0:
		current_direction = Direction.DOWN

func _update_sprite_animation():
	if not animation_player:
		return
	
	var anim_name = ""
	if current_state == State.MOVING:
		match current_direction:
			Direction.DOWN:
				anim_name = "walk_down"
			Direction.RIGHT:
				anim_name = "walk_right"  # Will be flipped for left movement
			Direction.UP:
				anim_name = "walk_up"
	else:
		match current_direction:
			Direction.DOWN:
				anim_name = "idle_down"
			Direction.RIGHT:
				anim_name = "idle_right"  # Will be flipped for left idle
			Direction.UP:
				anim_name = "idle_up"
	
	if anim_name != "" and animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

func _start_new_roam_cycle():
	if dialogue_active:
		return
	
	if randf() < 0.3:  # 30% chance to just idle
		_start_idle_period()
	else:
		_move_to_random_position()

func _move_to_random_position():
	if not navigation_agent:
		return
		
	# Generate random position within roam radius
	var angle = randf() * TAU
	var distance = randf() * roam_radius
	target_position = roam_center + Vector2.from_angle(angle) * distance
	
	navigation_agent.target_position = target_position
	current_state = State.MOVING

func _start_idle_period():
	current_state = State.IDLE
	is_idle_period = true
	velocity = Vector2.ZERO
	
	# Update to idle animation
	_update_sprite_animation()
	
	var idle_duration = randf_range(idle_time_min, idle_time_max)
	idle_timer.wait_time = idle_duration
	idle_timer.start()

func _start_collision_recovery():
	"""Start a brief recovery period after colliding with player"""
	current_state = State.IDLE
	is_idle_period = true
	velocity = Vector2.ZERO
	
	# Update to idle animation
	_update_sprite_animation()
	
	# Use a shorter recovery time than normal idle
	var recovery_duration = 1.0  # 1 second pause before trying to move again
	idle_timer.wait_time = recovery_duration
	idle_timer.start()

func _on_roam_timer_timeout():
	if not dialogue_active and not is_idle_period:
		_start_new_roam_cycle()

func _on_idle_timer_timeout():
	is_idle_period = false
	_start_new_roam_cycle()

func _create_outline_shader():
	var shader = load("res://outline.gdshader")
	if shader:
		outline_material = ShaderMaterial.new()
		outline_material.shader = shader
		outline_material.set_shader_parameter("color", Color.YELLOW)
		outline_material.set_shader_parameter("width", 2.0)
		outline_material.set_shader_parameter("pattern", 0)
		outline_material.set_shader_parameter("inside", false)
		outline_material.set_shader_parameter("add_margins", false)

func _highlight_npc(highlight: bool):
	if not sprite:
		return
		
	is_highlighted = highlight
	if highlight and outline_material:
		sprite.material = outline_material
	else:
		sprite.material = null

func _on_interaction_area_body_entered(body):
	if body is PlayerController:
		player_in_range = true

func _on_interaction_area_body_exited(body):
	if body is PlayerController:
		player_in_range = false
		_highlight_npc(false)
		if dialogue_active:
			_end_dialogue()

func _on_interaction_area_mouse_entered():
	if not dialogue_active:
		_highlight_npc(true)

func _on_interaction_area_mouse_exited():
	_highlight_npc(false)

func _on_interaction_area_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not dialogue_active:
			_start_dialogue()

func _start_dialogue():
	if dialogue_active:
		return
	
	dialogue_active = true
	current_state = State.TALKING
	velocity = Vector2.ZERO
	
	interaction_started.emit()
	
	# Create dialogue UI if it doesn't exist
	if not dialogue_ui:
		_create_dialogue_ui()
	
	# Show greeting message in chat
	if ChatManager:
		ChatManager.send_npc_message(dialogue_responses["greeting"], npc_name)
	
	# Show dialogue UI
	if dialogue_ui:
		dialogue_ui.visible = true

func _end_dialogue():
	if not dialogue_active:
		return
	
	dialogue_active = false
	current_state = State.IDLE
	
	interaction_ended.emit()
	
	if dialogue_ui:
		dialogue_ui.visible = false
	
	# Resume roaming after a short delay
	roam_timer.wait_time = 2.0
	roam_timer.start()

func _create_dialogue_ui():
	# Load custom dialogue scene if it exists
	var dialogue_scene = load("res://scenes/ui/LumberjackDialogue.tscn")
	if dialogue_scene:
		dialogue_ui = dialogue_scene.instantiate()
		get_tree().current_scene.add_child(dialogue_ui)
		_connect_dialogue_buttons()
	else:
		_create_basic_dialogue()

func _create_basic_dialogue():
	dialogue_ui = Control.new()
	dialogue_ui.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(500, 400)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dialogue_ui.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.add_theme_constant_override("margin_left", 20)
	vbox.add_theme_constant_override("margin_right", 20)
	vbox.add_theme_constant_override("margin_top", 20)
	vbox.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = npc_name
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Dialogue options
	var overview_button = Button.new()
	overview_button.text = "Tell me about woodcutting"
	overview_button.pressed.connect(_on_overview_requested)
	vbox.add_child(overview_button)
	
	var level_button = Button.new()
	level_button.text = "What's my woodcutting level?"
	level_button.pressed.connect(_on_level_info_requested)
	vbox.add_child(level_button)
	
	var tips_button = Button.new()
	tips_button.text = "How do I level up?"
	tips_button.pressed.connect(_on_tips_requested)
	vbox.add_child(tips_button)
	
	var trees_button = Button.new()
	trees_button.text = "What trees can I cut?"
	trees_button.pressed.connect(_on_tree_types_requested)
	vbox.add_child(trees_button)
	
	var exit_button = Button.new()
	exit_button.text = "Goodbye"
	exit_button.pressed.connect(_end_dialogue)
	vbox.add_child(exit_button)
	
	get_tree().current_scene.add_child(dialogue_ui)

func _connect_dialogue_buttons():
	# Connect to buttons in the custom dialogue scene
	if dialogue_ui.has_node("Panel/VBoxContainer/ScrollContainer/VBoxContainer/OverviewButton"):
		dialogue_ui.get_node("Panel/VBoxContainer/ScrollContainer/VBoxContainer/OverviewButton").pressed.connect(_on_overview_requested)
	
	if dialogue_ui.has_node("Panel/VBoxContainer/ScrollContainer/VBoxContainer/LevelButton"):
		dialogue_ui.get_node("Panel/VBoxContainer/ScrollContainer/VBoxContainer/LevelButton").pressed.connect(_on_level_info_requested)
	
	if dialogue_ui.has_node("Panel/VBoxContainer/ScrollContainer/VBoxContainer/TipsButton"):
		dialogue_ui.get_node("Panel/VBoxContainer/ScrollContainer/VBoxContainer/TipsButton").pressed.connect(_on_tips_requested)
	
	if dialogue_ui.has_node("Panel/VBoxContainer/ScrollContainer/VBoxContainer/TreesButton"):
		dialogue_ui.get_node("Panel/VBoxContainer/ScrollContainer/VBoxContainer/TreesButton").pressed.connect(_on_tree_types_requested)
	
	if dialogue_ui.has_node("Panel/VBoxContainer/ScrollContainer/VBoxContainer/ExitButton"):
		dialogue_ui.get_node("Panel/VBoxContainer/ScrollContainer/VBoxContainer/ExitButton").pressed.connect(_end_dialogue)

func _on_overview_requested():
	if ChatManager:
		ChatManager.send_npc_message(dialogue_responses["overview"], npc_name)

func _on_level_info_requested():
	var woodcutting_skill = SkillManager.get_skill(Skill.SkillType.WOODCUTTING)
	var level_message = ""
	
	if woodcutting_skill:
		var level = woodcutting_skill.current_level
		var current_xp = woodcutting_skill.current_xp
		var xp_needed = woodcutting_skill.get_xp_needed_for_next_level()
		var progress = woodcutting_skill.get_progress_percentage()
		
		level_message = "Your woodcutting level is %d! You have %d experience points. " % [level, current_xp]
		if level < 99:
			level_message += "You need %d more XP to reach level %d (%.1f%% progress)." % [xp_needed, level + 1, progress]
		else:
			level_message += "Congratulations, you've mastered woodcutting!"
	else:
		level_message = "Hmm, I can't seem to check your woodcutting level right now. Have you tried cutting any trees yet?"
	
	if ChatManager:
		ChatManager.send_npc_message(level_message, npc_name)

func _on_tips_requested():
	if ChatManager:
		ChatManager.send_npc_message(dialogue_responses["level_up_tips"], npc_name)

func _on_tree_types_requested():
	if ChatManager:
		ChatManager.send_npc_message(dialogue_responses["tree_types"], npc_name)

func get_roam_center() -> Vector2:
	return roam_center

func set_roam_center(new_center: Vector2):
	roam_center = new_center

func get_roam_radius() -> float:
	return roam_radius

func set_roam_radius(new_radius: float):
	roam_radius = max(10.0, new_radius)  # Minimum radius of 10 units

# Method called by InputManager when this NPC is clicked
func try_interact() -> bool:
	# Check if player is in range
	if not player_in_range:
		return false  # Player needs to move closer
	
	# Player is in range, start dialogue immediately
	if not dialogue_active:
		_start_dialogue()
	return true

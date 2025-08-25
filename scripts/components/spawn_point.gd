class_name SpawnPoint
extends Marker2D

@export var spawn_id: String = ""
@export var is_default: bool = false
@export var spawn_radius: float = 0.0
@export var spawn_conditions: Array[String] = []

signal player_spawned(spawn_point: SpawnPoint)

var is_occupied: bool = false

func _ready():
	# Register this spawn point with the GameManager if it exists
	if GameManager:
		GameManager.register_spawn_point(self)

func spawn_player(player_scene: PackedScene = null) -> Node:
	if is_occupied:
		return null
	
	var player
	if player_scene:
		player = player_scene.instantiate()
	else:
		# Use default player scene
		var default_player_scene = preload("res://scenes/characters/player/Player.tscn")
		player = default_player_scene.instantiate()
	
	# Position the player
	var spawn_position = global_position
	if spawn_radius > 0:
		# Randomize position within radius
		var random_offset = Vector2(
			randf_range(-spawn_radius, spawn_radius),
			randf_range(-spawn_radius, spawn_radius)
		)
		spawn_position += random_offset
	
	player.global_position = spawn_position
	
	# Add player to the scene tree
	get_tree().current_scene.add_child(player)
	
	is_occupied = true
	player_spawned.emit(self)
	
	# Connect to player's signals to know when they leave
	if player.has_signal("tree_exiting"):
		player.tree_exiting.connect(_on_player_left)
	
	return player

func _on_player_left():
	is_occupied = false

func can_spawn() -> bool:
	if is_occupied:
		return false
	
	# Check spawn conditions
	for condition in spawn_conditions:
		if not _check_spawn_condition(condition):
			return false
	
	return true

func _check_spawn_condition(condition: String) -> bool:
	# Implement your spawn condition logic here
	# Examples: "day_time", "quest_completed:quest_id", "level_requirement:5"
	match condition:
		"day_time":
			# Check if it's daytime
			return true  # Placeholder
		"night_time":
			# Check if it's nighttime
			return true  # Placeholder
		_:
			if condition.begins_with("quest_completed:"):
				var quest_id = condition.split(":")[1]
				# Check if quest is completed
				return true  # Placeholder
			elif condition.begins_with("level_requirement:"):
				var required_level = condition.split(":")[1].to_int()
				# Check player level
				if GameManager and GameManager.player_data.has("level"):
					return GameManager.player_data.level >= required_level
				return true  # Default to true if no level system
	
	return true

func get_spawn_info() -> Dictionary:
	return {
		"id": spawn_id,
		"position": global_position,
		"is_default": is_default,
		"is_occupied": is_occupied,
		"can_spawn": can_spawn()
	}

func _draw():
	# Debug visualization
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 16, Color.GREEN if can_spawn() else Color.RED, false, 2.0)
		if spawn_radius > 0:
			draw_circle(Vector2.ZERO, spawn_radius, Color.YELLOW, false, 1.0)
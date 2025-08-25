class_name DoorInteractable
extends Interactable

func _ready():
	# Configure this as a scene change interactable
	interaction_type = InteractionType.SCENE_CHANGE
	interaction_prompt_text = "Enter House"
	target_scene_path = "res://scenes/levels/interiors/HouseInterior.tscn"
	interaction_range = 48.0  # Doors need larger interaction range
	highlight_color = Color(1.0, 1.0, 0.0, 1.0)  # Bright yellow
	outline_width = 3.0  # Thicker outline for better visibility
	
	# Call parent ready to setup the system
	super._ready()
class_name ExitInteractable
extends Interactable

func _ready():
	# Configure this as a scene change interactable
	interaction_type = InteractionType.SCENE_CHANGE
	interaction_prompt_text = "Exit House"
	target_scene_path = "res://scenes/levels/world/MainWorld.tscn"
	interaction_range = 48.0  # Exits need larger interaction range
	
	# Call parent ready to setup the system
	super._ready()

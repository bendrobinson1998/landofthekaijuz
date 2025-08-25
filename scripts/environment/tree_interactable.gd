class_name TreeInteractable
extends Interactable

@export var woodcutting_xp_per_log: int = 25
@export var respawn_min_time: float = 36.0  # Minimum respawn time in seconds
@export var respawn_max_time: float = 60.0  # Maximum respawn time in seconds

# Tree state management
enum TreeState {
	ALIVE,    # Full tree, can be chopped
	STUMP,    # Tree chopped, showing stump
	GROWING   # Stump growing back into tree
}

var current_state: TreeState = TreeState.ALIVE
var respawn_timer: Timer
var original_tree_texture: Texture2D
var original_tree_region: Rect2
var original_collision_shape
var tree_info: Dictionary  # Stores tree type info for respawning

func _ready():
	# Configure this as a harvest resource interactable
	interaction_type = InteractionType.HARVEST_RESOURCE
	interaction_prompt_text = "Chop Tree"
	highlight_color = Color(1.0, 1.0, 0.0, 1.0)  # Bright yellow
	outline_width = 3.0  # Thicker outline for better visibility
	
	# Set harvest configuration
	harvest_item = preload("res://scripts/resources/items/log_item.tres")
	min_harvest_amount = 5
	max_harvest_amount = 15
	harvest_interval = 0.5
	requires_continuous_action = true  # Trees need chopping animation
	
	# Store original tree appearance
	_store_original_tree_data()
	
	# Setup respawn timer
	_setup_respawn_timer()
	
	# Call parent _ready() to setup the system
	super._ready()

# Override the single harvest method to grant woodcutting XP
func _perform_single_harvest():
	# Store initial resource count
	var resources_before = total_resources_remaining
	
	# Call parent implementation first
	super._perform_single_harvest()
	
	# Grant woodcutting XP if we actually harvested something
	# Check if resources decreased (meaning we successfully got a log)
	if resources_before > total_resources_remaining:
		SkillManager.add_skill_xp(Skill.SkillType.WOODCUTTING, woodcutting_xp_per_log)

# Override the harvest depleted method to show stump instead of removing tree
func _on_harvest_depleted():
	print("[TreeInteractable] Tree fully harvested! Converting to stump...")
	_stop_harvest()
	
	# Don't call parent implementation to prevent queue_free()
	# Instead handle our own logic for conversion to stump
	
	# Change to stump state
	current_state = TreeState.STUMP
	_convert_to_stump()
	
	# Start respawn timer
	_start_respawn_timer()

func _store_original_tree_data():
	# Store original tree texture and region
	var sprite = target_sprite
	if sprite and sprite is Sprite2D:
		original_tree_texture = sprite.texture
		original_tree_region = sprite.region_rect
		
		# Store original sprite offset for restoration
		if "offset" in sprite:
			tree_info["original_offset"] = sprite.offset
	
	# Store original collision shape
	var collision_shape = find_child("CollisionPolygon2D")
	if collision_shape:
		original_collision_shape = collision_shape.polygon.duplicate()
	
	# Try to determine tree type from texture path if possible
	if original_tree_texture and original_tree_texture.resource_path != "":
		var texture_name = original_tree_texture.resource_path.get_file().get_basename()
		tree_info["tree_type"] = texture_name

func _setup_respawn_timer():
	respawn_timer = Timer.new()
	add_child(respawn_timer)
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)

func _convert_to_stump():
	var sprite = target_sprite as Sprite2D
	if not sprite:
		return
	
	# Change to stump texture coordinates
	sprite.region_enabled = true
	
	# Get stump coordinates based on tree type and size
	var stump_region = _get_stump_region()
	sprite.region_rect = stump_region
	
	# Adjust sprite offset for stump - position it properly at tree base
	# For small stumps like 16x14, we want them positioned at ground level
	sprite.offset = Vector2(0, -stump_region.size.y * 0.7)  # Slightly above ground
	
	# Create smaller collision area for stump
	_create_stump_collision(stump_region.size)
	
	# Disable interaction while stump
	interaction_prompt_text = "Tree Stump (Growing...)"
	monitoring = false  # Disable clicking on stump

func _get_stump_coordinates_for_tree_type() -> Rect2:
	# Determine tree type from texture or stored info
	var tree_type = ""
	if tree_info.has("tree_type"):
		tree_type = tree_info["tree_type"]
	elif original_tree_texture and original_tree_texture.resource_path != "":
		tree_type = original_tree_texture.resource_path.get_file().get_basename()
	
	print("[TreeInteractable] Detected tree type: '", tree_type, "'")
	
	# Map tree types to their stump coordinates
	# Based on your TreeStump.tscn: Big_Oak_Tree stump is at Rect2(24, 52, 16, 14)
	match tree_type:
		"Big_Oak_Tree":
			return Rect2(24, 52, 16, 14)
		"Big_Birch_Tree":
			# You can adjust these coordinates for birch stumps
			return Rect2(24, 52, 16, 14)  # Using same for now
		"Big_Spruce_tree":
			# You can adjust these coordinates for spruce stumps  
			return Rect2(24, 52, 16, 14)  # Using same for now
		"Big_Fruit_Tree":
			# You can adjust these coordinates for fruit stumps
			return Rect2(24, 52, 16, 14)  # Using same for now
		"Medium_Oak_Tree":
			# Smaller trees might have different stump positions
			return Rect2(20, 45, 14, 12)  # Estimated smaller coordinates
		"Medium_Birch_Tree":
			return Rect2(20, 45, 14, 12)
		"Medium_Spruce_Tree":
			return Rect2(20, 45, 14, 12)
		"Medium_Fruit_Tree":
			return Rect2(20, 45, 14, 12)
		"Small_Oak_Tree":
			# Even smaller stumps for small trees
			return Rect2(18, 40, 12, 10)  # Estimated even smaller coordinates
		"Small_Birch_Tree":
			return Rect2(18, 40, 12, 10)
		"Small_Spruce_Tree":
			return Rect2(18, 40, 12, 10)
		"Small_Fruit_Tree":
			return Rect2(18, 40, 12, 10)
		_:
			# Default fallback - use Big Oak coordinates
			print("[TreeInteractable] Unknown tree type '", tree_type, "', using default stump coordinates")
			return Rect2(24, 52, 16, 14)

func _get_stump_region() -> Rect2:
	# Get the precise stump coordinates based on tree type
	var stump_coords = _get_stump_coordinates_for_tree_type()
	print("[TreeInteractable] Using stump coordinates: ", stump_coords)
	return stump_coords

func _create_stump_collision(stump_size: Vector2):
	var collision_shape = find_child("CollisionPolygon2D")
	if collision_shape:
		# Create a small rectangular collision for the stump
		# For 16x14 stumps, make collision slightly smaller for better feel
		var half_width = (stump_size.x * 0.6) / 2  # 60% of visual width
		var height = stump_size.y * 0.8  # 80% of visual height
		
		# Create collision box centered on the stump
		var stump_collision = PackedVector2Array([
			Vector2(-half_width, -height),
			Vector2(half_width, -height), 
			Vector2(half_width, 0),
			Vector2(-half_width, 0)
		])
		collision_shape.polygon = stump_collision
		
		print("[TreeInteractable] Created stump collision: ", stump_size, " -> ", half_width*2, "x", height)

func _start_respawn_timer():
	# Random respawn time between min and max
	var respawn_time = randf_range(respawn_min_time, respawn_max_time)
	print("[TreeInteractable] Tree will respawn in ", respawn_time, " seconds (", respawn_min_time, "-", respawn_max_time, ")")
	respawn_timer.wait_time = respawn_time
	respawn_timer.start()

func _on_respawn_timer_timeout():
	print("[TreeInteractable] Tree respawning...")
	current_state = TreeState.ALIVE
	_restore_tree()

func _restore_tree():
	var sprite = target_sprite as Sprite2D
	if not sprite:
		return
	
	# Restore original tree appearance
	sprite.texture = original_tree_texture
	sprite.region_rect = original_tree_region
	# Restore original offset
	if tree_info.has("original_offset"):
		sprite.offset = tree_info["original_offset"]
	else:
		sprite.offset = Vector2(0, -16)  # Fallback offset
	
	# Restore original collision
	var collision_shape = find_child("CollisionPolygon2D")
	if collision_shape and original_collision_shape:
		collision_shape.polygon = original_collision_shape
	
	# Reset harvest system
	total_resources_remaining = randi_range(min_harvest_amount, max_harvest_amount)
	interaction_prompt_text = "Chop Tree"
	monitoring = true  # Re-enable clicking
	
	print("[TreeInteractable] Tree respawned with ", total_resources_remaining, " resources!")
	
	# Optional: Add a small growing animation
	_play_respawn_animation()

func _play_respawn_animation():
	# Simple scale up animation when tree respawns
	var sprite = target_sprite as Sprite2D
	if not sprite:
		return
	
	sprite.scale = Vector2(0.1, 0.1)  # Start very small
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.8)

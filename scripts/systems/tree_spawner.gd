class_name TreeSpawner
extends ChunkObject

@export_group("Tree Settings")
@export var max_trees_per_chunk: int = 50
@export var random_placement: bool = true
@export var placement_seed: int = -1

var tree_scenes: Array[PackedScene] = []

func _ready():
	spawner_name = "trees"
	density = 0.04
	min_spacing = 12
	exclusion_radius = 32.0
	objects_per_frame = 5
	
	if placement_seed != -1:
		seed(placement_seed)
	
	_load_tree_resources()
	
	super._ready()

func _load_tree_resources():
	tree_scenes = [
		preload("res://scenes/environment/Tree1.tscn"),
	]

func get_max_objects_per_chunk() -> int:
	return max_trees_per_chunk

func _create_object_instance(object_data: Dictionary) -> Node:
	var tree_instance = _get_from_pool("tree")
	
	if not tree_instance:
		var random_scene = tree_scenes[randi() % tree_scenes.size()]
		tree_instance = random_scene.instantiate()
	
	return tree_instance

func _configure_object(instance: Node, object_data: Dictionary) -> void:
	super._configure_object(instance, object_data)
	
	if instance is StaticBody2D:
		var collision_shape = instance.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
		
		var tree_interactable = instance.get_node_or_null("TreeInteractable")
		if tree_interactable and tree_interactable is Area2D:
			var interactable_collision = tree_interactable.get_node_or_null("CollisionPolygon2D")
			if interactable_collision:
				interactable_collision.set_deferred("disabled", false)

func _reset_object_for_pool(obj: Node):
	if obj is StaticBody2D:
		var collision_shape = obj.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		
		var tree_interactable = obj.get_node_or_null("TreeInteractable")
		if tree_interactable and tree_interactable is Area2D:
			var interactable_collision = tree_interactable.get_node_or_null("CollisionPolygon2D")
			if interactable_collision:
				interactable_collision.set_deferred("disabled", true)

func _restore_object_from_pool(obj: Node):
	if obj is StaticBody2D:
		var collision_shape = obj.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
		
		var tree_interactable = obj.get_node_or_null("TreeInteractable")
		if tree_interactable and tree_interactable is Area2D:
			var interactable_collision = tree_interactable.get_node_or_null("CollisionPolygon2D")
			if interactable_collision:
				interactable_collision.set_deferred("disabled", false)

func _get_pool_key(obj: Node) -> String:
	return "tree"

func set_world_seed(new_seed: int):
	placement_seed = new_seed
	seed(placement_seed)

func get_world_seed() -> int:
	return placement_seed
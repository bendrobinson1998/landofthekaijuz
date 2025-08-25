class_name PlayersManager
extends Node

var multiplayer_client_scene = preload("res://scenes/characters/player/MultiplayerClient.tscn")

func _ready():
	# Note: Manual spawning disabled - using automatic MultiplayerSpawner instead
	# Listen for when peers disconnect to clean up
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("PlayersManager: Ready - using automatic spawning via MultiplayerSpawner")

func _on_peer_disconnected(peer_id: int):
	print("Player disconnected with ID: ", peer_id)
	# Note: Player cleanup is handled automatically by MultiplayerSpawner

# DEPRECATED: Manual spawning functions - now using automatic MultiplayerSpawner
# These methods are kept for reference but should not be used

# func spawn_player(peer_id: int):
# 	# DEPRECATED - Using automatic spawning via MultiplayerSpawner instead
# 	pass

# func spawn_player_for_host():
# 	# DEPRECATED - Using automatic spawning via MultiplayerSpawner instead  
# 	pass

func remove_player(peer_id: int):
	var player_name = str(peer_id)
	var player = get_node_or_null(player_name)
	if player:
		player.queue_free()
		print("Removed player: ", player_name)

func get_player(peer_id: int) -> Node:
	return get_node_or_null(str(peer_id))

func get_all_players() -> Array:
	var players = []
	for child in get_children():
		if child.name.is_valid_int():
			players.append(child)
	return players

func _apply_camera_settings_to_player(player_wrapper: Node, peer_id: int):
	"""Apply synchronized camera settings to a newly spawned player"""
	if not CameraManager:
		print("PlayersManager: WARNING - CameraManager not found, cannot apply camera settings to player ", peer_id)
		return
	
	if not CameraManager.has_host_settings():
		print("PlayersManager: No host camera settings available for player ", peer_id)
		return
	
	# Get the actual Player node from the MultiplayerClient wrapper
	var player_node = player_wrapper.get_node_or_null("Player")
	if not player_node:
		print("PlayersManager: ERROR - Player node not found in MultiplayerClient wrapper for peer ", peer_id)
		return
	
	# Apply camera settings using CameraManager
	var success = CameraManager.apply_camera_settings_to_player(player_node)
	if success:
		print("PlayersManager: Successfully applied camera settings to player ", peer_id)
	else:
		print("PlayersManager: Failed to apply camera settings to player ", peer_id)
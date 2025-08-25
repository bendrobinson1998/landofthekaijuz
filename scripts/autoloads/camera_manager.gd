extends Node

signal camera_settings_updated(settings: CameraSettings)

var current_camera_settings: CameraSettings
var is_host_settings_captured: bool = false

func _ready():
	# Initialize with default settings
	current_camera_settings = CameraSettings.new()
	
	# Connect to multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func capture_host_camera_settings(camera: Camera2D) -> void:
	"""Capture camera settings from the host's camera"""
	if not camera:
		print("CameraManager: ERROR - No camera provided for settings capture")
		return
	
	if not current_camera_settings:
		current_camera_settings = CameraSettings.new()
	
	current_camera_settings.copy_from_camera(camera)
	is_host_settings_captured = true
	
	print("CameraManager: Host camera settings captured")
	print("  - Zoom: ", current_camera_settings.zoom)
	print("  - Limits: L:", current_camera_settings.limit_left, " T:", current_camera_settings.limit_top, " R:", current_camera_settings.limit_right, " B:", current_camera_settings.limit_bottom)
	print("  - Smoothing: ", current_camera_settings.position_smoothing_enabled, " Speed: ", current_camera_settings.position_smoothing_speed)
	
	# Emit signal for any listeners
	camera_settings_updated.emit(current_camera_settings)

func apply_camera_settings_to_player(player_node: Node) -> bool:
	"""Apply current camera settings to a player's camera"""
	if not current_camera_settings or not is_host_settings_captured:
		print("CameraManager: No host camera settings available to apply")
		return false
	
	if not player_node:
		print("CameraManager: ERROR - No player node provided")
		return false
	
	# Find the camera in the player node
	var camera = player_node.get_node_or_null("Camera2D")
	if not camera:
		print("CameraManager: ERROR - No Camera2D found in player node")
		return false
	
	# Apply the settings
	current_camera_settings.apply_to_camera(camera)
	
	print("CameraManager: Camera settings applied to player: ", player_node.name)
	print("  - Applied zoom: ", camera.zoom)
	print("  - Applied limits: L:", camera.limit_left, " T:", camera.limit_top, " R:", camera.limit_right, " B:", camera.limit_bottom)
	
	return true

func get_current_settings() -> CameraSettings:
	"""Get the current camera settings"""
	return current_camera_settings

func has_host_settings() -> bool:
	"""Check if host camera settings have been captured"""
	return is_host_settings_captured

@rpc("authority", "call_local", "reliable")
func sync_camera_settings_to_client(settings_data: Dictionary) -> void:
	"""RPC method to synchronize camera settings from host to client"""
	print("CameraManager: Receiving camera settings from host")
	
	if not current_camera_settings:
		current_camera_settings = CameraSettings.new()
	
	current_camera_settings.from_dict(settings_data)
	is_host_settings_captured = true
	
	print("CameraManager: Camera settings synchronized from host")
	print("  - Received zoom: ", current_camera_settings.zoom)
	print("  - Received limits: L:", current_camera_settings.limit_left, " T:", current_camera_settings.limit_top, " R:", current_camera_settings.limit_right, " B:", current_camera_settings.limit_bottom)
	
	# Emit signal for any listeners (PlayerController will handle application when it gains authority)
	camera_settings_updated.emit(current_camera_settings)
	
	print("CameraManager: Settings stored, waiting for PlayerController to apply when authority is established")

func send_settings_to_client(peer_id: int) -> void:
	"""Send current camera settings to a specific client"""
	var is_actual_server = multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() == 1
	if not is_actual_server:
		print("CameraManager: ERROR - Only server can send settings to clients")
		return
	
	if not current_camera_settings or not is_host_settings_captured:
		print("CameraManager: No camera settings to send to client ", peer_id)
		return
	
	var settings_data = current_camera_settings.to_dict()
	print("CameraManager: Sending camera settings to client ", peer_id)
	
	# Send settings to specific client
	sync_camera_settings_to_client.rpc_id(peer_id, settings_data)

func send_settings_to_all_clients() -> void:
	"""Send current camera settings to all connected clients"""
	var is_actual_server = multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() == 1
	if not is_actual_server:
		print("CameraManager: ERROR - Only server can send settings to clients")
		return
	
	if not current_camera_settings or not is_host_settings_captured:
		print("CameraManager: No camera settings to send to clients")
		return
	
	var settings_data = current_camera_settings.to_dict()
	print("CameraManager: Broadcasting camera settings to all clients")
	
	# Send settings to all clients
	sync_camera_settings_to_client.rpc(settings_data)

func _on_peer_connected(peer_id: int) -> void:
	"""Handle new peer connection - send camera settings if we're the server"""
	print("CameraManager: Peer ", peer_id, " connected")
	
	# Only server (host) sends settings
	var is_actual_server = multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() == 1
	if is_actual_server and has_host_settings():
		# Wait a moment for the peer to be fully ready and player to spawn
		await get_tree().create_timer(1.0).timeout  # Longer wait for automatic spawning
		send_settings_to_client(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	"""Handle peer disconnection"""
	print("CameraManager: Peer ", peer_id, " disconnected")

func reset_settings() -> void:
	"""Reset camera settings (useful when leaving multiplayer)"""
	current_camera_settings = CameraSettings.new()
	is_host_settings_captured = false
	print("CameraManager: Camera settings reset")

func _try_apply_to_local_player() -> void:
	"""Try to find and apply settings to the local player's camera (debugging only)"""
	if not current_camera_settings or not is_host_settings_captured:
		return
	
	# Find the local player (the one with authority)
	var local_player = _find_local_player()
	if local_player:
		print("CameraManager: Found local player, applying camera settings")
		var success = apply_camera_settings_to_player(local_player)
		if success:
			# Ensure camera is activated for the local player
			var camera = local_player.get_node_or_null("Camera2D")
			if camera:
				print("CameraManager: Activating camera for local player")
				camera.enabled = true
				camera.make_current()
				print("CameraManager: Local player camera activated successfully")

func _find_local_player() -> Node:
	"""Find the local player node (the one with multiplayer authority)"""
	# Look in the Players container in MainWorld
	var main_world = get_tree().current_scene
	if not main_world:
		return null
	
	var players_container = main_world.get_node_or_null("Players")
	if not players_container:
		return null
	
	# Check each player to see which one has authority (is local)
	for child in players_container.get_children():
		if child.is_multiplayer_authority():
			print("CameraManager: Found local player with authority: ", child.name)
			return child
	
	return null
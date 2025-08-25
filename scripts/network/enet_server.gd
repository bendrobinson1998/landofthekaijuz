class_name ENETServer
extends Node

signal spawn_player_for_host()

func start_server(port: int, max_players: int = 16):
	var network = ENetMultiplayerPeer.new()
	network.create_server(port, max_players)
	multiplayer.multiplayer_peer = network
	
	print("Starting server on port: ", port)
	print("Max players: ", max_players)
	
	# Emit signal to spawn player for host (host is always peer ID 1)
	spawn_player_for_host.emit()
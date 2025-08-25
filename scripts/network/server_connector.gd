class_name ServerConnector
extends Node

func connect_to_server(host_ip: String, port: int):
	var network = ENetMultiplayerPeer.new()
	network.create_client(host_ip, port)
	multiplayer.multiplayer_peer = network
	
	print("Connecting to ", host_ip, ":", port)
	
	# Listen for connection success
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_connected_to_server():
	print("Connected to server")
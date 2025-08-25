extends Node

signal message_received(message: String)

@rpc("any_peer", "call_local", "reliable")
func receive_message(message: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		# Local call (from this client)
		sender_id = multiplayer.get_unique_id()
	
	# Check if message already contains username (single-player) vs needs Player ID (multiplayer)
	var formatted_message: String
	if message.contains(": "):
		# Message already has username format, preserve it (single-player)
		formatted_message = message
	else:
		# Raw message without username, add Player ID (multiplayer)
		formatted_message = "Player " + str(sender_id) + ": " + message
	
	message_received.emit(formatted_message)

func send_message_to_all(message: String):
	# Send message to all connected players via RPC
	receive_message.rpc(message)

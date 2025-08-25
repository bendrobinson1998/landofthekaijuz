extends Node

signal message_sent(message: ChatMessage)
signal message_received(message: ChatMessage)
signal chat_opened()
signal chat_closed()

var chat_history: Array[ChatMessage] = []
var max_history_size: int = 100
var local_player_name: String = "Player"
var is_chat_open: bool = false

func _ready():
	# Connect to multiplayer chat RPC system
	if ServerChatRPC:
		ServerChatRPC.message_received.connect(_on_multiplayer_message_received)


func open_chat():
	if is_chat_open:
		return
	
	is_chat_open = true
	chat_opened.emit()

func close_chat():
	if not is_chat_open:
		return
	
	is_chat_open = false
	chat_closed.emit()

func send_message(message_text: String, sender_name: String = "") -> bool:
	if message_text.is_empty() or message_text.strip_edges().is_empty():
		return false
	
	var clean_message = message_text.strip_edges()
	var final_sender_name = sender_name if not sender_name.is_empty() else get_local_player_name()
	
	var message = ChatMessage.new(final_sender_name, clean_message, "local_player", true)
	
	_add_message_to_history(message)
	
	message_sent.emit(message)
	
	# Handle multiplayer vs single-player
	if multiplayer.multiplayer_peer:
		# Multiplayer: send via RPC
		print("ChatManager: Sending multiplayer message: ", final_sender_name, ": ", clean_message)
		ServerChatRPC.send_message_to_all(final_sender_name + ": " + clean_message)
	else:
		# Single-player: local only
		print("ChatManager: Emitting local message for bubble display: ", message.sender_name, " - ", message.message_text)
		message_received.emit(message)
	
	return true

func receive_message(message: ChatMessage):
	if not message or not message.is_valid():
		return
	
	_add_message_to_history(message)
	message_received.emit(message)

func _on_multiplayer_message_received(message_text: String):
	"""Handle messages received from multiplayer RPC system"""
	# Parse the message - format is "Player X: message" or "username: message"
	var parts = message_text.split(": ", false, 1)
	if parts.size() >= 2:
		var sender_name = parts[0]
		var text = parts[1]
		
		# Determine if this is from the local player
		var local_player_name = get_local_player_name()
		var is_local = (sender_name == local_player_name)
		
		print("ChatManager: Multiplayer message - sender: '", sender_name, "' local_name: '", local_player_name, "' is_local: ", is_local)
		
		var message = ChatMessage.new(sender_name, text, "multiplayer_player", is_local)
		_add_message_to_history(message)
		message_received.emit(message)
	else:
		# Fallback: treat entire text as message from unknown player
		var message = ChatMessage.new("Unknown", message_text, "multiplayer_player", false)
		_add_message_to_history(message)
		message_received.emit(message)

func _add_message_to_history(message: ChatMessage):
	chat_history.append(message)
	
	if chat_history.size() > max_history_size:
		chat_history.pop_front()

func get_recent_messages(count: int = 10) -> Array[ChatMessage]:
	var start_index = max(0, chat_history.size() - count)
	return chat_history.slice(start_index)

func clear_history():
	chat_history.clear()

func set_local_player_name(name: String):
	local_player_name = name

func get_local_player_name() -> String:
	# Get username from current world save data if available
	if GameManager.player_data.has("username") and not GameManager.player_data["username"].is_empty():
		return GameManager.player_data["username"]
	return local_player_name

func get_chat_history() -> Array[ChatMessage]:
	return chat_history.duplicate()

func is_multiplayer_ready() -> bool:
	return false

func send_multiplayer_message(message_text: String) -> bool:
	return false

func send_npc_message(message_text: String, npc_name: String = "NPC") -> bool:
	"""Send a message from an NPC to the chat system"""
	if message_text.is_empty() or message_text.strip_edges().is_empty():
		return false
	
	var clean_message = message_text.strip_edges()
	var message = ChatMessage.new(npc_name, clean_message, "npc_" + npc_name, false)
	
	_add_message_to_history(message)
	message_received.emit(message)
	
	return true

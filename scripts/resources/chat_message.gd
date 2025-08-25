class_name ChatMessage
extends Resource

@export var sender_name: String = ""
@export var message_text: String = ""
@export var timestamp: float = 0.0
@export var sender_id: String = ""
@export var is_local_player: bool = false

func _init(p_sender_name: String = "", p_message_text: String = "", p_sender_id: String = "", p_is_local_player: bool = false):
	sender_name = p_sender_name
	message_text = p_message_text
	timestamp = Time.get_unix_time_from_system()
	sender_id = p_sender_id
	is_local_player = p_is_local_player

func get_formatted_message() -> String:
	if sender_name.is_empty():
		return message_text
	return "%s: %s" % [sender_name, message_text]

func is_valid() -> bool:
	return not message_text.is_empty()
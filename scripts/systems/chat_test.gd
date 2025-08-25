extends Node

func _ready():
	
	await get_tree().create_timer(2.0).timeout
	
	if ChatManager:
		ChatManager.send_message("Hello World! This is a test chat message.")
		
		await get_tree().create_timer(3.0).timeout
		ChatManager.send_message("Another test message!")
		
		await get_tree().create_timer(2.0).timeout
		ChatManager.send_message("Testing long messages to see how they wrap and display in the chat bubble system.")
	else:

func _input(event: InputEvent):
	if event.is_action_pressed("ui_accept"):  # Enter key
		if ChatManager:
			ChatManager.send_message("Quick test message from Enter key!")
		get_viewport().set_input_as_handled()
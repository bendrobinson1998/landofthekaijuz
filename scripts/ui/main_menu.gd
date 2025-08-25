extends Control

@onready var world_creation_dialog: AcceptDialog = $WorldCreationDialog
@onready var world_selection_dialog: AcceptDialog = $WorldSelectionDialog
@onready var world_name_input: LineEdit = $WorldCreationDialog/VBoxContainer/WorldNameInput
@onready var username_input: LineEdit = $WorldCreationDialog/VBoxContainer/UsernameInput
@onready var seed_input: LineEdit = $WorldCreationDialog/VBoxContainer/SeedInput
@onready var world_list: ItemList = $WorldSelectionDialog/VBoxContainer/WorldList
@onready var load_button: Button = $WorldSelectionDialog/VBoxContainer/ButtonContainer/LoadButton
@onready var delete_button: Button = $WorldSelectionDialog/VBoxContainer/ButtonContainer/DeleteButton

var available_worlds: Array[Dictionary] = []

func _ready():
	_refresh_world_list()

func _input(event):
	# Add debug key to force refresh world list (F5)
	if false:
		_refresh_world_list()
	
	# Add debug key to create test world (F6)
	if false:
		var test_name = "DebugWorld_" + str(Time.get_unix_time_from_system())
		_create_new_world(test_name, "TestPlayer", 12345)

func _on_new_world_button_pressed():
	world_name_input.text = ""
	username_input.text = ""
	seed_input.text = ""
	world_creation_dialog.popup_centered()
	world_name_input.grab_focus()

func _on_load_world_button_pressed():
	_refresh_world_list()
	world_selection_dialog.popup_centered()

func _on_multiplayer_button_pressed():
	GameManager.change_scene_to("res://scenes/ui/MultiplayerMenu.tscn")

func _on_quit_button_pressed():
	GameManager.quit_game()

func _on_create_button_pressed():
	var world_name = world_name_input.text.strip_edges()
	if world_name.is_empty():
		world_name = "My World"
	
	var username = username_input.text.strip_edges()
	if username.is_empty():
		username = "Player"
	
	var world_seed = -1
	if not seed_input.text.is_empty():
		if seed_input.text.is_valid_int():
			world_seed = int(seed_input.text)
		else:
			# Use string hash as seed
			world_seed = seed_input.text.hash()
	else:
		# Generate random seed
		world_seed = randi()
	
	_create_new_world(world_name, username, world_seed)
	world_creation_dialog.hide()

func _on_create_cancel_button_pressed():
	world_creation_dialog.hide()

func _on_world_list_item_selected(index: int):
	load_button.disabled = false
	delete_button.disabled = false

func _on_load_button_pressed():
	var selected_index = world_list.get_selected_items()
	if selected_index.size() > 0:
		var world_data = available_worlds[selected_index[0]]
		_load_world(world_data)
		world_selection_dialog.hide()

func _on_delete_button_pressed():
	var selected_index = world_list.get_selected_items()
	if selected_index.size() > 0:
		var world_data = available_worlds[selected_index[0]]
		_delete_world(world_data)
		_refresh_world_list()
		load_button.disabled = true
		delete_button.disabled = true

func _on_load_cancel_button_pressed():
	world_selection_dialog.hide()

func _create_new_world(world_name: String, username: String, world_seed: int):
	
	# Create new world using SaveManager
	if SaveManager.create_new_world(world_name, world_seed, username):
		# Refresh the world list to show the new world
		_refresh_world_list()
		
		# Load the main world scene
		GameManager.change_scene_to("res://scenes/levels/world/MainWorld.tscn")

func _load_world(world_data: Dictionary):
	# Load world using SaveManager
	var world_name = world_data.get("world_name", "")
	if world_name.is_empty():
		return
	
	if SaveManager.load_world(world_name):
		# Load the main world scene
		GameManager.change_scene_to("res://scenes/levels/world/MainWorld.tscn")

func _delete_world(world_data: Dictionary):
	var world_name = world_data.get("world_name", "")
	if world_name.is_empty():
		return
	
	SaveManager.delete_world(world_name)


func _refresh_world_list():
	available_worlds.clear()
	world_list.clear()
	
	
	# Get available worlds from SaveManager
	var worlds = SaveManager.get_available_worlds()
	
	for world_data in worlds:
		available_worlds.append(world_data)
		
		# Format the display text
		var creation_date = Time.get_datetime_string_from_unix_time(world_data.get("creation_timestamp", 0))
		var last_played = Time.get_datetime_string_from_unix_time(world_data.get("last_played_timestamp", 0))
		var save_status = " (New)" if not world_data.get("has_save_file", false) else ""
		var username = world_data.get("username", "Player")
		var display_text = "%s%s\nPlayer: %s\nCreated: %s\nLast Played: %s" % [world_data.get("world_name", "Unknown"), save_status, username, creation_date, last_played]
		
		world_list.add_item(display_text)
	

class_name InventoryUI
extends ScalableUIPanel

@onready var background_texture: TextureRect = $BackgroundTexture

var slot_scene = preload("res://scenes/ui/InventorySlot.tscn")
var inventory_slots: Array[InventorySlotUI] = []

func _ready():
	# Call parent _ready first for scaling setup
	super()
	
	# Ensure inventory UI is below control panel
	z_index = 10
	
	# Start hidden, will be shown if needed
	visible = false
	_setup_existing_slots()
	_connect_to_inventory_manager()


func _setup_existing_slots():
	# Get manually placed slot children from the InventoryUI root
	var all_children = get_children()
	inventory_slots.clear()
	
	# Find and configure InventorySlot nodes
	for child in all_children:
		var slot = child as InventorySlotUI
		if slot:
			inventory_slots.append(slot)
	
	# Sort slots by position (top-to-bottom, left-to-right) to ensure proper visual order
	inventory_slots.sort_custom(func(a, b):
		# First sort by row (top to bottom)
		if abs(a.position.y - b.position.y) > 5:  # 5 pixel tolerance for same row
			return a.position.y < b.position.y
		# Then by column (left to right) within the same row
		return a.position.x < b.position.x
	)
	
	# Configure slots with proper indices and connections
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		slot.slot_index = i
		# Disconnect any existing connections to avoid duplicates
		if slot.slot_clicked.is_connected(_on_slot_clicked):
			slot.slot_clicked.disconnect(_on_slot_clicked)
		if slot.slot_hovered.is_connected(_on_slot_hovered):
			slot.slot_hovered.disconnect(_on_slot_hovered)
		# Connect signals
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
	
	print("InventoryUI: Found and configured ", inventory_slots.size(), " manually placed slots")

func _connect_to_inventory_manager():
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		InventoryManager.inventory_opened.connect(_on_inventory_opened)
		InventoryManager.inventory_closed.connect(_on_inventory_closed)
		_on_inventory_changed()

func _on_inventory_changed():
	if not InventoryManager:
		return
	
	# Update all slots (handle case where slot count might differ from inventory size)
	var slot_count = inventory_slots.size()
	var inventory_size = InventoryManager.INVENTORY_SIZE
	var max_slots = min(slot_count, inventory_size)
	
	for i in range(max_slots):
		var slot_data = InventoryManager.get_slot(i)
		if slot_data and i < inventory_slots.size():
			inventory_slots[i].update_slot(slot_data)
	
	# Clear any extra slots if we have more slots than inventory size
	for i in range(max_slots, slot_count):
		if i < inventory_slots.size():
			inventory_slots[i].update_slot(null)

func _on_inventory_opened():
	print("InventoryUI: _on_inventory_opened called")
	visible = true
	print("InventoryUI: Inventory UI should now be visible")

func _on_inventory_closed():
	print("InventoryUI: _on_inventory_closed called")
	visible = false
	print("InventoryUI: Inventory UI should now be hidden")

func _on_slot_clicked(index: int):
	print("Slot clicked: ", index)
	# Future: Handle item movement, usage, etc.

func _on_slot_hovered(index: int):
	var slot_data = InventoryManager.get_slot(index)
	if slot_data and not slot_data.is_empty():
		# Future: Show item tooltip
		pass





func _input(event: InputEvent):
	if event.is_action_pressed("toggle_inventory"):
		InventoryManager.toggle_inventory()

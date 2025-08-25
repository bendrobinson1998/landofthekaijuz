extends Node

signal inventory_changed()
signal item_added(item: ItemResource, amount: int)
signal item_removed(item: ItemResource, amount: int)
signal inventory_opened()
signal inventory_closed()

const INVENTORY_SIZE = 25  # 5x5 grid

class InventorySlot:
	var item: ItemResource = null
	var quantity: int = 0
	
	func is_empty() -> bool:
		return item == null or quantity <= 0
	
	func can_add_item(new_item: ItemResource, amount: int = 1) -> bool:
		if is_empty():
			return true
		return item == new_item and quantity + amount <= item.max_stack_size
	
	func add_item(new_item: ItemResource, amount: int = 1) -> int:
		if is_empty():
			item = new_item
			quantity = amount
			return 0
		elif item == new_item:
			var space_available = item.max_stack_size - quantity
			var amount_to_add = min(amount, space_available)
			quantity += amount_to_add
			return amount - amount_to_add
		return amount
	
	func remove_item(amount: int = 1) -> int:
		if is_empty():
			return 0
		
		var amount_to_remove = min(amount, quantity)
		quantity -= amount_to_remove
		
		if quantity <= 0:
			item = null
			quantity = 0
		
		return amount_to_remove
	
	func clear():
		item = null
		quantity = 0

var inventory: Array[InventorySlot] = []
var is_inventory_open: bool = false

func _ready():
	_initialize_inventory()

func _initialize_inventory():
	inventory.clear()
	for i in INVENTORY_SIZE:
		inventory.append(InventorySlot.new())

func add_item(item: ItemResource, amount: int = 1) -> int:
	if not item:
		return amount
	
	var remaining = amount
	
	# First try to stack with existing items
	for slot in inventory:
		if remaining <= 0:
			break
		if slot.item == item and slot.quantity < item.max_stack_size:
			remaining = slot.add_item(item, remaining)
	
	# Then try to add to empty slots
	for slot in inventory:
		if remaining <= 0:
			break
		if slot.is_empty():
			remaining = slot.add_item(item, remaining)
	
	if amount - remaining > 0:
		item_added.emit(item, amount - remaining)
		inventory_changed.emit()
	
	return remaining

func remove_item(item: ItemResource, amount: int = 1) -> int:
	if not item:
		return 0
	
	var total_removed = 0
	
	for slot in inventory:
		if total_removed >= amount:
			break
		if slot.item == item:
			var removed = slot.remove_item(amount - total_removed)
			total_removed += removed
	
	if total_removed > 0:
		item_removed.emit(item, total_removed)
		inventory_changed.emit()
	
	return total_removed

func has_item(item: ItemResource, amount: int = 1) -> bool:
	if not item:
		return false
	
	var total_count = get_item_count(item)
	return total_count >= amount

func get_item_count(item: ItemResource) -> int:
	if not item:
		return 0
	
	var total = 0
	for slot in inventory:
		if slot.item == item:
			total += slot.quantity
	
	return total

func get_slot(index: int) -> InventorySlot:
	if index >= 0 and index < inventory.size():
		return inventory[index]
	return null

func swap_slots(index1: int, index2: int):
	if index1 < 0 or index1 >= inventory.size() or index2 < 0 or index2 >= inventory.size():
		return
	
	var temp = inventory[index1]
	inventory[index1] = inventory[index2]
	inventory[index2] = temp
	inventory_changed.emit()

func clear_slot(index: int):
	var slot = get_slot(index)
	if slot:
		slot.clear()
		inventory_changed.emit()

func clear_inventory():
	for slot in inventory:
		slot.clear()
	inventory_changed.emit()

func get_first_empty_slot_index() -> int:
	for i in range(inventory.size()):
		if inventory[i].is_empty():
			return i
	return -1

func is_full() -> bool:
	return get_first_empty_slot_index() == -1

func toggle_inventory():
	if is_inventory_open:
		close_inventory()
	else:
		open_inventory()

func open_inventory():
	if not is_inventory_open:
		is_inventory_open = true
		inventory_opened.emit()

func close_inventory():
	if is_inventory_open:
		print("InventoryManager: Closing inventory")
		is_inventory_open = false
		inventory_closed.emit()
		print("InventoryManager: inventory_closed signal emitted")

func get_inventory_data() -> Array:
	var data = []
	for slot in inventory:
		if not slot.is_empty():
			data.append({
				"item_path": slot.item.resource_path,
				"quantity": slot.quantity
			})
		else:
			data.append(null)
	return data

func load_inventory_data(data: Array):
	clear_inventory()
	for i in range(min(data.size(), inventory.size())):
		if data[i] != null:
			var item = load(data[i]["item_path"]) as ItemResource
			if item:
				inventory[i].item = item
				inventory[i].quantity = data[i]["quantity"]
	inventory_changed.emit()

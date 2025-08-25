class_name ItemResource
extends Resource

@export var item_name: String = "Item"
@export var item_icon: Texture2D
@export var item_icon_region: Rect2 = Rect2(0, 0, 16, 16)
@export var max_stack_size: int = 99
@export var item_description: String = ""

enum ItemType {
	RESOURCE,
	TOOL,
	CONSUMABLE,
	EQUIPMENT,
	MISC
}

@export var item_type: ItemType = ItemType.RESOURCE
@export var value: int = 1
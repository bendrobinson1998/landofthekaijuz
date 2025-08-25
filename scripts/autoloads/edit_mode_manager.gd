extends Node

signal edit_mode_toggled(enabled: bool)
signal edit_tool_changed(tool_name: String)

enum EditTool {
	NONE = 0,
	PATH = 1
}

var edit_mode_enabled: bool = false
var current_tool: EditTool = EditTool.NONE

func _ready() -> void:
	name = "EditModeManager"

func toggle_edit_mode() -> void:
	edit_mode_enabled = !edit_mode_enabled
	
	if edit_mode_enabled:
		current_tool = EditTool.PATH
	else:
		current_tool = EditTool.NONE
	
	edit_mode_toggled.emit(edit_mode_enabled)
	edit_tool_changed.emit(get_tool_name(current_tool))

func set_edit_mode(enabled: bool) -> void:
	if edit_mode_enabled != enabled:
		toggle_edit_mode()

func set_tool(tool: EditTool) -> void:
	if current_tool != tool:
		current_tool = tool
		edit_tool_changed.emit(get_tool_name(current_tool))

func get_tool_name(tool: EditTool) -> String:
	match tool:
		EditTool.PATH:
			return "Path"
		EditTool.NONE:
			return "None"
		_:
			return "Unknown"

func is_edit_mode() -> bool:
	return edit_mode_enabled

func get_current_tool() -> EditTool:
	return current_tool

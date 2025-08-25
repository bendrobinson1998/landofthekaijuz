class_name ScalableUIPanel
extends Control

## Base class for UI panels that support scaling while maintaining their position
## 
## This class provides a standard implementation for UI scaling that:
## - Scales the panel from its center point
## - Maintains the panel's anchor-based positioning
## - Provides consistent scaling behavior across all UI panels

var current_ui_scale: float = 1.0

func _ready():
	# Connect to UserPreferences for initial scale if not already connected by parent
	if UserPreferences and not UserPreferences.ui_scale_changed.is_connected(_on_ui_scale_changed):
		UserPreferences.ui_scale_changed.connect(_on_ui_scale_changed)
		# Apply initial scale
		call_deferred("_apply_initial_scale")

func _apply_initial_scale():
	"""Apply initial UI scale from UserPreferences"""
	if UserPreferences:
		apply_ui_scale(UserPreferences.get_ui_scale())

func apply_ui_scale(ui_scale: float):
	"""Apply UI scale to this panel while maintaining its anchor-based position"""
	if ui_scale == current_ui_scale:
		return
	
	current_ui_scale = ui_scale
	
	# Set scale from anchor-appropriate pivot point
	scale = Vector2(ui_scale, ui_scale)
	
	# Set pivot based on anchor preset to maintain position
	pivot_offset = _get_anchor_based_pivot()
	
	# Call virtual method for panels that need custom scaling behavior
	_on_scale_applied(ui_scale)

func _on_scale_applied(ui_scale: float):
	"""Virtual method called after scale is applied. Override in child classes for custom behavior."""
	pass

func _on_ui_scale_changed(new_scale: float):
	"""Handle UI scale changes from UserPreferences"""
	apply_ui_scale(new_scale)

func _get_anchor_based_pivot() -> Vector2:
	"""Get the appropriate pivot point based on the control's anchor preset"""
	# Map anchor presets to pivot points that maintain position during scaling
	# The pivot should be at the anchor point so scaling happens "outward" from that point
	
	# Check anchors to determine the anchor preset
	var left = anchor_left
	var top = anchor_top  
	var right = anchor_right
	var bottom = anchor_bottom
	
	# Center anchored (0.5, 0.5, 0.5, 0.5) - scale from center
	if left == 0.5 and top == 0.5 and right == 0.5 and bottom == 0.5:
		return size / 2.0
	
	# Bottom-left anchored (0, 1, 0, 1) - scale from bottom-left
	elif left == 0.0 and top == 1.0 and right == 0.0 and bottom == 1.0:
		return Vector2(0, size.y)
	
	# Bottom-wide anchored (0, 1, 1, 1) - scale from bottom-center  
	elif left == 0.0 and top == 1.0 and right == 1.0 and bottom == 1.0:
		return Vector2(size.x / 2.0, size.y)
	
	# Bottom-right anchored (1, 1, 1, 1) - scale from bottom-right
	elif left == 1.0 and top == 1.0 and right == 1.0 and bottom == 1.0:
		return Vector2(size.x, size.y)
	
	# Top-left anchored (0, 0, 0, 0) - scale from top-left
	elif left == 0.0 and top == 0.0 and right == 0.0 and bottom == 0.0:
		return Vector2.ZERO
	
	# Top-wide anchored (0, 0, 1, 0) - scale from top-center
	elif left == 0.0 and top == 0.0 and right == 1.0 and bottom == 0.0:
		return Vector2(size.x / 2.0, 0)
	
	# Top-right anchored (1, 0, 1, 0) - scale from top-right  
	elif left == 1.0 and top == 0.0 and right == 1.0 and bottom == 0.0:
		return Vector2(size.x, 0)
	
	# Left-wide anchored (0, 0, 0, 1) - scale from left-center
	elif left == 0.0 and top == 0.0 and right == 0.0 and bottom == 1.0:
		return Vector2(0, size.y / 2.0)
	
	# Right-wide anchored (1, 0, 1, 1) - scale from right-center
	elif left == 1.0 and top == 0.0 and right == 1.0 and bottom == 1.0:
		return Vector2(size.x, size.y / 2.0)
	
	# Full-rect anchored (0, 0, 1, 1) - scale from center (shouldn't really scale)
	elif left == 0.0 and top == 0.0 and right == 1.0 and bottom == 1.0:
		return size / 2.0
	
	# Default: scale from center for unknown anchor configurations
	else:
		print("ScalableUIPanel: Unknown anchor configuration for ", name, " - using center pivot")
		return size / 2.0

func get_current_ui_scale() -> float:
	"""Get the current UI scale for this panel"""
	return current_ui_scale
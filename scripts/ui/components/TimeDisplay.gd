class_name TimeDisplay
extends Control

@export var show_24_hour_format: bool = true
@export var show_day_counter: bool = true
@export var show_period_indicator: bool = true
@export var auto_hide_in_menus: bool = true

@onready var time_label: Label = $Background/TimeLabel
@onready var day_label: Label = $Background/DayLabel
@onready var period_label: Label = $Background/PeriodLabel
@onready var background: NinePatchRect = $Background

var is_hidden: bool = false

func _ready():
	_setup_ui_elements()
	_connect_to_time_manager()
	_update_display()

func _setup_ui_elements():
	if not background:
		background = NinePatchRect.new()
		background.name = "Background"
		add_child(background)
	
	if not time_label:
		time_label = Label.new()
		time_label.name = "TimeLabel"
		background.add_child(time_label)
	
	if not day_label:
		day_label = Label.new()
		day_label.name = "DayLabel"
		background.add_child(day_label)
	
	if not period_label:
		period_label = Label.new()
		period_label.name = "PeriodLabel" 
		background.add_child(period_label)
	
	_setup_label_properties()
	_setup_layout()

func _setup_label_properties():
	if time_label:
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		time_label.add_theme_font_size_override("font_size", 16)
	
	if day_label:
		day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		day_label.add_theme_font_size_override("font_size", 12)
	
	if period_label:
		period_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		period_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		period_label.add_theme_font_size_override("font_size", 10)

func _setup_layout():
	size = Vector2(120, 60)
	
	if background:
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.modulate = Color(0.2, 0.2, 0.2, 0.8)
	
	if time_label:
		time_label.position = Vector2(10, 5)
		time_label.size = Vector2(100, 20)
	
	if day_label:
		day_label.position = Vector2(10, 25)
		day_label.size = Vector2(100, 15)
	
	if period_label:
		period_label.position = Vector2(10, 40)
		period_label.size = Vector2(100, 15)

func _connect_to_time_manager():
	if not TimeManager:
		return
	
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.day_night_cycle_changed.connect(_on_day_night_changed)

func _update_display():
	if not TimeManager:
		return
	
	_update_time_display()
	_update_day_display()
	_update_period_display()

func _update_time_display():
	if not time_label or not TimeManager:
		return
	
	var time_string = TimeManager.get_current_time_string(show_24_hour_format)
	time_label.text = time_string
	
	var time_color = Color.WHITE
	if TimeManager.is_day_time:
		time_color = Color.YELLOW
	else:
		time_color = Color.LIGHT_BLUE
	
	time_label.modulate = time_color

func _update_day_display():
	if not day_label or not TimeManager:
		return
	
	if show_day_counter:
		day_label.text = TimeManager.get_current_day_string()
		day_label.visible = true
	else:
		day_label.visible = false

func _update_period_display():
	if not period_label or not TimeManager:
		return
	
	if show_period_indicator:
		period_label.text = TimeManager.get_time_period()
		period_label.visible = true
		
		var period_color = Color.WHITE
		match TimeManager.get_time_period():
			"Morning":
				period_color = Color.GOLD
			"Afternoon":
				period_color = Color.ORANGE
			"Evening":
				period_color = Color.ORANGE_RED
			"Night":
				period_color = Color.DEEP_SKY_BLUE
		
		period_label.modulate = period_color
	else:
		period_label.visible = false

func _on_time_changed(hour: int, minute: int):
	_update_time_display()

func _on_day_changed(day: int):
	_update_day_display()

func _on_day_night_changed(is_day: bool):
	_update_display()
	
	if background:
		var tween = create_tween()
		var target_alpha = 0.8 if is_day else 0.9
		var target_color = Color(0.2, 0.2, 0.2, target_alpha) if is_day else Color(0.1, 0.1, 0.3, target_alpha)
		tween.tween_property(background, "modulate", target_color, 1.0)

func set_24_hour_format(enabled: bool):
	show_24_hour_format = enabled
	_update_time_display()

func set_day_counter_visibility(visible: bool):
	show_day_counter = visible
	_update_day_display()

func set_period_indicator_visibility(visible: bool):
	show_period_indicator = visible
	_update_period_display()

func hide_display():
	if is_hidden:
		return
	
	is_hidden = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

func show_display():
	if not is_hidden:
		return
	
	is_hidden = false
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func toggle_display():
	if is_hidden:
		show_display()
	else:
		hide_display()

func set_background_color(color: Color):
	if background:
		background.modulate = color

func get_display_size() -> Vector2:
	return size
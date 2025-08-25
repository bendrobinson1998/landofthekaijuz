class_name Skill
extends Resource

signal level_changed(old_level: int, new_level: int)
signal xp_gained(skill: Skill, amount: int)

@export var skill_name: String = ""
@export var current_xp: int = 0
@export var current_level: int = 1

enum SkillType {
	WOODCUTTING,
	MINING,
	FISHING,
	FARMING,
	COOKING,
	SMITHING,
	CRAFTING,
	COMBAT
}

@export var skill_type: SkillType = SkillType.WOODCUTTING

func _init(name: String = "", type: SkillType = SkillType.WOODCUTTING):
	skill_name = name
	skill_type = type
	current_xp = 0
	current_level = 1

func add_xp(amount: int):
	if amount <= 0:
		return
	
	var old_level = current_level
	current_xp += amount
	
	# Update level based on new XP
	current_level = SkillManager.get_level_for_xp(current_xp)
	
	xp_gained.emit(self, amount)
	
	# Check for level up
	if current_level > old_level:
		level_changed.emit(old_level, current_level)

func get_xp_for_next_level() -> int:
	if current_level >= 99:
		return 0
	return SkillManager.get_xp_for_level(current_level + 1)

func get_xp_progress_to_next_level() -> int:
	if current_level >= 99:
		return 0
	var current_level_xp = SkillManager.get_xp_for_level(current_level)
	return current_xp - current_level_xp

func get_xp_needed_for_next_level() -> int:
	if current_level >= 99:
		return 0
	var next_level_xp = SkillManager.get_xp_for_level(current_level + 1)
	var current_level_xp = SkillManager.get_xp_for_level(current_level)
	var progress = get_xp_progress_to_next_level()
	return (next_level_xp - current_level_xp) - progress

func get_progress_percentage() -> float:
	if current_level >= 99:
		return 100.0
	
	var current_level_xp = SkillManager.get_xp_for_level(current_level)
	var next_level_xp = SkillManager.get_xp_for_level(current_level + 1)
	var level_xp_range = next_level_xp - current_level_xp
	var progress = get_xp_progress_to_next_level()
	
	return (float(progress) / float(level_xp_range)) * 100.0

func get_save_data() -> Dictionary:
	return {
		"skill_name": skill_name,
		"skill_type": skill_type,
		"current_xp": current_xp,
		"current_level": current_level
	}

func load_save_data(data: Dictionary):
	skill_name = data.get("skill_name", skill_name)
	skill_type = data.get("skill_type", skill_type)
	current_xp = data.get("current_xp", 0)
	current_level = data.get("current_level", 1)
	
	# Verify level matches XP
	current_level = SkillManager.get_level_for_xp(current_xp)
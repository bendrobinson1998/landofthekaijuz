extends Node

signal skill_level_up(skill: Skill, old_level: int, new_level: int)
signal skill_xp_gained(skill: Skill, amount: int)

# OSRS Experience Table - precomputed for performance
# Formula: floor((level-1) + 300 * 2^((level-1)/7)) / 4
var XP_TABLE: Array[int] = [
	0,        # Level 1
	83,       # Level 2
	174,      # Level 3
	276,      # Level 4
	388,      # Level 5
	512,      # Level 6
	650,      # Level 7
	801,      # Level 8
	969,      # Level 9
	1154,     # Level 10
	1358,     # Level 11
	1584,     # Level 12
	1833,     # Level 13
	2107,     # Level 14
	2411,     # Level 15
	2746,     # Level 16
	3115,     # Level 17
	3523,     # Level 18
	3973,     # Level 19
	4470,     # Level 20
	5018,     # Level 21
	5624,     # Level 22
	6291,     # Level 23
	7028,     # Level 24
	7842,     # Level 25
	8740,     # Level 26
	9730,     # Level 27
	10824,    # Level 28
	12031,    # Level 29
	13363,    # Level 30
	14833,    # Level 31
	16456,    # Level 32
	18247,    # Level 33
	20224,    # Level 34
	22406,    # Level 35
	24815,    # Level 36
	27473,    # Level 37
	30408,    # Level 38
	33648,    # Level 39
	37224,    # Level 40
	41171,    # Level 41
	45529,    # Level 42
	50339,    # Level 43
	55649,    # Level 44
	61512,    # Level 45
	67983,    # Level 46
	75127,    # Level 47
	83014,    # Level 48
	91721,    # Level 49
	101333,   # Level 50
	111945,   # Level 51
	123660,   # Level 52
	136594,   # Level 53
	150872,   # Level 54
	166636,   # Level 55
	184040,   # Level 56
	203254,   # Level 57
	224466,   # Level 58
	247886,   # Level 59
	273742,   # Level 60
	302288,   # Level 61
	333804,   # Level 62
	368599,   # Level 63
	407015,   # Level 64
	449428,   # Level 65
	496254,   # Level 66
	547953,   # Level 67
	605032,   # Level 68
	668051,   # Level 69
	737627,   # Level 70
	814445,   # Level 71
	899257,   # Level 72
	992895,   # Level 73
	1096278,  # Level 74
	1210421,  # Level 75
	1336443,  # Level 76
	1475581,  # Level 77
	1629200,  # Level 78
	1798808,  # Level 79
	1986068,  # Level 80
	2192818,  # Level 81
	2421087,  # Level 82
	2673114,  # Level 83
	2951373,  # Level 84
	3258594,  # Level 85
	3597792,  # Level 86
	3972294,  # Level 87
	4385776,  # Level 88
	4842295,  # Level 89
	5346332,  # Level 90
	5902831,  # Level 91
	6517253,  # Level 92
	7195629,  # Level 93
	7944614,  # Level 94
	8771558,  # Level 95
	9684577,  # Level 96
	10692629, # Level 97
	11805606, # Level 98
	13034431  # Level 99
]

# Player's skills
var skills: Dictionary = {}

func _ready():
	_initialize_skills()

func _initialize_skills():
	# Only initialize default skills if none exist
	if skills.is_empty():
		skills[Skill.SkillType.WOODCUTTING] = Skill.new("Woodcutting", Skill.SkillType.WOODCUTTING)
	
	# Connect skill signals for all skills
	_connect_skill_signals()

func _connect_skill_signals():
	# Connect skill signals for all skills
	for skill in skills.values():
		if not skill.level_changed.is_connected(_on_skill_level_changed):
			skill.level_changed.connect(_on_skill_level_changed)
		if not skill.xp_gained.is_connected(_on_skill_xp_gained):
			skill.xp_gained.connect(_on_skill_xp_gained)

func get_skill(skill_type: Skill.SkillType) -> Skill:
	return skills.get(skill_type)

func add_skill_xp(skill_type: Skill.SkillType, amount: int):
	var skill = get_skill(skill_type)
	if skill:
		skill.add_xp(amount)
	

func get_level_for_xp(xp: int) -> int:
	if xp <= 0:
		return 1
	
	# Binary search through XP table
	for level in range(XP_TABLE.size() - 1, 0, -1):
		if xp >= XP_TABLE[level]:
			return level + 1
	
	return 1

func get_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	if level > 99:
		return XP_TABLE[-1]  # Max XP at level 99
	
	return XP_TABLE[level - 1]

func get_xp_difference_for_level(level: int) -> int:
	if level <= 1:
		return 0
	if level > 99:
		return 0
	
	var current_level_xp = get_xp_for_level(level)
	var previous_level_xp = get_xp_for_level(level - 1)
	return current_level_xp - previous_level_xp

func calculate_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	
	var total = 0.0
	for i in range(2, level + 1):
		total += floor(float(i - 1) + 300.0 * pow(2.0, float(i - 1) / 7.0)) / 4.0
	
	return int(total)

func get_total_level() -> int:
	var total = 0
	for skill in skills.values():
		total += skill.current_level
	return total

func get_total_xp() -> int:
	var total = 0
	for skill in skills.values():
		total += skill.current_xp
	return total

func get_skill_data() -> Dictionary:
	var data = {}
	for skill_type in skills:
		data[skill_type] = skills[skill_type].get_save_data()
	return data

func load_skill_data(data: Dictionary):
	for skill_type_key in data:
		# Convert string key back to enum value
		var skill_type = int(skill_type_key)
		var skill = get_skill(skill_type)
		if skill:
			skill.load_save_data(data[skill_type_key])
		else:
			# Create skill if it doesn't exist
			var new_skill = Skill.new()
			new_skill.load_save_data(data[skill_type_key])
			skills[skill_type] = new_skill
	
	# Reconnect all signals after loading
	_connect_skill_signals()

func _on_skill_level_changed(skill: Skill, old_level: int, new_level: int):
	skill_level_up.emit(skill, old_level, new_level)

func _on_skill_xp_gained(skill: Skill, amount: int):
	skill_xp_gained.emit(skill, amount)

# Debug function to verify XP table accuracy
func _verify_xp_table():
	for level in range(1, 100):
		var table_xp = get_xp_for_level(level)
		var calculated_xp = calculate_xp_for_level(level)
		
		

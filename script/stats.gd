extends Resource
class_name Stats # contains stats for all characters in battle

enum BuffableStats { # stats that can be modified through buffs
	MAX_HP,
	MAX_SP,
	ATK,
	DEF,
	SPD,
}

signal hp_depleted
signal hp_changed(curr_hp: int, max_hp: int)

signal sp_changed(curr_sp: int, max_sp: int)

# base stats that can be set for each character
@export var base_max_hp: int = 15
@export var base_max_sp: int = 15
@export var base_atk: int = 10
@export var base_def: int = 5
@export var base_spd: int = 5

# actual stats used in battle, possibly modified by buffs
var curr_max_hp: int = 15
var curr_max_sp: int = 15
var curr_atk: int = 10
var curr_def: int = 5
var curr_spd: int = 5

# sets current hp and sp using functions
var health: int = 0: set = _on_health_set
var stamina: int = 0: set = _on_stamina_set

# current buffs on a character
var stat_buffs: Array[StatBuff]

func _init() -> void:
	setup_stats.call_deferred()

func setup_stats() -> void: 
	recalculate_stats()
	health = curr_max_hp
	stamina = curr_max_sp

# adds a new buff to the array of current buffs, then recalculates stats
func add_buff(buff: StatBuff) -> void:
	stat_buffs.append(buff)
	recalculate_stats.call_deferred()

# removes a buff from the array of current buffs, then recalculates stats
func remove_buff(buff: StatBuff) -> void:
	stat_buffs.erase(buff)
	recalculate_stats.call_deferred()

func recalculate_stats() -> void:
	# stat name -> amount multiplied by
	var stat_multipliers: Dictionary = {}
	# stat name -> amount added to
	var stat_addends: Dictionary = {}
	
	for buff in stat_buffs:
		# gets stat name in lowercase to look up variable
		var stat_name: String = BuffableStats.keys()[buff.stat].to_lower()
		
		match buff.buff_type:
			StatBuff.BuffType.ADD:
				# adds stat name to addends dictionary if not present
				if not stat_addends.has(stat_name):
					stat_addends[stat_name] = 0.0 # defaults to +0 per stat
					
				# adds the new buff amount to previous total
				stat_addends[stat_name] += buff.buff_amount
			StatBuff.BuffType.MULTIPLY:
				# adds stat name to multiplers dictionary if not present
				if not stat_multipliers.has(stat_name):
					stat_multipliers[stat_name] = 1.0 # defaults to *1 per stat
					
				# adds new buff amount to previous total
				# since each stat starts at *1, buffs should be decimal place only
				stat_multipliers[stat_name] += buff.buff_amount
	
	# stat buff order is mult first, add second (can be changed if desired)
	for stat_name in stat_multipliers:
		# gets name of stat to be buffed
		var curr_property_name: String = str("curr_" + stat_name)
		# sets stat value to stat *= buff amount
		set(curr_property_name, get(curr_property_name) 
			* stat_multipliers[stat_name])
			
	for stat_name in stat_addends:
		# gets name of stat to be buffed
		var curr_property_name: String = str("curr_" + stat_name)
		# sets stat value to stat += buff amount
		set(curr_property_name, get(curr_property_name) 
			+ stat_addends[stat_name])

func _on_health_set(new_value: int) -> void:
	health = clampi(new_value, 0, curr_max_hp) # sets hp between 0 and max
	hp_changed.emit(health, curr_max_hp) # signal to change health bar
	
	if health <= 0:
		hp_depleted.emit() # signal for when character is dead

func _on_stamina_set(new_value: int) -> void:
	stamina = clampi(new_value, 0 , curr_max_sp) # sets sp between 0 and max
	sp_changed.emit(stamina, curr_max_sp) #signal to change sp bar

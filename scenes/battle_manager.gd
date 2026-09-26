extends Node

func _ready():
	# change state to BATTLE_SETUP
	# load enemies
	pass

func get_turn_order():
	# determines turn order based on speed
	# speed ties = coin flip
	pass

func dog_turn():
	# change state to BATTLE_MENU
	# brings up menu to attack/investigate/inventory/flee
	# attack: pierce = left, bash = up, slice = right, duo = down
	# investigate: gives info about enemy
	# inventory: use item
	# flee: leave battle w/ penalty
	# once action is selected change state to BATTLE_PLAYER_ACTION
	pass

func rat_turn():
	# change state to BATTLE_MENU
	# brings up menu to attack/investigate/inventory/flee
	# attack: pierce = left, bash = up, slice = right, duo = down
	# investigate: gives info about enemy
	# inventory: use item
	# flee: leave battle w/ penalty
	# once action is selected change state to BATTLE_PLAYER_ACTION
	pass

func enemy_turn():
	# change state to BATTLE_ENEMY_ACTION
	# enemy picks an attack, area, and target
	# enemy begins attack, player can dodge/parry with good timing
	pass
	
func turn_resolution():
	# change state to BATTLE_WAITING
	# check for battle exit conditions: victory, loss, flee
	# victory: all enemies are defeated, player gets items/money
	# loss: dog & rat hp = 0, player gets game over > back to menu?
	# flee: player selected flee action, loses items/money
	# if battle continues, change state to BATTLE_SETUP
	# update stat changes if necessary
	# update turn order if necessary
	pass

# stamina: player can use a certain amount of stamina to
# add extra attacks to their attack combo. stamina has a flat gain
# per round + extra for dodging/parrying during enemy turn
# stamina loss for unsuccessful dodge/parry
# can use half/entire(?) stamina bar for duo attack

# triangle: pierce > bash > slice (duo always effective?) 

func disable() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED

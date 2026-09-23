extends Node

# state machine
enum GameState {
	NULL = 0,
	WORLD = 1, # overworld interactions: BATTLE_WAITING | MENU --> WORLD --> BATTLE_SETUP | MENU
	INTERACTING = 2, # MID INTERACTIOn
	MENU = 4, # BATTLE_MENU --> MENU --> BATTLE_MENU | WORLD
	BATTLE_SETUP = 8, # battle setup and turn resolution: WORLD --> BATTLE_SETUP -->
	BATTLE_MENU = 16, # player choosing actions from menus: IN_BATTLE
	BATTLE_PLAYER_ACTION = 32, # mid attack/defense action: IN_BATTLE_MENU | IN_BATTLE_ENEMY_ACTION
	BATTLE_ENEMY_ACTION = 64, # AI action, player can respond
	BATTLE_WAITING = 128, # turn resolution, if all dead battle ends
}

var current_game_state: GameState

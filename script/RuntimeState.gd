extends Node

# state machine
enum GameState {
	WORLD, # overworld interactions: BATTLE_WAITING | MENU --> WORLD --> BATTLE_SETUP | MENU
	MENU, # BATTLE_MENU --> MENU --> BATTLE_MENU | WORLD
	BATTLE_SETUP, # battle setup and turn resolution: WORLD --> BATTLE_SETUP --> 
	BATTLE_MENU, # player choosing actions from menus: IN_BATTLE
	BATTLE_PLAYER_ACTION, # mid attack/defense action: IN_BATTLE_MENU | IN_BATTLE_ENEMY_ACTION
	BATTLE_ENEMY_ACTION, # AI action, player can respond
	BATTLE_WAITING, # turn resolution, if all dead battle ends
}

var current_game_state: GameState

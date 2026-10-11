class_name EnemyData
extends Resource
## Static definition of an enemy type. Instances live in res://data/enemies/*.tres.

enum Movement {
	## Never moves.
	STATIONARY,
	## Steps to a random open neighbouring tile (seeded RNG).
	WANDER,
	## Steps one row toward the player's row; holds still once aligned.
	TRACK_ROW,
}

@export var id: StringName
@export var display_name: String = ""
@export var max_hp: int = 100

@export_group("Movement")
@export var movement: Movement = Movement.STATIONARY
@export var move_interval_ticks: int = 60

@export_group("Attack")
## Uses the same CardData format as player cards. Null = never attacks.
@export var attack: CardData
## Ticks between the end of one attack and the start of the next wind-up.
## Also the delay before the first attack of the battle.
@export var attack_cooldown_ticks: int = 120
## Telegraph time: the target tiles are shown for this many ticks before the hit.
@export var attack_windup_ticks: int = 30
## Only start an attack while in the same row as the player.
@export var attack_requires_alignment: bool = false

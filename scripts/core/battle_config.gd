class_name BattleConfig
extends Resource
## Tunables for one battle. The default lives in res://data/battle_config_default.tres.

@export_group("Timing")
@export var ticks_per_second: int = 60
## Seconds of active combat before the Focus gauge is full. 0 = always available.
@export var focus_gauge_seconds: float = 8.0
@export var move_cooldown_ticks: int = 6
@export var basic_attack_cooldown_ticks: int = 12

@export_group("Cards")
@export var hand_size: int = 5
@export var max_cards_per_focus: int = 3
## Reshuffles allowed per battle. -1 = unlimited.
@export var reshuffles_per_battle: int = 1
@export var starter_deck: Array[CardData] = []

@export_group("Combat")
@export var player_max_hp: int = 100
@export var player_start_cell := Vector2i(1, 1)
@export var basic_attack_damage: int = 5
## Enemies placed at battle start, stepped in this order every tick.
@export var enemy_spawns: Array[EnemySpawn] = []

@export_group("Randomness")
## Seed for deck shuffles. 0 = pick a random seed at battle start.
@export var rng_seed: int = 0


func focus_gauge_ticks() -> int:
	return roundi(focus_gauge_seconds * ticks_per_second)

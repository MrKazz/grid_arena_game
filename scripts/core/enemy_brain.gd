class_name EnemyBrain
extends RefCounted
## Drives one enemy: movement timer, attack cooldown, and a telegraphed
## wind-up. Owned and stepped by BattleState, once per tick, in spawn order.
##
## Per tick: while winding up, count down and fire at zero (no movement).
## Otherwise tick the timers, then start an attack if ready, else move if ready.

var data: EnemyData
var combatant: Combatant
## Tiles shown as a warning during wind-up. Empty when not winding up.
var telegraph: Array[Vector2i] = []
var windup_left := 0

var _move_timer: int
var _attack_timer: int


func _init(p_data: EnemyData, p_combatant: Combatant) -> void:
	data = p_data
	combatant = p_combatant
	_move_timer = data.move_interval_ticks
	_attack_timer = data.attack_cooldown_ticks


func is_winding_up() -> bool:
	return windup_left > 0


## Fraction of the wind-up already elapsed, for the view.
func windup_progress() -> float:
	if not is_winding_up() or data.attack_windup_ticks <= 0:
		return 0.0
	return 1.0 - float(windup_left) / data.attack_windup_ticks


func step(state: BattleState, rng: RandomNumberGenerator) -> void:
	if not combatant.is_alive():
		telegraph.clear()
		windup_left = 0
		return
	if is_winding_up():
		windup_left -= 1
		if windup_left == 0:
			_fire(state)
		return
	_move_timer = maxi(0, _move_timer - 1)
	_attack_timer = maxi(0, _attack_timer - 1)
	if _attack_timer == 0 and _wants_to_attack(state):
		_start_windup(state)
	elif _move_timer == 0:
		_move(state, rng)
		_move_timer = data.move_interval_ticks


func _wants_to_attack(state: BattleState) -> bool:
	if data.attack == null:
		return false
	return not data.attack_requires_alignment or combatant.cell.y == state.player.cell.y


func _start_windup(state: BattleState) -> void:
	telegraph = CardResolver.telegraph_cells(data.attack, combatant, state.grid)
	windup_left = data.attack_windup_ticks
	if windup_left <= 0:
		_fire(state)


func _fire(state: BattleState) -> void:
	# Projectiles resolve against whoever is in the row now; area attacks hit
	# the tiles that were telegraphed, so stepping off them dodges.
	var cells := telegraph
	if data.attack.targeting == CardData.Targeting.ROW_FIRST_HIT:
		cells = CardResolver.target_cells(data.attack, combatant, state.grid)
	telegraph = []
	windup_left = 0
	_attack_timer = data.attack_cooldown_ticks
	state.resolve_attack(combatant, data.attack, cells)


func _move(state: BattleState, rng: RandomNumberGenerator) -> void:
	var grid := state.grid
	match data.movement:
		EnemyData.Movement.WANDER:
			var options := grid.open_neighbours(combatant.cell, combatant.side)
			if not options.is_empty():
				grid.move(combatant, options[rng.randi_range(0, options.size() - 1)])
		EnemyData.Movement.TRACK_ROW:
			var dy := signi(state.player.cell.y - combatant.cell.y)
			if dy != 0:
				grid.move(combatant, combatant.cell + Vector2i(0, dy))

class_name BattleState
extends RefCounted
## The whole battle simulation, independent of nodes and rendering.
##
## Drive it by calling step() once per fixed tick while ACTIVE, plus the
## try_*/plan methods in response to input. Same seed + same calls in the
## same order = same result, which is what the replay tests rely on.

enum Phase { PLANNING, ACTIVE, ENDED }

signal phase_changed(phase: Phase)
signal card_used(user: Combatant, card: CardData, cells: Array[Vector2i], hits: Array[Combatant])

var config: BattleConfig
var grid := GridModel.new()
var deck: Deck
var gauge: PlanGauge
var player: Combatant
var enemies: Array[Combatant] = []
var phase := Phase.PLANNING
var tick_count := 0
var rng_seed: int
## Cards chosen during planning, used front-first with try_use_card().
var queued_cards: Array[CardData] = []
var reshuffles_left: int
## GridModel.Side of the winner once ENDED, otherwise -1.
var winner := -1

var _basic_attack: CardData
var _move_cooldown := 0
var _attack_cooldown := 0


func _init(p_config: BattleConfig) -> void:
	config = p_config
	rng_seed = config.rng_seed if config.rng_seed != 0 else randi()
	deck = Deck.new(config.starter_deck, config.hand_size, rng_seed)
	gauge = PlanGauge.new(config.plan_gauge_ticks())
	reshuffles_left = config.reshuffles_per_battle

	_basic_attack = CardData.new()
	_basic_attack.id = &"basic_attack"
	_basic_attack.display_name = "Basic Attack"
	_basic_attack.damage = config.basic_attack_damage
	_basic_attack.targeting = CardData.Targeting.ROW_FIRST_HIT

	player = Combatant.new(&"player", GridModel.Side.PLAYER, config.player_max_hp)
	var placed := grid.place(player, config.player_start_cell)
	assert(placed, "player_start_cell must be an empty player-side tile")

	# Battles open in the planning phase with a full hand.
	deck.fill_hand()


func add_enemy(enemy: Combatant, cell: Vector2i) -> bool:
	if not grid.place(enemy, cell):
		return false
	enemies.append(enemy)
	return true


## Advances the simulation by one fixed tick. No-op unless ACTIVE.
func step() -> void:
	if phase != Phase.ACTIVE:
		return
	tick_count += 1
	gauge.tick()
	_move_cooldown = maxi(0, _move_cooldown - 1)
	_attack_cooldown = maxi(0, _attack_cooldown - 1)


func try_move(direction: Vector2i) -> bool:
	if phase != Phase.ACTIVE or _move_cooldown > 0:
		return false
	if not grid.move(player, player.cell + direction):
		return false
	_move_cooldown = config.move_cooldown_ticks
	return true


func try_basic_attack() -> Array[Combatant]:
	if phase != Phase.ACTIVE or _attack_cooldown > 0:
		return []
	_attack_cooldown = config.basic_attack_cooldown_ticks
	return _use(player, _basic_attack)


func try_use_card() -> Array[Combatant]:
	if phase != Phase.ACTIVE or queued_cards.is_empty():
		return []
	var card: CardData = queued_cards.pop_front()
	deck.discard(card)
	return _use(player, card)


func can_open_plan() -> bool:
	return phase == Phase.ACTIVE and gauge.is_full()


## Pauses combat and tops the hand back up.
func open_plan() -> bool:
	if not can_open_plan():
		return false
	deck.fill_hand()
	_set_phase(Phase.PLANNING)
	return true


## Queues the chosen hand cards (in the given order) and resumes combat.
## Fails without changing anything if the selection is invalid.
func confirm_plan(hand_indices: Array[int]) -> bool:
	if phase != Phase.PLANNING or hand_indices.size() > config.max_cards_per_plan:
		return false
	var taken := deck.take_from_hand(hand_indices)
	if taken.size() != hand_indices.size():
		return false
	queued_cards.append_array(taken)
	gauge.reset()
	_set_phase(Phase.ACTIVE)
	return true


## Swaps the current hand for a fresh draw. Only while planning.
func reshuffle() -> bool:
	if phase != Phase.PLANNING or reshuffles_left == 0:
		return false
	deck.reshuffle_hand()
	if reshuffles_left > 0:
		reshuffles_left -= 1
	return true


func living_enemies() -> Array[Combatant]:
	var alive: Array[Combatant] = []
	for enemy in enemies:
		if enemy.is_alive():
			alive.append(enemy)
	return alive


func _use(user: Combatant, card: CardData) -> Array[Combatant]:
	var cells := CardResolver.target_cells(card, user, grid)
	var hits := CardResolver.apply(card, user, grid)
	for hit in hits:
		if not hit.is_alive():
			grid.remove(hit)
	card_used.emit(user, card, cells, hits)
	_check_end()
	return hits


func _check_end() -> void:
	if phase == Phase.ENDED:
		return
	if not player.is_alive():
		winner = GridModel.Side.ENEMY
		_set_phase(Phase.ENDED)
	elif not enemies.is_empty() and living_enemies().is_empty():
		winner = GridModel.Side.PLAYER
		_set_phase(Phase.ENDED)


func _set_phase(new_phase: Phase) -> void:
	if phase == new_phase:
		return
	phase = new_phase
	phase_changed.emit(phase)

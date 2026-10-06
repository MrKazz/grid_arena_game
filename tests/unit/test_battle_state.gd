extends TestCase

var state: BattleState
var dummy: Combatant


func before_each() -> void:
	state = BattleState.new(Fixtures.config())
	dummy = Combatant.new(&"dummy", GridModel.Side.ENEMY, 50)
	state.add_enemy(dummy, Vector2i(5, 1))


func _start_combat() -> void:
	assert_true(state.confirm_plan([]), "confirm empty plan")


func _step(ticks: int) -> void:
	for i in ticks:
		state.step()


func test_battle_opens_in_planning_with_full_hand() -> void:
	assert_eq(state.phase, BattleState.Phase.PLANNING)
	assert_eq(state.deck.hand.size(), 5)
	assert_eq(state.player.cell, Vector2i(1, 1))


func test_step_does_nothing_while_planning() -> void:
	_step(10)
	assert_eq(state.tick_count, 0)
	assert_eq(state.gauge.ticks, 0)


func test_confirm_plan_queues_cards_in_order_and_resumes() -> void:
	var first := state.deck.hand[2]
	var second := state.deck.hand[0]
	assert_true(state.confirm_plan([2, 0]))
	assert_eq(state.phase, BattleState.Phase.ACTIVE)
	assert_eq(state.queued_cards, [first, second])
	assert_eq(state.deck.hand.size(), 3)


func test_confirm_plan_rejects_invalid_selection() -> void:
	assert_false(state.confirm_plan([0, 1, 2, 3]), "over max_cards_per_plan")
	assert_false(state.confirm_plan([1, 1]), "duplicate")
	assert_false(state.confirm_plan([9]), "out of range")
	assert_eq(state.phase, BattleState.Phase.PLANNING)
	assert_eq(state.deck.hand.size(), 5)


func test_plan_only_opens_when_gauge_full() -> void:
	_start_combat()
	assert_false(state.open_plan())
	_step(59)
	assert_false(state.can_open_plan())
	_step(1)
	assert_true(state.open_plan())
	assert_eq(state.phase, BattleState.Phase.PLANNING)


func test_opening_plan_refills_hand() -> void:
	state.confirm_plan([0, 1])
	_step(60)
	state.open_plan()
	assert_eq(state.deck.hand.size(), 5)


func test_confirm_resets_gauge() -> void:
	_start_combat()
	_step(60)
	state.open_plan()
	state.confirm_plan([])
	assert_eq(state.gauge.ticks, 0)


func test_reshuffle_only_while_planning_and_limited() -> void:
	assert_true(state.reshuffle())
	assert_eq(state.reshuffles_left, 0)
	assert_false(state.reshuffle(), "out of charges")
	assert_eq(state.deck.hand.size(), 5)


func test_reshuffle_blocked_during_combat() -> void:
	_start_combat()
	assert_false(state.reshuffle())
	assert_eq(state.reshuffles_left, 1)


func test_unlimited_reshuffles() -> void:
	var cfg := Fixtures.config()
	cfg.reshuffles_per_battle = -1
	var s := BattleState.new(cfg)
	for i in 5:
		assert_true(s.reshuffle(), "reshuffle %d" % i)


func test_move_respects_cooldown_and_border() -> void:
	assert_false(state.try_move(Vector2i.RIGHT), "not while planning")
	_start_combat()
	assert_true(state.try_move(Vector2i.RIGHT))
	assert_false(state.try_move(Vector2i.RIGHT), "cooldown")
	_step(4)
	assert_true(state.try_move(Vector2i.RIGHT))
	assert_eq(state.player.cell, Vector2i(3, 1))
	_step(4)
	assert_false(state.try_move(Vector2i.RIGHT), "enemy side")
	assert_eq(state.player.cell, Vector2i(3, 1))


func test_basic_attack_hits_and_cools_down() -> void:
	_start_combat()
	assert_eq(state.try_basic_attack(), [dummy])
	assert_eq(dummy.hp, 45)
	assert_eq(state.try_basic_attack().size(), 0, "cooldown")
	_step(10)
	state.try_basic_attack()
	assert_eq(dummy.hp, 40)


func test_using_card_discards_it() -> void:
	var card := state.deck.hand[0]
	state.confirm_plan([0])
	state.try_use_card()
	assert_eq(state.queued_cards.size(), 0)
	assert_eq(state.deck.discard_pile, [card])
	assert_eq(state.try_use_card().size(), 0, "queue empty")


func test_card_used_signal_reports_cells() -> void:
	var events := []
	state.card_used.connect(func(_u, card, cells, _h): events.append([card.id, cells]))
	_start_combat()
	state.try_basic_attack()
	assert_eq(events, [[&"basic_attack", [Vector2i(5, 1)]]])


func test_killing_last_enemy_wins() -> void:
	var cfg := Fixtures.config()
	cfg.basic_attack_damage = 50
	var s := BattleState.new(cfg)
	var e := Combatant.new(&"e", GridModel.Side.ENEMY, 50)
	s.add_enemy(e, Vector2i(6, 1))
	s.confirm_plan([])
	s.try_basic_attack()
	assert_eq(s.phase, BattleState.Phase.ENDED)
	assert_eq(s.winner, GridModel.Side.PLAYER)
	assert_null(s.grid.occupant_at(Vector2i(6, 1)), "dead enemies leave the grid")
	s.step()
	assert_eq(s.tick_count, 0, "no ticks after the battle ends")


func test_zero_seed_picks_a_seed() -> void:
	var cfg := Fixtures.config(0)
	var s := BattleState.new(cfg)
	assert_ne(s.rng_seed, 0)

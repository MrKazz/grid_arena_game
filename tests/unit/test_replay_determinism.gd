extends TestCase
## Same seed + same inputs must give the same battle. This is the foundation
## for recorded-input regression tests and, later, rollback netcode.

const SCRIPT_LENGTH := 600


## A fixed, varied input script: moves, attacks, card use, planning, reshuffles.
func _play(rng_seed: int) -> Dictionary:
	var state := BattleState.new(Fixtures.config(rng_seed))
	var dummy := Combatant.new(&"dummy", GridModel.Side.ENEMY, 10000)
	state.add_enemy(dummy, Vector2i(5, 1))
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	state.reshuffle()
	state.confirm_plan([0, 2])
	for t in SCRIPT_LENGTH:
		if state.phase == BattleState.Phase.PLANNING:
			state.confirm_plan([1, 0])
		if t % 7 == 0:
			state.try_move(dirs[(t / 7) % dirs.size()])
		if t % 11 == 0:
			state.try_basic_attack()
		if t % 37 == 0:
			state.try_use_card()
		state.open_plan()
		state.step()
	return {
		"tick": state.tick_count,
		"cell": state.player.cell,
		"dummy_hp": dummy.hp,
		"hand": Fixtures.ids(state.deck.hand),
		"queue": Fixtures.ids(state.queued_cards),
		"discard": Fixtures.ids(state.deck.discard_pile),
	}


func test_same_seed_same_outcome() -> void:
	assert_eq(_play(2024), _play(2024))


func test_script_actually_exercises_the_battle() -> void:
	var result := _play(2024)
	assert_true(result["dummy_hp"] < 10000, "dummy took damage")
	assert_true(result["discard"].size() > 0, "cards were used")

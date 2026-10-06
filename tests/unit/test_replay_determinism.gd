extends TestCase
## Same seed + same inputs must give the same battle. This is the foundation
## for recorded-input regression tests and, later, rollback netcode.

const SCRIPT_LENGTH := 600


## A fixed, varied input script: moves, attacks, card use, planning, reshuffles.
func _play(rng_seed: int) -> Dictionary:
	var cfg := Fixtures.config(rng_seed)
	cfg.player_max_hp = 10000
	var state := BattleState.new(cfg)
	var dummy := Combatant.new(&"dummy", GridModel.Side.ENEMY, 10000)
	state.add_enemy(dummy, Vector2i(5, 1))
	var lob := Fixtures.card(&"lob", 7, CardData.Targeting.AIMED, [])
	var shot := Fixtures.card(&"shot", 3, CardData.Targeting.ROW_FIRST_HIT, [])
	var wanderer := state.spawn_enemy(
			Fixtures.enemy(&"wanderer", EnemyData.Movement.WANDER, lob, 40, 15, 9, 10000), Vector2i(7, 0))
	var tracker := state.spawn_enemy(
			Fixtures.enemy(&"tracker", EnemyData.Movement.TRACK_ROW, shot, 30, 10, 13, 10000), Vector2i(6, 3))
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
		"player_hp": state.player.hp,
		"wanderer_cell": wanderer.combatant.cell,
		"tracker_cell": tracker.combatant.cell,
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
	assert_true(result["player_hp"] < 10000, "enemies landed hits")


func test_different_seed_changes_enemy_movement() -> void:
	assert_ne(_play(2024)["wanderer_cell"], _play(1)["wanderer_cell"])

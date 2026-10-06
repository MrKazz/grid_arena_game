extends TestCase
## The gray middle column (x = 3): either side may stand there, but each tile
## holds one combatant at a time. It frees up when that combatant moves off or dies.

const N := GridModel.NEUTRAL_COLUMN

var grid: GridModel


func before_each() -> void:
	grid = GridModel.new()


func test_every_row_of_the_middle_column_is_neutral() -> void:
	for y in GridModel.ROWS:
		assert_eq(grid.owner_of(Vector2i(N, y)), GridModel.Side.NEUTRAL, "row %d" % y)


func test_both_sides_can_step_into_neutral() -> void:
	var p := Combatant.new(&"p", GridModel.Side.PLAYER, 10)
	var e := Combatant.new(&"e", GridModel.Side.ENEMY, 10)
	grid.place(p, Vector2i(N - 1, 0))
	grid.place(e, Vector2i(N + 1, 1))
	assert_true(grid.move(p, Vector2i(N, 0)), "player enters neutral")
	assert_true(grid.move(e, Vector2i(N, 1)), "enemy enters neutral")


func test_occupied_neutral_tile_blocks_everyone() -> void:
	var p := Combatant.new(&"p", GridModel.Side.PLAYER, 10)
	var ally := Combatant.new(&"ally", GridModel.Side.PLAYER, 10)
	var e := Combatant.new(&"e", GridModel.Side.ENEMY, 10)
	grid.place(p, Vector2i(N, 2))
	grid.place(ally, Vector2i(N - 1, 2))
	grid.place(e, Vector2i(N + 1, 2))
	assert_false(grid.move(e, Vector2i(N, 2)), "opponent blocked")
	assert_false(grid.move(ally, Vector2i(N, 2)), "ally blocked")
	assert_false(grid.can_enter(GridModel.Side.ENEMY, Vector2i(N, 2)))
	assert_false(grid.can_enter(GridModel.Side.PLAYER, Vector2i(N, 2)))
	assert_eq(grid.occupant_at(Vector2i(N, 2)), p)


func test_tile_frees_when_occupant_moves_off() -> void:
	var p := Combatant.new(&"p", GridModel.Side.PLAYER, 10)
	var e := Combatant.new(&"e", GridModel.Side.ENEMY, 10)
	grid.place(p, Vector2i(N, 2))
	grid.place(e, Vector2i(N + 1, 2))
	assert_true(grid.move(p, Vector2i(N - 1, 2)))
	assert_true(grid.move(e, Vector2i(N, 2)))


func test_neutral_is_not_a_bridge_to_the_other_side() -> void:
	var p := Combatant.new(&"p", GridModel.Side.PLAYER, 10)
	var e := Combatant.new(&"e", GridModel.Side.ENEMY, 10)
	grid.place(p, Vector2i(N, 0))
	grid.place(e, Vector2i(N, 3))
	assert_false(grid.move(p, Vector2i(N + 1, 0)), "player can't continue onto enemy tiles")
	assert_false(grid.move(e, Vector2i(N - 1, 3)), "enemy can't continue onto player tiles")
	assert_true(grid.move(p, Vector2i(N, 1)), "moving within the neutral column is fine")


# --- Through BattleState (player at (1, 1), 100 HP) ---------------------------

func _active_state() -> BattleState:
	var state := BattleState.new(Fixtures.config())
	state.confirm_plan([])
	return state


func _walk_player_to_neutral(state: BattleState) -> void:
	for i in 2:
		assert_true(state.try_move(Vector2i.RIGHT), "step %d" % i)
		for t in state.config.move_cooldown_ticks:
			state.step()


func test_player_blocked_until_enemy_on_neutral_tile_dies() -> void:
	var state := _active_state()
	var e := Combatant.new(&"e", GridModel.Side.ENEMY, 5)
	state.add_enemy(e, Vector2i(N, 1))
	state.add_enemy(Combatant.new(&"other", GridModel.Side.ENEMY, 100), Vector2i(6, 3))
	assert_true(state.try_move(Vector2i.RIGHT))
	for t in state.config.move_cooldown_ticks:
		state.step()
	assert_false(state.try_move(Vector2i.RIGHT), "neutral tile taken")
	assert_eq(state.player.cell, Vector2i(2, 1))
	state.try_basic_attack()
	assert_false(e.is_alive())
	assert_null(state.grid.occupant_at(Vector2i(N, 1)), "dead combatant leaves the tile")
	assert_true(state.try_move(Vector2i.RIGHT), "tile free after death")
	assert_eq(state.player.cell, Vector2i(N, 1))


func test_wandering_enemy_never_enters_players_neutral_tile() -> void:
	var state := _active_state()
	_walk_player_to_neutral(state)
	assert_eq(state.player.cell, Vector2i(N, 1))
	var brain := state.spawn_enemy(
			Fixtures.enemy(&"w", EnemyData.Movement.WANDER, null, 10, 5, 1), Vector2i(N + 1, 1))
	var neutral_visits := 0
	for i in 400:
		state.step()
		assert_ne(brain.combatant.cell, state.player.cell, "tick %d" % i)
		if brain.combatant.cell.x == N:
			neutral_visits += 1
	assert_eq(state.player.cell, Vector2i(N, 1))
	assert_true(neutral_visits > 0, "enemy still uses the other neutral tiles")


func test_player_on_neutral_tile_can_attack_and_be_hit() -> void:
	var state := _active_state()
	_walk_player_to_neutral(state)
	var slash := Fixtures.card(&"slash", 30, CardData.Targeting.TILES, [Vector2i(1, 0)])
	var e := Combatant.new(&"e", GridModel.Side.ENEMY, 100)
	state.add_enemy(e, Vector2i(N + 1, 1))
	state.resolve_attack(state.player, slash, CardResolver.target_cells(slash, state.player, state.grid))
	assert_eq(e.hp, 70, "adjacent enemy hit from the neutral column")
	state.resolve_attack(e, slash, CardResolver.target_cells(slash, e, state.grid))
	assert_eq(state.player.hp, 70, "mirrored attack reaches the neutral column")

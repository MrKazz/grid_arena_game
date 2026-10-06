extends TestCase

var grid: GridModel


func before_each() -> void:
	grid = GridModel.new()


func test_dimensions_are_8_by_4() -> void:
	assert_eq(GridModel.COLUMNS, 8)
	assert_eq(GridModel.ROWS, 4)
	assert_true(GridModel.is_in_bounds(Vector2i(7, 3)))
	assert_false(GridModel.is_in_bounds(Vector2i(8, 0)))
	assert_false(GridModel.is_in_bounds(Vector2i(0, 4)))
	assert_false(GridModel.is_in_bounds(Vector2i(-1, 0)))


func test_left_half_player_right_half_enemy() -> void:
	for y in GridModel.ROWS:
		for x in GridModel.COLUMNS:
			var expected := GridModel.Side.PLAYER if x < 4 else GridModel.Side.ENEMY
			assert_eq(grid.owner_of(Vector2i(x, y)), expected, "cell %d,%d" % [x, y])


func test_facing() -> void:
	assert_eq(GridModel.facing(GridModel.Side.PLAYER), 1)
	assert_eq(GridModel.facing(GridModel.Side.ENEMY), -1)


func test_can_only_place_on_own_empty_tiles() -> void:
	var a := Combatant.new(&"a", GridModel.Side.PLAYER, 10)
	var b := Combatant.new(&"b", GridModel.Side.PLAYER, 10)
	assert_false(grid.place(a, Vector2i(4, 0)), "enemy tile")
	assert_false(grid.place(a, Vector2i(-1, 0)), "out of bounds")
	assert_true(grid.place(a, Vector2i(3, 0)))
	assert_eq(a.cell, Vector2i(3, 0))
	assert_false(grid.place(b, Vector2i(3, 0)), "occupied")


func test_move_updates_cell_and_occupancy() -> void:
	var a := Combatant.new(&"a", GridModel.Side.PLAYER, 10)
	grid.place(a, Vector2i(0, 0))
	assert_true(grid.move(a, Vector2i(1, 0)))
	assert_eq(a.cell, Vector2i(1, 0))
	assert_null(grid.occupant_at(Vector2i(0, 0)))
	assert_eq(grid.occupant_at(Vector2i(1, 0)), a)


func test_cannot_move_across_the_border() -> void:
	var a := Combatant.new(&"a", GridModel.Side.PLAYER, 10)
	grid.place(a, Vector2i(3, 2))
	assert_false(grid.move(a, Vector2i(4, 2)))
	assert_eq(a.cell, Vector2i(3, 2))


func test_ownership_change_lets_side_enter() -> void:
	var a := Combatant.new(&"a", GridModel.Side.PLAYER, 10)
	grid.place(a, Vector2i(3, 2))
	grid.set_owner(Vector2i(4, 2), GridModel.Side.PLAYER)
	assert_true(grid.move(a, Vector2i(4, 2)))


func test_first_opponent_in_row_skips_allies_and_other_rows() -> void:
	var me := Combatant.new(&"me", GridModel.Side.PLAYER, 10)
	var ally := Combatant.new(&"ally", GridModel.Side.PLAYER, 10)
	var off_row := Combatant.new(&"off_row", GridModel.Side.ENEMY, 10)
	var target := Combatant.new(&"target", GridModel.Side.ENEMY, 10)
	grid.place(me, Vector2i(0, 1))
	grid.place(ally, Vector2i(2, 1))
	grid.place(off_row, Vector2i(4, 0))
	grid.place(target, Vector2i(6, 1))
	assert_eq(grid.first_opponent_in_row(me.cell, me.side), target)
	assert_eq(grid.first_opponent_in_row(target.cell, target.side), ally)
	assert_null(grid.first_opponent_in_row(Vector2i(0, 3), GridModel.Side.PLAYER))

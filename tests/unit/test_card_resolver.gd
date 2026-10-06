extends TestCase

var grid: GridModel
var player: Combatant
var enemy: Combatant


func before_each() -> void:
	grid = GridModel.new()
	player = Combatant.new(&"player", GridModel.Side.PLAYER, 100)
	enemy = Combatant.new(&"enemy", GridModel.Side.ENEMY, 100)
	grid.place(player, Vector2i(2, 1))
	grid.place(enemy, Vector2i(5, 1))


func test_tile_pattern_is_relative_to_user() -> void:
	var card := Fixtures.card(&"c", 10, CardData.Targeting.TILES, [Vector2i(1, 0), Vector2i(2, -1)])
	assert_eq(CardResolver.target_cells(card, player, grid), [Vector2i(3, 1), Vector2i(4, 0)])


func test_tile_pattern_is_mirrored_for_enemies() -> void:
	var card := Fixtures.card(&"c", 10, CardData.Targeting.TILES, [Vector2i(1, 0), Vector2i(2, -1)])
	assert_eq(CardResolver.target_cells(card, enemy, grid), [Vector2i(4, 1), Vector2i(3, 0)])


func test_off_grid_tiles_are_dropped() -> void:
	var card := Fixtures.card(&"c", 10, CardData.Targeting.TILES, [Vector2i(0, -2), Vector2i(10, 0), Vector2i(1, 0)])
	assert_eq(CardResolver.target_cells(card, player, grid), [Vector2i(3, 1)])


func test_tile_hit_damages_opponent() -> void:
	var card := Fixtures.card(&"c", 30, CardData.Targeting.TILES, [Vector2i(3, 0)])
	var hits := CardResolver.apply(card, player, grid)
	assert_eq(hits, [enemy])
	assert_eq(enemy.hp, 70)


func test_no_friendly_fire() -> void:
	var ally := Combatant.new(&"ally", GridModel.Side.PLAYER, 100)
	grid.place(ally, Vector2i(3, 1))
	var card := Fixtures.card(&"c", 30, CardData.Targeting.TILES, [Vector2i(1, 0)])
	assert_eq(CardResolver.apply(card, player, grid).size(), 0)
	assert_eq(ally.hp, 100)


func test_row_first_hit() -> void:
	var card := Fixtures.card(&"bolt", 40, CardData.Targeting.ROW_FIRST_HIT, [])
	assert_eq(CardResolver.target_cells(card, player, grid), [Vector2i(5, 1)])
	CardResolver.apply(card, player, grid)
	assert_eq(enemy.hp, 60)


func test_row_first_hit_misses_empty_row() -> void:
	grid.move(player, Vector2i(2, 3))
	var card := Fixtures.card(&"bolt", 40, CardData.Targeting.ROW_FIRST_HIT, [])
	assert_eq(CardResolver.target_cells(card, player, grid).size(), 0)
	assert_eq(CardResolver.apply(card, player, grid).size(), 0)


func test_damage_does_not_go_below_zero() -> void:
	var card := Fixtures.card(&"c", 999, CardData.Targeting.TILES, [Vector2i(3, 0)])
	CardResolver.apply(card, player, grid)
	assert_eq(enemy.hp, 0)
	assert_false(enemy.is_alive())

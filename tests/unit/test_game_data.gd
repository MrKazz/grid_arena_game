extends TestCase
## Validates authored content in res://data so bad .tres edits fail fast.

const CARD_DIR := "res://data/cards"
const DEFAULT_CONFIG := "res://data/battle_config_default.tres"


func _all_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	for file in DirAccess.get_files_at(CARD_DIR):
		if file.ends_with(".tres"):
			result.append(load(CARD_DIR.path_join(file)) as CardData)
	return result


func test_cards_load_and_are_valid() -> void:
	var cards := _all_cards()
	assert_true(cards.size() >= 5, "starter cards exist")
	var seen := {}
	for card in cards:
		assert_not_null(card, "card loads as CardData")
		if card == null:
			continue
		assert_false(String(card.id).is_empty(), "card has id")
		assert_false(seen.has(card.id), "unique id %s" % card.id)
		seen[card.id] = true
		assert_false(card.display_name.is_empty(), "%s has a name" % card.id)
		assert_true(card.damage > 0, "%s deals damage" % card.id)
		if card.targeting == CardData.Targeting.TILES:
			assert_false(card.pattern.is_empty(), "%s has a pattern" % card.id)


func test_card_file_name_matches_id() -> void:
	for file in DirAccess.get_files_at(CARD_DIR):
		if file.ends_with(".tres"):
			var card: CardData = load(CARD_DIR.path_join(file))
			assert_eq(String(card.id), file.get_basename())


func test_default_config_is_sane() -> void:
	var cfg: BattleConfig = load(DEFAULT_CONFIG)
	assert_not_null(cfg)
	assert_eq(cfg.starter_deck.size(), 16)
	assert_true(cfg.starter_deck.size() >= cfg.hand_size, "deck can fill a hand")
	assert_true(cfg.max_cards_per_plan <= cfg.hand_size)
	assert_true(cfg.plan_gauge_ticks() >= 0)
	assert_true(GridModel.is_in_bounds(cfg.player_start_cell))
	assert_eq(GridModel.default_owner(cfg.player_start_cell.x), GridModel.Side.PLAYER, "player starts on their side")
	for card in cfg.starter_deck:
		assert_not_null(card, "no empty deck slots")


func _load_dir(dir: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			result.append(load(dir.path_join(file)))
	return result


func test_enemy_attacks_are_valid() -> void:
	for res in _load_dir("res://data/enemy_attacks"):
		var card := res as CardData
		assert_not_null(card, "enemy attack loads as CardData")
		if card == null:
			continue
		assert_eq(String(card.id), res.resource_path.get_file().get_basename())
		assert_true(card.damage > 0, "%s deals damage" % card.id)
		if card.targeting == CardData.Targeting.TILES:
			assert_false(card.pattern.is_empty(), "%s has a pattern" % card.id)


func test_enemies_are_valid() -> void:
	var enemies := _load_dir("res://data/enemies")
	assert_true(enemies.size() >= 1, "enemy definitions exist")
	for res in enemies:
		var enemy := res as EnemyData
		assert_not_null(enemy, "enemy loads as EnemyData")
		if enemy == null:
			continue
		assert_eq(String(enemy.id), res.resource_path.get_file().get_basename())
		assert_false(enemy.display_name.is_empty(), "%s has a name" % enemy.id)
		assert_true(enemy.max_hp > 0, "%s has HP" % enemy.id)
		assert_true(enemy.move_interval_ticks > 0, "%s move interval" % enemy.id)
		if enemy.attack != null:
			assert_true(enemy.attack_cooldown_ticks > 0, "%s attack cooldown" % enemy.id)
			assert_true(enemy.attack_windup_ticks > 0, "%s telegraphs its attack" % enemy.id)


func test_default_enemy_spawns_are_valid() -> void:
	var cfg: BattleConfig = load(DEFAULT_CONFIG)
	assert_true(cfg.enemy_spawns.size() > 0, "default battle has enemies")
	var cells := {}
	for spawn in cfg.enemy_spawns:
		assert_not_null(spawn.enemy, "spawn has an enemy")
		assert_true(GridModel.is_in_bounds(spawn.cell), "spawn %s in bounds" % spawn.cell)
		assert_eq(GridModel.default_owner(spawn.cell.x), GridModel.Side.ENEMY, "spawn %s on enemy side" % spawn.cell)
		assert_false(cells.has(spawn.cell), "spawn %s not shared" % spawn.cell)
		cells[spawn.cell] = true

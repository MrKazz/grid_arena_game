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
	assert_true(cfg.player_start_cell.x < GridModel.PLAYER_COLUMNS, "player starts on their side")
	for card in cfg.starter_deck:
		assert_not_null(card, "no empty deck slots")

class_name Fixtures
extends RefCounted
## Builders for test data so tests don't depend on tuning in res://data.


static func card(id: StringName, damage: int = 10, targeting: CardData.Targeting = CardData.Targeting.TILES,
		pattern: Array[Vector2i] = [Vector2i(1, 0)]) -> CardData:
	var c := CardData.new()
	c.id = id
	c.display_name = String(id)
	c.damage = damage
	c.targeting = targeting
	c.pattern = pattern
	return c


## `count` distinct cards named card_0, card_1, ...
static func cards(count: int) -> Array[CardData]:
	var result: Array[CardData] = []
	for i in count:
		result.append(card(StringName("card_%d" % i)))
	return result


static func ids(cards_in: Array[CardData]) -> Array[StringName]:
	var result: Array[StringName] = []
	for c in cards_in:
		result.append(c.id)
	return result


## Enemy with explicit timings. `attack` may be null for a non-attacker.
static func enemy(id: StringName, movement: EnemyData.Movement = EnemyData.Movement.STATIONARY,
		attack: CardData = null, attack_cooldown_ticks: int = 10, attack_windup_ticks: int = 5,
		move_interval_ticks: int = 10, max_hp: int = 100) -> EnemyData:
	var e := EnemyData.new()
	e.id = id
	e.display_name = String(id)
	e.max_hp = max_hp
	e.movement = movement
	e.move_interval_ticks = move_interval_ticks
	e.attack = attack
	e.attack_cooldown_ticks = attack_cooldown_ticks
	e.attack_windup_ticks = attack_windup_ticks
	return e


## Fast, deterministic config (no enemies): 1s gauge at 60 ticks, fixed seed, 12-card deck.
static func config(rng_seed: int = 1234) -> BattleConfig:
	var cfg := BattleConfig.new()
	cfg.ticks_per_second = 60
	cfg.plan_gauge_seconds = 1.0
	cfg.move_cooldown_ticks = 4
	cfg.basic_attack_cooldown_ticks = 10
	cfg.hand_size = 5
	cfg.max_cards_per_plan = 3
	cfg.reshuffles_per_battle = 1
	cfg.starter_deck = cards(12)
	cfg.player_max_hp = 100
	cfg.player_start_cell = Vector2i(1, 1)
	cfg.basic_attack_damage = 5
	cfg.rng_seed = rng_seed
	return cfg

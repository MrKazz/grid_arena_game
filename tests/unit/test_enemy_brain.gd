extends TestCase
## Enemy movement and telegraphed attacks. Player starts at (1, 1) with 100 HP.

var state: BattleState


func before_each() -> void:
	state = BattleState.new(Fixtures.config())
	state.confirm_plan([])


func _step(ticks: int) -> void:
	for i in ticks:
		state.step()


func _lob(damage: int = 20) -> CardData:
	return Fixtures.card(&"lob", damage, CardData.Targeting.AIMED, [])


func _shot(damage: int = 10) -> CardData:
	return Fixtures.card(&"shot", damage, CardData.Targeting.ROW_FIRST_HIT, [])


func test_stationary_non_attacker_does_nothing() -> void:
	var brain := state.spawn_enemy(Fixtures.enemy(&"dummy"), Vector2i(5, 1))
	_step(300)
	assert_eq(brain.combatant.cell, Vector2i(5, 1))
	assert_false(brain.is_winding_up())
	assert_eq(state.player.hp, 100)


func test_track_row_steps_toward_player_row_once_per_interval() -> void:
	var brain := state.spawn_enemy(Fixtures.enemy(&"tracker", EnemyData.Movement.TRACK_ROW), Vector2i(6, 3))
	_step(9)
	assert_eq(brain.combatant.cell, Vector2i(6, 3), "waits for the interval")
	_step(1)
	assert_eq(brain.combatant.cell, Vector2i(6, 2))
	_step(10)
	assert_eq(brain.combatant.cell, Vector2i(6, 1))
	_step(30)
	assert_eq(brain.combatant.cell, Vector2i(6, 1), "holds once aligned")


func test_track_row_follows_player() -> void:
	var brain := state.spawn_enemy(Fixtures.enemy(&"tracker", EnemyData.Movement.TRACK_ROW), Vector2i(6, 1))
	state.try_move(Vector2i.DOWN)
	_step(10)
	assert_eq(brain.combatant.cell, Vector2i(6, 2))


func test_wander_moves_and_stays_on_enemy_side() -> void:
	var data := Fixtures.enemy(&"wanderer", EnemyData.Movement.WANDER, null, 10, 5, 1)
	var brain := state.spawn_enemy(data, Vector2i(5, 1))
	var visited := {}
	for i in 400:
		state.step()
		visited[brain.combatant.cell] = true
		assert_eq(state.grid.owner_of(brain.combatant.cell), GridModel.Side.ENEMY, "tick %d" % i)
	assert_true(visited.size() >= 8, "explores the enemy half (visited %d tiles)" % visited.size())


func _wander_path(rng_seed: int) -> Array[Vector2i]:
	var s := BattleState.new(Fixtures.config(rng_seed))
	s.confirm_plan([])
	var brain := s.spawn_enemy(Fixtures.enemy(&"w", EnemyData.Movement.WANDER, null, 10, 5, 1), Vector2i(5, 1))
	var path: Array[Vector2i] = []
	for i in 50:
		s.step()
		path.append(brain.combatant.cell)
	return path


func test_wander_is_deterministic_per_seed() -> void:
	assert_eq(_wander_path(7), _wander_path(7))
	assert_ne(_wander_path(7), _wander_path(8))


func test_attack_telegraphs_then_hits_after_windup() -> void:
	var brain := state.spawn_enemy(Fixtures.enemy(&"lobber", EnemyData.Movement.STATIONARY, _lob()), Vector2i(6, 2))
	_step(9)
	assert_false(brain.is_winding_up(), "cooldown not over")
	_step(1)
	assert_true(brain.is_winding_up())
	assert_eq(brain.telegraph, [Vector2i(1, 1)], "aims at the player's tile")
	_step(4)
	assert_eq(state.player.hp, 100, "no damage during wind-up")
	_step(1)
	assert_eq(state.player.hp, 80)
	assert_false(brain.is_winding_up())
	assert_eq(brain.telegraph.size(), 0)


func test_cooldown_restarts_after_each_attack() -> void:
	var brain := state.spawn_enemy(Fixtures.enemy(&"lobber", EnemyData.Movement.STATIONARY, _lob()), Vector2i(6, 2))
	_step(15)
	assert_eq(state.player.hp, 80)
	_step(9)
	assert_false(brain.is_winding_up())
	_step(1)
	assert_true(brain.is_winding_up(), "next wind-up after a full cooldown")
	_step(5)
	assert_eq(state.player.hp, 60)


func test_stepping_off_telegraphed_tile_dodges() -> void:
	state.spawn_enemy(Fixtures.enemy(&"lobber", EnemyData.Movement.STATIONARY, _lob()), Vector2i(6, 2))
	_step(10)
	assert_true(state.try_move(Vector2i.UP))
	_step(5)
	assert_eq(state.player.hp, 100)


func test_no_movement_during_windup() -> void:
	var data := Fixtures.enemy(&"wanderer", EnemyData.Movement.WANDER, _lob(), 3, 20, 1)
	var brain := state.spawn_enemy(data, Vector2i(5, 1))
	_step(3)
	assert_true(brain.is_winding_up())
	var cell := brain.combatant.cell
	_step(19)
	assert_eq(brain.combatant.cell, cell)


func test_aligned_attacker_waits_for_alignment() -> void:
	var data := Fixtures.enemy(&"gunner", EnemyData.Movement.STATIONARY, _shot())
	data.attack_requires_alignment = true
	var brain := state.spawn_enemy(data, Vector2i(6, 3))
	_step(100)
	assert_false(brain.is_winding_up())
	assert_eq(state.player.hp, 100)


func test_projectile_telegraphs_row_and_hits() -> void:
	var data := Fixtures.enemy(&"gunner", EnemyData.Movement.STATIONARY, _shot())
	data.attack_requires_alignment = true
	var brain := state.spawn_enemy(data, Vector2i(6, 1))
	_step(10)
	assert_eq(brain.telegraph, [Vector2i(5, 1), Vector2i(4, 1), Vector2i(3, 1), Vector2i(2, 1),
			Vector2i(1, 1), Vector2i(0, 1)])
	_step(5)
	assert_eq(state.player.hp, 90)


func test_projectile_misses_if_player_leaves_row() -> void:
	var data := Fixtures.enemy(&"gunner", EnemyData.Movement.STATIONARY, _shot())
	state.spawn_enemy(data, Vector2i(6, 1))
	_step(10)
	state.try_move(Vector2i.DOWN)
	_step(5)
	assert_eq(state.player.hp, 100)


func test_enemy_attack_can_end_battle() -> void:
	state.spawn_enemy(Fixtures.enemy(&"lobber", EnemyData.Movement.STATIONARY, _lob(500)), Vector2i(6, 2))
	_step(15)
	assert_eq(state.player.hp, 0)
	assert_eq(state.phase, BattleState.Phase.ENDED)
	assert_eq(state.winner, GridModel.Side.ENEMY)
	var ticks := state.tick_count
	_step(10)
	assert_eq(state.tick_count, ticks)


func test_enemies_frozen_while_planning() -> void:
	var s := BattleState.new(Fixtures.config())
	var brain := s.spawn_enemy(Fixtures.enemy(&"lobber", EnemyData.Movement.WANDER, _lob(), 1, 1, 1), Vector2i(5, 1))
	for i in 100:
		s.step()
	assert_eq(brain.combatant.cell, Vector2i(5, 1))
	assert_eq(s.player.hp, 100)


func test_dead_enemy_cancels_its_attack() -> void:
	var brain := state.spawn_enemy(Fixtures.enemy(&"lobber", EnemyData.Movement.STATIONARY, _lob(), 10, 5, 10, 5), Vector2i(6, 1))
	state.spawn_enemy(Fixtures.enemy(&"dummy"), Vector2i(7, 3))  # keeps the battle going
	_step(10)
	assert_true(brain.is_winding_up())
	state.try_basic_attack()
	assert_false(brain.combatant.is_alive())
	_step(10)
	assert_false(brain.is_winding_up())
	assert_eq(state.player.hp, 100)


func test_enemy_hits_emit_card_used() -> void:
	var users := []
	state.card_used.connect(func(user, _c, _cells, _hits): users.append(user.id))
	state.spawn_enemy(Fixtures.enemy(&"lobber", EnemyData.Movement.STATIONARY, _lob()), Vector2i(6, 2))
	_step(15)
	assert_eq(users, [&"lobber"])


func test_spawns_come_from_config() -> void:
	var cfg := Fixtures.config()
	var spawn := EnemySpawn.new()
	spawn.enemy = Fixtures.enemy(&"from_config", EnemyData.Movement.STATIONARY, null, 10, 5, 10, 33)
	spawn.cell = Vector2i(7, 0)
	cfg.enemy_spawns = [spawn]
	var s := BattleState.new(cfg)
	assert_eq(s.brains.size(), 1)
	assert_eq(s.enemies[0].id, &"from_config")
	assert_eq(s.enemies[0].cell, Vector2i(7, 0))
	assert_eq(s.enemies[0].hp, 33)


func test_spawn_on_invalid_tile_fails() -> void:
	assert_null(state.spawn_enemy(Fixtures.enemy(&"lost"), Vector2i(2, 2)), "player side")
	assert_eq(state.brains.size(), 0)
	assert_eq(state.enemies.size(), 0)

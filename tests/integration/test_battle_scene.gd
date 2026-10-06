extends TestCase
## Smoke tests: the real scene boots, runs, and reacts to input actions.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

var battle: Node


func before_each() -> void:
	battle = (load(BATTLE_SCENE) as PackedScene).instantiate()
	tree.root.add_child(battle)


func after_each() -> void:
	for action in [&"move_right", &"open_plan", &"basic_attack"]:
		Input.action_release(action)
	battle.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(1)


func test_input_actions_are_defined() -> void:
	for action in [&"move_up", &"move_down", &"move_left", &"move_right",
			&"basic_attack", &"use_card", &"open_plan", &"reshuffle"]:
		assert_true(InputMap.has_action(action), "missing action %s" % action)


func test_scene_boots_into_planning() -> void:
	await _frames(5)
	var state: BattleState = battle.state
	assert_not_null(state)
	assert_eq(state.phase, BattleState.Phase.PLANNING)
	assert_eq(state.deck.hand.size(), state.config.hand_size)
	assert_eq(state.enemies.size(), state.config.enemy_spawns.size())
	assert_eq(state.brains.size(), state.enemies.size(), "every spawned enemy has AI")
	assert_true(state.enemies.size() > 0, "default battle has enemies")
	assert_false((battle.get_node("Hud/Info") as Label).text.is_empty(), "hud renders")


func test_confirm_then_move_and_attack_via_input() -> void:
	var state: BattleState = battle.state
	await _tap(&"open_plan")
	assert_eq(state.phase, BattleState.Phase.ACTIVE, "confirm empty plan")
	var start := state.player.cell
	await _tap(&"move_right")
	assert_eq(state.player.cell, start + Vector2i.RIGHT)
	# Lambdas capture locals by value, so collect into an Array. Don't capture
	# `state` itself: that would make a reference cycle through its signal.
	var hits := []
	state.card_used.connect(func(user: Combatant, card: CardData, _c, h: Array[Combatant]) -> void:
		if user.side == GridModel.Side.PLAYER and card.id == &"basic_attack":
			hits.append(h.size()))
	await _tap(&"basic_attack")
	assert_eq(hits.size(), 1, "basic attack fired")
	assert_true(state.tick_count > 0, "simulation advanced")


func test_enemies_act_in_the_real_scene() -> void:
	var state: BattleState = battle.state
	var start: Array[Vector2i] = []
	for enemy in state.enemies:
		start.append(enemy.cell)
	var enemy_attacks := []
	state.card_used.connect(func(user: Combatant, card: CardData, _c, _h) -> void:
		if user.side == GridModel.Side.ENEMY:
			enemy_attacks.append(card.id))
	state.confirm_plan([])
	# Step the state directly (not via frames) so the test stays fast.
	for i in 600:
		state.step()
		if state.phase == BattleState.Phase.PLANNING:
			state.confirm_plan([])
	var moved := false
	for i in state.enemies.size():
		moved = moved or state.enemies[i].cell != start[i]
	assert_true(moved, "some enemy moved within 10 s")
	assert_false(enemy_attacks.is_empty(), "some enemy attacked within 10 s")

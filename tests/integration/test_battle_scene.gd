extends TestCase
## Smoke tests: the real scene boots, runs, and reacts to input actions.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right",
		&"button_a", &"button_b", &"open_focus", &"reshuffle"]

var battle: Node


func before_each() -> void:
	battle = (load(BATTLE_SCENE) as PackedScene).instantiate()
	tree.root.add_child(battle)


func after_each() -> void:
	for action in ACTIONS:
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


func _keycodes(action: StringName) -> Array[int]:
	var codes: Array[int] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			codes.append((event as InputEventKey).physical_keycode)
	return codes


func _ids(cards: Array[CardData]) -> Array[StringName]:
	return Fixtures.ids(cards)


func test_input_actions_are_defined() -> void:
	for action in ACTIONS:
		assert_true(InputMap.has_action(action), "missing action %s" % action)
	assert_false(InputMap.has_action(&"basic_attack"), "replaced by button_b")
	assert_false(InputMap.has_action(&"use_card"), "replaced by button_a")


func test_a_and_b_are_on_zero_and_period_including_numpad() -> void:
	var a := _keycodes(&"button_a")
	assert_true(a.has(KEY_0) and a.has(KEY_KP_0), "A on 0 and numpad 0: %s" % [a])
	var b := _keycodes(&"button_b")
	assert_true(b.has(KEY_PERIOD) and b.has(KEY_KP_PERIOD), "B on . and numpad .: %s" % [b])
	assert_true(_keycodes(&"open_focus").has(KEY_KP_ENTER), "numpad Enter opens Focus")


func test_scene_boots_into_focus_screen() -> void:
	await _frames(5)
	var state: BattleState = battle.state
	assert_not_null(state)
	assert_eq(state.phase, BattleState.Phase.FOCUS)
	assert_eq(state.deck.hand.size(), state.config.hand_size)
	assert_eq(state.enemies.size(), state.config.enemy_spawns.size())
	assert_eq(state.brains.size(), state.enemies.size(), "every spawned enemy has AI")
	assert_true(state.enemies.size() > 0, "default battle has enemies")
	assert_true(battle.focus_panel.visible, "Focus screen shown")
	assert_false(battle.next_card.visible, "Next widget hidden during Focus")
	assert_eq(battle.menu.hand_size, state.deck.hand.size())
	assert_eq(battle.focus_panel.highlighted_card(), state.deck.hand[0], "details show highlighted card")


func test_key_hints_sit_at_the_bottom_and_track_the_phase() -> void:
	await _frames(2)
	var hints: Label = battle.key_hints
	assert_true(hints.position.y >= 300, "hints at the bottom (y=%d)" % hints.position.y)
	assert_true(hints.text.contains("[0]") and hints.text.contains("[.]"), hints.text)
	assert_true(hints.text.contains("undo"), "Focus hints: %s" % hints.text)
	await _tap(&"open_focus")
	assert_true(hints.text.contains("attack"), "battle hints: %s" % hints.text)


func test_pick_cards_rank_them_and_confirm_with_ok() -> void:
	var state: BattleState = battle.state
	var first := state.deck.hand[2]
	var second := state.deck.hand[0]
	await _tap(&"move_right")
	await _tap(&"move_right")
	await _tap(&"button_a")
	await _tap(&"move_left")
	await _tap(&"move_left")
	await _tap(&"button_a")
	assert_eq(battle.menu.picks, [2, 0])
	assert_eq(battle.focus_panel.ranked_queue(), [first, second], "queue shows trigger order")
	await _tap(&"move_down")
	await _tap(&"button_a")
	assert_eq(state.phase, BattleState.Phase.ACTIVE, "OK resumes the battle")
	assert_eq(state.queued_cards, [first, second])
	assert_false(battle.focus_panel.visible)
	assert_true(battle.next_card.visible)
	assert_eq(battle.next_card.displayed_card(), first)


func test_next_widget_advances_and_empties_as_cards_are_used() -> void:
	var state: BattleState = battle.state
	await _tap(&"button_a")
	await _tap(&"move_right")
	await _tap(&"button_a")
	var second: CardData = state.deck.hand[1]
	await _tap(&"open_focus")
	assert_eq(state.phase, BattleState.Phase.ACTIVE)
	await _tap(&"button_a")
	assert_eq(battle.next_card.displayed_card(), second, "advances after use")
	await _tap(&"button_a")
	assert_null(battle.next_card.displayed_card(), "empty once the queue runs out")
	assert_eq(state.deck.discard_pile.size(), 2)


func test_b_undoes_last_pick_in_focus() -> void:
	await _tap(&"button_a")
	await _tap(&"move_right")
	await _tap(&"button_a")
	await _tap(&"button_b")
	assert_eq(battle.menu.picks, [0])


func test_reshuffle_button_redraws_and_clears_picks() -> void:
	var state: BattleState = battle.state
	await _tap(&"button_a")
	await _tap(&"move_down")
	await _tap(&"move_left")
	await _tap(&"button_a")
	assert_eq(state.reshuffles_left, state.config.reshuffles_per_battle - 1)
	assert_eq(battle.menu.picks.size(), 0)
	assert_eq(state.deck.hand.size(), state.config.hand_size)
	assert_eq(state.phase, BattleState.Phase.FOCUS, "still in Focus")


func test_confirm_then_move_and_basic_attack_with_b() -> void:
	var state: BattleState = battle.state
	await _tap(&"open_focus")
	assert_eq(state.phase, BattleState.Phase.ACTIVE, "Space confirms an empty Focus")
	var start := state.player.cell
	await _tap(&"move_right")
	assert_eq(state.player.cell, start + Vector2i.RIGHT)
	# Lambdas capture locals by value, so collect into an Array. Don't capture
	# `state` itself: that would make a reference cycle through its signal.
	var hits := []
	state.card_used.connect(func(user: Combatant, card: CardData, _c, h: Array[Combatant]) -> void:
		if user.side == GridModel.Side.PLAYER and card.id == &"basic_attack":
			hits.append(h.size()))
	await _tap(&"button_b")
	assert_eq(hits.size(), 1, "B fires the basic attack")
	assert_true(state.tick_count > 0, "simulation advanced")


func test_enemies_act_in_the_real_scene() -> void:
	var state: BattleState = battle.state
	var last: Array[Vector2i] = []
	for enemy in state.enemies:
		last.append(enemy.cell)
	var enemy_attacks := []
	state.card_used.connect(func(user: Combatant, card: CardData, _c, _h) -> void:
		if user.side == GridModel.Side.ENEMY:
			enemy_attacks.append(card.id))
	state.confirm_focus([])
	# Step the state directly (not via frames) so the test stays fast.
	# Check for movement on every tick: the scene uses a random seed, and a
	# wandering enemy often ends up back on its starting tile, so comparing
	# only start and end positions fails for about 1 seed in 5.
	var moves := 0
	for i in 600:
		state.step()
		if state.phase == BattleState.Phase.FOCUS:
			state.confirm_focus([])
		for k in state.enemies.size():
			if state.enemies[k].cell != last[k]:
				moves += 1
				last[k] = state.enemies[k].cell
	assert_true(moves > 0, "some enemy moved within 10 s")
	assert_false(enemy_attacks.is_empty(), "some enemy attacked within 10 s")

extends TestCase
## Presses the real keys. These tests send InputEventKey events through
## Input.parse_input_event, the same path an OS keypress takes (key ->
## InputMap -> action -> battle.gd), instead of Input.action_press, which
## skips the key bindings entirely.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const ALL_KEYS: Array[Key] = [KEY_PERIOD, KEY_KP_PERIOD, KEY_0, KEY_KP_0, KEY_SPACE, KEY_ENTER,
		KEY_KP_ENTER, KEY_R, KEY_RIGHT, KEY_DOWN, KEY_D, KEY_S]

var battle: Node


func before_each() -> void:
	_spawn_battle()


func after_each() -> void:
	for code in ALL_KEYS:
		_key(code, false)
	battle.queue_free()
	# Undo any test that tampered with the input map.
	InputMap.load_from_project_settings()


func _spawn_battle() -> void:
	battle = (load(BATTLE_SCENE) as PackedScene).instantiate()
	tree.root.add_child(battle)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	# Deliver now: Godot may otherwise hold scripted events for a few frames,
	# which would make "did the press register?" checks timing-dependent.
	Input.flush_buffered_events()


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


## A normal keypress held for a couple of ticks.
func _press(code: Key) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)
	await _frames(1)


## A tap that goes down and up between two physics ticks.
func _quick_tap(code: Key) -> void:
	await tree.physics_frame
	_key(code, true)
	_key(code, false)
	await _frames(2)


func _state() -> BattleState:
	return battle.state


func _start_battle() -> void:
	await _press(KEY_SPACE)
	assert_eq(_state().phase, BattleState.Phase.ACTIVE, "Space confirms Focus")


func _player_attacks() -> Array:
	# Lambdas capture locals by value, so collect into an Array; don't capture
	# the state itself (reference cycle through its own signal).
	var attacks := []
	_state().card_used.connect(func(user: Combatant, card: CardData, _c, _h) -> void:
		if user.side == GridModel.Side.PLAYER:
			attacks.append(card.id))
	return attacks


# --- Bindings -----------------------------------------------------------------

func test_project_input_map_matches_input_bindings_defaults() -> void:
	for action: StringName in InputBindings.DEFAULTS:
		assert_true(InputMap.has_action(action), "project.godot defines %s" % action)
		var codes: Array = []
		for event in InputMap.action_get_events(action):
			codes.append((event as InputEventKey).physical_keycode)
		assert_eq(codes, InputBindings.DEFAULTS[action], "keys for %s" % action)


# --- Focus screen ---------------------------------------------------------------

func test_period_picks_a_card() -> void:
	await _press(KEY_PERIOD)
	assert_eq(battle.menu.picks, [0])


func test_numpad_period_picks_a_card() -> void:
	await _press(KEY_KP_PERIOD)
	assert_eq(battle.menu.picks, [0])


func test_zero_and_numpad_zero_undo_picks() -> void:
	await _press(KEY_PERIOD)
	await _press(KEY_RIGHT)
	await _press(KEY_PERIOD)
	assert_eq(battle.menu.picks, [0, 1])
	await _press(KEY_0)
	assert_eq(battle.menu.picks, [0], "0 undoes the last pick")
	await _press(KEY_KP_0)
	assert_eq(battle.menu.picks.size(), 0, "numpad 0 undoes too")


func test_space_confirms_focus_with_picks_in_order() -> void:
	var first := _state().deck.hand[1]
	await _press(KEY_D)
	await _press(KEY_PERIOD)
	await _start_battle()
	assert_eq(_state().queued_cards, [first])


func test_enter_and_numpad_enter_confirm_focus() -> void:
	await _press(KEY_ENTER)
	assert_eq(_state().phase, BattleState.Phase.ACTIVE, "Enter")
	battle.queue_free()
	_spawn_battle()
	await _press(KEY_KP_ENTER)
	assert_eq(_state().phase, BattleState.Phase.ACTIVE, "numpad Enter")


func test_period_on_ok_button_confirms_focus() -> void:
	await _press(KEY_DOWN)
	await _press(KEY_PERIOD)
	assert_eq(_state().phase, BattleState.Phase.ACTIVE)


func test_r_reshuffles() -> void:
	var left := _state().reshuffles_left
	await _press(KEY_R)
	assert_eq(_state().reshuffles_left, left - 1)


# --- Battle --------------------------------------------------------------------

func test_period_uses_the_next_card() -> void:
	await _press(KEY_PERIOD)
	await _start_battle()
	assert_eq(_state().queued_cards.size(), 1)
	await _press(KEY_PERIOD)
	assert_eq(_state().queued_cards.size(), 0, ". used the card")
	assert_eq(_state().deck.discard_pile.size(), 1)


func test_zero_and_numpad_zero_fire_the_basic_attack() -> void:
	await _start_battle()
	var attacks := _player_attacks()
	await _press(KEY_0)
	await _frames(_state().config.basic_attack_cooldown_ticks)
	await _press(KEY_KP_0)
	assert_eq(attacks, [&"basic_attack", &"basic_attack"])


func test_space_opens_focus_when_the_gauge_is_full() -> void:
	await _start_battle()
	await _press(KEY_SPACE)
	assert_eq(_state().phase, BattleState.Phase.ACTIVE, "gauge not full yet")
	_state().gauge.ticks = _state().gauge.fill_ticks
	await _press(KEY_SPACE)
	assert_eq(_state().phase, BattleState.Phase.FOCUS, "Space opens Focus when ready")


# --- Robustness (regressions for "keys don't work") --------------------------

func test_first_keypress_after_start_registers() -> void:
	# No frames waited: the very first press of the battle.
	await _press(KEY_PERIOD)
	assert_eq(battle.menu.picks, [0])


func test_quick_taps_between_ticks_are_never_dropped() -> void:
	var toggles := 0
	for i in 20:
		var before: Array = battle.menu.picks.duplicate()
		await _quick_tap(KEY_PERIOD)
		if battle.menu.picks != before:
			toggles += 1
	assert_eq(toggles, 20, "every quick tap of . registered")
	await _quick_tap(KEY_SPACE)
	assert_eq(_state().phase, BattleState.Phase.ACTIVE, "quick tap of Space")
	var attacks := _player_attacks()
	await _quick_tap(KEY_0)
	assert_eq(attacks.size(), 1, "quick tap of 0")


func test_keys_work_even_if_the_input_map_is_stale() -> void:
	# What the editor runs with if it kept an old project.godot in memory:
	# the renamed actions don't exist at all.
	battle.queue_free()
	for action in [&"button_a", &"button_b", &"open_focus"]:
		InputMap.erase_action(action)
	_spawn_battle()
	await _press(KEY_PERIOD)
	assert_eq(battle.menu.picks, [0], ". works")
	await _press(KEY_0)
	assert_eq(battle.menu.picks.size(), 0, "0 works")
	await _press(KEY_SPACE)
	assert_eq(_state().phase, BattleState.Phase.ACTIVE, "Space works")


func test_ensure_defaults_repairs_only_what_is_missing() -> void:
	InputMap.erase_action(&"button_a")
	InputMap.action_erase_events(&"open_focus")
	InputMap.action_erase_events(&"reshuffle")
	var custom := InputEventKey.new()
	custom.physical_keycode = KEY_T
	InputMap.action_add_event(&"reshuffle", custom)
	var repaired := InputBindings.ensure_defaults()
	assert_eq(repaired, PackedStringArray(["button_a", "open_focus"]))
	assert_eq(InputMap.action_get_events(&"button_a").size(), 2)
	assert_eq(InputMap.action_get_events(&"open_focus").size(), 3)
	var reshuffle_keys := InputMap.action_get_events(&"reshuffle")
	assert_eq(reshuffle_keys.size(), 1, "custom binding kept")
	assert_eq((reshuffle_keys[0] as InputEventKey).physical_keycode, KEY_T)

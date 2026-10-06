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
	assert_eq(state.enemies.size(), 1)
	assert_false((battle.get_node("Hud/Info") as Label).text.is_empty(), "hud renders")


func test_confirm_then_move_and_attack_via_input() -> void:
	var state: BattleState = battle.state
	await _tap(&"open_plan")
	assert_eq(state.phase, BattleState.Phase.ACTIVE, "confirm empty plan")
	var start := state.player.cell
	await _tap(&"move_right")
	assert_eq(state.player.cell, start + Vector2i.RIGHT)
	var enemy: Combatant = state.enemies[0]
	var hp := enemy.hp
	await _tap(&"basic_attack")
	assert_true(enemy.hp < hp, "basic attack lands")
	assert_true(state.tick_count > 0, "simulation advanced")

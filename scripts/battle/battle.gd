extends Node2D
## Battle scene root: owns the BattleState, steps it on fixed ticks, and
## translates input into state calls. Keep game rules out of this file.

const DIRECTIONS := {
	&"move_up": Vector2i.UP,
	&"move_down": Vector2i.DOWN,
	&"move_left": Vector2i.LEFT,
	&"move_right": Vector2i.RIGHT,
}

@export var config: BattleConfig

var state: BattleState
var plan_cursor := 0
var plan_selection: Array[int] = []

@onready var grid_view: GridView = $GridView
@onready var hud: Label = $Hud/Info


func _ready() -> void:
	if config == null:
		config = BattleConfig.new()
	Engine.physics_ticks_per_second = config.ticks_per_second
	state = BattleState.new(config)
	grid_view.state = state
	print("Battle started with seed %d" % state.rng_seed)


func _physics_process(_delta: float) -> void:
	match state.phase:
		BattleState.Phase.ACTIVE:
			_handle_active_input()
			state.step()
		BattleState.Phase.PLANNING:
			_handle_plan_input()
	_update_hud()


func _handle_active_input() -> void:
	for action: StringName in DIRECTIONS:
		if Input.is_action_pressed(action) and state.try_move(DIRECTIONS[action]):
			break
	if Input.is_action_just_pressed(&"basic_attack"):
		state.try_basic_attack()
	if Input.is_action_just_pressed(&"use_card"):
		state.try_use_card()
	if Input.is_action_just_pressed(&"open_plan") and state.open_plan():
		plan_cursor = 0
		plan_selection.clear()


func _handle_plan_input() -> void:
	var hand_size := state.deck.hand.size()
	if Input.is_action_just_pressed(&"move_left"):
		plan_cursor = wrapi(plan_cursor - 1, 0, maxi(hand_size, 1))
	if Input.is_action_just_pressed(&"move_right"):
		plan_cursor = wrapi(plan_cursor + 1, 0, maxi(hand_size, 1))
	if Input.is_action_just_pressed(&"use_card") and hand_size > 0:
		if plan_selection.has(plan_cursor):
			plan_selection.erase(plan_cursor)
		elif plan_selection.size() < config.max_cards_per_plan:
			plan_selection.append(plan_cursor)
	if Input.is_action_just_pressed(&"reshuffle") and state.reshuffle():
		plan_selection.clear()
	if Input.is_action_just_pressed(&"open_plan") and state.confirm_plan(plan_selection):
		plan_selection.clear()


func _update_hud() -> void:
	var lines: PackedStringArray = []
	lines.append("HP %d/%d   Gauge %d%%   Tick %d" % [
			state.player.hp, state.player.max_hp, roundi(state.gauge.ratio() * 100), state.tick_count])
	lines.append("Queue: %s" % ", ".join(state.queued_cards.map(func(c: CardData) -> String: return c.display_name)))
	match state.phase:
		BattleState.Phase.ACTIVE:
			lines.append("WASD move   J attack   K use card   Space plan%s" % (
					" (ready)" if state.can_open_plan() else ""))
		BattleState.Phase.PLANNING:
			lines.append("PLANNING  (A/D cursor, K select, R reshuffle [%s left], Space confirm)" % (
					"inf" if state.reshuffles_left < 0 else str(state.reshuffles_left)))
			var hand := PackedStringArray()
			for i in state.deck.hand.size():
				var card := state.deck.hand[i]
				var label := card.display_name
				if plan_selection.has(i):
					label = "[%d:%s]" % [plan_selection.find(i) + 1, label]
				if i == plan_cursor:
					label = ">" + label
				hand.append(label)
			lines.append("Hand: " + "  ".join(hand))
		BattleState.Phase.ENDED:
			lines.append("YOU WIN" if state.winner == GridModel.Side.PLAYER else "DEFEATED")
	hud.text = "\n".join(lines)

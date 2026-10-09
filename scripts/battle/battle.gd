extends Node2D
## Battle scene root: owns the BattleState, steps it on fixed ticks, and
## translates input into state calls. Keep game rules out of this file.
##
## Two action buttons, A (`button_a`: 0 / numpad 0) and B (`button_b`:
## . / numpad .), mean different things per phase:
##   battle: A = use next queued card, B = basic attack
##   Focus:  A = pick/unpick card or press the highlighted button,
##           B = undo the last pick

const DIRECTIONS := {
	&"move_up": Vector2i.UP,
	&"move_down": Vector2i.DOWN,
	&"move_left": Vector2i.LEFT,
	&"move_right": Vector2i.RIGHT,
}

const HINTS_ACTIVE := "WASD / Arrows  move     [0] use card     [.] attack     [Space] Focus%s"
const HINTS_FOCUS := "Arrows  choose     [0] pick / press     [.] undo     [R] reshuffle     [Space] start"
const HINTS_ENDED := "Battle over"

@export var config: BattleConfig

var state: BattleState
var menu := FocusMenu.new()

@onready var grid_view: GridView = $GridView
@onready var status_bar: StatusBar = $Hud/StatusBar
@onready var next_card: NextCardWidget = $Hud/NextCard
@onready var focus_panel: FocusPanel = $Hud/FocusPanel
@onready var key_hints: Label = $Hud/KeyHints


func _ready() -> void:
	if config == null:
		config = BattleConfig.new()
	Engine.physics_ticks_per_second = config.ticks_per_second
	state = BattleState.new(config)
	grid_view.state = state
	status_bar.state = state
	next_card.state = state
	focus_panel.state = state
	focus_panel.menu = menu
	_reset_menu()
	_update_ui()
	print("Battle started with seed %d" % state.rng_seed)


func _physics_process(_delta: float) -> void:
	match state.phase:
		BattleState.Phase.ACTIVE:
			_handle_active_input()
			state.step()
		BattleState.Phase.FOCUS:
			_handle_focus_input()
	_update_ui()


func _handle_active_input() -> void:
	for action: StringName in DIRECTIONS:
		if Input.is_action_pressed(action) and state.try_move(DIRECTIONS[action]):
			break
	if Input.is_action_just_pressed(&"button_b"):
		state.try_basic_attack()
	if Input.is_action_just_pressed(&"button_a"):
		state.try_use_card()
	if Input.is_action_just_pressed(&"open_focus") and state.open_focus():
		_reset_menu()


func _handle_focus_input() -> void:
	for action: StringName in DIRECTIONS:
		if Input.is_action_just_pressed(action):
			menu.move(DIRECTIONS[action])
	if Input.is_action_just_pressed(&"button_b"):
		menu.press_b()
	if Input.is_action_just_pressed(&"button_a"):
		match menu.press_a():
			FocusMenu.Result.RESHUFFLE:
				_reshuffle()
			FocusMenu.Result.CONFIRM:
				_confirm()
	if Input.is_action_just_pressed(&"reshuffle"):
		_reshuffle()
	if Input.is_action_just_pressed(&"open_focus"):
		_confirm()


func _reshuffle() -> void:
	if state.reshuffle():
		_reset_menu()


func _confirm() -> void:
	state.confirm_focus(menu.picks)


func _reset_menu() -> void:
	menu.reset(state.deck.hand.size(), config.max_cards_per_focus)


func _update_ui() -> void:
	var in_focus := state.phase == BattleState.Phase.FOCUS
	focus_panel.visible = in_focus
	next_card.visible = state.phase == BattleState.Phase.ACTIVE
	match state.phase:
		BattleState.Phase.ACTIVE:
			key_hints.text = HINTS_ACTIVE % ("  (ready)" if state.can_open_focus() else "")
		BattleState.Phase.FOCUS:
			key_hints.text = HINTS_FOCUS
		BattleState.Phase.ENDED:
			key_hints.text = HINTS_ENDED

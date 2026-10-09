extends TestCase

var menu: FocusMenu


func before_each() -> void:
	menu = FocusMenu.new()
	menu.reset(5, 3)


func test_reset_starts_on_first_card_with_no_picks() -> void:
	assert_eq(menu.current_item(), FocusMenu.Item.CARD)
	assert_eq(menu.card_cursor, 0)
	assert_eq(menu.picks.size(), 0)


func test_empty_hand_starts_on_buttons() -> void:
	menu.reset(0, 3)
	assert_eq(menu.current_item(), FocusMenu.Item.CONFIRM)
	menu.move(Vector2i.UP)
	assert_eq(menu.current_item(), FocusMenu.Item.CONFIRM, "no card row to go back to")


func test_left_right_wraps_through_the_hand() -> void:
	menu.move(Vector2i.LEFT)
	assert_eq(menu.card_cursor, 4)
	menu.move(Vector2i.RIGHT)
	assert_eq(menu.card_cursor, 0)


func test_up_down_switches_rows_and_buttons_wrap() -> void:
	menu.move(Vector2i.DOWN)
	assert_eq(menu.current_item(), FocusMenu.Item.CONFIRM)
	menu.move(Vector2i.LEFT)
	assert_eq(menu.current_item(), FocusMenu.Item.RESHUFFLE)
	menu.move(Vector2i.LEFT)
	assert_eq(menu.current_item(), FocusMenu.Item.CONFIRM)
	menu.move(Vector2i.UP)
	assert_eq(menu.current_item(), FocusMenu.Item.CARD)


func test_picks_are_ranked_in_selection_order() -> void:
	menu.card_cursor = 3
	assert_eq(menu.press_a(), FocusMenu.Result.PICKED)
	menu.card_cursor = 1
	menu.press_a()
	assert_eq(menu.picks, [3, 1])
	assert_eq(menu.rank_of(3), 1)
	assert_eq(menu.rank_of(1), 2)
	assert_eq(menu.rank_of(0), 0, "unpicked")


func test_a_on_picked_card_unpicks_and_reranks() -> void:
	for i in [0, 2, 4]:
		menu.card_cursor = i
		menu.press_a()
	menu.on_buttons = false
	menu.card_cursor = 0
	assert_eq(menu.press_a(), FocusMenu.Result.UNPICKED)
	assert_eq(menu.picks, [2, 4])
	assert_eq(menu.rank_of(2), 1, "later picks move up")


func test_cannot_pick_more_than_max() -> void:
	menu.reset(5, 2)
	menu.press_a()
	menu.card_cursor = 1
	menu.press_a()
	menu.on_buttons = false
	menu.card_cursor = 2
	assert_eq(menu.press_a(), FocusMenu.Result.FULL)
	assert_eq(menu.picks, [0, 1])


func test_filling_the_last_pick_jumps_to_ok() -> void:
	menu.reset(5, 1)
	menu.card_cursor = 2
	menu.press_a()
	assert_eq(menu.current_item(), FocusMenu.Item.CONFIRM)
	assert_true(menu.is_full())


func test_b_undoes_last_pick_and_returns_cursor_to_it() -> void:
	menu.card_cursor = 1
	menu.press_a()
	menu.card_cursor = 4
	menu.press_a()
	menu.card_cursor = 0
	assert_eq(menu.press_b(), FocusMenu.Result.UNPICKED)
	assert_eq(menu.picks, [1])
	assert_eq(menu.card_cursor, 4)
	assert_eq(menu.current_item(), FocusMenu.Item.CARD)
	menu.press_b()
	assert_eq(menu.press_b(), FocusMenu.Result.NONE, "nothing left to undo")


func test_buttons_report_their_action() -> void:
	menu.move(Vector2i.DOWN)
	assert_eq(menu.press_a(), FocusMenu.Result.CONFIRM)
	menu.move(Vector2i.LEFT)
	assert_eq(menu.press_a(), FocusMenu.Result.RESHUFFLE)
	assert_eq(menu.picks.size(), 0, "buttons don't pick cards")

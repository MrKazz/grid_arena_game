class_name FocusMenu
extends RefCounted
## Cursor and selection state for the Focus screen. Pure logic, no drawing:
## battle.gd feeds it input and FocusPanel draws it. It never touches
## BattleState; battle.gd turns the results into state calls.
##
## The cursor moves over two rows: the hand (cards) and the buttons
## (Reshuffle, OK). Picks are hand indices in the order they will trigger.

enum Item { CARD, RESHUFFLE, CONFIRM }
enum Result { NONE, PICKED, UNPICKED, FULL, RESHUFFLE, CONFIRM }

const BUTTON_RESHUFFLE := 0
const BUTTON_CONFIRM := 1

var hand_size := 0
var max_picks := 0
## True while the cursor is on the button row.
var on_buttons := false
var card_cursor := 0
var button_cursor := BUTTON_CONFIRM
## Hand indices in trigger order.
var picks: Array[int] = []


## Starts a fresh selection for a hand of `p_hand_size` cards.
func reset(p_hand_size: int, p_max_picks: int) -> void:
	hand_size = p_hand_size
	max_picks = p_max_picks
	picks.clear()
	card_cursor = 0
	button_cursor = BUTTON_CONFIRM
	on_buttons = hand_size == 0


## Left/right moves along the current row (wrapping); up/down switches rows.
func move(direction: Vector2i) -> void:
	if direction.y != 0:
		on_buttons = direction.y > 0 or hand_size == 0
	elif on_buttons:
		button_cursor = wrapi(button_cursor + direction.x, 0, 2)
	elif hand_size > 0:
		card_cursor = wrapi(card_cursor + direction.x, 0, hand_size)


func current_item() -> Item:
	if not on_buttons:
		return Item.CARD
	return Item.RESHUFFLE if button_cursor == BUTTON_RESHUFFLE else Item.CONFIRM


## A / confirm: toggle the highlighted card, or activate the highlighted button.
## Filling the last pick moves the cursor to OK.
func press_a() -> Result:
	match current_item():
		Item.RESHUFFLE:
			return Result.RESHUFFLE
		Item.CONFIRM:
			return Result.CONFIRM
	if picks.has(card_cursor):
		picks.erase(card_cursor)
		return Result.UNPICKED
	if picks.size() >= max_picks:
		return Result.FULL
	picks.append(card_cursor)
	if picks.size() == max_picks:
		on_buttons = true
		button_cursor = BUTTON_CONFIRM
	return Result.PICKED


## B / back: undo the most recent pick and put the cursor back on that card.
func press_b() -> Result:
	if picks.is_empty():
		return Result.NONE
	card_cursor = picks.pop_back()
	on_buttons = false
	return Result.UNPICKED


## 1-based trigger position of a hand card, or 0 if it isn't picked.
func rank_of(hand_index: int) -> int:
	return picks.find(hand_index) + 1


func is_full() -> bool:
	return picks.size() >= max_picks

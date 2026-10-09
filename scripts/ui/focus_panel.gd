class_name FocusPanel
extends Control
## The Focus screen: drawn hand, ranked queue, details of the highlighted
## card, and the Reshuffle / OK buttons. Reads BattleState and FocusMenu;
## never changes them.
##
## Layout keeps the field visible: the hand and details sit in the band
## above the field, the queue and buttons in the band below it, nothing is
## drawn over `field_rect`, and only the area around the field is dimmed.

const DIM := Color(0.05, 0.06, 0.09, 0.35)
const FIELD_OUTLINE := Color(1, 1, 1, 0.25)
const CARD_SIZE := Vector2(72, 100)
const CARD_GAP := 8.0
const HAND_ORIGIN := Vector2(16, 44)
const DETAILS_RECT := Rect2(416, 30, 208, 114)
const QUEUE_ORIGIN := Vector2(16, 302)
const QUEUE_WIDTH := 392.0
const CHIP_HEIGHT := 26.0
const CHIP_GAP := 6.0
const BUTTON_SIZE := Vector2(100, 26)
const BUTTONS_ORIGIN := Vector2(416, 302)

var state: BattleState
var menu: FocusMenu
## Where the field is on screen; battle.gd sets it from GridView.
var field_rect := Rect2(125, 150, 392, 128)


func _process(_delta: float) -> void:
	queue_redraw()


func card_rect(hand_index: int) -> Rect2:
	return Rect2(HAND_ORIGIN + Vector2((CARD_SIZE.x + CARD_GAP) * hand_index, 0), CARD_SIZE)


func button_rect(button: int) -> Rect2:
	return Rect2(BUTTONS_ORIGIN + Vector2((BUTTON_SIZE.x + CARD_GAP) * button, 0), BUTTON_SIZE)


func queue_slot_count() -> int:
	return state.queued_cards.size() + menu.max_picks


func queue_chip_rect(slot: int) -> Rect2:
	var slots := maxi(queue_slot_count(), 1)
	var width := minf(120.0, (QUEUE_WIDTH - CHIP_GAP * (slots - 1)) / slots)
	return Rect2(QUEUE_ORIGIN + Vector2((width + CHIP_GAP) * slot, 0), Vector2(width, CHIP_HEIGHT))


## Every rectangle the panel draws UI into (used to check nothing covers the field).
func ui_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = [DETAILS_RECT, button_rect(FocusMenu.BUTTON_RESHUFFLE),
			button_rect(FocusMenu.BUTTON_CONFIRM)]
	for i in state.deck.hand.size():
		rects.append(card_rect(i))
	for slot in queue_slot_count():
		rects.append(queue_chip_rect(slot))
	return rects


## The translucent layer: the whole panel except the field.
func dim_rects() -> Array[Rect2]:
	var f := field_rect
	return [
		Rect2(0, 0, size.x, f.position.y),
		Rect2(0, f.end.y, size.x, size.y - f.end.y),
		Rect2(0, f.position.y, f.position.x, f.size.y),
		Rect2(f.end.x, f.position.y, size.x - f.end.x, f.size.y),
	]


## The card the details panel describes: the highlighted hand card, if any.
func highlighted_card() -> CardData:
	if menu == null or menu.on_buttons or menu.card_cursor >= state.deck.hand.size():
		return null
	return state.deck.hand[menu.card_cursor]


## Cards in trigger order: carried-over queue first, then this Focus's picks.
func ranked_queue() -> Array[CardData]:
	var result: Array[CardData] = state.queued_cards.duplicate()
	for i in menu.picks:
		result.append(state.deck.hand[i])
	return result


func _draw() -> void:
	if state == null or menu == null:
		return
	var f := CardArt.font()
	for rect in dim_rects():
		draw_rect(rect, DIM)
	draw_rect(field_rect.grow(2), FIELD_OUTLINE, false, 1.0)

	draw_string(f, Vector2(16, 38), "FOCUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CardArt.HIGHLIGHT)
	draw_string(f, Vector2(70, 38), "Pick up to %d. They trigger in the order picked." % menu.max_picks,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CardArt.TEXT)

	var carried := state.queued_cards.size()
	for i in state.deck.hand.size():
		var rank := menu.rank_of(i)
		var highlighted := not menu.on_buttons and menu.card_cursor == i
		var blocked := rank == 0 and menu.is_full()
		CardArt.card(self, card_rect(i), state.deck.hand[i], highlighted,
				rank + carried if rank > 0 else 0, rank > 0 or blocked)

	_draw_details(f)
	_draw_queue(f, carried)
	_draw_button(FocusMenu.BUTTON_RESHUFFLE, _reshuffle_label(), state.reshuffles_left != 0)
	_draw_button(FocusMenu.BUTTON_CONFIRM, "OK", true)


func _reshuffle_label() -> String:
	if state.reshuffles_left < 0:
		return "Reshuffle"
	return "Reshuffle (%d)" % state.reshuffles_left


func _draw_button(button: int, text: String, enabled: bool) -> void:
	var rect := button_rect(button)
	var highlighted := menu.on_buttons and menu.button_cursor == button
	CardArt.panel(self, rect, CardArt.HIGHLIGHT if highlighted else CardArt.BORDER)
	if highlighted:
		draw_rect(rect.grow(-1), Color(CardArt.HIGHLIGHT, 0.2))
	draw_string(CardArt.font(), rect.position + Vector2(0, 17), text, HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x, 11, CardArt.TEXT if enabled else CardArt.TEXT_DIM)


func _draw_queue(f: Font, carried: int) -> void:
	var header := "QUEUE  (trigger order)"
	if carried > 0:
		header = "QUEUE  (trigger order, %d carried over)" % carried
	draw_string(f, QUEUE_ORIGIN + Vector2(0, -6), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CardArt.TEXT)
	var queue := ranked_queue()
	for slot in queue_slot_count():
		var rect := queue_chip_rect(slot)
		if slot < queue.size():
			var c := queue[slot]
			CardArt.panel(self, rect)
			draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), CardArt.type_color(c))
			draw_string(f, rect.position + Vector2(9, 17), "%d  %s" % [slot + 1, c.display_name],
					HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12, 10,
					CardArt.TEXT_DIM if slot < carried else CardArt.TEXT)
		else:
			draw_rect(rect, Color(CardArt.BG, 0.6))
			draw_rect(rect, CardArt.BORDER, false, 1.0)
			draw_string(f, rect.position + Vector2(9, 17), "%d  -" % (slot + 1),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CardArt.TEXT_DIM)


func _draw_details(f: Font) -> void:
	var rect := DETAILS_RECT
	CardArt.panel(self, rect)
	var pos := rect.position + Vector2(8, 0)
	var c := highlighted_card()
	if c == null:
		var help := "Choose cards, then press OK to resume the battle."
		if menu.current_item() == FocusMenu.Item.RESHUFFLE:
			help = "Return your hand to the deck, shuffle, and draw a new hand. Clears your picks."
		draw_multiline_string(f, pos + Vector2(0, 18), help, HORIZONTAL_ALIGNMENT_LEFT,
				rect.size.x - 16, 10, -1, CardArt.TEXT_DIM)
		return
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), CardArt.type_color(c))
	draw_string(f, pos + Vector2(0, 21), c.display_name, HORIZONTAL_ALIGNMENT_LEFT, 116, 13, CardArt.TEXT)
	draw_string(f, pos + Vector2(0, 36), "%s  |  %d dmg" % [CardArt.type_name(c), c.damage],
			HORIZONTAL_ALIGNMENT_LEFT, 120, 10, CardArt.HIGHLIGHT)
	var pattern_rect := Rect2(rect.position + Vector2(130, 10), Vector2(70, 30))
	CardArt.pattern(self, pattern_rect, c)
	_legend_entry(f, pattern_rect.position + Vector2(0, 42), CardArt.PATTERN_USER, "you")
	_legend_entry(f, pattern_rect.position + Vector2(36, 42), CardArt.PATTERN_HIT, "hit")
	draw_multiline_string(f, pos + Vector2(0, 62), c.description, HORIZONTAL_ALIGNMENT_LEFT,
			rect.size.x - 16, 10, 4, CardArt.TEXT)


func _legend_entry(f: Font, pos: Vector2, color: Color, text: String) -> void:
	draw_rect(Rect2(pos - Vector2(0, 7), Vector2(7, 7)), color)
	draw_string(f, pos + Vector2(10, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, CardArt.TEXT_DIM)

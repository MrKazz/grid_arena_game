class_name FocusPanel
extends Control
## The Focus screen: drawn hand, ranked queue, details of the highlighted
## card, and the Reshuffle / OK buttons. Reads BattleState and FocusMenu;
## never changes them.

const DIM := Color(0.05, 0.06, 0.09, 0.88)
const CARD_SIZE := Vector2(72, 100)
const CARD_GAP := 8.0
const HAND_ORIGIN := Vector2(16, 52)
const BUTTON_SIZE := Vector2(120, 24)
const SIDE_X := 432.0
const SIDE_W := 192.0

var state: BattleState
var menu: FocusMenu


func _process(_delta: float) -> void:
	queue_redraw()


func card_rect(hand_index: int) -> Rect2:
	return Rect2(HAND_ORIGIN + Vector2((CARD_SIZE.x + CARD_GAP) * hand_index, 0), CARD_SIZE)


func button_rect(button: int) -> Rect2:
	var y := HAND_ORIGIN.y + CARD_SIZE.y + 14
	return Rect2(Vector2(HAND_ORIGIN.x + (BUTTON_SIZE.x + CARD_GAP) * button, y), BUTTON_SIZE)


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
	draw_rect(Rect2(Vector2.ZERO, size), DIM)
	draw_string(f, Vector2(16, 40), "FOCUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CardArt.HIGHLIGHT)
	draw_string(f, Vector2(96, 40), "Pick up to %d cards. They trigger in the order you pick them." %
			menu.max_picks, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CardArt.TEXT_DIM)

	var carried := state.queued_cards.size()
	for i in state.deck.hand.size():
		var rank := menu.rank_of(i)
		var highlighted := not menu.on_buttons and menu.card_cursor == i
		var blocked := rank == 0 and menu.is_full()
		CardArt.card(self, card_rect(i), state.deck.hand[i], highlighted,
				rank + carried if rank > 0 else 0, rank > 0 or blocked)

	_draw_button(FocusMenu.BUTTON_RESHUFFLE, _reshuffle_label(), state.reshuffles_left != 0)
	_draw_button(FocusMenu.BUTTON_CONFIRM, "OK  (start)", true)
	_draw_queue(f, carried)
	_draw_details(f)


func _reshuffle_label() -> String:
	if state.reshuffles_left < 0:
		return "Reshuffle"
	return "Reshuffle (%d)" % state.reshuffles_left


func _draw_button(button: int, text: String, enabled: bool) -> void:
	var rect := button_rect(button)
	var highlighted := menu.on_buttons and menu.button_cursor == button
	CardArt.panel(self, rect, CardArt.HIGHLIGHT if highlighted else CardArt.BORDER)
	if highlighted:
		draw_rect(rect.grow(-1), Color(CardArt.HIGHLIGHT, 0.15))
	draw_string(CardArt.font(), rect.position + Vector2(0, 16), text, HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x, 11, CardArt.TEXT if enabled else CardArt.TEXT_DIM)


func _draw_queue(f: Font, carried: int) -> void:
	var rect := Rect2(SIDE_X, 52, SIDE_W, 112)
	CardArt.panel(self, rect)
	draw_string(f, rect.position + Vector2(8, 15), "QUEUE  (trigger order)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CardArt.TEXT_DIM)
	var queue := ranked_queue()
	var slots := carried + menu.max_picks
	for i in slots:
		var y := rect.position.y + 32 + i * 16
		if y > rect.end.y - 4:
			break
		var label := "%d." % (i + 1)
		if i < queue.size():
			var c := queue[i]
			draw_rect(Rect2(rect.position.x + 26, y - 9, 4, 10), CardArt.type_color(c))
			var suffix := "  (carried)" if i < carried else ""
			label += "     %s%s" % [c.display_name, suffix]
			draw_string(f, Vector2(rect.position.x + 8, y), label, HORIZONTAL_ALIGNMENT_LEFT,
					SIDE_W - 16, 11, CardArt.TEXT_DIM if i < carried else CardArt.TEXT)
		else:
			draw_string(f, Vector2(rect.position.x + 8, y), label + "     -",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CardArt.TEXT_DIM)


func _draw_details(f: Font) -> void:
	var rect := Rect2(SIDE_X, 172, SIDE_W, 156)
	CardArt.panel(self, rect)
	var pos := rect.position + Vector2(8, 0)
	var c := highlighted_card()
	if c == null:
		var help := "Choose cards first, then press OK to resume the battle."
		if menu.current_item() == FocusMenu.Item.RESHUFFLE:
			help = "Return your hand to the deck, shuffle, and draw a new hand. Clears your picks."
		draw_multiline_string(f, pos + Vector2(0, 18), help, HORIZONTAL_ALIGNMENT_LEFT,
				SIDE_W - 16, 11, -1, CardArt.TEXT_DIM)
		return
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), CardArt.type_color(c))
	draw_string(f, pos + Vector2(0, 22), c.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CardArt.TEXT)
	draw_string(f, pos + Vector2(0, 38), "%s  |  %d damage" % [CardArt.type_name(c), c.damage],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CardArt.HIGHLIGHT)
	draw_multiline_string(f, pos + Vector2(0, 56), c.description, HORIZONTAL_ALIGNMENT_LEFT,
			SIDE_W - 16, 11, 4, CardArt.TEXT)
	CardArt.pattern(self, Rect2(pos + Vector2(0, 108), Vector2(112, 40)), c)
	_legend_entry(f, pos + Vector2(122, 118), CardArt.PATTERN_USER, "you")
	_legend_entry(f, pos + Vector2(122, 136), CardArt.PATTERN_HIT, "hit")


func _legend_entry(f: Font, pos: Vector2, color: Color, text: String) -> void:
	draw_rect(Rect2(pos - Vector2(0, 7), Vector2(8, 8)), color)
	draw_string(f, pos + Vector2(12, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CardArt.TEXT_DIM)

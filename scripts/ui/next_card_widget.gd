class_name NextCardWidget
extends Control
## In-battle box showing the next queued card (or that the queue is empty).
## Reads BattleState; never changes it.

var state: BattleState


func _process(_delta: float) -> void:
	queue_redraw()


## The card the widget is showing, or null when the queue is empty.
func displayed_card() -> CardData:
	if state == null or state.queued_cards.is_empty():
		return null
	return state.queued_cards[0]


func _draw() -> void:
	if state == null:
		return
	var f := CardArt.font()
	var rect := Rect2(Vector2.ZERO, size)
	var c := displayed_card()
	CardArt.panel(self, rect, CardArt.BORDER if c == null else CardArt.type_color(c))
	draw_string(f, Vector2(8, 14), "NEXT  [.]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CardArt.TEXT_DIM)
	if c == null:
		draw_string(f, Vector2(8, 34), "Empty", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CardArt.TEXT_DIM)
		draw_string(f, Vector2(8, 50), "Refill in Focus", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CardArt.TEXT_DIM)
		return
	draw_rect(Rect2(0, 0, 4, size.y), CardArt.type_color(c))
	draw_string(f, Vector2(8, 32), c.display_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 70, 13, CardArt.TEXT)
	draw_string(f, Vector2(8, 48), "%d  %s" % [c.damage, CardArt.type_name(c)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CardArt.HIGHLIGHT)
	var more := state.queued_cards.size() - 1
	if more > 0:
		draw_string(f, Vector2(8, 62), "+%d more" % more, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CardArt.TEXT_DIM)
	CardArt.pattern(self, Rect2(size.x - 62, 22, 56, 32), c)

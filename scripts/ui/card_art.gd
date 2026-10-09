class_name CardArt
extends RefCounted
## Placeholder card rendering shared by the Focus screen and the Next widget.
## Static helpers that draw onto any CanvasItem inside its _draw().

const BG := Color("1d2230")
const BORDER := Color("5a6378")
const TEXT := Color("e8ecf4")
const TEXT_DIM := Color("8a93a8")
const HIGHLIGHT := Color("ffd166")
const PATTERN_EMPTY := Color("2c3345")
const PATTERN_USER := Color("8fd3ff")
const PATTERN_HIT := Color("ff8a5c")

const TYPE_COLORS := {
	CardData.Targeting.TILES: Color("3fa7a0"),
	CardData.Targeting.ROW_FIRST_HIT: Color("d9a441"),
	CardData.Targeting.AIMED: Color("9a6fd6"),
}
const TYPE_NAMES := {
	CardData.Targeting.TILES: "Area",
	CardData.Targeting.ROW_FIRST_HIT: "Projectile",
	CardData.Targeting.AIMED: "Aimed",
}


static func font() -> Font:
	return ThemeDB.fallback_font


static func type_color(card: CardData) -> Color:
	return TYPE_COLORS.get(card.targeting, BORDER)


static func type_name(card: CardData) -> String:
	return TYPE_NAMES.get(card.targeting, "?")


static func panel(canvas: CanvasItem, rect: Rect2, border: Color = BORDER) -> void:
	canvas.draw_rect(rect, BG)
	canvas.draw_rect(rect, border, false, 1.0)


## A hand-sized card: type stripe, name, damage, mini pattern. `rank` > 0
## draws its trigger-order badge; `dimmed` greys it out.
static func card(canvas: CanvasItem, rect: Rect2, c: CardData, highlighted: bool,
		rank: int = 0, dimmed: bool = false) -> void:
	var f := font()
	canvas.draw_rect(rect, BG)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6)), type_color(c))
	var text := TEXT_DIM if dimmed else TEXT
	canvas.draw_string(f, rect.position + Vector2(5, 20), c.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 11, text)
	canvas.draw_string(f, rect.position + Vector2(5, 34), str(c.damage),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, HIGHLIGHT if not dimmed else TEXT_DIM)
	pattern(canvas, Rect2(rect.position + Vector2(5, rect.size.y - 34), Vector2(rect.size.x - 10, 28)), c)
	if dimmed:
		canvas.draw_rect(rect, Color(0, 0, 0, 0.45))
	canvas.draw_rect(rect, HIGHLIGHT if highlighted else BORDER, false, 2.0 if highlighted else 1.0)
	if rank > 0:
		var badge := Rect2(rect.end - Vector2(18, rect.size.y - 10), Vector2(16, 16))
		canvas.draw_rect(badge, HIGHLIGHT)
		canvas.draw_string(f, badge.position + Vector2(4, 13), str(rank),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BG)


## Mini 7x4 field showing what the card hits when used from tile (1, 1).
static func pattern(canvas: CanvasItem, rect: Rect2, c: CardData) -> void:
	var user := Vector2i(1, 1)
	var hit := {}
	match c.targeting:
		CardData.Targeting.TILES:
			for offset in c.pattern:
				hit[user + offset] = true
		CardData.Targeting.ROW_FIRST_HIT:
			for x in range(user.x + 1, GridModel.COLUMNS):
				hit[Vector2i(x, user.y)] = true
		CardData.Targeting.AIMED:
			hit[Vector2i(5, 2)] = true  # "wherever the nearest opponent stands"
	var cell := Vector2(rect.size.x / GridModel.COLUMNS, rect.size.y / GridModel.ROWS)
	for y in GridModel.ROWS:
		for x in GridModel.COLUMNS:
			var r := Rect2(rect.position + Vector2(x, y) * cell, cell - Vector2.ONE)
			var color := PATTERN_EMPTY
			if Vector2i(x, y) == user:
				color = PATTERN_USER
			elif hit.has(Vector2i(x, y)):
				color = PATTERN_HIT
			canvas.draw_rect(r, color)

class_name StatusBar
extends Control
## Top-of-screen HP and Focus gauge bars, plus the end-of-battle banner.
## Reads BattleState; never changes it.

const HP_COLOR := Color("6fd38f")
const GAUGE_COLOR := Color("5aa9ff")
const BAR_BG := Color("2c3345")

var state: BattleState


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if state == null:
		return
	var f := CardArt.font()
	_bar(f, Vector2(16, 8), "HP", float(state.player.hp) / state.player.max_hp,
			"%d/%d" % [state.player.hp, state.player.max_hp], HP_COLOR)
	var ready := state.gauge.is_full()
	_bar(f, Vector2(272, 8), "FOCUS", state.gauge.ratio(), "READY" if ready else "",
			CardArt.HIGHLIGHT if ready else GAUGE_COLOR)
	if state.phase == BattleState.Phase.ENDED:
		var won := state.winner == GridModel.Side.PLAYER
		draw_string(f, Vector2(0, size.y / 2), "YOU WIN" if won else "DEFEATED",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, HP_COLOR if won else Color("ff6b6b"))


func _bar(f: Font, pos: Vector2, title: String, ratio: float, text: String, color: Color) -> void:
	draw_string(f, pos + Vector2(0, 11), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CardArt.TEXT_DIM)
	var bar := Rect2(pos + Vector2(44, 2), Vector2(120, 10))
	draw_rect(bar, BAR_BG)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0, 1), bar.size.y)), color)
	draw_string(f, pos + Vector2(170, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CardArt.TEXT)

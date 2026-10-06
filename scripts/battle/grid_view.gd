class_name GridView
extends Node2D
## Placeholder renderer for the battle field. Reads BattleState; never writes it.

const TILE_SIZE := Vector2(56, 32)
const TILE_GAP := 2.0
const FLASH_TICKS := 10

const PLAYER_TILE := Color("3d6fb6")
const ENEMY_TILE := Color("b6453d")
const NEUTRAL_TILE := Color("7a7a7a")
const PLAYER_UNIT := Color("8fd3ff")
const ENEMY_UNIT := Color("ffb08f")
const FLASH := Color(1, 1, 0.6, 0.7)
const WARNING := Color(1, 0.6, 0.1)

var state: BattleState:
	set(value):
		state = value
		_flashes.clear()
		if state != null:
			state.card_used.connect(_on_card_used)

var _flashes: Dictionary = {}  # Vector2i -> ticks remaining


func _physics_process(_delta: float) -> void:
	for cell in _flashes.keys():
		_flashes[cell] -= 1
		if _flashes[cell] <= 0:
			_flashes.erase(cell)
	queue_redraw()


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * TILE_SIZE, TILE_SIZE - Vector2(TILE_GAP, TILE_GAP))


func _draw() -> void:
	if state == null:
		return
	var font := ThemeDB.fallback_font
	var warnings := {}  # Vector2i -> wind-up progress 0..1
	for brain in state.brains:
		for cell in brain.telegraph:
			warnings[cell] = maxf(warnings.get(cell, 0.0), brain.windup_progress())
	for y in GridModel.ROWS:
		for x in GridModel.COLUMNS:
			var cell := Vector2i(x, y)
			var rect := cell_rect(cell)
			draw_rect(rect, _tile_color(state.grid.owner_of(cell)))
			if warnings.has(cell):
				var warn := WARNING
				warn.a = lerpf(0.25, 0.8, warnings[cell])
				draw_rect(rect, warn)
				draw_rect(rect.grow(-1), WARNING, false, 2.0)
			if _flashes.has(cell):
				draw_rect(rect, FLASH)
			var unit := state.grid.occupant_at(cell)
			if unit != null:
				var is_player_unit := unit.side == GridModel.Side.PLAYER
				draw_circle(rect.get_center(), 10, PLAYER_UNIT if is_player_unit else ENEMY_UNIT)
				draw_string(font, rect.position + Vector2(2, 10), str(unit.hp),
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10)


func _tile_color(tile_owner: int) -> Color:
	match tile_owner:
		GridModel.Side.PLAYER:
			return PLAYER_TILE
		GridModel.Side.ENEMY:
			return ENEMY_TILE
	return NEUTRAL_TILE


func _on_card_used(_user: Combatant, _card: CardData, cells: Array[Vector2i], _hits: Array[Combatant]) -> void:
	for cell in cells:
		_flashes[cell] = FLASH_TICKS

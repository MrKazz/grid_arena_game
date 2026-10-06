class_name GridView
extends Node2D
## Placeholder renderer for the battle field. Reads BattleState; never writes it.

const TILE_SIZE := Vector2(56, 32)
const TILE_GAP := 2.0
const FLASH_TICKS := 10

const PLAYER_TILE := Color("3d6fb6")
const ENEMY_TILE := Color("b6453d")
const PLAYER_UNIT := Color("8fd3ff")
const ENEMY_UNIT := Color("ffb08f")
const FLASH := Color(1, 1, 0.6, 0.7)

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
	for y in GridModel.ROWS:
		for x in GridModel.COLUMNS:
			var cell := Vector2i(x, y)
			var rect := cell_rect(cell)
			var is_player_tile := state.grid.owner_of(cell) == GridModel.Side.PLAYER
			draw_rect(rect, PLAYER_TILE if is_player_tile else ENEMY_TILE)
			if _flashes.has(cell):
				draw_rect(rect, FLASH)
			var unit := state.grid.occupant_at(cell)
			if unit != null:
				var is_player_unit := unit.side == GridModel.Side.PLAYER
				draw_circle(rect.get_center(), 10, PLAYER_UNIT if is_player_unit else ENEMY_UNIT)
				draw_string(font, rect.position + Vector2(2, 10), str(unit.hp),
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10)


func _on_card_used(_user: Combatant, _card: CardData, cells: Array[Vector2i], _hits: Array[Combatant]) -> void:
	for cell in cells:
		_flashes[cell] = FLASH_TICKS

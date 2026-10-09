class_name GridModel
extends RefCounted
## Pure-data model of the 7x4 battle field. No nodes, no rendering.
##
## Coordinates are Vector2i(column, row) with (0, 0) at the top-left.
## Columns 0-2 start owned by the player side, column 3 is neutral, and
## columns 4-6 belong to the enemy side. Anyone may enter a neutral tile, but
## like every tile it holds at most one combatant at a time.
## Tile ownership is stored per tile so it can change mid-battle later.

## NEUTRAL is only a tile owner; combatants are always PLAYER or ENEMY.
enum Side { PLAYER, ENEMY, NEUTRAL }

const COLUMNS := 7
const ROWS := 4
const PLAYER_COLUMNS := 3
const NEUTRAL_COLUMN := 3

var _owners: Array[int] = []
var _occupants: Dictionary = {}  # Vector2i -> Combatant


func _init() -> void:
	reset_ownership()


## Restores the default split: player | neutral column | enemy.
func reset_ownership() -> void:
	_owners.resize(COLUMNS * ROWS)
	for y in ROWS:
		for x in COLUMNS:
			_owners[_index(Vector2i(x, y))] = default_owner(x)


static func default_owner(column: int) -> int:
	if column < PLAYER_COLUMNS:
		return Side.PLAYER
	if column == NEUTRAL_COLUMN:
		return Side.NEUTRAL
	return Side.ENEMY


## +1 for the player side (attacks travel right), -1 for the enemy side.
static func facing(side: int) -> int:
	return 1 if side == Side.PLAYER else -1


static func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS


func owner_of(cell: Vector2i) -> int:
	assert(is_in_bounds(cell), "cell out of bounds: %s" % cell)
	return _owners[_index(cell)]


func set_owner(cell: Vector2i, side: int) -> void:
	assert(is_in_bounds(cell), "cell out of bounds: %s" % cell)
	_owners[_index(cell)] = side


func occupant_at(cell: Vector2i) -> Combatant:
	return _occupants.get(cell)


func is_occupied(cell: Vector2i) -> bool:
	return _occupants.has(cell)


## A combatant may only stand on in-bounds, unoccupied tiles that its side
## owns or that are neutral.
func can_enter(side: int, cell: Vector2i) -> bool:
	if not is_in_bounds(cell) or is_occupied(cell):
		return false
	var tile_owner := owner_of(cell)
	return tile_owner == side or tile_owner == Side.NEUTRAL


func place(combatant: Combatant, cell: Vector2i) -> bool:
	if not can_enter(combatant.side, cell):
		return false
	_occupants[cell] = combatant
	combatant.cell = cell
	return true


func move(combatant: Combatant, to: Vector2i) -> bool:
	if occupant_at(combatant.cell) != combatant or not can_enter(combatant.side, to):
		return false
	_occupants.erase(combatant.cell)
	_occupants[to] = combatant
	combatant.cell = to
	return true


func remove(combatant: Combatant) -> void:
	if occupant_at(combatant.cell) == combatant:
		_occupants.erase(combatant.cell)


## First opposing combatant in front of `from`, scanning along its row in
## the direction `side` faces. Returns null if the row is clear.
func first_opponent_in_row(from: Vector2i, side: int) -> Combatant:
	var step := facing(side)
	var x := from.x + step
	while x >= 0 and x < COLUMNS:
		var other: Combatant = occupant_at(Vector2i(x, from.y))
		if other != null and other.side != side:
			return other
		x += step
	return null


## Closest living opposing combatant by grid distance (Manhattan). Ties go to
## the lowest row, then the lowest column, so the result is deterministic.
func nearest_opponent(from: Vector2i, side: int) -> Combatant:
	var best: Combatant = null
	var best_key := Vector3i.MAX
	for cell: Vector2i in _occupants:
		var other: Combatant = _occupants[cell]
		if other.side == side or not other.is_alive():
			continue
		var distance := absi(cell.x - from.x) + absi(cell.y - from.y)
		var key := Vector3i(distance, cell.y, cell.x)
		if key < best_key:
			best_key = key
			best = other
	return best


## Unoccupied neighbouring tiles (up, down, left, right) that `side` may enter.
func open_neighbours(cell: Vector2i, side: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if can_enter(side, cell + dir):
			result.append(cell + dir)
	return result


func _index(cell: Vector2i) -> int:
	return cell.y * COLUMNS + cell.x

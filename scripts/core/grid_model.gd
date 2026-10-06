class_name GridModel
extends RefCounted
## Pure-data model of the 8x4 battle field. No nodes, no rendering.
##
## Coordinates are Vector2i(column, row) with (0, 0) at the top-left.
## Columns 0-3 start owned by the player side, columns 4-7 by the enemy side.
## Tile ownership is stored per tile so it can change mid-battle later.

enum Side { PLAYER, ENEMY }

const COLUMNS := 8
const ROWS := 4
const PLAYER_COLUMNS := 4

var _owners: Array[int] = []
var _occupants: Dictionary = {}  # Vector2i -> Combatant


func _init() -> void:
	reset_ownership()


## Restores the default split: left half player, right half enemy.
func reset_ownership() -> void:
	_owners.resize(COLUMNS * ROWS)
	for y in ROWS:
		for x in COLUMNS:
			_owners[_index(Vector2i(x, y))] = Side.PLAYER if x < PLAYER_COLUMNS else Side.ENEMY


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


## A combatant may only stand on in-bounds, unoccupied tiles its side owns.
func can_enter(side: int, cell: Vector2i) -> bool:
	return is_in_bounds(cell) and owner_of(cell) == side and not is_occupied(cell)


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


func _index(cell: Vector2i) -> int:
	return cell.y * COLUMNS + cell.x

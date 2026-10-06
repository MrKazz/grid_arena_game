class_name CardData
extends Resource
## Static definition of a card. Instances live in res://data/cards/*.tres.

enum Targeting {
	## Hits every tile in `pattern`, relative to the user.
	TILES,
	## Hits the first opponent in the user's row (projectile).
	ROW_FIRST_HIT,
	## Hits the tile of the nearest opponent at the moment of targeting.
	AIMED,
}

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var damage: int = 10
@export var targeting: Targeting = Targeting.TILES
## Offsets from the user's tile. +x is "forward" (toward the opposing side)
## and is mirrored automatically for enemy users.
@export var pattern: Array[Vector2i] = []

class_name Combatant
extends RefCounted
## Anything that occupies a tile and has HP: the player, enemies, obstacles.

var id: StringName
var side: int
var cell := Vector2i(-1, -1)
var max_hp: int
var hp: int


func _init(p_id: StringName, p_side: int, p_max_hp: int) -> void:
	id = p_id
	side = p_side
	max_hp = p_max_hp
	hp = p_max_hp


func is_alive() -> bool:
	return hp > 0


## Applies damage and returns how much was actually dealt.
func take_damage(amount: int) -> int:
	var dealt := clampi(amount, 0, hp)
	hp -= dealt
	return dealt

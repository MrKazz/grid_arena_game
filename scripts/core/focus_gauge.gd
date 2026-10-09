class_name FocusGauge
extends RefCounted
## Fills one step per simulation tick. When full, the player may enter Focus (combat pauses to pick cards).

var fill_ticks: int
var ticks := 0


func _init(p_fill_ticks: int) -> void:
	fill_ticks = maxi(0, p_fill_ticks)


func tick() -> void:
	ticks = mini(ticks + 1, fill_ticks)


func is_full() -> bool:
	return ticks >= fill_ticks


func ratio() -> float:
	return 1.0 if fill_ticks == 0 else float(ticks) / fill_ticks


func reset() -> void:
	ticks = 0

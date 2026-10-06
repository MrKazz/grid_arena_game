class_name CardResolver
extends RefCounted
## Turns a card + user + grid into targeted tiles and damage. Stateless.


## Tiles the card affects. Off-grid tiles are dropped.
static func target_cells(card: CardData, user: Combatant, grid: GridModel) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match card.targeting:
		CardData.Targeting.ROW_FIRST_HIT:
			var target := grid.first_opponent_in_row(user.cell, user.side)
			if target != null:
				cells.append(target.cell)
		CardData.Targeting.TILES:
			var dir := GridModel.facing(user.side)
			for offset in card.pattern:
				var cell := user.cell + Vector2i(offset.x * dir, offset.y)
				if GridModel.is_in_bounds(cell) and not cells.has(cell):
					cells.append(cell)
	return cells


## Damages every opposing combatant on the targeted tiles. Returns those hit.
static func apply(card: CardData, user: Combatant, grid: GridModel) -> Array[Combatant]:
	var hits: Array[Combatant] = []
	for cell in target_cells(card, user, grid):
		var target := grid.occupant_at(cell)
		if target != null and target.side != user.side and target.is_alive():
			target.take_damage(card.damage)
			hits.append(target)
	return hits

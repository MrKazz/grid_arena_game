class_name CardResolver
extends RefCounted
## Turns a card + user + grid into targeted tiles and damage. Stateless.


## Tiles the card affects right now. Off-grid tiles are dropped.
static func target_cells(card: CardData, user: Combatant, grid: GridModel) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match card.targeting:
		CardData.Targeting.ROW_FIRST_HIT:
			var target := grid.first_opponent_in_row(user.cell, user.side)
			if target != null:
				cells.append(target.cell)
		CardData.Targeting.AIMED:
			var target := grid.nearest_opponent(user.cell, user.side)
			if target != null:
				cells.append(target.cell)
		CardData.Targeting.TILES:
			var dir := GridModel.facing(user.side)
			for offset in card.pattern:
				var cell := user.cell + Vector2i(offset.x * dir, offset.y)
				if GridModel.is_in_bounds(cell) and not cells.has(cell):
					cells.append(cell)
	return cells


## Tiles to warn about while an attack winds up. Projectiles warn along the
## whole row ahead; everything else warns on the tiles it will hit.
static func telegraph_cells(card: CardData, user: Combatant, grid: GridModel) -> Array[Vector2i]:
	if card.targeting != CardData.Targeting.ROW_FIRST_HIT:
		return target_cells(card, user, grid)
	var cells: Array[Vector2i] = []
	var cell := user.cell + Vector2i(GridModel.facing(user.side), 0)
	while GridModel.is_in_bounds(cell):
		cells.append(cell)
		cell.x += GridModel.facing(user.side)
	return cells


## Damages every opposing combatant on the targeted tiles. Returns those hit.
static func apply(card: CardData, user: Combatant, grid: GridModel) -> Array[Combatant]:
	return apply_to_cells(card, user, grid, target_cells(card, user, grid))


## Like apply(), but on tiles chosen earlier (e.g. locked in at wind-up start).
static func apply_to_cells(card: CardData, user: Combatant, grid: GridModel,
		cells: Array[Vector2i]) -> Array[Combatant]:
	var hits: Array[Combatant] = []
	for cell in cells:
		var target := grid.occupant_at(cell)
		if target != null and target.side != user.side and target.is_alive():
			target.take_damage(card.damage)
			hits.append(target)
	return hits

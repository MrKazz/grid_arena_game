class_name Deck
extends RefCounted
## Draw pile / hand / discard pile with a seeded RNG so battles can be replayed.
##
## Cards taken out of the hand for use (see take_from_hand) are held by the
## caller until they are passed back to discard().

var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand_size: int

var _rng := RandomNumberGenerator.new()


func _init(cards: Array[CardData], p_hand_size: int = 5, rng_seed: int = 0) -> void:
	hand_size = p_hand_size
	_rng.seed = rng_seed
	draw_pile = cards.duplicate()
	_shuffle(draw_pile)


## Draws up to `count` cards, recycling the discard pile when the draw pile
## runs out. Returns how many were drawn.
func draw(count: int) -> int:
	var drawn := 0
	while drawn < count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile
			discard_pile = []
			_shuffle(draw_pile)
		hand.append(draw_pile.pop_back())
		drawn += 1
	return drawn


func fill_hand() -> int:
	return draw(maxi(0, hand_size - hand.size()))


## Removes the given hand indices and returns those cards in the order given.
## Returns an empty array (and changes nothing) if any index is invalid or repeated.
func take_from_hand(indices: Array[int]) -> Array[CardData]:
	var taken: Array[CardData] = []
	var seen := {}
	for i in indices:
		if i < 0 or i >= hand.size() or seen.has(i):
			return taken
		seen[i] = true
	for i in indices:
		taken.append(hand[i])
	var sorted := indices.duplicate()
	sorted.sort()
	sorted.reverse()
	for i in sorted:
		hand.remove_at(i)
	return taken


func discard(card: CardData) -> void:
	discard_pile.append(card)


## Returns the whole hand to the draw pile, shuffles, and draws a fresh hand.
func reshuffle_hand() -> void:
	draw_pile.append_array(hand)
	hand.clear()
	_shuffle(draw_pile)
	fill_hand()


## Cards currently tracked by the deck (excludes cards held by the caller).
func card_count() -> int:
	return draw_pile.size() + hand.size() + discard_pile.size()


## Fisher-Yates with our own RNG; Array.shuffle() uses the global RNG.
func _shuffle(cards: Array[CardData]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp

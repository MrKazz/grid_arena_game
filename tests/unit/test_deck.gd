extends TestCase


func test_fill_hand_draws_hand_size() -> void:
	var deck := Deck.new(Fixtures.cards(10), 5, 1)
	assert_eq(deck.fill_hand(), 5)
	assert_eq(deck.hand.size(), 5)
	assert_eq(deck.draw_pile.size(), 5)
	assert_eq(deck.fill_hand(), 0, "already full")


func test_small_deck_draws_what_it_can() -> void:
	var deck := Deck.new(Fixtures.cards(3), 5, 1)
	assert_eq(deck.fill_hand(), 3)


func test_same_seed_same_order() -> void:
	var a := Deck.new(Fixtures.cards(20), 5, 42)
	var b := Deck.new(Fixtures.cards(20), 5, 42)
	assert_eq(Fixtures.ids(a.draw_pile), Fixtures.ids(b.draw_pile))


func test_different_seed_different_order() -> void:
	var a := Deck.new(Fixtures.cards(20), 5, 1)
	var b := Deck.new(Fixtures.cards(20), 5, 2)
	assert_ne(Fixtures.ids(a.draw_pile), Fixtures.ids(b.draw_pile))


func test_take_from_hand_keeps_requested_order() -> void:
	var deck := Deck.new(Fixtures.cards(10), 5, 1)
	deck.fill_hand()
	var expected: Array[CardData] = [deck.hand[3], deck.hand[0]]
	var taken := deck.take_from_hand([3, 0])
	assert_eq(taken, expected)
	assert_eq(deck.hand.size(), 3)
	assert_false(deck.hand.has(expected[0]))


func test_take_from_hand_rejects_bad_indices() -> void:
	var deck := Deck.new(Fixtures.cards(10), 5, 1)
	deck.fill_hand()
	assert_eq(deck.take_from_hand([0, 0]).size(), 0, "duplicate")
	assert_eq(deck.take_from_hand([5]).size(), 0, "out of range")
	assert_eq(deck.take_from_hand([-1]).size(), 0, "negative")
	assert_eq(deck.hand.size(), 5, "hand untouched")


func test_discard_recycles_when_draw_pile_empty() -> void:
	var deck := Deck.new(Fixtures.cards(6), 5, 1)
	deck.fill_hand()
	for card in deck.take_from_hand([0, 1, 2]):
		deck.discard(card)
	assert_eq(deck.draw_pile.size(), 1)
	assert_eq(deck.fill_hand(), 3)
	assert_eq(deck.hand.size(), 5)
	assert_eq(deck.discard_pile.size(), 0)


func test_reshuffle_hand_returns_cards_and_redraws() -> void:
	var deck := Deck.new(Fixtures.cards(10), 5, 7)
	deck.fill_hand()
	var before := Fixtures.ids(deck.hand)
	deck.reshuffle_hand()
	assert_eq(deck.hand.size(), 5)
	assert_eq(deck.card_count(), 10)
	assert_ne(Fixtures.ids(deck.hand), before, "seed 7 should produce a different hand")


func test_cards_are_conserved_through_a_long_sequence() -> void:
	var deck := Deck.new(Fixtures.cards(16), 5, 99)
	var held: Array[CardData] = []
	for round in 50:
		deck.fill_hand()
		held.append_array(deck.take_from_hand([0, 1]))
		if round % 3 == 0:
			deck.reshuffle_hand()
		while held.size() > 1:
			deck.discard(held.pop_front())
		assert_eq(deck.card_count() + held.size(), 16, "round %d" % round)

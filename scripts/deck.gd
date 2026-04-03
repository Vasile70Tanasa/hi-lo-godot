class_name Deck
extends RefCounted

# Suits and rank names
const SUITS = ["♠", "♥", "♦", "♣"]
const RANK_NAMES = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var cards: Array = []

func _init():
	reset()

func reset():
	cards.clear()
	for suit in SUITS:
		for rank in range(1, 14):  # 1=Ace ... 13=King
			cards.append({"rank": rank, "suit": suit})
	cards.shuffle()

func draw() -> Dictionary:
	return cards.pop_back()

func is_empty() -> bool:
	return cards.is_empty()

static func card_text(card: Dictionary) -> String:
	return RANK_NAMES[card.rank] + " " + card.suit

static func suit_color(card: Dictionary) -> Color:
	if card.suit == "♥" or card.suit == "♦":
		return Color.RED
	return Color.WHITE

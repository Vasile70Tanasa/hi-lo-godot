class_name Deck
extends RefCounted

const TOTAL_CARDS := 52
const SUITS := ["spades", "hearts", "diamonds", "clubs"]
const SUIT_SYMBOLS := {
	"spades": "♠",
	"hearts": "♥",
	"diamonds": "♦",
	"clubs": "♣",
}
const RANK_NAMES := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var cards: Array[Dictionary] = []

func _init() -> void:
	reset()

func reset() -> void:
	cards.clear()
	for suit in SUITS:
		for rank in range(1, 14):
			cards.append({"rank": rank, "suit": suit})
	cards.shuffle()

func draw() -> Dictionary:
	if cards.is_empty():
		return {}
	return cards.pop_back()

func is_empty() -> bool:
	return cards.is_empty()

func cards_left() -> int:
	return cards.size()

static func rank_value(rank: int) -> int:
	if rank == 1:
		return 14
	return rank

static func card_value(card: Dictionary) -> int:
	return rank_value(int(card["rank"]))

static func rank_text(card: Dictionary) -> String:
	return RANK_NAMES[int(card["rank"])]

static func suit_symbol(card: Dictionary) -> String:
	return SUIT_SYMBOLS[card["suit"]]

static func card_text(card: Dictionary) -> String:
	return "%s %s" % [rank_text(card), suit_symbol(card)]

static func suit_color(card: Dictionary) -> Color:
	if card["suit"] == "hearts" or card["suit"] == "diamonds":
		return Color("b33951")
	return Color("16202a")

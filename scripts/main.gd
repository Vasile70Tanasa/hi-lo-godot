extends Control

var deck: Deck
var current_card: Dictionary
var score: int = 0

@onready var card_label: Label = %CardLabel
@onready var score_label: Label = %ScoreLabel
@onready var higher_button: Button = %HigherButton
@onready var lower_button: Button = %LowerButton
@onready var result_label: Label = %ResultLabel
@onready var play_again_button: Button = %PlayAgainButton

func _ready():
	higher_button.pressed.connect(_on_higher)
	lower_button.pressed.connect(_on_lower)
	play_again_button.pressed.connect(_on_play_again)
	start_game()

func start_game():
	deck = Deck.new()
	score = 0
	current_card = deck.draw()
	update_ui()
	set_game_over(false)

func update_ui():
	card_label.text = Deck.card_text(current_card)
	card_label.add_theme_color_override("font_color", Deck.suit_color(current_card))
	score_label.text = "Scor: " + str(score)
	result_label.text = ""

func _on_higher():
	guess(true)

func _on_lower():
	guess(false)

func guess(player_said_higher: bool):
	if deck.is_empty():
		game_over("Ai terminat tot pachetul! Bravo!")
		return

	var next_card = deck.draw()
	var next_is_higher = next_card.rank > current_card.rank
	var is_equal = next_card.rank == current_card.rank

	# Show the new card
	current_card = next_card
	card_label.text = Deck.card_text(current_card)
	card_label.add_theme_color_override("font_color", Deck.suit_color(current_card))

	if is_equal:
		# Equal counts as correct
		score += 1
		score_label.text = "Scor: " + str(score)
		result_label.text = "Egal - conteaza ca punct!"
		result_label.add_theme_color_override("font_color", Color.YELLOW)
	elif player_said_higher == next_is_higher:
		score += 1
		score_label.text = "Scor: " + str(score)
		result_label.text = "Corect!"
		result_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		game_over("Gresit! Scor final: " + str(score))

func game_over(message: String):
	result_label.text = message
	result_label.add_theme_color_override("font_color", Color.RED)
	set_game_over(true)

func set_game_over(is_over: bool):
	higher_button.visible = !is_over
	lower_button.visible = !is_over
	play_again_button.visible = is_over

func _on_play_again():
	start_game()

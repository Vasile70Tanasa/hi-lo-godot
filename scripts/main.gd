extends Control

const SAVE_PATH := "user://save_data.json"
const RESULT_NEUTRAL := Color("f3f1d4")
const RESULT_SUCCESS := Color("8fe388")
const RESULT_FAIL := Color("ff7b72")
const RESULT_WIN := Color("ffe08a")
const SCREEN_SHAKE_STRENGTH := 10.0
const SCREEN_SHAKE_STEP := 0.03
const SFX_SAMPLE_RATE := 44100.0
const SFX_BUFFER_LENGTH := 0.6
const MEDIUM_STREAK_THRESHOLD := 5
const HIGH_STREAK_THRESHOLD := 10

var deck: Deck
var game_state: GameState
var current_card: Dictionary = {}
var high_score: int = 0
var is_muted: bool = false
var round_active: bool = false
var input_locked: bool = false
var awaiting_deck_pick: bool = false
var pending_guess_higher: bool = false
var remaining_deck_revealed: bool = false
var remaining_deck_reveal_in_progress: bool = false
var awaiting_tie_bet: bool = false
var pending_tie_bet: bool = false
var deck_reveal_generation: int = 0
var pending_level_intro_message: String = ""
var pending_level_outcome: Dictionary = {}
var pending_reward_message: String = ""
var shake_tween: Tween
var bonus_banner_tween: Tween
var card_sfx_player: AudioStreamPlayer
var success_sfx_player: AudioStreamPlayer
var fail_sfx_player: AudioStreamPlayer
var effects_layer: Control
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var background: ColorRect = %Background
@onready var deck_grid: GridContainer = %DeckGrid
@onready var deck_label: Label = %DeckLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var bonus_banner: PanelContainer = %BonusBanner
@onready var bonus_banner_label: Label = %BonusBannerLabel
@onready var modifier_banner: PanelContainer = %ModifierBanner
@onready var modifier_banner_label: Label = %ModifierBannerLabel
@onready var card_panel: PanelContainer = %CardPanel
@onready var card_label: Label = %CardLabel
@onready var card_suit_center: Label = %CardSuitCenter
@onready var corner_rank_top: Label = %CornerRankTop
@onready var corner_suit_top: Label = %CornerSuitTop
@onready var corner_rank_bottom: Label = %CornerRankBottom
@onready var corner_suit_bottom: Label = %CornerSuitBottom
@onready var score_label: Label = %ScoreLabel
@onready var high_score_label: Label = %HighScoreLabel
@onready var remaining_label: Label = %RemainingLabel
@onready var streak_label: Label = %StreakLabel
@onready var mute_button: Button = %MuteButton
@onready var higher_button: Button = %HigherButton
@onready var lower_button: Button = %LowerButton
@onready var lower_preview_panel: PanelContainer = %LowerPreviewPanel
@onready var lower_preview_rank_top: Label = %LowerPreviewRankTop
@onready var lower_preview_suit_top: Label = %LowerPreviewSuitTop
@onready var lower_preview_suit_center: Label = %LowerPreviewSuitCenter
@onready var lower_preview_rank_center: Label = %LowerPreviewRankCenter
@onready var lower_preview_rank_bottom: Label = %LowerPreviewRankBottom
@onready var lower_preview_suit_bottom: Label = %LowerPreviewSuitBottom
@onready var higher_preview_panel: PanelContainer = %HigherPreviewPanel
@onready var higher_preview_rank_top: Label = %HigherPreviewRankTop
@onready var higher_preview_suit_top: Label = %HigherPreviewSuitTop
@onready var higher_preview_suit_center: Label = %HigherPreviewSuitCenter
@onready var higher_preview_rank_center: Label = %HigherPreviewRankCenter
@onready var higher_preview_rank_bottom: Label = %HigherPreviewRankBottom
@onready var higher_preview_suit_bottom: Label = %HigherPreviewSuitBottom
@onready var result_label: Label = %ResultLabel
@onready var back_button: Button = %BackButton
@onready var play_again_button: Button = %PlayAgainButton
@onready var start_overlay: CenterContainer = %StartOverlay
@onready var level_overlay: CenterContainer = %LevelOverlay
@onready var level_title: Label = %LevelTitle
@onready var level_text: Label = %LevelText
@onready var reward_choice_row: HBoxContainer = %RewardChoiceRow
@onready var reward_life_button: Button = %RewardLifeButton
@onready var reward_draws_button: Button = %RewardDrawsButton
@onready var reward_hint_label: Label = %RewardHintLabel
@onready var level_continue_button: Button = %LevelContinueButton
@onready var start_button: Button = %StartButton

func _ready() -> void:
	_setup_audio()
	_setup_effects_layer()
	rng.randomize()
	mute_button.pressed.connect(_on_mute_pressed)
	higher_button.pressed.connect(_on_higher)
	lower_button.pressed.connect(_on_lower)
	back_button.pressed.connect(_on_back_pressed)
	play_again_button.pressed.connect(_on_play_again)
	start_button.pressed.connect(_on_start_pressed)
	reward_life_button.pressed.connect(_on_reward_life_pressed)
	reward_draws_button.pressed.connect(_on_reward_draws_pressed)
	level_continue_button.pressed.connect(_on_level_continue_pressed)
	card_panel.resized.connect(_refresh_pivots)
	streak_label.resized.connect(_refresh_pivots)
	high_score = _load_high_score()
	_update_mute_button()
	await get_tree().process_frame
	_refresh_pivots()
	_show_start_state()

func start_game() -> void:
	deck_reveal_generation += 1
	game_state = GameState.new()
	start_overlay.visible = false
	level_overlay.visible = false
	play_again_button.visible = false
	back_button.visible = false
	_reset_level_overlay_state()
	pending_level_intro_message = ""
	subtitle_label.text = "Build enough correct guesses before the level runs out of draws."
	_start_level("Run started. %s" % _current_level_brief())

func _start_level(message: String) -> void:
	deck = Deck.new()
	round_active = true
	input_locked = false
	awaiting_deck_pick = false
	awaiting_tie_bet = false
	pending_guess_higher = false
	remaining_deck_revealed = false
	remaining_deck_reveal_in_progress = false
	level_overlay.visible = false
	pending_level_intro_message = ""
	_reset_level_overlay_state()
	current_card = deck.draw()
	play_again_button.visible = false
	back_button.visible = false
	card_panel.visible = true
	_apply_card_visual(current_card)
	_play_card_sound()
	_update_status_labels()
	_set_result_text(message, RESULT_NEUTRAL)
	_reset_choice_slots()
	_set_guess_buttons_enabled(true)

func _show_start_state() -> void:
	deck_reveal_generation += 1
	start_overlay.visible = true
	round_active = false
	input_locked = false
	awaiting_deck_pick = false
	pending_guess_higher = false
	remaining_deck_revealed = false
	remaining_deck_reveal_in_progress = false
	level_overlay.visible = false
	pending_level_intro_message = ""
	_reset_level_overlay_state()
	game_state = null
	current_card = {}
	card_panel.scale = Vector2.ONE
	card_panel.visible = true
	_apply_card_back()
	_update_status_labels()
	subtitle_label.text = "A run-based card game: beat level targets before the draw limit ends."
	_set_result_text("Press Start to begin.", RESULT_NEUTRAL)
	back_button.visible = false
	play_again_button.visible = false
	_reset_choice_slots()
	_set_guess_buttons_enabled(false)

func _update_status_labels() -> void:
	var run_score: int = 0 if game_state == null else game_state.run_score
	var active_multiplier: int = 1 if game_state == null else game_state.get_streak_multiplier()
	var modifier_label: String = "" if game_state == null else game_state.get_level_modifier_label()
	var modifier_description: String = "" if game_state == null else game_state.get_level_modifier_description()
	if modifier_label == "Precision" and game_state != null:
		score_label.text = "Run: %d  Precision: %d/2" % [run_score, game_state.get_precision_chain()]
	else:
		score_label.text = "Run: %d  Mult: x%d" % [run_score, active_multiplier]
	high_score_label.text = "Best: %d" % high_score
	var bonus_draws: int = 0 if game_state == null else game_state.get_active_bonus_draws()
	var _cards_left: int = _get_cards_left_for_display()
	if game_state == null:
		remaining_label.text = "Level: 1  Lives: %d" % GameState.DEFAULT_LIVES
		streak_label.text = "Goal: 0 / 5  Draws: 0 / 10"
	else:
		remaining_label.text = "Level: %d  Lives: %d" % [game_state.get_level_number(), game_state.lives]
		streak_label.text = "Goal: %d / %d  Draws: %d / %d  Streak: %d" % [
			game_state.level_score,
			game_state.get_level_target(),
			game_state.draws_used,
			game_state.get_level_draw_limit(),
			game_state.current_streak,
		]
	if bonus_draws > 0:
		remaining_label.text += "  Bonus: +%d draws" % bonus_draws
	var streak_color: Color = Color("f5f1da")
	var streak_value: int = 0 if game_state == null else game_state.current_streak
	if streak_value >= 10:
		streak_color = Color("ffd166")
	elif streak_value >= 5:
		streak_color = Color("ffe29a")
	streak_label.add_theme_color_override("font_color", streak_color)
	_set_bonus_banner_state(bonus_draws)
	_set_modifier_banner_state(modifier_label, modifier_description)
	_update_deck_label()
	_rebuild_deck_view()

func _current_level_brief() -> String:
	if game_state == null:
		return ""
	var brief: String = "Level %d: reach %d points in %d draws" % [
		game_state.get_level_number(),
		game_state.get_level_target(),
		game_state.get_level_draw_limit(),
	]
	var bonus_draws: int = game_state.get_active_bonus_draws()
	if bonus_draws > 0:
		brief += " (%d bonus draws active)." % bonus_draws
	else:
		brief += "."
	var modifier_label: String = game_state.get_level_modifier_label()
	if not modifier_label.is_empty():
		brief += " Modifier: %s." % modifier_label
	return brief

func _set_bonus_banner_state(bonus_draws: int) -> void:
	var has_bonus: bool = bonus_draws > 0
	bonus_banner.visible = has_bonus
	if has_bonus:
		bonus_banner_label.text = "Bonus Active: +%d draws this level" % bonus_draws
	else:
		bonus_banner_label.text = ""

	var table_color: Color = Color("0f703e") if has_bonus else Color("155835")
	background.color = table_color
	deck_label.add_theme_color_override("font_color", Color("ffd166") if has_bonus else Color("f5f1da"))

	if bonus_banner_tween != null:
		bonus_banner_tween.kill()
		bonus_banner_tween = null

	if not has_bonus:
		bonus_banner.scale = Vector2.ONE
		return

	bonus_banner.scale = Vector2.ONE
	bonus_banner_tween = create_tween()
	bonus_banner_tween.set_loops()
	bonus_banner_tween.tween_property(bonus_banner, "scale", Vector2(1.015, 1.015), 0.65)
	bonus_banner_tween.tween_property(bonus_banner, "scale", Vector2.ONE, 0.65)

func _set_modifier_banner_state(modifier_label: String, modifier_description: String) -> void:
	var has_modifier: bool = not modifier_label.is_empty()
	modifier_banner.visible = has_modifier
	if has_modifier:
		var short_hint: String = modifier_description
		if modifier_label == "Royal Bonus":
			short_hint = "J, Q, K, and A give +1 point"
		elif modifier_label == "Blackout":
			short_hint = "Only black revealed cards score"
		elif modifier_label == "Precision":
			short_hint = "2 correct in a row = 3 points"
		modifier_banner_label.text = "Modifier: %s | %s" % [modifier_label, short_hint]
	else:
		modifier_banner_label.text = ""

func _reset_level_overlay_state() -> void:
	pending_level_outcome = {}
	pending_reward_message = ""
	reward_choice_row.visible = false
	reward_hint_label.visible = false
	reward_hint_label.text = ""
	reward_life_button.disabled = false
	reward_draws_button.disabled = false
	reward_life_button.text = "+1 Life"
	reward_draws_button.text = "+%d Draws" % GameState.NEXT_LEVEL_BONUS_DRAWS
	level_continue_button.visible = true

func _refresh_level_overlay_content() -> void:
	if game_state == null or pending_level_outcome.is_empty():
		return
	var cleared_level_number: int = int(pending_level_outcome.get("level_number", game_state.get_level_number() - 1))
	var next_level_number: int = int(pending_level_outcome.get("next_level_number", game_state.get_level_number()))
	var next_level_bonus_draws: int = game_state.get_active_bonus_draws()
	var reward_choice_available: bool = bool(pending_level_outcome.get("reward_choice_available", false))
	var reward_choice_pending: bool = reward_choice_available and game_state.has_pending_reward_choice()
	var modifier_label: String = game_state.get_level_modifier_label()
	var modifier_description: String = game_state.get_level_modifier_description()

	level_title.text = "Checkpoint Reward" if reward_choice_pending else "Level %d Cleared" % cleared_level_number
	level_text.text = "Run score: %d\nLives left: %d\n\nNext up: reach %d points in %d draws." % [
		game_state.run_score,
		game_state.lives,
		game_state.get_level_target(),
		game_state.get_level_draw_limit(),
	]
	if next_level_bonus_draws > 0:
		level_text.text += "\nReward selected: +%d draws for Level %d." % [next_level_bonus_draws, next_level_number]
	elif reward_choice_pending:
		level_text.text += "\nCheckpoint reward ready for Level %d." % next_level_number
	if not modifier_label.is_empty():
		level_text.text += "\nModifier: %s - %s" % [modifier_label, modifier_description]

	reward_choice_row.visible = reward_choice_pending
	level_continue_button.visible = not reward_choice_row.visible
	reward_life_button.disabled = not game_state.can_gain_life()
	reward_draws_button.disabled = false
	if game_state.can_gain_life():
		reward_life_button.text = "+1 Life (%d/%d)" % [mini(game_state.lives + 1, GameState.MAX_LIVES), GameState.MAX_LIVES]
	else:
		reward_life_button.text = "Lives Full"
	reward_draws_button.text = "+%d Draws (Lv %d)" % [GameState.NEXT_LEVEL_BONUS_DRAWS, next_level_number]

	if reward_choice_row.visible:
		reward_hint_label.visible = true
		if game_state.can_gain_life():
			reward_hint_label.text = "Choose one reward. +1 Life is permanent for this run, while +%d Draws only helps the next level." % GameState.NEXT_LEVEL_BONUS_DRAWS
		else:
			reward_hint_label.text = "Lives are full, so +%d Draws is the only available reward." % GameState.NEXT_LEVEL_BONUS_DRAWS
	elif not pending_reward_message.is_empty():
		reward_hint_label.visible = true
		reward_hint_label.text = pending_reward_message
	else:
		reward_hint_label.visible = false
		reward_hint_label.text = ""

func _update_deck_label() -> void:
	if start_overlay.visible:
		deck_label.text = "Deck"
	elif remaining_deck_reveal_in_progress or (remaining_deck_revealed and !round_active):
		deck_label.text = "Remaining Cards"
	elif awaiting_deck_pick:
		deck_label.text = "Pick a Card"
	else:
		deck_label.text = "Deck"

func _get_cards_left_for_display() -> int:
	if deck == null or current_card.is_empty():
		return Deck.TOTAL_CARDS
	return deck.cards_left()

func _rebuild_deck_view() -> void:
	for child: Node in deck_grid.get_children():
		deck_grid.remove_child(child)
		child.queue_free()

	var cards_left: int = _get_cards_left_for_display()
	var reveal_remaining_cards: bool = _should_show_remaining_deck_fronts()
	for index in range(cards_left):
		var deck_button: Button = Button.new()
		deck_button.custom_minimum_size = Vector2(34, 50)
		deck_button.focus_mode = Control.FOCUS_NONE
		if reveal_remaining_cards and deck != null and index < deck.cards.size():
			var remaining_card: Dictionary = deck.cards[index]
			_apply_deck_card_front(deck_button, remaining_card)
		else:
			_apply_deck_card_back(deck_button)
			deck_button.pressed.connect(_on_deck_card_pressed)
		deck_grid.add_child(deck_button)

func _make_deck_card_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _should_show_remaining_deck_fronts() -> bool:
	return !round_active and !start_overlay.visible and deck != null and !current_card.is_empty() and remaining_deck_revealed

func _apply_deck_card_back(deck_button: Button) -> void:
	deck_button.text = "HI\nLO"
	deck_button.disabled = !awaiting_deck_pick or !round_active
	deck_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if awaiting_deck_pick and round_active else Control.CURSOR_ARROW
	var is_pick_state: bool = awaiting_deck_pick and round_active
	var base_fill: Color = Color("24575a") if is_pick_state else Color("173246")
	var hover_fill: Color = Color("2f7376") if is_pick_state else Color("23516f")
	var pressed_fill: Color = Color("183e40") if is_pick_state else Color("102635")
	var border_color: Color = Color("ffd166") if is_pick_state else Color(0.952941, 0.945098, 0.831373, 0.24)
	var disabled_border: Color = Color(0.952941, 0.945098, 0.831373, 0.32) if is_pick_state else Color(0.952941, 0.945098, 0.831373, 0.14)
	deck_button.add_theme_stylebox_override("normal", _make_deck_card_style(base_fill, border_color))
	deck_button.add_theme_stylebox_override("hover", _make_deck_card_style(hover_fill, Color("ffe6a7")))
	deck_button.add_theme_stylebox_override("pressed", _make_deck_card_style(pressed_fill, Color(1.0, 0.901961, 0.654902, 0.6)))
	deck_button.add_theme_stylebox_override("disabled", _make_deck_card_style(base_fill, disabled_border))
	deck_button.add_theme_color_override("font_color", Color("f3edd1"))
	deck_button.add_theme_color_override("font_hover_color", Color("fff7de"))
	deck_button.add_theme_color_override("font_pressed_color", Color("f3edd1"))
	deck_button.add_theme_color_override("font_disabled_color", Color(0.952941, 0.945098, 0.831373, 0.55))
	deck_button.add_theme_font_size_override("font_size", 10)

func _apply_deck_card_front(deck_button: Button, card: Dictionary) -> void:
	var suit_color: Color = Deck.suit_color(card)
	deck_button.text = "%s\n%s" % [Deck.rank_text(card), Deck.suit_symbol(card)]
	deck_button.disabled = true
	deck_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	deck_button.add_theme_stylebox_override("normal", _make_deck_card_style(Color("f7f1df"), Color(0.14902, 0.184314, 0.231373, 0.22)))
	deck_button.add_theme_stylebox_override("hover", _make_deck_card_style(Color("f7f1df"), Color(0.14902, 0.184314, 0.231373, 0.22)))
	deck_button.add_theme_stylebox_override("pressed", _make_deck_card_style(Color("f7f1df"), Color(0.14902, 0.184314, 0.231373, 0.22)))
	deck_button.add_theme_stylebox_override("disabled", _make_deck_card_style(Color("f7f1df"), Color(0.14902, 0.184314, 0.231373, 0.22)))
	deck_button.add_theme_color_override("font_color", suit_color)
	deck_button.add_theme_color_override("font_hover_color", suit_color)
	deck_button.add_theme_color_override("font_pressed_color", suit_color)
	deck_button.add_theme_color_override("font_disabled_color", suit_color)
	deck_button.add_theme_font_size_override("font_size", 11)

func _start_remaining_deck_reveal() -> void:
	if remaining_deck_revealed or remaining_deck_reveal_in_progress:
		return
	if _is_deck_reveal_cancelled(deck_reveal_generation):
		return
	remaining_deck_reveal_in_progress = true
	_update_deck_label()
	var generation: int = deck_reveal_generation
	var cards_snapshot: Array[Dictionary] = deck.cards.duplicate(true)
	var deck_buttons: Array[Button] = []
	for child: Node in deck_grid.get_children():
		var deck_button: Button = child as Button
		if deck_button != null:
			deck_buttons.append(deck_button)

	var reveal_count: int = mini(deck_buttons.size(), cards_snapshot.size())
	for index in range(reveal_count):
		if _is_deck_reveal_cancelled(generation):
			_stop_remaining_deck_reveal()
			return
		var deck_button: Button = deck_buttons[index]
		if not is_instance_valid(deck_button):
			continue
		var flip_finished: bool = await _animate_deck_card_flip(deck_button, cards_snapshot[index], generation)
		if not flip_finished and _is_deck_reveal_cancelled(generation):
			_stop_remaining_deck_reveal()
			return
		if index < reveal_count - 1:
			await get_tree().create_timer(0.02).timeout

	if _is_deck_reveal_cancelled(generation):
		_stop_remaining_deck_reveal()
		return

	remaining_deck_reveal_in_progress = false
	remaining_deck_revealed = true
	_update_deck_label()

func _animate_deck_card_flip(deck_button: Button, card: Dictionary, generation: int) -> bool:
	if not is_instance_valid(deck_button) or _is_deck_reveal_cancelled(generation):
		return false
	deck_button.pivot_offset = deck_button.custom_minimum_size / 2.0
	deck_button.scale = Vector2.ONE
	deck_button.rotation = 0.0
	var close_tween: Tween = create_tween()
	close_tween.bind_node(deck_button)
	close_tween.set_trans(Tween.TRANS_CUBIC)
	close_tween.set_ease(Tween.EASE_IN)
	close_tween.set_parallel(true)
	close_tween.tween_property(deck_button, "scale", Vector2(0.05, 1.07), 0.05)
	close_tween.tween_property(deck_button, "rotation", -0.08, 0.05)
	await close_tween.finished
	if not is_instance_valid(deck_button) or _is_deck_reveal_cancelled(generation):
		return false

	_apply_deck_card_front(deck_button, card)

	var open_tween: Tween = create_tween()
	open_tween.bind_node(deck_button)
	open_tween.set_trans(Tween.TRANS_BACK)
	open_tween.set_ease(Tween.EASE_OUT)
	open_tween.set_parallel(true)
	open_tween.tween_property(deck_button, "scale", Vector2(1.12, 0.97), 0.08)
	open_tween.tween_property(deck_button, "rotation", 0.06, 0.08)
	await open_tween.finished
	if not is_instance_valid(deck_button) or _is_deck_reveal_cancelled(generation):
		return false

	var settle_tween: Tween = create_tween()
	settle_tween.bind_node(deck_button)
	settle_tween.set_trans(Tween.TRANS_SINE)
	settle_tween.set_ease(Tween.EASE_OUT)
	settle_tween.set_parallel(true)
	settle_tween.tween_property(deck_button, "scale", Vector2.ONE, 0.04)
	settle_tween.tween_property(deck_button, "rotation", 0.0, 0.04)
	return true

func _is_deck_reveal_cancelled(generation: int) -> bool:
	return generation != deck_reveal_generation or round_active or start_overlay.visible or deck == null

func _stop_remaining_deck_reveal() -> void:
	remaining_deck_reveal_in_progress = false
	_update_deck_label()

func _apply_card_visual(card: Dictionary) -> void:
	var rank_text: String = Deck.rank_text(card)
	var suit_symbol: String = Deck.suit_symbol(card)
	var suit_color: Color = Deck.suit_color(card)
	card_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	card_label.text = rank_text
	card_suit_center.text = suit_symbol
	corner_rank_top.text = rank_text
	corner_suit_top.text = suit_symbol
	corner_rank_bottom.text = rank_text
	corner_suit_bottom.text = suit_symbol
	card_label.add_theme_color_override("font_color", suit_color)
	card_suit_center.add_theme_color_override("font_color", suit_color)
	corner_rank_top.add_theme_color_override("font_color", suit_color)
	corner_suit_top.add_theme_color_override("font_color", suit_color)
	corner_rank_bottom.add_theme_color_override("font_color", suit_color)
	corner_suit_bottom.add_theme_color_override("font_color", suit_color)

func _apply_card_back() -> void:
	var back_color: Color = Color("16202a")
	card_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	card_label.text = "?"
	card_suit_center.text = "?"
	corner_rank_top.text = "?"
	corner_suit_top.text = ""
	corner_rank_bottom.text = "?"
	corner_suit_bottom.text = ""
	card_label.add_theme_color_override("font_color", back_color)
	card_suit_center.add_theme_color_override("font_color", back_color)
	corner_rank_top.add_theme_color_override("font_color", back_color)
	corner_suit_top.add_theme_color_override("font_color", back_color)
	corner_rank_bottom.add_theme_color_override("font_color", back_color)
	corner_suit_bottom.add_theme_color_override("font_color", back_color)

func _set_result_text(message: String, color: Color) -> void:
	result_label.text = message
	result_label.add_theme_color_override("font_color", color)

func _update_mute_button() -> void:
	mute_button.text = "Sound: Off" if is_muted else "Sound: On"

func _set_muted(value: bool) -> void:
	is_muted = value
	_update_mute_button()
	if is_muted:
		if card_sfx_player != null:
			card_sfx_player.stop()
		if success_sfx_player != null:
			success_sfx_player.stop()
		if fail_sfx_player != null:
			fail_sfx_player.stop()

func _set_guess_buttons_enabled(is_enabled: bool) -> void:
	higher_button.disabled = !is_enabled
	lower_button.disabled = !is_enabled

func _set_deck_pick_enabled(is_enabled: bool) -> void:
	awaiting_deck_pick = is_enabled
	back_button.visible = is_enabled and round_active and !input_locked
	for child: Node in deck_grid.get_children():
		var deck_button: Button = child as Button
		if deck_button != null:
			deck_button.disabled = !is_enabled or !round_active

func _reset_choice_slots() -> void:
	_apply_preview_placeholder(
		lower_preview_panel,
		lower_preview_rank_top,
		lower_preview_suit_top,
		lower_preview_suit_center,
		lower_preview_rank_center,
		lower_preview_rank_bottom,
		lower_preview_suit_bottom
	)
	_apply_preview_placeholder(
		higher_preview_panel,
		higher_preview_rank_top,
		higher_preview_suit_top,
		higher_preview_suit_center,
		higher_preview_rank_center,
		higher_preview_rank_bottom,
		higher_preview_suit_bottom
	)

func _show_choice_preview(show_higher_side: bool, card: Dictionary) -> void:
	_reset_choice_slots()

	if show_higher_side:
		_apply_preview_card(
			higher_preview_panel,
			card,
			higher_preview_rank_top,
			higher_preview_suit_top,
			higher_preview_suit_center,
			higher_preview_rank_center,
			higher_preview_rank_bottom,
			higher_preview_suit_bottom
		)
	else:
		_apply_preview_card(
			lower_preview_panel,
			card,
			lower_preview_rank_top,
			lower_preview_suit_top,
			lower_preview_suit_center,
			lower_preview_rank_center,
			lower_preview_rank_bottom,
			lower_preview_suit_bottom
		)

func _apply_preview_card(
	panel: PanelContainer,
	card: Dictionary,
	rank_top: Label,
	suit_top: Label,
	suit_center: Label,
	rank_center: Label,
	rank_bottom: Label,
	suit_bottom: Label
) -> void:
	var rank_text: String = Deck.rank_text(card)
	var suit_symbol: String = Deck.suit_symbol(card)
	var suit_color: Color = Deck.suit_color(card)
	panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	rank_top.text = rank_text
	suit_top.text = suit_symbol
	suit_center.text = suit_symbol
	rank_center.text = rank_text
	rank_bottom.text = rank_text
	suit_bottom.text = suit_symbol
	rank_top.add_theme_color_override("font_color", suit_color)
	suit_top.add_theme_color_override("font_color", suit_color)
	suit_center.add_theme_color_override("font_color", suit_color)
	rank_center.add_theme_color_override("font_color", suit_color)
	rank_bottom.add_theme_color_override("font_color", suit_color)
	suit_bottom.add_theme_color_override("font_color", suit_color)

func _apply_preview_placeholder(
	panel: PanelContainer,
	rank_top: Label,
	suit_top: Label,
	suit_center: Label,
	rank_center: Label,
	rank_bottom: Label,
	suit_bottom: Label
) -> void:
	var placeholder_color: Color = Color(0.086275, 0.12549, 0.164706, 0.4)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.42)
	rank_top.text = ""
	suit_top.text = ""
	suit_center.text = ""
	rank_center.text = ""
	rank_bottom.text = ""
	suit_bottom.text = ""
	rank_top.add_theme_color_override("font_color", placeholder_color)
	suit_top.add_theme_color_override("font_color", placeholder_color)
	suit_center.add_theme_color_override("font_color", placeholder_color)
	rank_center.add_theme_color_override("font_color", placeholder_color)
	rank_bottom.add_theme_color_override("font_color", placeholder_color)
	suit_bottom.add_theme_color_override("font_color", placeholder_color)

func _apply_empty_center_slot() -> void:
	var placeholder_color: Color = Color(0.086275, 0.12549, 0.164706, 0.38)
	card_panel.visible = true
	card_panel.modulate = Color(1.0, 1.0, 1.0, 0.45)
	card_label.text = ""
	card_suit_center.text = ""
	corner_rank_top.text = ""
	corner_suit_top.text = ""
	corner_rank_bottom.text = ""
	corner_suit_bottom.text = ""
	card_label.add_theme_color_override("font_color", placeholder_color)
	card_suit_center.add_theme_color_override("font_color", placeholder_color)
	corner_rank_top.add_theme_color_override("font_color", placeholder_color)
	corner_suit_top.add_theme_color_override("font_color", placeholder_color)
	corner_rank_bottom.add_theme_color_override("font_color", placeholder_color)
	corner_suit_bottom.add_theme_color_override("font_color", placeholder_color)

func _refresh_pivots() -> void:
	card_panel.pivot_offset = card_panel.size / 2.0
	streak_label.pivot_offset = streak_label.size / 2.0

func _on_higher() -> void:
	guess(true)

func _on_lower() -> void:
	guess(false)

func _on_mute_pressed() -> void:
	_set_muted(!is_muted)

func guess(player_said_higher: bool) -> void:
	if not round_active or input_locked or awaiting_deck_pick:
		return
	if awaiting_tie_bet:
		awaiting_tie_bet = false
		pending_tie_bet = true
		pending_guess_higher = player_said_higher
		_set_guess_buttons_enabled(false)
		_show_choice_preview(player_said_higher, current_card)
		_apply_empty_center_slot()
		_set_result_text("Pick a card from the deck.", RESULT_NEUTRAL)
		_set_deck_pick_enabled(true)
		return
	if deck.is_empty():
		_finish_run("The deck ran out unexpectedly. Final run: %d" % _get_run_score(), false)
		return

	pending_guess_higher = player_said_higher
	_set_guess_buttons_enabled(false)
	_show_choice_preview(player_said_higher, current_card)
	_apply_empty_center_slot()
	_set_result_text("Pick any facedown card from the deck.", RESULT_NEUTRAL)
	_set_deck_pick_enabled(true)

func _on_back_pressed() -> void:
	if not round_active or input_locked or !awaiting_deck_pick or current_card.is_empty():
		return
	_set_deck_pick_enabled(false)
	_reset_choice_slots()
	card_panel.visible = true
	_apply_card_visual(current_card)
	_set_result_text("Choice canceled. Pick Higher or Lower.", RESULT_NEUTRAL)
	_set_guess_buttons_enabled(true)

func _on_deck_card_pressed() -> void:
	if not round_active or input_locked or !awaiting_deck_pick:
		return
	if deck.is_empty():
		_finish_run("The deck ran out unexpectedly. Final run: %d" % _get_run_score(), false)
		return

	input_locked = true
	_set_deck_pick_enabled(false)
	var previous_card: Dictionary = current_card
	var previous_value: int = Deck.card_value(previous_card)
	var next_card: Dictionary = deck.draw()
	var next_value: int = Deck.card_value(next_card)
	card_panel.visible = true
	await _animate_card_reveal(next_card)
	current_card = next_card
	_update_status_labels()
	var comparison_text: String = "%s after %s." % [Deck.card_text(next_card), Deck.card_text(previous_card)]

	if pending_tie_bet:
		pending_tie_bet = false
		await _resolve_tie_bet(pending_guess_higher, previous_value, next_card, next_value)
		return

	if next_value == previous_value:
		await _handle_tie(next_card)
		return

	var guessed_right: bool = pending_guess_higher == (next_value > previous_value)
	if guessed_right:
		var correct_outcome: Dictionary = game_state.resolve_correct_guess(next_card)
		_update_high_score()
		_update_status_labels()
		_play_success_sound()
		var awarded_points: int = int(correct_outcome.get("awarded_points", 1))
		var multiplier: int = int(correct_outcome.get("multiplier", 1))
		var modifier_bonus: int = int(correct_outcome.get("modifier_bonus", 0))
		var modifier_name: String = String(correct_outcome.get("modifier_name", ""))
		var modifier_effect_text: String = String(correct_outcome.get("modifier_effect_text", ""))
		var modifier_blocked: bool = bool(correct_outcome.get("modifier_blocked", false))
		var reward_text: String
		if modifier_name == "Precision":
			if awarded_points > 0:
				reward_text = "+%d points (%s)" % [awarded_points, modifier_effect_text]
			else:
				reward_text = "No points (%s)" % modifier_effect_text
		elif modifier_blocked:
			reward_text = "No points"
		else:
			reward_text = "+%d points" % awarded_points
			if awarded_points == 1:
				reward_text = "+1 point"
			if multiplier > 1:
				reward_text += " (x%d streak)" % multiplier
			if modifier_bonus > 0 and not modifier_name.is_empty():
				reward_text += " +1 %s" % modifier_name
		if not modifier_effect_text.is_empty() and modifier_blocked:
			reward_text += " (%s)" % modifier_effect_text
		_set_result_text("Correct! %s %s." % [comparison_text, reward_text], RESULT_SUCCESS)
		_animate_streak()
		_emit_streak_particles()
		if await _handle_level_outcome(correct_outcome):
			return
		await get_tree().create_timer(0.55).timeout
		_reset_choice_slots()
		input_locked = false
		_set_guess_buttons_enabled(true)
	else:
		var wrong_outcome: Dictionary = game_state.resolve_wrong_guess()
		_update_status_labels()
		_set_result_text("Wrong! %s" % comparison_text, RESULT_FAIL)
		if await _handle_level_outcome(wrong_outcome):
			return
		await get_tree().create_timer(0.55).timeout
		_reset_choice_slots()
		input_locked = false
		_set_guess_buttons_enabled(true)

func _handle_tie(tie_card: Dictionary) -> void:
	var consecutive: int = game_state.consecutive_ties
	var tie_outcome: Dictionary = game_state.resolve_tie()
	_update_status_labels()

	# Triple tie - jackpot instant
	if consecutive >= 2:
		var jackpot_outcome: Dictionary = game_state.resolve_triple_tie()
		_update_high_score()
		_update_status_labels()
		_play_success_sound()
		_set_result_text("TRIPLE TIE! JACKPOT! +15 points!", RESULT_WIN)
		_emit_streak_particles()
		await get_tree().create_timer(1.5).timeout
		if await _handle_level_outcome(jackpot_outcome):
			return
		_deal_new_card_after_tie()
		return

	if await _handle_level_outcome(tie_outcome):
		return

	if deck.is_empty():
		_finish_run("The deck ran out. Final run: %d" % _get_run_score(), false)
		return

	# Dramatic equal bet
	_play_fail_sound()
	_set_result_text("TIE! Both cards are %s. Bet: will the next card be Higher or Lower?" % Deck.card_text(tie_card), RESULT_WIN)
	await get_tree().create_timer(0.4).timeout
	input_locked = false
	_set_guess_buttons_enabled(true)
	awaiting_tie_bet = true

func _resolve_tie_bet(player_said_higher: bool, bet_card_value: int, _next_card: Dictionary, next_value: int) -> void:
	if next_value == bet_card_value:
		_update_status_labels()
		_set_result_text("Another tie! Bet again.", RESULT_NEUTRAL)
		_reset_choice_slots()
		input_locked = false
		_set_guess_buttons_enabled(true)
		awaiting_tie_bet = true
		return

	var guessed_right: bool = player_said_higher == (next_value > bet_card_value)
	if guessed_right:
		var outcome: Dictionary = game_state.resolve_tie_bet_correct()
		_update_high_score()
		_update_status_labels()
		_play_success_sound()
		var bonus: int = int(outcome.get("awarded_points", 2))
		_set_result_text("Correct bet! +%d bonus points. Streak reset." % bonus, RESULT_SUCCESS)
		_emit_streak_particles()
		if await _handle_level_outcome(outcome):
			return
	else:
		var outcome: Dictionary = game_state.resolve_tie_bet_wrong()
		_update_status_labels()
		_play_fail_sound()
		_set_result_text("Wrong bet! Streak reset and -1 draw.", RESULT_FAIL)
		if await _handle_level_outcome(outcome):
			return

	await get_tree().create_timer(0.55).timeout
	_reset_choice_slots()
	input_locked = false
	_set_guess_buttons_enabled(true)

func _deal_new_card_after_tie() -> void:
	if deck.is_empty():
		_finish_run("The deck ran out. Final run: %d" % _get_run_score(), false)
		return
	var new_card: Dictionary = deck.draw()
	card_panel.visible = true
	await _animate_card_reveal(new_card)
	current_card = new_card
	_update_status_labels()
	_set_result_text("New card dealt. Pick Higher or Lower.", RESULT_NEUTRAL)
	if deck.is_empty():
		_finish_run("The deck ran out. Final run: %d" % _get_run_score(), false)
		return
	_reset_choice_slots()
	input_locked = false
	_set_guess_buttons_enabled(true)

func _handle_level_outcome(outcome: Dictionary) -> bool:
	if not bool(outcome.get("level_completed", false)) and not bool(outcome.get("level_failed", false)):
		return false

	round_active = false
	input_locked = true
	awaiting_deck_pick = false
	_set_guess_buttons_enabled(false)
	_set_deck_pick_enabled(false)
	_reset_choice_slots()

	if bool(outcome.get("level_completed", false)):
		_show_level_clear_overlay(outcome)
		return true

	if bool(outcome.get("run_over", false)):
		_finish_run(
			"Level %d failed. No lives left. Final run: %d" % [int(outcome.get("level_number", game_state.get_level_number())), _get_run_score()],
			false
		)
		return true

	_play_fail_sound()
	_shake_screen()
	subtitle_label.text = "You missed the level target, but the run is still alive."
	_set_result_text(
		"Level %d failed. Lives left: %d. Retry the same level." % [
			int(outcome.get("level_number", game_state.get_level_number())),
			int(outcome.get("lives_left", game_state.lives)),
		],
		RESULT_FAIL
	)
	await get_tree().create_timer(1.1).timeout
	if start_overlay.visible or game_state == null:
		return true
	subtitle_label.text = "Build enough correct guesses before the level runs out of draws."
	_start_level("Retry Level %d. %s" % [game_state.get_level_number(), _current_level_brief()])
	return true

func _get_run_score() -> int:
	return 0 if game_state == null else game_state.run_score

func _animate_card_reveal(card: Dictionary) -> void:
	_refresh_pivots()
	card_panel.scale = Vector2.ONE
	card_panel.rotation = 0.0
	card_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_play_card_sound()

	var close_front: Tween = create_tween()
	close_front.set_trans(Tween.TRANS_CUBIC)
	close_front.set_ease(Tween.EASE_IN)
	close_front.set_parallel(true)
	close_front.tween_property(card_panel, "scale", Vector2(0.02, 1.08), 0.08)
	close_front.tween_property(card_panel, "rotation", -0.09, 0.08)
	close_front.tween_property(card_panel, "modulate", Color(0.82, 0.82, 0.82, 1.0), 0.08)
	await close_front.finished

	_apply_card_back()
	var show_back: Tween = create_tween()
	show_back.set_trans(Tween.TRANS_CUBIC)
	show_back.set_ease(Tween.EASE_OUT)
	show_back.set_parallel(true)
	show_back.tween_property(card_panel, "scale", Vector2(0.78, 1.02), 0.06)
	show_back.tween_property(card_panel, "rotation", 0.07, 0.06)
	show_back.tween_property(card_panel, "modulate", Color(0.9, 0.9, 0.9, 1.0), 0.06)
	await show_back.finished

	var hide_back: Tween = create_tween()
	hide_back.set_trans(Tween.TRANS_CUBIC)
	hide_back.set_ease(Tween.EASE_IN)
	hide_back.set_parallel(true)
	hide_back.tween_property(card_panel, "scale", Vector2(0.02, 1.08), 0.06)
	hide_back.tween_property(card_panel, "rotation", -0.08, 0.06)
	hide_back.tween_property(card_panel, "modulate", Color(0.82, 0.82, 0.82, 1.0), 0.06)
	await hide_back.finished

	_apply_card_visual(card)
	var open_front: Tween = create_tween()
	open_front.set_trans(Tween.TRANS_BACK)
	open_front.set_ease(Tween.EASE_OUT)
	open_front.set_parallel(true)
	open_front.tween_property(card_panel, "scale", Vector2(1.08, 0.97), 0.12)
	open_front.tween_property(card_panel, "rotation", 0.08, 0.12)
	open_front.tween_property(card_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	await open_front.finished

	var settle_front: Tween = create_tween()
	settle_front.set_trans(Tween.TRANS_SINE)
	settle_front.set_ease(Tween.EASE_OUT)
	settle_front.set_parallel(true)
	settle_front.tween_property(card_panel, "scale", Vector2.ONE, 0.06)
	settle_front.tween_property(card_panel, "rotation", 0.0, 0.06)
	await settle_front.finished

func _animate_streak() -> void:
	_refresh_pivots()
	streak_label.scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(streak_label, "scale", Vector2(1.12, 1.12), 0.08)
	tween.tween_property(streak_label, "scale", Vector2.ONE, 0.1)

func _finish_run(message: String, won: bool) -> void:
	round_active = false
	input_locked = false
	awaiting_deck_pick = false
	pending_guess_higher = false
	level_overlay.visible = false
	pending_level_intro_message = ""
	_reset_level_overlay_state()
	_set_guess_buttons_enabled(false)
	_set_deck_pick_enabled(false)
	back_button.visible = false
	play_again_button.visible = true
	if won:
		subtitle_label.text = "The run is complete. You can start another one right away."
		_set_result_text(message, RESULT_WIN)
	else:
		_play_fail_sound()
		_shake_screen()
		subtitle_label.text = "The run is over. Try again."
		_set_result_text(message, RESULT_FAIL)
	_update_status_labels()
	call_deferred("_start_remaining_deck_reveal")

func _show_level_clear_overlay(outcome: Dictionary) -> void:
	if game_state == null:
		return
	pending_level_outcome = outcome.duplicate(true)
	pending_reward_message = ""
	var next_level_number: int = int(outcome.get("next_level_number", game_state.get_level_number()))
	level_continue_button.text = "Start Level %d" % next_level_number
	pending_level_intro_message = "Level %d begins. %s" % [next_level_number, _current_level_brief()]
	subtitle_label.text = "Take a breath, then continue when you're ready."
	if bool(outcome.get("reward_choice_available", false)):
		_set_result_text("Checkpoint reached. Choose a reward for the next level.", RESULT_WIN)
	else:
		_set_result_text("Strong round. You're moving up.", RESULT_WIN)
	_refresh_level_overlay_content()
	level_overlay.visible = true

func _on_reward_life_pressed() -> void:
	_apply_reward_choice(GameState.REWARD_LIFE)

func _on_reward_draws_pressed() -> void:
	_apply_reward_choice(GameState.REWARD_DRAWS)

func _apply_reward_choice(reward_id: String) -> void:
	if game_state == null or pending_level_outcome.is_empty():
		return
	var reward_result: Dictionary = game_state.apply_reward_choice(reward_id)
	if not bool(reward_result.get("applied", false)):
		pending_reward_message = String(reward_result.get("label", "Choose a reward."))
		_refresh_level_overlay_content()
		return
	pending_reward_message = "Reward selected: %s." % String(reward_result.get("label", ""))
	level_continue_button.text = "Start Level %d" % game_state.get_level_number()
	pending_level_intro_message = "Level %d begins. %s" % [game_state.get_level_number(), _current_level_brief()]
	_update_status_labels()
	_refresh_level_overlay_content()

func _on_level_continue_pressed() -> void:
	if game_state == null or pending_level_intro_message.is_empty() or game_state.has_pending_reward_choice():
		return
	subtitle_label.text = "Build enough correct guesses before the level runs out of draws."
	_start_level(pending_level_intro_message)

func _shake_screen() -> void:
	if shake_tween != null:
		shake_tween.kill()

	position = Vector2.ZERO
	shake_tween = create_tween()
	var shake_offsets: Array[Vector2] = [
		Vector2(-1.0, 0.0),
		Vector2(1.0, -0.35),
		Vector2(-0.85, 0.45),
		Vector2(0.85, -0.2),
		Vector2(-0.45, 0.3),
		Vector2(0.45, 0.0),
	]

	for offset in shake_offsets:
		shake_tween.tween_property(self, "position", offset * SCREEN_SHAKE_STRENGTH, SCREEN_SHAKE_STEP)

	shake_tween.tween_property(self, "position", Vector2.ZERO, 0.04)

func _setup_audio() -> void:
	card_sfx_player = _create_sfx_player("CardSfxPlayer")
	success_sfx_player = _create_sfx_player("SuccessSfxPlayer")
	fail_sfx_player = _create_sfx_player("FailSfxPlayer")

func _setup_effects_layer() -> void:
	effects_layer = Control.new()
	effects_layer.name = "EffectsLayer"
	effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effects_layer)

func _create_sfx_player(node_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = node_name
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.mix_rate = SFX_SAMPLE_RATE
	stream.buffer_length = SFX_BUFFER_LENGTH
	player.stream = stream
	add_child(player)
	return player

func _play_card_sound() -> void:
	_play_tone_sequence(card_sfx_player, [
		{"from": 820.0, "to": 540.0, "duration": 0.04, "volume": 0.10},
		{"from": 400.0, "to": 240.0, "duration": 0.05, "volume": 0.07},
	])

func _play_success_sound() -> void:
	_play_tone_sequence(success_sfx_player, [
		{"from": 620.0, "to": 760.0, "duration": 0.07, "volume": 0.14},
		{"from": 820.0, "to": 980.0, "duration": 0.10, "volume": 0.12},
	])

func _play_fail_sound() -> void:
	_play_tone_sequence(fail_sfx_player, [
		{"from": 420.0, "to": 280.0, "duration": 0.10, "volume": 0.15},
		{"from": 250.0, "to": 130.0, "duration": 0.16, "volume": 0.13},
	])

func _play_tone_sequence(player: AudioStreamPlayer, segments: Array) -> void:
	if player == null or is_muted:
		return
	player.stop()
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	for segment in segments:
		_push_tone_segment(
			playback,
			float(segment.get("from", 440.0)),
			float(segment.get("to", 440.0)),
			float(segment.get("duration", 0.08)),
			float(segment.get("volume", 0.1))
		)

func _push_tone_segment(
	playback: AudioStreamGeneratorPlayback,
	start_frequency: float,
	end_frequency: float,
	duration: float,
	volume: float
) -> void:
	var frame_count: int = maxi(int(SFX_SAMPLE_RATE * duration), 1)
	var phase: float = 0.0

	for i in range(frame_count):
		var progress: float = float(i) / float(maxi(frame_count - 1, 1))
		var frequency: float = lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / SFX_SAMPLE_RATE
		var envelope: float = sin(progress * PI)
		var sample: float = sin(phase) * envelope * volume
		playback.push_frame(Vector2(sample, sample))

func _emit_streak_particles() -> void:
	var streak_value: int = 0 if game_state == null else game_state.current_streak
	if streak_value < MEDIUM_STREAK_THRESHOLD or effects_layer == null:
		return

	var is_big_streak: bool = streak_value >= HIGH_STREAK_THRESHOLD
	var particle_count: int = 26 if is_big_streak else 14
	var origin: Vector2 = streak_label.get_global_rect().get_center() - get_global_rect().position
	var palette: Array[Color] = [
		Color("ffe08a"),
		Color("ffd166"),
		Color("f94144"),
		Color("f8f9fa"),
	]

	if is_big_streak:
		palette.append(Color("90e0ef"))
		palette.append(Color("c77dff"))

	for i in range(particle_count):
		var particle: ColorRect = ColorRect.new()
		var size_value: float = rng.randf_range(5.0, 9.0) if is_big_streak else rng.randf_range(4.0, 7.0)
		particle.color = palette[rng.randi_range(0, palette.size() - 1)]
		particle.custom_minimum_size = Vector2(size_value, size_value)
		particle.size = Vector2(size_value, size_value)
		particle.position = origin - particle.size / 2.0
		particle.pivot_offset = particle.size / 2.0
		particle.rotation = rng.randf_range(0.0, TAU)
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effects_layer.add_child(particle)

		var horizontal_offset: float = rng.randf_range(-120.0, 120.0) if is_big_streak else rng.randf_range(-80.0, 80.0)
		var vertical_lift: float = rng.randf_range(-110.0, -45.0) if is_big_streak else rng.randf_range(-80.0, -35.0)
		var fall_offset: float = rng.randf_range(25.0, 55.0)
		var target_position: Vector2 = particle.position + Vector2(horizontal_offset, vertical_lift + fall_offset)
		var duration: float = rng.randf_range(0.45, 0.8) if is_big_streak else rng.randf_range(0.35, 0.65)
		var target_rotation: float = particle.rotation + rng.randf_range(-4.0, 4.0)
		var target_scale: Vector2 = Vector2.ONE * rng.randf_range(0.2, 0.55)
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_position, duration)
		tween.tween_property(particle, "rotation", target_rotation, duration)
		tween.tween_property(particle, "scale", target_scale, duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration)
		tween.chain().tween_callback(particle.queue_free)

func _update_high_score() -> void:
	var run_score: int = _get_run_score()
	if run_score <= high_score:
		return
	high_score = run_score
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"high_score": high_score}))

func _load_high_score() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return 0
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	return int(parsed.get("high_score", 0))

func _on_start_pressed() -> void:
	start_game()

func _on_play_again() -> void:
	start_game()

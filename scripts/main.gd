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
const DRAMATIC_FAIL_THRESHOLD := 5
const NEAR_MISS_DISTANCE := 1
const CardViewScript := preload("res://scripts/card_view.gd")
const DeckViewScript := preload("res://scripts/deck_view.gd")
const RunHudScript := preload("res://scripts/run_hud.gd")

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
var streak_bar: ProgressBar
var card_sfx_player: AudioStreamPlayer
var success_sfx_player: AudioStreamPlayer
var fail_sfx_player: AudioStreamPlayer
var effects_layer: Control
var incoming_overlay: Control = null
var feedback_panel_node: PanelContainer
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var card_view
var deck_view
var run_hud

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
	_setup_views()
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
	_restructure_layout()
	_create_streak_bar()
	_show_start_state()

func _setup_views() -> void:
	card_view = CardViewScript.new()
	card_view.setup(
		card_panel,
		card_label,
		card_suit_center,
		corner_rank_top,
		corner_suit_top,
		corner_rank_bottom,
		corner_suit_bottom
	)
	deck_view = DeckViewScript.new()
	deck_view.setup(deck_grid, deck_label)
	run_hud = RunHudScript.new()
	run_hud.setup(
		background,
		score_label,
		high_score_label,
		remaining_label,
		streak_label,
		bonus_banner,
		bonus_banner_label,
		modifier_banner,
		modifier_banner_label,
		deck_label
	)

func start_game() -> void:
	deck_reveal_generation += 1
	game_state = GameState.new()
	deck = null
	current_card = {}
	awaiting_tie_bet = false
	pending_tie_bet = false
	start_overlay.visible = false
	level_overlay.visible = false
	play_again_button.visible = false
	back_button.visible = false
	_reset_level_overlay_state()
	pending_level_intro_message = ""
	subtitle_label.text = "Build enough correct guesses before the level runs out of draws."
	_start_level("Run started. %s" % _current_level_brief())

func _start_level(message: String) -> void:
	_dismiss_incoming_overlay()
	round_active = true
	input_locked = false
	awaiting_deck_pick = false
	awaiting_tie_bet = false
	pending_tie_bet = false
	pending_guess_higher = false
	remaining_deck_revealed = false
	remaining_deck_reveal_in_progress = false
	level_overlay.visible = false
	pending_level_intro_message = ""
	_reset_level_overlay_state()
	var level_message: String = message
	if _prepare_level_deck_state():
		level_message += " Fresh deck shuffled."
	play_again_button.visible = false
	back_button.visible = false
	card_panel.visible = true
	_apply_card_visual(current_card)
	_play_card_sound()
	_update_status_labels()
	_set_result_text(level_message, RESULT_NEUTRAL)
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
	deck_view.clear_slots()
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
	run_hud.update(game_state, high_score, self)
	card_view.apply_streak_momentum(0 if game_state == null else game_state.current_streak)
	_update_deck_label()
	_rebuild_deck_view()

func _restructure_layout() -> void:
	var game_margin: MarginContainer = $GameMargin
	var old_vbox: VBoxContainer = $GameMargin/GameVBox

	var page_vbox := VBoxContainer.new()
	page_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_vbox.add_theme_constant_override("separation", 14)
	page_vbox.alignment = BoxContainer.ALIGNMENT_END
	game_margin.add_child(page_vbox)

	var main_hbox := HBoxContainer.new()
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 24)
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	page_vbox.add_child(main_hbox)

	# LEFT: played card, streak bar, and local feedback.
	var card_stack := VBoxContainer.new()
	card_stack.custom_minimum_size = Vector2(246, 0)
	card_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_stack.add_theme_constant_override("separation", 10)
	card_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(card_stack)

	var left_col := HBoxContainer.new()
	left_col.custom_minimum_size = Vector2(246, 0)
	left_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left_col.add_theme_constant_override("separation", 12)
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	var card_stack_top_spacer := Control.new()
	card_stack_top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_stack.add_child(card_stack_top_spacer)

	card_stack.add_child(left_col)

	var card_stack_spacer := Control.new()
	card_stack_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_stack.add_child(card_stack_spacer)

	# DECK: imediat lângă carte (VBox)
	var deck_section := VBoxContainer.new()
	deck_section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	deck_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_section.add_theme_constant_override("separation", 8)
	main_hbox.add_child(deck_section)

	# CENTRU: statistici + info (VBox, expandat)
	var center_col := VBoxContainer.new()
	center_col.custom_minimum_size = Vector2(318, 0)
	center_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_col.add_theme_constant_override("separation", 12)
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(center_col)

	# Mutăm carta în stânga, mărită dar fără să se extindă vertical
	card_panel.reparent(left_col)
	card_panel.custom_minimum_size = Vector2(200, 280)
	card_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Butoanele verticale, text pe litere
	lower_button.text = "L\nO\nW\nE\nR"
	higher_button.text = "H\nI\nG\nH\nE\nR"
	back_button.text = "Back  [Esc]"
	lower_button.custom_minimum_size = Vector2(44, 0)
	higher_button.custom_minimum_size = Vector2(44, 0)
	back_button.custom_minimum_size = Vector2(120, 40)
	lower_button.add_theme_font_size_override("font_size", 13)
	higher_button.add_theme_font_size_override("font_size", 13)

	# Nod title direct din scenă
	var title_node: Label = $GameMargin/GameVBox/Title

	var feedback_panel := PanelContainer.new()
	feedback_panel.custom_minimum_size = Vector2(246, 88)
	feedback_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var feedback_style := StyleBoxFlat.new()
	feedback_style.bg_color = Color(0.035, 0.045, 0.055, 0.76)
	feedback_style.border_color = Color(1.0, 0.878431, 0.537255, 0.2)
	feedback_style.border_width_top = 1
	feedback_style.border_width_right = 1
	feedback_style.border_width_bottom = 1
	feedback_style.border_width_left = 1
	feedback_style.corner_radius_top_left = 8
	feedback_style.corner_radius_top_right = 8
	feedback_style.corner_radius_bottom_right = 8
	feedback_style.corner_radius_bottom_left = 8
	feedback_panel.add_theme_stylebox_override("panel", feedback_style)
	feedback_panel_node = feedback_panel
	card_stack.add_child(feedback_panel)

	var feedback_margin := MarginContainer.new()
	feedback_margin.add_theme_constant_override("margin_left", 12)
	feedback_margin.add_theme_constant_override("margin_top", 10)
	feedback_margin.add_theme_constant_override("margin_right", 12)
	feedback_margin.add_theme_constant_override("margin_bottom", 10)
	feedback_panel.add_child(feedback_margin)

	var feedback_col := VBoxContainer.new()
	feedback_col.add_theme_constant_override("separation", 4)
	feedback_col.alignment = BoxContainer.ALIGNMENT_CENTER
	feedback_margin.add_child(feedback_col)

	# Reparentăm nodurile în ordinea dorită în centru
	title_node.reparent(center_col)
	title_node.size_flags_horizontal = Control.SIZE_FILL
	result_label.reparent(feedback_col)
	result_label.size_flags_horizontal = Control.SIZE_FILL
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.reparent(feedback_col)
	subtitle_label.size_flags_horizontal = Control.SIZE_FILL
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 13)
	play_again_button.reparent(center_col)
	$GameMargin/GameVBox/TopBar.reparent(center_col)
	bonus_banner.reparent(center_col)
	modifier_banner.reparent(center_col)
	mute_button.reparent(center_col)

	# Deck label deasupra, apoi [butoane | grid] pe același rând
	deck_label.reparent(deck_section)
	var deck_row := HBoxContainer.new()
	deck_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_row.add_theme_constant_override("separation", 6)
	deck_section.add_child(deck_row)

	var buttons_col := VBoxContainer.new()
	buttons_col.custom_minimum_size = Vector2(104, 0)
	buttons_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buttons_col.add_theme_constant_override("separation", 8)
	buttons_col.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_row.add_child(buttons_col)

	higher_button.reparent(buttons_col)
	higher_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	higher_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	back_button.reparent(buttons_col)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lower_button.reparent(buttons_col)
	lower_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lower_button.size_flags_vertical = Control.SIZE_EXPAND_FILL

	deck_grid.reparent(deck_row)
	deck_grid.columns = 6

	# Eliminăm vechiul VBox (include ComparisonRow cu preview slots)
	old_vbox.queue_free()

func _create_streak_bar() -> void:
	# Bara e verticală, lângă card în left_col
	var left_col: HBoxContainer = card_panel.get_parent() as HBoxContainer
	if left_col == null:
		return

	streak_bar = ProgressBar.new()
	streak_bar.min_value = 0
	streak_bar.max_value = HIGH_STREAK_THRESHOLD
	streak_bar.value = 0
	streak_bar.show_percentage = false
	streak_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	streak_bar.custom_minimum_size = Vector2(14, 0)
	streak_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.08, 0.6)
	bg_style.corner_radius_top_left = 5
	bg_style.corner_radius_top_right = 5
	bg_style.corner_radius_bottom_right = 5
	bg_style.corner_radius_bottom_left = 5
	streak_bar.add_theme_stylebox_override("background", bg_style)

	left_col.add_child(streak_bar)
	_apply_streak_bar_fill_style(0)
	run_hud.streak_bar = streak_bar

func _streak_bar_color(streak: int) -> Color:
	if streak >= HIGH_STREAK_THRESHOLD:
		return Color("ff4444")
	if streak >= MEDIUM_STREAK_THRESHOLD:
		return Color("ff9944")
	if streak >= 3:
		return Color("ffd166")
	return Color("8fe388")

func _apply_streak_bar_fill_style(streak: int) -> void:
	if streak_bar == null:
		return
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = _streak_bar_color(streak)
	fill_style.corner_radius_top_left = 5
	fill_style.corner_radius_top_right = 5
	fill_style.corner_radius_bottom_right = 5
	fill_style.corner_radius_bottom_left = 5
	streak_bar.add_theme_stylebox_override("fill", fill_style)

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

func _prepare_level_deck_state() -> bool:
	if current_card.is_empty():
		_start_new_deck_cycle()
		return true
	if deck == null or deck.is_empty():
		_reshuffle_deck_around_current_card()
		return true
	return false

func _ensure_deck_for_pick() -> bool:
	if current_card.is_empty():
		_start_new_deck_cycle()
		return true
	if deck == null or deck.is_empty():
		_reshuffle_deck_around_current_card()
		return true
	return false

func _start_new_deck_cycle() -> void:
	deck = Deck.new()
	current_card = deck.draw()
	_reset_deck_visual_slots()

func _reshuffle_deck_around_current_card() -> void:
	deck = Deck.new()
	_remove_card_from_deck(current_card)
	_reset_deck_visual_slots()

func _remove_card_from_deck(card: Dictionary) -> void:
	if deck == null or card.is_empty():
		return
	var target_rank: int = int(card.get("rank", 0))
	var target_suit: String = String(card.get("suit", ""))
	for index in range(deck.cards.size()):
		var candidate: Dictionary = deck.cards[index]
		if int(candidate.get("rank", 0)) == target_rank and String(candidate.get("suit", "")) == target_suit:
			deck.cards.remove_at(index)
			return

func _reset_deck_visual_slots() -> void:
	if deck == null:
		deck_view.clear_slots()
		return
	deck_view.reset_slots(deck.cards_left())

func _consume_deck_visual_slot(slot_index: int) -> void:
	deck_view.consume_slot(slot_index)

func _consume_next_visual_slot() -> void:
	deck_view.consume_next_slot()

func _draw_new_current_card() -> bool:
	if deck == null or deck.is_empty():
		_start_new_deck_cycle()
		return true
	current_card = deck.draw()
	_consume_next_visual_slot()
	return false

func _reshuffle_after_reveal_if_needed() -> bool:
	if current_card.is_empty() or deck == null or !deck.is_empty():
		return false
	_reshuffle_deck_around_current_card()
	return true

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
	deck_view.update_label(start_overlay.visible, remaining_deck_reveal_in_progress, remaining_deck_revealed, round_active, awaiting_deck_pick)

func _get_cards_left_for_display() -> int:
	if deck == null or current_card.is_empty():
		return Deck.TOTAL_CARDS
	return deck.cards_left()

func _rebuild_deck_view() -> void:
	deck_view.rebuild(deck, current_card, round_active, awaiting_deck_pick, _should_show_remaining_deck_fronts(), Callable(self, "_on_deck_card_pressed"))

func _should_show_remaining_deck_fronts() -> bool:
	return !round_active and !start_overlay.visible and deck != null and !current_card.is_empty() and remaining_deck_revealed

func _apply_deck_card_back(deck_button: Button) -> void:
	deck_view.apply_card_back(deck_button, awaiting_deck_pick, round_active)

func _apply_deck_card_front(deck_button: Button, card: Dictionary) -> void:
	deck_view.apply_card_front(deck_button, card)

func _start_remaining_deck_reveal() -> void:
	if remaining_deck_revealed or remaining_deck_reveal_in_progress:
		return
	if _is_deck_reveal_cancelled(deck_reveal_generation):
		return
	remaining_deck_reveal_in_progress = true
	_update_deck_label()
	var generation: int = deck_reveal_generation
	var cards_snapshot: Array[Dictionary] = deck.cards.duplicate(true)
	var deck_buttons: Array[Button] = deck_view.get_deck_buttons()

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
	return await deck_view.animate_card_flip(self, deck_button, card, Callable(self, "_is_deck_reveal_cancelled").bind(generation))

func _is_deck_reveal_cancelled(generation: int) -> bool:
	return generation != deck_reveal_generation or round_active or start_overlay.visible or deck == null

func _stop_remaining_deck_reveal() -> void:
	remaining_deck_reveal_in_progress = false
	_update_deck_label()

func _apply_card_visual(card: Dictionary) -> void:
	card_view.apply_card(card)

func _apply_card_back() -> void:
	card_view.apply_back()

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
	deck_view.set_pick_enabled(is_enabled, round_active)

func _reset_choice_slots() -> void:
	pass

func _apply_empty_center_slot() -> void:
	card_view.apply_empty()

func _refresh_pivots() -> void:
	card_view.refresh_pivot()
	run_hud.refresh_pivot()

func _on_higher() -> void:
	guess(true)

func _on_lower() -> void:
	guess(false)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_D, KEY_RIGHT:
			if higher_button.visible and not higher_button.disabled:
				_on_higher()
		KEY_A, KEY_LEFT:
			if lower_button.visible and not lower_button.disabled:
				_on_lower()
		KEY_ESCAPE:
			if back_button.visible and not back_button.disabled:
				_on_back_pressed()

func _on_mute_pressed() -> void:
	_set_muted(!is_muted)

func guess(player_said_higher: bool) -> void:
	if not round_active or input_locked or awaiting_deck_pick:
		return
	var reshuffled: bool = _ensure_deck_for_pick()
	if reshuffled:
		_update_status_labels()
	if awaiting_tie_bet:
		awaiting_tie_bet = false
		pending_tie_bet = true
		pending_guess_higher = player_said_higher
		_set_guess_buttons_enabled(false)
		_set_result_text("Fresh deck shuffled. Pick a card from the deck." if reshuffled else "Pick a card from the deck.", RESULT_NEUTRAL)
		_set_deck_pick_enabled(true)
		return

	pending_guess_higher = player_said_higher
	_set_guess_buttons_enabled(false)
	_set_result_text("Fresh deck shuffled. Pick any facedown card from the deck." if reshuffled else "Pick any facedown card from the deck.", RESULT_NEUTRAL)
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

func _on_deck_card_pressed(pressed_button: Button) -> void:
	if not round_active or input_locked or !awaiting_deck_pick:
		return
	if _ensure_deck_for_pick():
		_update_status_labels()

	input_locked = true
	_set_deck_pick_enabled(false)
	var slot_index: int = pressed_button.get_index()
	_consume_deck_visual_slot(slot_index)
	_dismiss_incoming_overlay()
	var fly_overlay: Control = await _animate_card_fly(pressed_button, pending_guess_higher)
	var previous_card: Dictionary = current_card
	var previous_value: int = Deck.card_value(previous_card)
	var next_card: Dictionary = deck.draw()
	var next_value: int = Deck.card_value(next_card)
	card_panel.visible = true
	await _animate_card_reveal(next_card)
	current_card = next_card
	var reshuffled_after_reveal: bool = _reshuffle_after_reveal_if_needed()
	_update_status_labels()
	var comparison_text: String = "%s after %s." % [Deck.card_text(next_card), Deck.card_text(previous_card)]

	if pending_tie_bet:
		pending_tie_bet = false
		_free_overlay(fly_overlay)
		await _resolve_tie_bet(pending_guess_higher, previous_value, next_card, next_value)
		return

	if next_value == previous_value:
		incoming_overlay = fly_overlay
		await _handle_tie(next_card)
		return

	_free_overlay(fly_overlay)
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
		var success_text: String = "Correct! %s %s." % [comparison_text, reward_text]
		if reshuffled_after_reveal:
			success_text += " Fresh deck shuffled."
		_set_result_text(success_text, RESULT_SUCCESS)
		_animate_streak()
		_emit_streak_particles()
		if await _handle_level_outcome(correct_outcome):
			return
		await get_tree().create_timer(0.55).timeout
		_reset_choice_slots()
		input_locked = false
		_set_guess_buttons_enabled(true)
	else:
		var previous_streak: int = 0 if game_state == null else game_state.current_streak
		var is_near_miss: bool = _is_near_miss(previous_value, next_value)
		var wrong_outcome: Dictionary = game_state.resolve_near_miss_guess() if is_near_miss else game_state.resolve_wrong_guess()
		_update_status_labels()
		var had_near_miss: bool = false
		var had_dramatic_fail: bool = false
		if is_near_miss:
			had_near_miss = await _play_near_miss(previous_value, next_value, comparison_text, reshuffled_after_reveal)
		else:
			had_dramatic_fail = await _play_dramatic_fail(previous_streak, comparison_text, reshuffled_after_reveal)
		if not had_dramatic_fail and not had_near_miss:
			var fail_text: String = "Wrong! %s" % comparison_text
			if reshuffled_after_reveal:
				fail_text += " Fresh deck shuffled."
			_set_result_text(fail_text, RESULT_FAIL)
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

	var reshuffled: bool = _ensure_deck_for_pick()
	if reshuffled:
		_update_status_labels()

	# Dramatic equal bet
	_play_fail_sound()
	var tie_message: String = "TIE! Both cards are %s. Bet: will the next card be Higher or Lower?" % Deck.card_text(tie_card)
	if reshuffled:
		tie_message += " Fresh deck shuffled."
	_set_result_text(tie_message, RESULT_WIN)
	await get_tree().create_timer(0.4).timeout
	input_locked = false
	_set_guess_buttons_enabled(true)
	awaiting_tie_bet = true

func _resolve_tie_bet(player_said_higher: bool, bet_card_value: int, _next_card: Dictionary, next_value: int) -> void:
	if next_value == bet_card_value:
		var tie_count_before: int = game_state.consecutive_ties
		var tie_outcome: Dictionary = game_state.resolve_tie()
		_update_status_labels()
		if tie_count_before >= 2:
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

		var tie_label: String = "DOUBLE TIE! Bet again." if game_state.consecutive_ties >= 2 else "Another tie! Bet again."
		_set_result_text(tie_label, RESULT_WIN if game_state.consecutive_ties >= 2 else RESULT_NEUTRAL)
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
		_set_result_text("Correct bet! +%d bonus points." % bonus, RESULT_SUCCESS)
		_emit_streak_particles()
		if await _handle_level_outcome(outcome):
			return
	else:
		var is_near_miss: bool = _is_near_miss(bet_card_value, next_value)
		var outcome: Dictionary = game_state.resolve_near_miss_tie_bet_wrong() if is_near_miss else game_state.resolve_tie_bet_wrong()
		_update_status_labels()
		var tie_bet_comparison: String = "It was %s, not %s." % [
			"higher" if next_value > bet_card_value else "lower",
			"higher" if player_said_higher else "lower",
		]
		var had_near_miss: bool = false
		if is_near_miss:
			had_near_miss = await _play_near_miss(bet_card_value, next_value, tie_bet_comparison, false)
		if not had_near_miss:
			_play_fail_sound()
			_set_result_text("Wrong bet! Streak reset and -1 draw.", RESULT_FAIL)
		if await _handle_level_outcome(outcome):
			return

	await get_tree().create_timer(0.55).timeout
	_reset_choice_slots()
	input_locked = false
	_set_guess_buttons_enabled(true)

func _deal_new_card_after_tie() -> void:
	_dismiss_incoming_overlay()
	var reshuffled: bool = _draw_new_current_card()
	card_panel.visible = true
	await _animate_card_reveal(current_card)
	reshuffled = _reshuffle_after_reveal_if_needed() or reshuffled
	_update_status_labels()
	_set_result_text("New card dealt. Pick Higher or Lower.%s" % (" Fresh deck shuffled." if reshuffled else ""), RESULT_NEUTRAL)
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

func _animate_card_fly(from_button: Button, guess_higher: bool) -> Control:
	if not is_instance_valid(from_button):
		return null

	# Întoarce cartea cu fața în sus în deck înainte de zbor
	var peeked_card: Dictionary = {}
	if deck != null and not deck.cards.is_empty():
		peeked_card = deck.cards.back()
		_apply_deck_card_front(from_button, peeked_card)
		await get_tree().create_timer(0.42).timeout

	if not is_instance_valid(from_button):
		return null

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(overlay)

	# Fundal carte
	var fly_bg := Panel.new()
	fly_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fly_style := StyleBoxFlat.new()
	fly_style.bg_color = Color("f7f1df")
	fly_style.corner_radius_top_left = 8
	fly_style.corner_radius_top_right = 8
	fly_style.corner_radius_bottom_right = 8
	fly_style.corner_radius_bottom_left = 8
	fly_bg.add_theme_stylebox_override("panel", fly_style)
	overlay.add_child(fly_bg)

	# Text carte (apare după aterizare)
	var fly_label := Label.new()
	fly_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fly_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fly_label.add_theme_font_size_override("font_size", 18)
	fly_label.modulate.a = 0.0
	if not peeked_card.is_empty():
		fly_label.text = "%s\n%s" % [Deck.rank_text(peeked_card), Deck.suit_symbol(peeked_card)]
		fly_label.add_theme_color_override("font_color", Deck.suit_color(peeked_card))
	overlay.add_child(fly_label)

	# Rect sursă și destinație: current card stays centered, played card lands above or below it.
	var from_rect: Rect2 = from_button.get_global_rect()
	var card_rect: Rect2 = card_panel.get_global_rect()
	var card_stack_rect: Rect2 = card_panel.get_parent().get_parent().get_global_rect()
	var feedback_rect: Rect2 = feedback_panel_node.get_global_rect() if feedback_panel_node != null else Rect2()
	var viewport_h: float = get_viewport().get_visible_rect().size.y
	var land_scale := 0.6
	var land_size := card_rect.size * land_scale
	var gap := 10.0
	var dest_x := card_rect.position.x + (card_rect.size.x - land_size.x) * 0.5
	var available_top: float = card_stack_rect.position.y
	var available_bottom: float = card_stack_rect.end.y
	if feedback_panel_node != null:
		available_bottom = feedback_rect.position.y - gap
	var dest_y: float
	if guess_higher:
		dest_y = maxf(available_top, card_rect.position.y - land_size.y - gap)
	else:
		dest_y = minf(available_bottom - land_size.y, card_rect.position.y + card_rect.size.y + gap)
	dest_y = clampf(dest_y, 0.0, viewport_h - land_size.y)
	var to_rect := Rect2(dest_x, dest_y, land_size.x, land_size.y)

	fly_bg.position = from_rect.position
	fly_bg.size = from_rect.size
	fly_label.position = from_rect.position
	fly_label.size = from_rect.size
	from_button.modulate.a = 0.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	tween.tween_property(fly_bg, "position", to_rect.position, 0.3)
	tween.tween_property(fly_bg, "size", to_rect.size, 0.3)
	tween.tween_property(fly_label, "position", to_rect.position, 0.3)
	tween.tween_property(fly_label, "size", to_rect.size, 0.3)
	await tween.finished

	# Dezvăluie textul după aterizare
	var fade_tween := create_tween()
	fade_tween.tween_property(fly_label, "modulate:a", 1.0, 0.15)
	await fade_tween.finished

	return overlay

func _free_overlay(overlay: Control) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	var t := create_tween()
	t.tween_property(overlay, "modulate:a", 0.0, 0.2)
	t.tween_callback(overlay.queue_free)

func _dismiss_incoming_overlay() -> void:
	if incoming_overlay == null:
		return
	_free_overlay(incoming_overlay)
	incoming_overlay = null

func _animate_card_reveal(card: Dictionary) -> void:
	await card_view.animate_reveal(self, card, Callable(self, "_play_card_sound"))

func _animate_streak() -> void:
	run_hud.animate_streak(self)

func _is_near_miss(previous_value: int, next_value: int) -> bool:
	return absi(previous_value - next_value) == NEAR_MISS_DISTANCE

func _play_near_miss(previous_value: int, next_value: int, comparison_text: String, reshuffled_after_reveal: bool) -> bool:
	if not _is_near_miss(previous_value, next_value):
		return false

	_play_near_miss_sound()
	subtitle_label.text = "Near miss. One rank away, and your streak is preserved."
	card_panel.pivot_offset = card_panel.size / 2.0
	card_panel.scale = Vector2.ONE
	card_panel.rotation = 0.0

	await get_tree().create_timer(0.12).timeout

	var near_miss_overlay: Control = _create_near_miss_overlay(previous_value, next_value)

	var slow_tween: Tween = create_tween()
	slow_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slow_tween.set_parallel(true)
	slow_tween.tween_property(card_panel, "scale", Vector2(1.18, 1.18), 0.18)
	slow_tween.tween_property(card_panel, "rotation", 0.055, 0.18)
	if near_miss_overlay != null:
		slow_tween.tween_property(near_miss_overlay, "modulate:a", 1.0, 0.12)
	await slow_tween.finished

	var near_miss_text: String = "NEAR MISS! %s Streak preserved." % comparison_text
	if reshuffled_after_reveal:
		near_miss_text += " Fresh deck shuffled."
	_set_result_text(near_miss_text, RESULT_WIN)
	_shake_screen(0.65)
	_emit_near_miss_particles()
	await get_tree().create_timer(0.85).timeout

	var settle_tween: Tween = create_tween()
	settle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settle_tween.set_parallel(true)
	settle_tween.tween_property(card_panel, "scale", Vector2.ONE, 0.14)
	settle_tween.tween_property(card_panel, "rotation", 0.0, 0.14)
	if near_miss_overlay != null:
		settle_tween.tween_property(near_miss_overlay, "modulate:a", 0.0, 0.14)
	await settle_tween.finished
	if near_miss_overlay != null and is_instance_valid(near_miss_overlay):
		near_miss_overlay.queue_free()
	return true

func _create_near_miss_overlay(previous_value: int, next_value: int) -> Control:
	if effects_layer == null:
		return null

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate.a = 0.0
	effects_layer.add_child(overlay)

	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(0.04, 0.03, 0.02, 0.34)
	overlay.add_child(veil)

	var card_rect: Rect2 = card_panel.get_global_rect()
	var origin_offset: Vector2 = effects_layer.get_global_rect().position
	var center: Vector2 = card_rect.get_center() - origin_offset
	var layer_size: Vector2 = effects_layer.size

	var banner := PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner_width: float = minf(380.0, maxf(260.0, layer_size.x - 24.0))
	banner.position = Vector2(clampf(center.x - banner_width / 2.0, 12.0, maxf(12.0, layer_size.x - banner_width - 12.0)), maxf(18.0, center.y - 178.0))
	banner.size = Vector2(banner_width, 92.0)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.07, 0.065, 0.05, 0.92)
	banner_style.border_color = Color("ffe08a")
	banner_style.border_width_top = 2
	banner_style.border_width_right = 2
	banner_style.border_width_bottom = 2
	banner_style.border_width_left = 2
	banner_style.corner_radius_top_left = 8
	banner_style.corner_radius_top_right = 8
	banner_style.corner_radius_bottom_right = 8
	banner_style.corner_radius_bottom_left = 8
	banner_style.shadow_color = Color(1.0, 0.78, 0.25, 0.38)
	banner_style.shadow_size = 22
	banner.add_theme_stylebox_override("panel", banner_style)
	overlay.add_child(banner)

	var title := Label.new()
	title.text = "SO CLOSE..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("ffe08a"))
	banner.add_child(title)

	_add_near_miss_rank_ghost(overlay, _rank_text_from_value(previous_value), center + Vector2(-150.0, 4.0), Color(0.55, 0.82, 1.0, 0.72))
	_add_near_miss_rank_ghost(overlay, _rank_text_from_value(next_value), center + Vector2(92.0, 4.0), Color(1.0, 0.62, 0.47, 0.78))

	var marker := Label.new()
	marker.text = "1"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.position = center + Vector2(-28.0, 23.0)
	marker.size = Vector2(56.0, 48.0)
	marker.add_theme_font_size_override("font_size", 36)
	marker.add_theme_color_override("font_color", Color("f8f9fa"))
	overlay.add_child(marker)

	var pop_tween: Tween = create_tween()
	pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.set_parallel(true)
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.86, 0.86)
	pop_tween.tween_property(banner, "scale", Vector2.ONE, 0.24)
	pop_tween.tween_property(marker, "scale", Vector2(1.2, 1.2), 0.18)
	pop_tween.chain().tween_property(marker, "scale", Vector2.ONE, 0.12)

	return overlay

func _add_near_miss_rank_ghost(parent: Control, text: String, position_value: Vector2, color: Color) -> void:
	var ghost := Label.new()
	ghost.text = text
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ghost.position = position_value
	ghost.size = Vector2(58.0, 70.0)
	ghost.modulate = color
	ghost.add_theme_font_size_override("font_size", 54)
	parent.add_child(ghost)

	var drift: Tween = create_tween()
	drift.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	drift.set_parallel(true)
	drift.tween_property(ghost, "position:y", ghost.position.y - 12.0, 0.46)
	drift.tween_property(ghost, "modulate:a", 0.18, 0.46)

func _emit_near_miss_particles() -> void:
	if effects_layer == null:
		return

	var origin: Vector2 = card_panel.get_global_rect().get_center() - effects_layer.get_global_rect().position
	var palette: Array[Color] = [
		Color("ffe08a"),
		Color("ff9f7a"),
		Color("90e0ef"),
		Color("f8f9fa"),
	]

	for i in range(22):
		var particle := ColorRect.new()
		var size_value: float = rng.randf_range(3.0, 7.0)
		particle.color = palette[rng.randi_range(0, palette.size() - 1)]
		particle.custom_minimum_size = Vector2(size_value, size_value)
		particle.size = Vector2(size_value, size_value)
		particle.position = origin - particle.size / 2.0
		particle.pivot_offset = particle.size / 2.0
		particle.rotation = rng.randf_range(0.0, TAU)
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effects_layer.add_child(particle)

		var angle: float = rng.randf_range(0.0, TAU)
		var distance: float = rng.randf_range(58.0, 145.0)
		var target_position: Vector2 = particle.position + Vector2(cos(angle), sin(angle)) * distance
		var duration: float = rng.randf_range(0.34, 0.62)
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_position, duration)
		tween.tween_property(particle, "rotation", particle.rotation + rng.randf_range(-4.0, 4.0), duration)
		tween.tween_property(particle, "scale", Vector2.ONE * rng.randf_range(0.25, 0.55), duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration)
		tween.chain().tween_callback(particle.queue_free)

func _rank_text_from_value(value: int) -> String:
	match value:
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
		14:
			return "A"
		_:
			return str(value)

func _play_dramatic_fail(previous_streak: int, comparison_text: String, reshuffled_after_reveal: bool) -> bool:
	if previous_streak < DRAMATIC_FAIL_THRESHOLD:
		return false

	var is_big_collapse: bool = previous_streak >= HIGH_STREAK_THRESHOLD
	_play_collapse_sound(is_big_collapse)
	subtitle_label.text = "The run buckled under pressure." if is_big_collapse else "That streak had real momentum."
	card_panel.pivot_offset = card_panel.size / 2.0
	card_panel.scale = Vector2.ONE
	card_panel.rotation = 0.0

	var freeze_time: float = 0.28 if is_big_collapse else 0.18
	await get_tree().create_timer(freeze_time).timeout

	var zoom_tween: Tween = create_tween()
	zoom_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	zoom_tween.set_parallel(true)
	zoom_tween.tween_property(card_panel, "scale", Vector2(1.16, 1.16) if is_big_collapse else Vector2(1.1, 1.1), 0.16)
	zoom_tween.tween_property(card_panel, "rotation", -0.05 if is_big_collapse else -0.03, 0.16)
	await zoom_tween.finished

	_shake_screen(1.45 if is_big_collapse else 1.15)
	var fail_text: String = "Catastrophe! %s streak lost on %s." % [previous_streak, comparison_text] if is_big_collapse else "So close. %s streak lost on %s." % [previous_streak, comparison_text]
	if reshuffled_after_reveal:
		fail_text += " Fresh deck shuffled."
	_set_result_text(fail_text, RESULT_FAIL)

	var settle_tween: Tween = create_tween()
	settle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settle_tween.set_parallel(true)
	settle_tween.tween_property(card_panel, "scale", Vector2.ONE, 0.18)
	settle_tween.tween_property(card_panel, "rotation", 0.0, 0.18)
	await settle_tween.finished
	return true

func _finish_run(message: String, won: bool) -> void:
	_dismiss_incoming_overlay()
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

func _shake_screen(multiplier: float = 1.0) -> void:
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
		shake_tween.tween_property(self, "position", offset * SCREEN_SHAKE_STRENGTH * multiplier, SCREEN_SHAKE_STEP)

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

func _play_collapse_sound(is_big_collapse: bool) -> void:
	_play_tone_sequence(fail_sfx_player, [
		{"from": 180.0 if is_big_collapse else 240.0, "to": 110.0 if is_big_collapse else 150.0, "duration": 0.18, "volume": 0.16},
		{"from": 120.0 if is_big_collapse else 150.0, "to": 70.0 if is_big_collapse else 95.0, "duration": 0.22, "volume": 0.14},
	])

func _play_near_miss_sound() -> void:
	if fail_sfx_player == null or is_muted:
		return
	fail_sfx_player.stop()
	fail_sfx_player.play()
	var playback: AudioStreamGeneratorPlayback = fail_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	_push_crowd_groan_segment(playback, 0.82, 0.12)

func _push_crowd_groan_segment(playback: AudioStreamGeneratorPlayback, duration: float, volume: float) -> void:
	var frame_count: int = maxi(int(SFX_SAMPLE_RATE * duration), 1)
	var start_frequencies: Array[float] = [255.0, 274.0, 292.0, 315.0, 338.0, 362.0, 386.0]
	var end_frequencies: Array[float] = [152.0, 164.0, 176.0, 190.0, 204.0, 218.0, 232.0]
	var phases: Array[float] = []

	for _i in range(start_frequencies.size()):
		phases.append(rng.randf_range(0.0, TAU))

	for frame_index in range(frame_count):
		var progress: float = float(frame_index) / float(maxi(frame_count - 1, 1))
		var pitch_progress: float = 1.0 - pow(1.0 - progress, 2.4)
		var attack: float = smoothstep(0.0, 0.12, progress)
		var release: float = 1.0 - smoothstep(0.58, 1.0, progress)
		var envelope: float = attack * release
		var sample: float = 0.0

		for voice_index in range(start_frequencies.size()):
			var wobble: float = sin(progress * TAU * (1.1 + float(voice_index) * 0.17)) * 4.0
			var frequency: float = lerpf(start_frequencies[voice_index], end_frequencies[voice_index], pitch_progress) + wobble
			phases[voice_index] += TAU * frequency / SFX_SAMPLE_RATE
			var voice: float = sin(phases[voice_index]) * 0.74
			voice += sin(phases[voice_index] * 2.0) * 0.18
			voice += sin(phases[voice_index] * 0.5) * 0.08
			sample += voice

		sample = sample / float(start_frequencies.size())
		var breath: float = rng.randf_range(-0.035, 0.035) * (1.0 - progress)
		var final_sample: float = (sample + breath) * envelope * volume
		playback.push_frame(Vector2(final_sample, final_sample))

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

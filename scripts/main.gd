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
var current_card: Dictionary = {}
var score: int = 0
var high_score: int = 0
var round_active: bool = false
var input_locked: bool = false
var shake_tween: Tween
var card_sfx_player: AudioStreamPlayer
var success_sfx_player: AudioStreamPlayer
var fail_sfx_player: AudioStreamPlayer
var effects_layer: Control
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var subtitle_label: Label = %SubtitleLabel
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
@onready var higher_button: Button = %HigherButton
@onready var lower_button: Button = %LowerButton
@onready var result_label: Label = %ResultLabel
@onready var play_again_button: Button = %PlayAgainButton
@onready var start_overlay: CenterContainer = %StartOverlay
@onready var start_button: Button = %StartButton

func _ready() -> void:
	_setup_audio()
	_setup_effects_layer()
	rng.randomize()
	higher_button.pressed.connect(_on_higher)
	lower_button.pressed.connect(_on_lower)
	play_again_button.pressed.connect(_on_play_again)
	start_button.pressed.connect(_on_start_pressed)
	card_panel.resized.connect(_refresh_pivots)
	streak_label.resized.connect(_refresh_pivots)
	high_score = _load_high_score()
	await get_tree().process_frame
	_refresh_pivots()
	_show_start_state()

func start_game() -> void:
	deck = Deck.new()
	score = 0
	round_active = true
	input_locked = false
	current_card = deck.draw()
	start_overlay.visible = false
	play_again_button.visible = false
	subtitle_label.text = "Guess whether the next card will be higher or lower."
	_apply_card_visual(current_card)
	_play_card_sound()
	_update_status_labels()
	_set_result_text("A tie counts as a loss.", RESULT_NEUTRAL)
	_set_guess_buttons_enabled(true)

func _show_start_state() -> void:
	start_overlay.visible = true
	round_active = false
	input_locked = false
	current_card = {}
	card_panel.scale = Vector2.ONE
	_apply_card_back()
	score = 0
	_update_status_labels()
	subtitle_label.text = "A small Godot game for practicing scenes, UI, and scripts."
	_set_result_text("Press Start to begin.", RESULT_NEUTRAL)
	play_again_button.visible = false
	_set_guess_buttons_enabled(false)

func _update_status_labels() -> void:
	score_label.text = "Score: %d" % score
	high_score_label.text = "Best: %d" % high_score
	var cards_left: int = Deck.TOTAL_CARDS if deck == null or current_card.is_empty() else deck.cards_left()
	remaining_label.text = "Cards left: %d / %d" % [cards_left, Deck.TOTAL_CARDS]
	streak_label.text = "Streak: %d" % score
	var streak_color: Color = Color("f5f1da")
	if score >= 10:
		streak_color = Color("ffd166")
	elif score >= 5:
		streak_color = Color("ffe29a")
	streak_label.add_theme_color_override("font_color", streak_color)

func _apply_card_visual(card: Dictionary) -> void:
	var rank_text: String = Deck.rank_text(card)
	var suit_symbol: String = Deck.suit_symbol(card)
	var suit_color: Color = Deck.suit_color(card)
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

func _set_guess_buttons_enabled(is_enabled: bool) -> void:
	higher_button.disabled = !is_enabled
	lower_button.disabled = !is_enabled

func _refresh_pivots() -> void:
	card_panel.pivot_offset = card_panel.size / 2.0
	streak_label.pivot_offset = streak_label.size / 2.0

func _on_higher() -> void:
	guess(true)

func _on_lower() -> void:
	guess(false)

func guess(player_said_higher: bool) -> void:
	if not round_active or input_locked:
		return
	if deck.is_empty():
		_finish_round("You cleared the whole deck! Nice job!", true)
		return

	input_locked = true
	_set_guess_buttons_enabled(false)
	var previous_card: Dictionary = current_card
	var previous_value: int = Deck.card_value(previous_card)
	var next_card: Dictionary = deck.draw()
	var next_value: int = Deck.card_value(next_card)
	await _animate_card_reveal(next_card)
	current_card = next_card
	var comparison_text: String = "%s after %s." % [Deck.card_text(next_card), Deck.card_text(previous_card)]

	if next_value == previous_value:
		_finish_round("Tie! %s" % comparison_text, false)
		return

	var guessed_right: bool = player_said_higher == (next_value > previous_value)
	if guessed_right:
		score += 1
		_update_high_score()
		_update_status_labels()
		_play_success_sound()
		_set_result_text("Correct! %s" % comparison_text, RESULT_SUCCESS)
		_animate_streak()
		_emit_streak_particles()
		input_locked = false
		if deck.is_empty():
			_finish_round("You emptied the deck! Final score: %d" % score, true)
			return
		_set_guess_buttons_enabled(true)
	else:
		_finish_round("Wrong! %s Final score: %d" % [comparison_text, score], false)

func _animate_card_reveal(card: Dictionary) -> void:
	_refresh_pivots()
	card_panel.scale = Vector2.ONE
	card_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_play_card_sound()

	var close_front: Tween = create_tween()
	close_front.set_trans(Tween.TRANS_CUBIC)
	close_front.set_ease(Tween.EASE_IN)
	close_front.set_parallel(true)
	close_front.tween_property(card_panel, "scale", Vector2(0.03, 1.06), 0.08)
	close_front.tween_property(card_panel, "modulate", Color(0.82, 0.82, 0.82, 1.0), 0.08)
	await close_front.finished

	_apply_card_back()
	var show_back: Tween = create_tween()
	show_back.set_trans(Tween.TRANS_CUBIC)
	show_back.set_ease(Tween.EASE_OUT)
	show_back.set_parallel(true)
	show_back.tween_property(card_panel, "scale", Vector2(0.72, 1.03), 0.06)
	show_back.tween_property(card_panel, "modulate", Color(0.9, 0.9, 0.9, 1.0), 0.06)
	await show_back.finished

	var hide_back: Tween = create_tween()
	hide_back.set_trans(Tween.TRANS_CUBIC)
	hide_back.set_ease(Tween.EASE_IN)
	hide_back.set_parallel(true)
	hide_back.tween_property(card_panel, "scale", Vector2(0.03, 1.06), 0.06)
	hide_back.tween_property(card_panel, "modulate", Color(0.82, 0.82, 0.82, 1.0), 0.06)
	await hide_back.finished

	_apply_card_visual(card)
	var open_front: Tween = create_tween()
	open_front.set_trans(Tween.TRANS_BACK)
	open_front.set_ease(Tween.EASE_OUT)
	open_front.set_parallel(true)
	open_front.tween_property(card_panel, "scale", Vector2(1.04, 0.98), 0.12)
	open_front.tween_property(card_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	await open_front.finished

	var settle_front: Tween = create_tween()
	settle_front.set_trans(Tween.TRANS_SINE)
	settle_front.set_ease(Tween.EASE_OUT)
	settle_front.tween_property(card_panel, "scale", Vector2.ONE, 0.06)
	await settle_front.finished

func _animate_streak() -> void:
	_refresh_pivots()
	streak_label.scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(streak_label, "scale", Vector2(1.12, 1.12), 0.08)
	tween.tween_property(streak_label, "scale", Vector2.ONE, 0.1)

func _finish_round(message: String, won: bool) -> void:
	round_active = false
	input_locked = false
	_set_guess_buttons_enabled(false)
	play_again_button.visible = true
	if won:
		subtitle_label.text = "The round is over. You can start another one right away."
		_set_result_text(message, RESULT_WIN)
	else:
		_play_fail_sound()
		_shake_screen()
		subtitle_label.text = "You lost the current round. Try again."
		_set_result_text(message, RESULT_FAIL)
	_update_status_labels()

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
	if player == null:
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
	if score < MEDIUM_STREAK_THRESHOLD or effects_layer == null:
		return

	var is_big_streak: bool = score >= HIGH_STREAK_THRESHOLD
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
	if score <= high_score:
		return
	high_score = score
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"high_score": high_score}))

func _load_high_score() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return 0
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	return int(parsed.get("high_score", 0))

func _on_start_pressed() -> void:
	start_game()

func _on_play_again() -> void:
	start_game()

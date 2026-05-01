class_name RunHud
extends RefCounted

const MEDIUM_STREAK_THRESHOLD := 5
const HIGH_STREAK_THRESHOLD := 10

var background: ColorRect
var score_label: Label
var high_score_label: Label
var remaining_label: Label
var streak_label: Label
var bonus_banner: PanelContainer
var bonus_banner_label: Label
var modifier_banner: PanelContainer
var modifier_banner_label: Label
var deck_label: Label
var streak_bar: ProgressBar
var bonus_banner_tween: Tween
var streak_bar_tween: Tween
var momentum_tween: Tween

func setup(
	background_node: ColorRect,
	score: Label,
	high_score: Label,
	remaining: Label,
	streak: Label,
	bonus_panel: PanelContainer,
	bonus_label: Label,
	modifier_panel: PanelContainer,
	modifier_label: Label,
	deck_label_node: Label
) -> void:
	background = background_node
	score_label = score
	high_score_label = high_score
	remaining_label = remaining
	streak_label = streak
	bonus_banner = bonus_panel
	bonus_banner_label = bonus_label
	modifier_banner = modifier_panel
	modifier_banner_label = modifier_label
	deck_label = deck_label_node

func create_streak_bar(owner: Control, left_col: HBoxContainer) -> void:
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

func update(game_state: GameState, high_score: int, owner: Control) -> void:
	var run_score: int = 0 if game_state == null else game_state.run_score
	var active_multiplier: int = 1 if game_state == null else game_state.get_streak_multiplier()
	var modifier_label: String = "" if game_state == null else game_state.get_level_modifier_label()
	var modifier_description: String = "" if game_state == null else game_state.get_level_modifier_description()
	var streak_value: int = 0 if game_state == null else game_state.current_streak
	if modifier_label == "Precision" and game_state != null:
		score_label.text = "Run: %d  Precision: %d/2" % [run_score, game_state.get_precision_chain()]
	else:
		score_label.text = "Run: %d  Mult: x%d" % [run_score, active_multiplier]
	high_score_label.text = "Best: %d" % high_score

	var bonus_draws: int = 0 if game_state == null else game_state.get_active_bonus_draws()
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
	if streak_value >= 10:
		streak_color = Color("ffd166")
	elif streak_value >= 5:
		streak_color = Color("ffe29a")
	streak_label.add_theme_color_override("font_color", streak_color)
	_set_bonus_banner_state(bonus_draws, owner)
	_set_modifier_banner_state(modifier_label, modifier_description)
	_update_streak_bar(streak_value, owner)
	_apply_momentum(streak_value, bonus_draws, owner)

func refresh_pivot() -> void:
	streak_label.pivot_offset = streak_label.size / 2.0

func animate_streak(owner: Control) -> void:
	refresh_pivot()
	streak_label.scale = Vector2.ONE
	var tween: Tween = owner.create_tween()
	tween.tween_property(streak_label, "scale", Vector2(1.12, 1.12), 0.08)
	tween.tween_property(streak_label, "scale", Vector2.ONE, 0.1)

func _set_bonus_banner_state(bonus_draws: int, owner: Control) -> void:
	var has_bonus: bool = bonus_draws > 0
	bonus_banner.visible = has_bonus
	if has_bonus:
		bonus_banner_label.text = "Bonus Active: +%d draws this level" % bonus_draws
	else:
		bonus_banner_label.text = ""

	if bonus_banner_tween != null:
		bonus_banner_tween.kill()
		bonus_banner_tween = null

	if not has_bonus:
		bonus_banner.scale = Vector2.ONE
		return

	bonus_banner.scale = Vector2.ONE
	bonus_banner_tween = owner.create_tween()
	bonus_banner_tween.set_loops()
	bonus_banner_tween.tween_property(bonus_banner, "scale", Vector2(1.015, 1.015), 0.65)
	bonus_banner_tween.tween_property(bonus_banner, "scale", Vector2.ONE, 0.65)

func _apply_momentum(streak: int, bonus_draws: int, owner: Control) -> void:
	var table_color: Color = Color("0f703e") if bonus_draws > 0 else Color("155835")
	var deck_color: Color = Color("ffd166") if bonus_draws > 0 else Color("f5f1da")
	var score_color: Color = Color("f5f1da")
	var high_score_color: Color = Color("f5f1da")
	var remaining_color: Color = Color("f5f1da")

	if streak >= HIGH_STREAK_THRESHOLD:
		table_color = Color("7b2215") if bonus_draws <= 0 else Color("7a4d0f")
		deck_color = Color("ffe8a3")
		score_color = Color("ffe29a")
		high_score_color = Color("ffd166")
		remaining_color = Color("fff1c2")
	elif streak >= MEDIUM_STREAK_THRESHOLD:
		table_color = Color("7a4a12") if bonus_draws <= 0 else Color("87620f")
		deck_color = Color("ffe29a")
		score_color = Color("fff1c2")
		high_score_color = Color("ffe29a")
		remaining_color = Color("f7f0d7")

	if momentum_tween != null:
		momentum_tween.kill()
	momentum_tween = owner.create_tween()
	momentum_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	momentum_tween.tween_property(background, "color", table_color, 0.25)

	deck_label.add_theme_color_override("font_color", deck_color)
	score_label.add_theme_color_override("font_color", score_color)
	high_score_label.add_theme_color_override("font_color", high_score_color)
	remaining_label.add_theme_color_override("font_color", remaining_color)

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

func _update_streak_bar(streak: int, owner: Control) -> void:
	if streak_bar == null:
		return
	_apply_streak_bar_fill_style(streak)
	if streak_bar_tween != null:
		streak_bar_tween.kill()
	streak_bar_tween = owner.create_tween()
	streak_bar_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	streak_bar_tween.tween_property(streak_bar, "value", float(mini(streak, HIGH_STREAK_THRESHOLD)), 0.25)

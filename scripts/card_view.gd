class_name CardView
extends RefCounted

const MEDIUM_STREAK_THRESHOLD := 5
const HIGH_STREAK_THRESHOLD := 10

var panel: PanelContainer
var rank_label: Label
var suit_center: Label
var corner_rank_top: Label
var corner_suit_top: Label
var corner_rank_bottom: Label
var corner_suit_bottom: Label
var base_panel_style: StyleBoxFlat

func setup(
	card_panel: PanelContainer,
	card_label: Label,
	card_suit_center: Label,
	top_rank: Label,
	top_suit: Label,
	bottom_rank: Label,
	bottom_suit: Label
) -> void:
	panel = card_panel
	rank_label = card_label
	suit_center = card_suit_center
	corner_rank_top = top_rank
	corner_suit_top = top_suit
	corner_rank_bottom = bottom_rank
	corner_suit_bottom = bottom_suit
	base_panel_style = _get_panel_style()

func apply_card(card: Dictionary) -> void:
	var rank_text: String = Deck.rank_text(card)
	var suit_symbol: String = Deck.suit_symbol(card)
	var suit_color: Color = Deck.suit_color(card)
	panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	rank_label.text = rank_text
	suit_center.text = suit_symbol
	corner_rank_top.text = rank_text
	corner_suit_top.text = suit_symbol
	corner_rank_bottom.text = rank_text
	corner_suit_bottom.text = suit_symbol
	_apply_text_color(suit_color)

func apply_back() -> void:
	var back_color: Color = Color("16202a")
	panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	rank_label.text = "?"
	suit_center.text = "?"
	corner_rank_top.text = "?"
	corner_suit_top.text = ""
	corner_rank_bottom.text = "?"
	corner_suit_bottom.text = ""
	_apply_text_color(back_color)

func apply_empty() -> void:
	var placeholder_color: Color = Color(0.086275, 0.12549, 0.164706, 0.38)
	panel.visible = true
	panel.modulate = Color(1.0, 1.0, 1.0, 0.45)
	rank_label.text = ""
	suit_center.text = ""
	corner_rank_top.text = ""
	corner_suit_top.text = ""
	corner_rank_bottom.text = ""
	corner_suit_bottom.text = ""
	_apply_text_color(placeholder_color)

func refresh_pivot() -> void:
	panel.pivot_offset = panel.size / 2.0

func apply_streak_momentum(streak: int) -> void:
	var style: StyleBoxFlat = base_panel_style.duplicate() as StyleBoxFlat
	if style == null:
		return

	if streak >= HIGH_STREAK_THRESHOLD:
		style.border_color = Color("ffd166")
		style.shadow_color = Color(1.0, 0.721569, 0.270588, 0.42)
		style.shadow_size = 24
	elif streak >= MEDIUM_STREAK_THRESHOLD:
		style.border_color = Color(0.992157, 0.823529, 0.388235, 0.38)
		style.shadow_color = Color(1.0, 0.878431, 0.537255, 0.26)
		style.shadow_size = 18

	panel.add_theme_stylebox_override("panel", style)

func animate_reveal(owner: Control, card: Dictionary, play_sound: Callable) -> void:
	refresh_pivot()
	panel.scale = Vector2.ONE
	panel.rotation = 0.0
	panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	play_sound.call()

	var close_front: Tween = owner.create_tween()
	close_front.set_trans(Tween.TRANS_CUBIC)
	close_front.set_ease(Tween.EASE_IN)
	close_front.set_parallel(true)
	close_front.tween_property(panel, "scale", Vector2(0.02, 1.08), 0.08)
	close_front.tween_property(panel, "rotation", -0.09, 0.08)
	close_front.tween_property(panel, "modulate", Color(0.82, 0.82, 0.82, 1.0), 0.08)
	await close_front.finished

	apply_back()
	var show_back: Tween = owner.create_tween()
	show_back.set_trans(Tween.TRANS_CUBIC)
	show_back.set_ease(Tween.EASE_OUT)
	show_back.set_parallel(true)
	show_back.tween_property(panel, "scale", Vector2(0.78, 1.02), 0.06)
	show_back.tween_property(panel, "rotation", 0.07, 0.06)
	show_back.tween_property(panel, "modulate", Color(0.9, 0.9, 0.9, 1.0), 0.06)
	await show_back.finished

	var hide_back: Tween = owner.create_tween()
	hide_back.set_trans(Tween.TRANS_CUBIC)
	hide_back.set_ease(Tween.EASE_IN)
	hide_back.set_parallel(true)
	hide_back.tween_property(panel, "scale", Vector2(0.02, 1.08), 0.06)
	hide_back.tween_property(panel, "rotation", -0.08, 0.06)
	hide_back.tween_property(panel, "modulate", Color(0.82, 0.82, 0.82, 1.0), 0.06)
	await hide_back.finished

	apply_card(card)
	var open_front: Tween = owner.create_tween()
	open_front.set_trans(Tween.TRANS_BACK)
	open_front.set_ease(Tween.EASE_OUT)
	open_front.set_parallel(true)
	open_front.tween_property(panel, "scale", Vector2(1.08, 0.97), 0.12)
	open_front.tween_property(panel, "rotation", 0.08, 0.12)
	open_front.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	await open_front.finished

	var settle_front: Tween = owner.create_tween()
	settle_front.set_trans(Tween.TRANS_SINE)
	settle_front.set_ease(Tween.EASE_OUT)
	settle_front.set_parallel(true)
	settle_front.tween_property(panel, "scale", Vector2.ONE, 0.06)
	settle_front.tween_property(panel, "rotation", 0.0, 0.06)
	await settle_front.finished

func _apply_text_color(color: Color) -> void:
	rank_label.add_theme_color_override("font_color", color)
	suit_center.add_theme_color_override("font_color", color)
	corner_rank_top.add_theme_color_override("font_color", color)
	corner_suit_top.add_theme_color_override("font_color", color)
	corner_rank_bottom.add_theme_color_override("font_color", color)
	corner_suit_bottom.add_theme_color_override("font_color", color)

func _get_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
	return style

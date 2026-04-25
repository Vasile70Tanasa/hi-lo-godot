class_name DeckView
extends RefCounted

var grid: GridContainer
var label: Label
var visual_slots: Array[bool] = []

func setup(deck_grid: GridContainer, deck_label: Label) -> void:
	grid = deck_grid
	label = deck_label

func clear_slots() -> void:
	visual_slots.clear()

func reset_slots(slot_count: int) -> void:
	visual_slots.clear()
	for _slot in range(slot_count):
		visual_slots.append(true)

func consume_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= visual_slots.size():
		return
	visual_slots[slot_index] = false

func consume_next_slot() -> void:
	for index in range(visual_slots.size() - 1, -1, -1):
		if visual_slots[index]:
			visual_slots[index] = false
			return

func update_label(is_start_visible: bool, is_reveal_in_progress: bool, is_revealed: bool, is_round_active: bool, is_awaiting_pick: bool) -> void:
	if is_start_visible:
		label.text = "Deck"
	elif is_reveal_in_progress or (is_revealed and !is_round_active):
		label.text = "Remaining Cards"
	elif is_awaiting_pick:
		label.text = "Pick a Card"
	else:
		label.text = "Deck"

func rebuild(
	deck: Deck,
	current_card: Dictionary,
	round_active: bool,
	awaiting_pick: bool,
	reveal_remaining_cards: bool,
	card_pressed_callback: Callable
) -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	var slot_count: int = visual_slots.size()
	if slot_count == 0 and deck != null and deck.cards_left() > 0 and !current_card.is_empty():
		reset_slots(deck.cards_left())
		slot_count = visual_slots.size()

	var remaining_card_index: int = 0
	for index in range(slot_count):
		if !visual_slots[index]:
			var empty_slot: Control = Control.new()
			empty_slot.custom_minimum_size = Vector2(34, 50)
			empty_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(empty_slot)
			continue

		var deck_button: Button = Button.new()
		deck_button.custom_minimum_size = Vector2(50, 70)
		deck_button.focus_mode = Control.FOCUS_NONE
		if reveal_remaining_cards and deck != null and remaining_card_index < deck.cards.size():
			var remaining_card: Dictionary = deck.cards[remaining_card_index]
			remaining_card_index += 1
			apply_card_front(deck_button, remaining_card)
		else:
			apply_card_back(deck_button, awaiting_pick, round_active)
			deck_button.pressed.connect(card_pressed_callback.bind(deck_button))
		grid.add_child(deck_button)

func set_pick_enabled(is_enabled: bool, round_active: bool) -> void:
	for child: Node in grid.get_children():
		var deck_button: Button = child as Button
		if deck_button != null:
			deck_button.disabled = !is_enabled or !round_active

func get_deck_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in grid.get_children():
		var deck_button: Button = child as Button
		if deck_button != null:
			buttons.append(deck_button)
	return buttons

func apply_card_back(deck_button: Button, awaiting_pick: bool, round_active: bool) -> void:
	deck_button.text = "HI\nLO"
	deck_button.disabled = !awaiting_pick or !round_active
	deck_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if awaiting_pick and round_active else Control.CURSOR_ARROW
	var is_pick_state: bool = awaiting_pick and round_active
	var base_fill: Color = Color("24575a") if is_pick_state else Color("173246")
	var hover_fill: Color = Color("2f7376") if is_pick_state else Color("23516f")
	var pressed_fill: Color = Color("183e40") if is_pick_state else Color("102635")
	var border_color: Color = Color("ffd166") if is_pick_state else Color(0.952941, 0.945098, 0.831373, 0.24)
	var disabled_border: Color = Color(0.952941, 0.945098, 0.831373, 0.32) if is_pick_state else Color(0.952941, 0.945098, 0.831373, 0.14)
	deck_button.add_theme_stylebox_override("normal", _make_card_style(base_fill, border_color))
	deck_button.add_theme_stylebox_override("hover", _make_card_style(hover_fill, Color("ffe6a7")))
	deck_button.add_theme_stylebox_override("pressed", _make_card_style(pressed_fill, Color(1.0, 0.901961, 0.654902, 0.6)))
	deck_button.add_theme_stylebox_override("disabled", _make_card_style(base_fill, disabled_border))
	deck_button.add_theme_color_override("font_color", Color("f3edd1"))
	deck_button.add_theme_color_override("font_hover_color", Color("fff7de"))
	deck_button.add_theme_color_override("font_pressed_color", Color("f3edd1"))
	deck_button.add_theme_color_override("font_disabled_color", Color(0.952941, 0.945098, 0.831373, 0.55))
	deck_button.add_theme_font_size_override("font_size", 10)

func apply_card_front(deck_button: Button, card: Dictionary) -> void:
	var suit_color: Color = Deck.suit_color(card)
	deck_button.text = "%s\n%s" % [Deck.rank_text(card), Deck.suit_symbol(card)]
	deck_button.disabled = true
	deck_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	deck_button.add_theme_stylebox_override("normal", _make_card_style(Color("f7f1df"), Color(0.14902, 0.184314, 0.231373, 0.22)))
	deck_button.add_theme_stylebox_override("hover", _make_card_style(Color("f7f1df"), Color(0.14902, 0.184314, 0.231373, 0.22)))
	deck_button.add_theme_stylebox_override("pressed", _make_card_style(Color("f7f1df"), Color(0.14902, 0.184314, 0.231373, 0.22)))
	deck_button.add_theme_stylebox_override("disabled", _make_card_style(Color("f7f1df"), Color(0.14902, 0.184314, 0.231373, 0.22)))
	deck_button.add_theme_color_override("font_color", suit_color)
	deck_button.add_theme_color_override("font_hover_color", suit_color)
	deck_button.add_theme_color_override("font_pressed_color", suit_color)
	deck_button.add_theme_color_override("font_disabled_color", suit_color)
	deck_button.add_theme_font_size_override("font_size", 11)

func animate_card_flip(owner: Control, deck_button: Button, card: Dictionary, is_cancelled: Callable) -> bool:
	if not is_instance_valid(deck_button) or bool(is_cancelled.call()):
		return false
	deck_button.pivot_offset = deck_button.custom_minimum_size / 2.0
	deck_button.scale = Vector2.ONE
	deck_button.rotation = 0.0
	var close_tween: Tween = owner.create_tween()
	close_tween.bind_node(deck_button)
	close_tween.set_trans(Tween.TRANS_CUBIC)
	close_tween.set_ease(Tween.EASE_IN)
	close_tween.set_parallel(true)
	close_tween.tween_property(deck_button, "scale", Vector2(0.05, 1.07), 0.05)
	close_tween.tween_property(deck_button, "rotation", -0.08, 0.05)
	await close_tween.finished
	if not is_instance_valid(deck_button) or bool(is_cancelled.call()):
		return false

	apply_card_front(deck_button, card)

	var open_tween: Tween = owner.create_tween()
	open_tween.bind_node(deck_button)
	open_tween.set_trans(Tween.TRANS_BACK)
	open_tween.set_ease(Tween.EASE_OUT)
	open_tween.set_parallel(true)
	open_tween.tween_property(deck_button, "scale", Vector2(1.12, 0.97), 0.08)
	open_tween.tween_property(deck_button, "rotation", 0.06, 0.08)
	await open_tween.finished
	if not is_instance_valid(deck_button) or bool(is_cancelled.call()):
		return false

	var settle_tween: Tween = owner.create_tween()
	settle_tween.bind_node(deck_button)
	settle_tween.set_trans(Tween.TRANS_SINE)
	settle_tween.set_ease(Tween.EASE_OUT)
	settle_tween.set_parallel(true)
	settle_tween.tween_property(deck_button, "scale", Vector2.ONE, 0.04)
	settle_tween.tween_property(deck_button, "rotation", 0.0, 0.04)
	return true

func _make_card_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
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

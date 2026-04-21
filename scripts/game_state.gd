class_name GameState
extends RefCounted

const DEFAULT_LIVES := 3
const MAX_LIVES := 4
const MODIFIER_NONE := ""
const MODIFIER_ROYAL_BONUS := "royal_bonus"
const MODIFIER_BLACKOUT := "blackout"
const MODIFIER_PRECISION := "precision"
const REWARD_NONE := ""
const REWARD_LIFE := "life"
const REWARD_DRAWS := "draws"
const LEVEL_CONFIGS: Array[Dictionary] = [
	{"target": 5, "draw_limit": 10},
	{"target": 6, "draw_limit": 9},
	{"target": 7, "draw_limit": 8},
	{"target": 8, "draw_limit": 8},
	{"target": 8, "draw_limit": 9, "modifier": MODIFIER_ROYAL_BONUS},
	{"target": 9, "draw_limit": 8},
	{"target": 9, "draw_limit": 9},
	{"target": 6, "draw_limit": 11, "modifier": MODIFIER_BLACKOUT},
	{"target": 10, "draw_limit": 9},
	{"target": 10, "draw_limit": 10},
	{"target": 9, "draw_limit": 11, "modifier": MODIFIER_PRECISION},
]
const NEXT_LEVEL_BONUS_DRAWS := 3
const BONUS_UNLOCK_INTERVAL := 3

var lives: int = DEFAULT_LIVES
var level_index: int = 0
var run_score: int = 0
var level_score: int = 0
var draws_used: int = 0
var current_streak: int = 0
var precision_chain: int = 0
var consecutive_ties: int = 0
var active_bonus_draws: int = 0
var reward_choice_pending: bool = false

func _init() -> void:
	start_new_run()

func start_new_run() -> void:
	lives = DEFAULT_LIVES
	level_index = 0
	run_score = 0
	active_bonus_draws = 0
	reward_choice_pending = false
	_reset_level_progress()

func get_level_number() -> int:
	return level_index + 1

func get_level_target() -> int:
	return int(get_current_level_config().get("target", 5))

func get_level_draw_limit() -> int:
	return get_base_level_draw_limit() + active_bonus_draws

func get_level_modifier() -> String:
	return String(get_current_level_config().get("modifier", MODIFIER_NONE))

func get_level_modifier_label() -> String:
	match get_level_modifier():
		MODIFIER_PRECISION:
			return "Precision"
		MODIFIER_BLACKOUT:
			return "Blackout"
		MODIFIER_ROYAL_BONUS:
			return "Royal Bonus"
		_:
			return ""

func get_level_modifier_description() -> String:
	match get_level_modifier():
		MODIFIER_PRECISION:
			return "Every 2 correct guesses in a row give 3 points, then the counter resets."
		MODIFIER_BLACKOUT:
			return "Only black revealed cards score. Correct red cards give 0 points."
		MODIFIER_ROYAL_BONUS:
			return "Correct guesses on J, Q, K, or A give +1 extra point."
		_:
			return ""

func get_precision_chain() -> int:
	return precision_chain

func get_base_level_draw_limit() -> int:
	return int(get_current_level_config().get("draw_limit", 10))

func get_active_bonus_draws() -> int:
	return active_bonus_draws

func has_pending_reward_choice() -> bool:
	return reward_choice_pending

func can_gain_life() -> bool:
	return lives < MAX_LIVES

func apply_reward_choice(reward_id: String) -> Dictionary:
	if not reward_choice_pending:
		return {
			"reward_id": REWARD_NONE,
			"label": "",
			"applied": false,
		}

	var result: Dictionary = {
		"reward_id": reward_id,
		"label": "",
		"applied": false,
	}
	active_bonus_draws = 0

	match reward_id:
		REWARD_LIFE:
			if can_gain_life():
				lives += 1
				result["label"] = "+1 Life"
				result["applied"] = true
			else:
				result["label"] = "Lives are already full"
		REWARD_DRAWS:
			active_bonus_draws = NEXT_LEVEL_BONUS_DRAWS
			result["label"] = "+%d Draws" % NEXT_LEVEL_BONUS_DRAWS
			result["applied"] = true
		_:
			result["reward_id"] = REWARD_NONE

	if bool(result.get("applied", false)):
		reward_choice_pending = false
	result["lives"] = lives
	result["next_level_bonus_draws"] = active_bonus_draws
	return result

func get_current_level_config() -> Dictionary:
	if level_index < LEVEL_CONFIGS.size():
		return LEVEL_CONFIGS[level_index]

	var extra_level_index: int = level_index - LEVEL_CONFIGS.size()
	return {
		"target": 10 + int((extra_level_index + 1) / 2),
		"draw_limit": 10 + int(extra_level_index / 3),
	}

func get_streak_multiplier() -> int:
	if current_streak >= 5:
		return 3
	if current_streak >= 3:
		return 2
	return 1

func resolve_correct_guess(revealed_card: Dictionary) -> Dictionary:
	draws_used += 1
	current_streak += 1
	var streak_points: int = get_streak_multiplier()
	var modifier_result: Dictionary = _get_correct_guess_modifier_result(revealed_card, streak_points)
	var modifier_bonus: int = int(modifier_result.get("modifier_bonus", 0))
	var awarded_points: int = int(modifier_result.get("awarded_points", streak_points))
	level_score += awarded_points
	run_score += awarded_points
	var result: Dictionary = _evaluate_attempt(false, awarded_points)
	result["streak_points"] = streak_points
	result["modifier_bonus"] = modifier_bonus
	result["modifier_name"] = get_level_modifier_label()
	result["modifier_blocked"] = bool(modifier_result.get("modifier_blocked", false))
	result["modifier_effect_text"] = String(modifier_result.get("modifier_effect_text", ""))
	result["precision_chain"] = precision_chain
	return result

func resolve_wrong_guess() -> Dictionary:
	draws_used += 1
	current_streak = 0
	precision_chain = 0
	return _evaluate_attempt(false, 0)

func resolve_tie() -> Dictionary:
	draws_used += 1
	current_streak = 0
	precision_chain = 0
	consecutive_ties += 1
	return _evaluate_attempt(true, 0)

func resolve_tie_bet_correct() -> Dictionary:
	var multiplier: int = get_streak_multiplier()
	var bonus: int = multiplier * 2
	run_score += bonus
	level_score += bonus
	current_streak = 0
	precision_chain = 0
	consecutive_ties = 0
	return _evaluate_attempt(true, bonus)

func resolve_tie_bet_wrong() -> Dictionary:
	current_streak = 0
	precision_chain = 0
	consecutive_ties = 0
	draws_used += 1
	return _evaluate_attempt(true, 0)

func resolve_triple_tie() -> Dictionary:
	var jackpot: int = 15
	run_score += jackpot
	level_score += jackpot
	current_streak = 0
	precision_chain = 0
	consecutive_ties = 0
	return _evaluate_attempt(true, jackpot)

func pop_consecutive_ties() -> int:
	var count: int = consecutive_ties
	consecutive_ties = 0
	return count

func _evaluate_attempt(was_tie: bool, awarded_points: int) -> Dictionary:
	var result: Dictionary = {
		"was_tie": was_tie,
		"awarded_points": awarded_points,
		"multiplier": get_streak_multiplier(),
		"modifier_name": get_level_modifier_label(),
		"level_completed": false,
		"level_failed": false,
		"life_lost": false,
		"run_over": false,
		"advanced_level": false,
		"level_number": get_level_number(),
		"lives_left": lives,
		"reward_choice_available": false,
		"next_level_bonus_draws": 0,
	}

	if level_score >= get_level_target():
		var cleared_level_number: int = get_level_number()
		active_bonus_draws = 0
		level_index += 1
		if cleared_level_number % BONUS_UNLOCK_INTERVAL == 0:
			reward_choice_pending = true
			result["reward_choice_available"] = true
		result["level_completed"] = true
		result["advanced_level"] = true
		result["next_level_number"] = get_level_number()
		result["level_number"] = cleared_level_number
		result["next_level_bonus_draws"] = 0
		_reset_level_progress()
		return result

	if draws_used >= get_level_draw_limit():
		lives -= 1
		result["level_failed"] = true
		result["life_lost"] = true
		result["lives_left"] = lives
		if lives <= 0:
			result["run_over"] = true
		else:
			_reset_level_progress()
		return result

	return result

func _get_correct_guess_modifier_result(revealed_card: Dictionary, streak_points: int) -> Dictionary:
	var result: Dictionary = {
		"awarded_points": streak_points,
		"modifier_bonus": 0,
		"modifier_blocked": false,
		"modifier_effect_text": "",
	}
	match get_level_modifier():
		MODIFIER_PRECISION:
			precision_chain += 1
			result["modifier_effect_text"] = "Precision %d/2" % precision_chain
			if precision_chain >= 2:
				result["awarded_points"] = 3
				result["modifier_effect_text"] = "Precision combo complete"
				precision_chain = 0
		MODIFIER_BLACKOUT:
			var suit: String = String(revealed_card.get("suit", ""))
			if suit == "hearts" or suit == "diamonds":
				result["awarded_points"] = 0
				result["modifier_blocked"] = true
				result["modifier_effect_text"] = "Blackout blocked the score on a red card"
		MODIFIER_ROYAL_BONUS:
			var rank: int = int(revealed_card.get("rank", 0))
			if rank == 1 or rank >= 11:
				result["modifier_bonus"] = 1
				result["awarded_points"] = streak_points + 1
				result["modifier_effect_text"] = "+1 Royal Bonus"
		_:
			pass
	return result

func _reset_level_progress() -> void:
	level_score = 0
	draws_used = 0
	current_streak = 0
	precision_chain = 0
	consecutive_ties = 0

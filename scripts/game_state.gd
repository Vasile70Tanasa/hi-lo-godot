class_name GameState
extends RefCounted

const DEFAULT_LIVES := 3
const LEVEL_CONFIGS: Array[Dictionary] = [
	{"target": 5, "draw_limit": 10},
	{"target": 6, "draw_limit": 9},
	{"target": 7, "draw_limit": 8},
	{"target": 8, "draw_limit": 8},
	{"target": 9, "draw_limit": 7},
]
const NEXT_LEVEL_BONUS_DRAWS := 2
const BONUS_UNLOCK_INTERVAL := 3

var lives: int = DEFAULT_LIVES
var level_index: int = 0
var run_score: int = 0
var level_score: int = 0
var draws_used: int = 0
var current_streak: int = 0
var active_bonus_draws: int = 0
var queued_bonus_draws: int = 0

func _init() -> void:
	start_new_run()

func start_new_run() -> void:
	lives = DEFAULT_LIVES
	level_index = 0
	run_score = 0
	active_bonus_draws = 0
	queued_bonus_draws = 0
	_reset_level_progress()

func get_level_number() -> int:
	return level_index + 1

func get_level_target() -> int:
	return int(get_current_level_config().get("target", 5))

func get_level_draw_limit() -> int:
	return get_base_level_draw_limit() + active_bonus_draws

func get_base_level_draw_limit() -> int:
	return int(get_current_level_config().get("draw_limit", 10))

func get_active_bonus_draws() -> int:
	return active_bonus_draws

func get_current_level_config() -> Dictionary:
	if level_index < LEVEL_CONFIGS.size():
		return LEVEL_CONFIGS[level_index]

	var extra_level_index: int = level_index - LEVEL_CONFIGS.size()
	return {
		"target": 10 + extra_level_index,
		"draw_limit": maxi(7 - int((extra_level_index + 1) / 2), 5),
	}

func get_streak_multiplier() -> int:
	if current_streak >= 5:
		return 3
	if current_streak >= 3:
		return 2
	return 1

func resolve_correct_guess() -> Dictionary:
	draws_used += 1
	current_streak += 1
	var awarded_points: int = get_streak_multiplier()
	level_score += awarded_points
	run_score += awarded_points
	return _evaluate_attempt(false, awarded_points)

func resolve_wrong_guess() -> Dictionary:
	draws_used += 1
	current_streak = 0
	return _evaluate_attempt(false, 0)

func resolve_tie() -> Dictionary:
	draws_used += 1
	current_streak = 0
	return _evaluate_attempt(true, 0)

func _evaluate_attempt(was_tie: bool, awarded_points: int) -> Dictionary:
	var result: Dictionary = {
		"was_tie": was_tie,
		"awarded_points": awarded_points,
		"multiplier": get_streak_multiplier(),
		"level_completed": false,
		"level_failed": false,
		"life_lost": false,
		"run_over": false,
		"advanced_level": false,
		"level_number": get_level_number(),
		"lives_left": lives,
		"bonus_unlocked": false,
		"next_level_bonus_draws": active_bonus_draws,
	}

	if level_score >= get_level_target():
		var cleared_level_number: int = get_level_number()
		if cleared_level_number % BONUS_UNLOCK_INTERVAL == 0:
			queued_bonus_draws = NEXT_LEVEL_BONUS_DRAWS
			result["bonus_unlocked"] = true
		level_index += 1
		active_bonus_draws = queued_bonus_draws
		queued_bonus_draws = 0
		result["level_completed"] = true
		result["advanced_level"] = true
		result["next_level_number"] = get_level_number()
		result["level_number"] = cleared_level_number
		result["next_level_bonus_draws"] = active_bonus_draws
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

func _reset_level_progress() -> void:
	level_score = 0
	draws_used = 0
	current_streak = 0

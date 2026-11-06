extends RefCounted
class_name OysterSim
## The complete four-gesture oyster. Pure logic: no scene tree, so tests drive it.
## Pearls are injected at construction (rolled at spawn by the spawner).

enum State { SPAWNED, SEATED, OPEN, PLATED, SERVED, BINNED }
enum Stage { WEDGE, POP, SLIDE, RESEAT, DONE }
enum Wedge { NONE, SNAG, CLEAN, WOBBLE, SLIP }
enum Pop { NONE, PERFECT, NORMAL, CRACKED, FIGHTBACK }

const TRANSITIONS := {
	State.SPAWNED: [State.SEATED, State.BINNED],
	State.SEATED: [State.OPEN, State.SPAWNED, State.BINNED],
	State.OPEN: [State.PLATED, State.BINNED],
	State.PLATED: [State.SERVED, State.BINNED],
	State.SERVED: [],
	State.BINNED: [],
}

var species: SpeciesData
var balance: BalanceData
var grades: GradeData
var rng: RandomNumberGenerator
var pearls: Array[Pearl] = []
var pearls_forfeited := false

var state := State.SPAWNED
var stage := Stage.WEDGE
var wedge_value := 0.0
var wedge_result := Wedge.NONE
var steady := false
var wobble := false
var slipped := false
var wet_hands := false
var free_slip_available := false
var nicked := false
var pop_ring := 1.0
var pop_active := false
var pop_result := Pop.NONE
var cracked := false
var slide_progress := 0.0
var slide_offline := 0.0
var slide_inside := 0
var slide_samples := 0
var slide_max_speed := 0.0
var slide_done := false
var sliced := false
var shattered := false
var juice_loss := false
var stabbed := false
var surgical := false
var ruined := false
var ruin_reason := ""
var fightbacks := 0
var time_elapsed := 0.0
var time_penalty := 0.0
var grade := ""
var grade_score := 0
var plated_portions := 0
var perfect_pops := 0
var served := false
var no_pop := false

func _init(p_species: SpeciesData, p_balance: BalanceData, p_grades: GradeData, p_rng: RandomNumberGenerator) -> void:
	species = p_species
	balance = p_balance
	grades = p_grades
	rng = p_rng

func setup_pearls(rolled: Array[Pearl]) -> void:
	pearls = rolled.duplicate()
	for p in pearls:
		p.pier = species.pier

func can_begin() -> bool:
	return state == State.SPAWNED and stage == Stage.WEDGE

func wedge_begin() -> void:
	if not can_begin():
		return
	wedge_value = 0.0
	wedge_result = Wedge.NONE
	wet_hands = false

func wedge_tick(dt: float) -> void:
	if stage != Stage.WEDGE:
		return
	var speed := balance.wet_hands_meter_speed if wet_hands else 1.0
	var step: InteractionStep = Registry.steps.get("wedge", null)
	var dur := (step.duration if step != null and step.duration > 0.0 else balance.wedge_duration) + species.gesture_time_add
	if dur <= 0.0:
		dur = balance.wedge_duration
	wedge_value += (dt / dur) * speed
	time_elapsed += dt

func wedge_release() -> int:
	if stage != Stage.WEDGE:
		return wedge_result
	if wedge_value > 1.0:
		wedge_result = Wedge.SLIP
		slipped = true
		if not free_slip_available:
			if rng == null or rng.randf() < balance.wedge_slip_nick_chance:
				nicked = true
		else:
			free_slip_available = false
		wedge_value = 0.0
		return wedge_result
	if wedge_value < balance.wedge_none_max:
		wedge_result = Wedge.NONE
		wedge_value = 0.0
		return wedge_result
	var scale := species.meter_window_scale
	var center := (balance.wedge_clean_start + balance.wedge_clean_end) * 0.5
	var half := (balance.wedge_clean_end - balance.wedge_clean_start) * 0.5 * scale
	if wedge_value < center - half:
		wedge_result = Wedge.SNAG
		time_penalty += balance.wedge_snag_time_penalty
	elif wedge_value <= center + half:
		wedge_result = Wedge.CLEAN
		steady = true
	else:
		wedge_result = Wedge.WOBBLE
		wobble = true
	_transition(State.SEATED)
	stage = Stage.POP
	return wedge_result

func pop_begin() -> void:
	if state != State.SEATED or stage != Stage.POP:
		return
	pop_ring = 1.0
	pop_active = true
	pop_result = Pop.NONE

func pop_tick(dt: float) -> void:
	if not pop_active:
		return
	var pop_step: InteractionStep = Registry.steps.get("pop", null)
	var dur := (pop_step.duration if pop_step != null and pop_step.duration > 0.0 else balance.pop_duration) + species.gesture_time_add
	pop_ring -= dt / maxf(dur, 0.01)
	time_elapsed += dt
	if pop_ring <= 0.0:
		pop_ring = 0.0
		pop_active = false
		_pop_fightback()

func pop_click() -> int:
	if not pop_active:
		return pop_result
	pop_active = false
	var r := clampf(pop_ring, 0.0, 1.0)
	if r <= balance.pop_perfect_max:
		pop_result = Pop.PERFECT
		perfect_pops = 1
		_transition(State.OPEN)
		stage = Stage.SLIDE
	elif r <= balance.pop_normal_max:
		pop_result = Pop.NORMAL
		_transition(State.OPEN)
		stage = Stage.SLIDE
	else:
		pop_result = Pop.CRACKED
		cracked = true
		_transition(State.OPEN)
		stage = Stage.SLIDE
	return pop_result

func _pop_fightback() -> void:
	pop_result = Pop.FIGHTBACK
	fightbacks += 1
	_transition(State.SPAWNED)
	stage = Stage.WEDGE
	wedge_value = 0.0
	steady = false
	wobble = false
	time_penalty += balance.pop_fightback_time

func slide_begin() -> void:
	if state != State.OPEN:
		return
	slide_done = false

func tolerance_px(knife_tier: int, tide_mult := 1.0, rash := false) -> float:
	var i := clampi(knife_tier - 1, 0, balance.knife_tolerances.size() - 1)
	var t := balance.knife_tolerances[i]
	# A species tolerance (Dock Blue 8, Razor 14) shifts the whole knife ladder.
	if species.slide_tolerance > 0.0:
		t = species.slide_tolerance + (t - balance.knife_tolerances[0])
	if steady:
		t *= (1.0 + balance.wedge_steady_tolerance_bonus)
	if wobble:
		t *= (1.0 - balance.wedge_wobble_penalty)
	if rash:
		t *= 0.8
	t *= tide_mult
	return maxf(t, 1.0)

func slide_sample(offline_px: float, speed_px_s: float, dt: float, tol: float) -> void:
	if state != State.OPEN or slide_done or shattered or stabbed:
		return
	slide_samples += 1
	slide_max_speed = maxf(slide_max_speed, speed_px_s)
	if absf(offline_px) <= tol:
		slide_inside += 1
	if absf(offline_px) > balance.slide_off_shell:
		_shatter()
		return
	if absf(offline_px) > tol:
		slide_offline += (absf(offline_px) - tol) * dt
	if slide_offline > balance.slide_offline_limit:
		stabbed = true
		juice_loss = true
		slide_done = true

func slide_finish() -> void:
	if state != State.OPEN or slide_done:
		return
	slide_done = true
	var ratio := 0.0
	if slide_samples > 0:
		ratio = float(slide_inside) / float(slide_samples)
	if ratio >= balance.slide_surgical_inside_ratio and slide_max_speed >= balance.slide_hover_speed_ref * balance.slide_surgical_speed_ratio:
		surgical = true

func _shatter() -> void:
	shattered = true
	ruined = true
	ruin_reason = "shattered"
	grade = "F"
	_transition(State.BINNED)

func reseat(over_plate: bool) -> void:
	if state != State.OPEN:
		return
	if over_plate:
		_transition(State.PLATED)
		stage = Stage.DONE
		plated_portions = species.meat_yield
		grade = compute_grade()
	else:
		ruined = true
		ruin_reason = "dropped"
		grade = "F"
		_transition(State.BINNED)

func abandon() -> void:
	if state == State.SERVED or state == State.BINNED:
		return
	ruined = true
	ruin_reason = "abandoned"
	grade = "F"
	_transition(State.BINNED)

func serve() -> bool:
	if state != State.PLATED:
		return false
	served = true
	_transition(State.SERVED)
	return true

func _transition(to: State) -> bool:
	var allowed: Array = TRANSITIONS[state]
	if not allowed.has(to):
		return false
	state = to
	return true

func compute_grade() -> String:
	if ruined:
		grade = "F"
		return grade
	var score := 0
	match wedge_result:
		Wedge.CLEAN:
			score += balance.wedge_bonus_clean
		Wedge.SNAG, Wedge.WOBBLE:
			score += balance.wedge_bonus_imperfect
		Wedge.SLIP:
			score += balance.wedge_bonus_slip
	match pop_result:
		Pop.PERFECT:
			score += balance.pop_bonus_perfect
		Pop.NORMAL:
			score += balance.pop_bonus_normal
		Pop.CRACKED:
			score += 0
	if surgical:
		score += balance.surgical_bonus
	if nicked:
		score -= balance.nick_penalty
	if juice_loss or stabbed:
		score -= (balance.juice_penalty if juice_loss else balance.stab_penalty)
	score += int(species_tier_score_bonus())
	grade_score = score
	var g := GradeLogic.bucket(score, grades)
	if pop_result == Pop.PERFECT:
		g = GradeLogic.raise_to(g, "A")
	if cracked or juice_loss or stabbed:
		g = GradeLogic.cap_at(g, "C")
	if nicked:
		g = GradeLogic.lower(g, 1)
	if shattered:
		g = "F"
	grade = g
	return grade

var knife_tier_bonus := 0
func species_tier_score_bonus() -> int:
	return knife_tier_bonus

func pearl_chance_mult() -> float:
	return 1.0

func value_pearls() -> int:
	var total := 0
	for p in pearls:
		total += p.value
	return total

func has_pearl() -> bool:
	return pearls.size() > 0 and not pearls_forfeited

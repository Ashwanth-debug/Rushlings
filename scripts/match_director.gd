class_name MatchDirector
extends Node

# M3-2 Step 3 - the full approved match-state architecture. See
# docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S03/S11/S12/S13 and S19 Step 3.
#
# SETUP -> UNLOCKING -> OPEN -> RESULTS -> (reset_round) -> SETUP.
# One float clock accumulated in _physics_process(delta) - never frame
# counts - so the whole loop is Engine.time_scale-safe by construction, the
# same way bot timers already are. UNLOCKING is the TAIL of the setup timer,
# not an additional wait: it starts at (setup_duration - unlocking_duration)
# and OPEN fires at setup_duration exactly. OPEN has no timer exit - the
# only way out is collect().
#
# Deliberately NOT here yet (Step 4+): SEEK_RELIC, the OPEN goal switch,
# fairness telemetry.

enum State { SETUP, UNLOCKING, OPEN, RESULTS }

signal state_changed(new_state: int)

@export var setup_duration: float = 10.0
@export var unlocking_duration: float = 2.0

## Approved S03: "a short minimum dwell (~1.2s)" before RESULTS accepts a
## rematch, so a key held at the moment of victory cannot skip the result
## just earned. A timer inside RESULTS, not a fifth state.
const RESULTS_MIN_DWELL := 1.2

var state: int = State.SETUP
var clock: float = 0.0
var winner_slot_id: int = -1
var results_dwell: float = 0.0

## M4-1 dev-only Contact Lab mode (CLAUDE.md M4-1 S11): the accepted M3 match
## resolves in ~10s, far too fast for pickup/power interaction to actually
## occur. Rather than changing setup_duration itself (which would touch the
## accepted M3 match), Contact Lab simply freezes the SETUP clock forever -
## the vault stays sealed (no Relic/extraction change, per M4-1 scope), and
## players/bots keep roaming and using powers indefinitely. Toggled from
## arena_01.gd's debug_contact_lab key.
var contact_lab: bool = false

func enter_contact_lab() -> void:
	reset_round()
	contact_lab = true

func exit_contact_lab() -> void:
	contact_lab = false
	reset_round()

func _physics_process(delta: float) -> void:
	if contact_lab:
		return
	match state:
		State.SETUP, State.UNLOCKING:
			clock += delta
			var unlocking_start := _unlocking_start()
			if state == State.SETUP and clock >= unlocking_start:
				_set_state(State.UNLOCKING)
			if clock >= setup_duration and state != State.OPEN:
				_set_state(State.OPEN)
		State.RESULTS:
			results_dwell += delta
		State.OPEN:
			pass  # OPEN's only exit is collect() - no timer

## Called by Relic (scripts/relic.gd) exactly once, when a body wins.
## Approved S11 "poll, do not listen": Relic itself resolves the same-frame
## tie (closest to centre, then lowest slot_id) and calls this only once it
## has a single winner. Ignored outside OPEN - defence in depth alongside
## Relic's own `_collected` guard, so a stray second call can never re-fire.
func collect(slot_id: int) -> void:
	if state != State.OPEN:
		return
	winner_slot_id = slot_id
	results_dwell = 0.0
	_set_state(State.RESULTS)

## RESULTS ignores rematch input until this returns true.
func rematch_ready() -> bool:
	return state == State.RESULTS and results_dwell >= RESULTS_MIN_DWELL

func _unlocking_start() -> float:
	return max(0.0, setup_duration - unlocking_duration)

func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)

## 0 at the start of UNLOCKING, 1 at OPEN - the bar-lift animation's only
## input. Delta-driven via `clock`, so it is Engine.time_scale-safe like
## everything else here.
func unlocking_progress() -> float:
	if unlocking_duration <= 0.0:
		return 1.0
	return clamp((clock - _unlocking_start()) / unlocking_duration, 0.0, 1.0)

## Seconds left before OPEN, floored at 0. Used by the match HUD during both
## SETUP and UNLOCKING - the tail of the same countdown, not a second timer.
func time_remaining_in_setup() -> float:
	return max(0.0, setup_duration - clock)

## A function, not a state (docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S03).
## Not wired to a win condition yet in Step 2 - exists now so the debug
## duration keys and the debug gate-force key have one correct place to
## return to SETUP through, rather than each hand-rolling their own reset.
func reset_round(new_setup_duration: float = -1.0) -> void:
	if new_setup_duration > 0.0:
		setup_duration = new_setup_duration
	clock = 0.0
	winner_slot_id = -1
	results_dwell = 0.0
	_set_state(State.SETUP)

## Dev-only (STOP 2 inspection, debug_toggle_gate / G): jump straight to OPEN
## without waiting for the timer. Still goes through _set_state, so
## MatchDirector's state remains authoritative and nothing downstream (the
## gate, the HUD, the nav graph) can tell this apart from the timer actually
## having elapsed.
func debug_force_open() -> void:
	clock = setup_duration
	_set_state(State.OPEN)

## Dev-only (STOP 2 inspection, debug_toggle_gate / G): back to a fresh
## SETUP, e.g. to re-inspect CLOSED after forcing OPEN. Just reset_round()
## under a clearer name at the call site.
func debug_force_setup() -> void:
	reset_round()

extends Label

# M3-2 Step 2/3 - the match state readout. Deliberately separate from
# DebugLabel (scripts/debug_hud.gd), which stays the M1/M2 movement debug
# readout - see docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S15. Greybox only:
# no typography/animation polish, legibility only.

const OPEN_HOLD := 1.0  # seconds "OPEN" stays on screen before clearing

@export var director_path: NodePath
var _director: MatchDirector
var _open_elapsed := 0.0

func _ready() -> void:
	_director = get_node(director_path)
	_director.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: int) -> void:
	if new_state == MatchDirector.State.OPEN:
		_open_elapsed = 0.0

func _process(delta: float) -> void:
	if _director == null:
		return
	match _director.state:
		MatchDirector.State.SETUP:
			text = "RELIC SEALED · %d" % ceili(_director.time_remaining_in_setup())
		MatchDirector.State.UNLOCKING:
			text = "OPENING · %d" % ceili(_director.time_remaining_in_setup())
		MatchDirector.State.OPEN:
			_open_elapsed += delta
			text = "OPEN" if _open_elapsed < OPEN_HOLD else ""
		MatchDirector.State.RESULTS:
			text = "P%d WINS\n[R] REMATCH" % _director.winner_slot_id

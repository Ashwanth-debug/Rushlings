extends Area2D

# M3-2 Step 3 - collection + deterministic winner resolution. See
# docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S10/S11.
#
# Approved "poll, do not listen": winner resolution does NOT use
# body_entered - signal emission order across simultaneous overlaps is an
# engine detail, not a rule that can be stated. Instead, once per physics
# frame while MatchDirector.state == OPEN, poll get_overlapping_bodies() and
# resolve:
#   1 candidate  -> that player wins
#   several      -> closest to the Relic's centre x wins
#   exact tie    -> lowest slot_id
#
# `monitoring` stays permanently TRUE, deliberately NOT toggled off during
# SETUP/UNLOCKING/after collection. That was the original design (matching
# the plan's own "monitoring=false until OPEN" text) and it is wrong:
# toggling Area2D.monitoring off while a body is inside, then back on once
# that body has moved away, does not reliably fire the missed body_exited -
# Godot can keep reporting a body as "overlapping" from before monitoring
# was disabled, even many physics frames after it has genuinely left. This
# was caught by the rematch test: round 2 credited round 1's winner (still
# stale-"overlapping" from the moment collection disabled monitoring) even
# though that body had since been moved far away for round 2. The state/
# _collected guard below is sufficient on its own - the vault is physically
# sealed by scripts/relic_gate.gd for the entire SETUP/UNLOCKING duration
# regardless, so an Area2D that is always monitoring never has anything to
# report until OPEN in practice anyway.

@onready var _director: MatchDirector = get_parent().get_node("MatchDirector")

var _collected := false

func _ready() -> void:
	# Players live on collision layer 2 only, since the M3-1 collision fix
	# (player.gd) - this Area2D's default mask (layer 1) would otherwise
	# never detect anybody. Same workaround as traversal_zone.gd/launch_pad.gd.
	set_collision_mask_value(2, true)
	monitoring = true
	_director.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: int) -> void:
	if new_state == MatchDirector.State.SETUP:
		_collected = false

func _physics_process(_delta: float) -> void:
	if _collected or _director.state != MatchDirector.State.OPEN:
		return
	var winner: CharacterBody2D = null
	var winner_dist := INF
	for body in get_overlapping_bodies():
		if not (body is CharacterBody2D) or not ("slot_id" in body):
			continue
		var d: float = abs(body.global_position.x - global_position.x)
		if winner == null or d < winner_dist - 0.001 or (abs(d - winner_dist) <= 0.001 and body.slot_id < winner.slot_id):
			winner = body
			winner_dist = d
	if winner == null:
		return
	_collected = true
	_director.collect(winner.slot_id)

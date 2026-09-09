class_name EdgeExecutor
extends RefCounted

# Runs one nav-graph edge to completion using only the three intent signals
# player.gd already reads from any controller - no teleports, no position
# writes, no physics exemptions. The recipes are not invented: they are
# tools/arena_check.gd's already-proven route primitives
# (_run_and_jump_near_edge, _drop_to_band_c, the ladder-climb blocks,
# _route_launcher's 12-tick steering delay) re-shaped from await coroutines
# into a per-frame tick() a bot can call from _physics_process.

enum Status { RUNNING, SUCCESS, FAILED }

var body: CharacterBody2D
var geometry: ArenaGeometry
var edge: Dictionary
var elapsed: float = 0.0
var timeout: float
var phase: String = ""
var _delay_ticks: int = 0
var _stuck_timer: float = 0.0
var _unstick_attempts: int = 0
var _climb_start_y: float = NAN

# Bounded retry budget (Director feedback after A1/A2: a bot must never
# indefinitely spam Jump against the same obstacle). Centralised here so the
# threshold stays a single tunable constant rather than a magic number
# scattered across every phase that calls _walk_with_unstick.
const MAX_UNSTICK_ATTEMPTS := 2

var horizontal_intent: float = 0.0
var vertical_intent: float = 0.0
var jump_flag: bool = false

# Executor-local, never written back onto `edge` - the same edge Dictionary
# is shared by every bot that ever takes this edge (it lives once in
# NavGraph.edges), so two bots mid-traversal of the same edge at once would
# corrupt each other's direction if this were stored on the shared dict.
var _dir: int = 0
var _preserve_air_velocity: bool = false

# Whether this edge's geometry actually exists in the LIVE scene right now,
# checked once here rather than trusting NavGraph's static node/edge list.
# Root cause of a real crash (Director report): NavGraph's node list is
# hand-authored and has no way to know a scene edit removed a platform - a
# deleted CoverW still has "CoverW" edges in the graph, ArenaGeometry's
# aabb() then quietly returns {} for it (geom.get(name, {}) - a valid empty
# Dictionary, not null, so nothing upstream noticed anything was wrong)
# instead of erroring, and _advance_jump's later `to_aabb.center` access on
# that {} was the actual crash: "Invalid access to property or key 'center'
# on a base object of type 'Dictionary'." A scene geometry edit can leave
# stale navigation metadata like this at either end of an edge, or on its
# ladder/pad reference - this executor must never assume any of it is
# still real.
var _valid: bool = true

func _init(p_body: CharacterBody2D, p_geometry: ArenaGeometry, p_edge: Dictionary) -> void:
	body = p_body
	geometry = p_geometry
	edge = p_edge
	timeout = float(edge.get("timeout", 5.0))
	_valid = _validate_geometry()
	match edge.type:
		"jump":
			phase = "walk"
		"drop":
			phase = "walk"
		"walk":
			phase = "walk"
		"ladder":
			phase = "approach"
		"launch":
			phase = "approach"

func _validate_geometry() -> bool:
	match edge.type:
		"jump", "drop", "walk":
			if not geometry.has(edge.from):
				push_warning("EdgeExecutor: edge.from '%s' has no live geometry - rejecting edge %s->%s" % [edge.from, edge.from, edge.to])
				return false
			if not geometry.has(edge.to):
				push_warning("EdgeExecutor: edge.to '%s' has no live geometry - rejecting edge %s->%s" % [edge.to, edge.from, edge.to])
				return false
		"ladder":
			if not geometry.ladders.has(edge.get("ladder", "")):
				push_warning("EdgeExecutor: ladder '%s' has no live geometry - rejecting edge %s->%s" % [edge.get("ladder", ""), edge.from, edge.to])
				return false
		"launch":
			if not geometry.pads.has(edge.get("pad", "")):
				push_warning("EdgeExecutor: pad '%s' has no live geometry - rejecting edge %s->%s" % [edge.get("pad", ""), edge.from, edge.to])
				return false
	return true

func tick(delta: float) -> Status:
	elapsed += delta
	horizontal_intent = 0.0
	vertical_intent = 0.0
	jump_flag = false
	if not _valid:
		return Status.FAILED
	if elapsed > timeout:
		return Status.FAILED
	match edge.type:
		"jump":
			if edge.get("vertical_clear", false):
				return _advance_vertical_clear_jump(delta)
			if edge.get("fixed_trigger", false):
				return _advance_fixed_trigger_jump(delta)
			return _advance_jump(delta)
		"drop":
			return _advance_drop(delta)
		"walk":
			return _advance_walk(delta)
		"ladder":
			return _advance_ladder(delta)
		"launch":
			return _advance_launch(delta)
	return Status.FAILED

# --- walk: two platforms at the same height with touching/overlapping x
# ranges and no solid wall between them (e.g. A_W <-> A_W_Bridge) - ordinary
# ground walking carries the body across with no jump at all. Using the jump
# recipe here would launch a body far past a narrow connector platform,
# since deceleration is floor-only and a jump's flight time is fixed - only
# takeoff speed controls how far it travels, and a full-speed takeoff
# overshoots badly on a short hop.
func _advance_walk(delta: float) -> Status:
	var to_aabb: Dictionary = geometry.aabb(edge.to)
	var diff: float = geometry.shortest_diff(to_aabb.center.x, body.global_position.x)
	if geometry.on_platform_like(body, edge.to):
		return Status.SUCCESS
	if _walk_with_unstick(1 if diff >= 0.0 else -1, delta):
		return Status.FAILED
	return Status.RUNNING

func _landed_on_target() -> bool:
	return geometry.on_platform_like(body, edge.to)

# Same ballistic model as tools/arena_check.gd's _jump_arc: rise>0 means the
# target is higher (dy<0, ascending arrival, first height crossing); rise<=0
# uses the second (falling) crossing. Read straight from the body's own
# exported constants so this can never drift from what actually ships.
func _jump_arc_time(rise: float) -> float:
	var vy0: float = -body.jump_strength
	var dy: float = -rise
	var disc: float = vy0 * vy0 + 2.0 * body.gravity * dy
	if disc < 0.0:
		return -1.0
	if dy < 0.0:
		return (-vy0 - sqrt(disc)) / body.gravity
	return (-vy0 + sqrt(disc)) / body.gravity

# Some platforms (CoverE) are solid blocks sitting directly on the
# Floor, not thin elevated slabs - walking toward a point past one hits its
# wall and stalls forever. A real player would just hop over it. Detect a
# wall stall (holding a direction, grounded, but not actually moving) and
# jump - since every solid obstacle in Arena 01 is within normal jump range,
# this generically un-sticks any walk phase without needing to know the
# arena's specific obstacle layout.
#
# Bounded: after MAX_UNSTICK_ATTEMPTS failed un-stick jumps against the same
# obstacle, this returns true ("give up") instead of jumping again. A bot
# must never indefinitely spam Jump against the same wall - the caller is
# expected to return Status.FAILED immediately when this returns true,
# rather than waiting out the edge's full timeout.
func _walk_with_unstick(dir: int, delta: float) -> bool:
	horizontal_intent = dir
	if body.is_on_floor() and abs(body.velocity.x) < 15.0:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
	if _stuck_timer > 0.25 and body.is_on_floor():
		_stuck_timer = 0.0
		_unstick_attempts += 1
		if _unstick_attempts > MAX_UNSTICK_ATTEMPTS:
			return true
		jump_flag = true
	return false

# A creep phase (drop's low-speed departure, jump's short walk to an
# overlap midpoint) deliberately never jumps, so it cannot use
# _walk_with_unstick's own giveup - but it must not be able to stall for a
# full edge timeout either if something (a corner, a wedge) stops it dead.
# A generous timeout, since creeping is intentionally slow.
const CREEP_STALL_TIMEOUT := 1.5
var _creep_stall_timer: float = 0.0

func _check_creep_stall(delta: float) -> bool:
	if body.is_on_floor() and abs(body.velocity.x) < 10.0:
		_creep_stall_timer += delta
	else:
		_creep_stall_timer = 0.0
	return _creep_stall_timer > CREEP_STALL_TIMEOUT

# --- jump: covers both R1 "step_up" (overlapping columns) and R2 "jump_gap"
# (a genuine gap). These need different takeoff points, not just different
# distances:
#  - If the target overlaps `from` in x AND there is real clearance beneath
#    it (e.g. Floor -> C_W, a thin slab with open air underneath), the
#    takeoff point is the middle of the overlap - anywhere under it works.
#  - Otherwise (a genuine gap, OR an overlapping target with NO clearance,
#    like CoverW/CoverE - solid blocks flush with the Floor, not standable
#    underneath) the takeoff point is the target's own near edge, clamped to
#    what `from` can actually stand on - walking towards a point past your
#    own platform's edge would walk off it instead of arriving anywhere.
const BLOCK_STANDOFF := 85.0
# Absolute last-resort floor - fires the jump regardless of speed reached, so
# a short hop whose entire runway is smaller than BLOCK_STANDOFF still gets
# some walking distance instead of jumping in place, but never actually
# collides with the wall it's approaching.
const WALL_SAFETY_MARGIN := 20.0
const CLEARANCE_SAFETY_MARGIN := 40.0

func _advance_jump(delta: float) -> Status:
	var from_aabb: Dictionary = geometry.aabb(edge.from)
	var to_aabb: Dictionary = geometry.aabb(edge.to)
	match phase:
		"walk":
			# An earlier "walkable underneath" special case tried to jump
			# straight up from the middle of the from/to overlap whenever
			# there was headroom to stand underneath `to` (e.g. Floor under
			# C_M). That can never actually work: standing room underneath a
			# solid platform says nothing about being able to pass THROUGH
			# it - any point within the overlap has `to`'s solid underside
			# directly above it, so a vertical hop always clips that
			# underside and falls back down (confirmed regression: Floor ->
			# C_M repeatedly hit C_M's own underside regardless of takeoff
			# position or speed tuning). Landing on top of a solid platform
			# only ever works by launching from just outside its edge and
			# arcing up and across onto it - exactly the flush-wall model
			# below already does correctly for CoverE/VaultEast (CoverW was
			# removed from Arena 01, see docs/DECISIONS.md), and it applies
			# here too without any special-casing.
			var diff: float = geometry.shortest_diff(to_aabb.center.x, body.global_position.x)
			_dir = 1 if diff >= 0.0 else -1
			var to_near_edge: float = to_aabb.left if _dir > 0 else to_aabb.right
			var from_far_edge: float = from_aabb.right if _dir > 0 else from_aabb.left
			# A genuine physical gap - `from`'s own standable surface ends
			# before ever reaching anywhere near `to`'s wall (e.g. C_W -> C_M,
			# ~160px of open air between them) - is a completely different
			# situation from a flush wall (CoverE/VaultEast sitting right
			# on/against `from`'s own surface). Walking toward
			# `to_near_edge` in the gap case ran the body straight off the
			# edge of its OWN platform before ever reaching that point,
			# turning into an uncontrolled fall that landed somewhere else
			# entirely (confirmed regression: C_W -> C_M fell all the way to
			# Floor and re-launched from there, onto a completely different
			# target). A true gap must launch from `from`'s own edge, at
			# whatever speed was built crossing it, with ordinary continued
			# air acceleration - there is no wall to scrape, so none of the
			# standoff/creep tuning below applies or is correct here.
			var is_true_gap: bool = (_dir > 0 and from_far_edge < to_near_edge) or (_dir < 0 and from_far_edge > to_near_edge)
			if is_true_gap:
				var takeoff_edge: float = from_far_edge - (8.0 * _dir)
				var dist_to_edge: float = abs(geometry.shortest_diff(takeoff_edge, body.global_position.x))
				if dist_to_edge <= 4.0:
					horizontal_intent = _dir
					if body.is_on_floor():
						phase = "jump"
					return Status.RUNNING
				if _walk_with_unstick(_dir, delta):
					return Status.FAILED
				return Status.RUNNING
			# A target with no clearance underneath (CoverE, VaultEast) is a
			# genuine solid wall flush with `from`'s surface,
			# not just a distant ledge - taking off flush against it makes
			# the ascent scrape straight up its face (move_and_slide zeroes
			# the horizontal velocity on contact) instead of arcing onto its
			# top (confirmed: the body's origin needs to clear the wall's
			# TOP HEIGHT before its leading edge crosses the wall's x
			# boundary, or it clips the side/underside instead of landing).
			# A FIXED standoff (walk toward the wall, then require BOTH
			# "close enough" and "at max_speed" before jumping) cannot work
			# in general: on a short approach, "at max_speed" is reached
			# later than "close enough", so the ACTUAL trigger point ends up
			# governed purely by acceleration distance from a stop, not by
			# how much runway the rise actually needs - confirmed regression:
			# Floor -> C_M's 120px available approach is less than the
			# ~104px pure acceleration-to-max-speed distance leaves as
			# remaining runway, so it launched with only ~74px left of the
			# ~104px a 140px rise needs, and clipped C_M's side. The fix
			# tracks a continuously shrinking safe-speed ceiling instead
			# (bang-bang creep, same pattern as the drop executor): the
			# fastest speed that still clears the wall's height using
			# whatever distance is left RIGHT NOW. Freely accelerating until
			# hitting that ceiling and jumping the instant it's reached self-
			# adjusts to whatever runway is actually available, whether
			# that's enough to reach max_speed or not.
			var rise: float = from_aabb.top - to_aabb.top
			var arc_t: float = _jump_arc_time(rise)
			var needs_clearance: bool = arc_t > 0.0
			var dist_to_wall: float = abs(geometry.shortest_diff(to_near_edge, body.global_position.x))
			var should_jump: bool = dist_to_wall <= WALL_SAFETY_MARGIN
			if needs_clearance and not should_jump:
				# For an ASCENDING target, arc_t is the time to first climb
				# high enough (the ascending height crossing) - the real
				# landing only happens much later, on the descending
				# crossing, well past the target's own peak (a fixed ~184px
				# above launch, set purely by jump_strength/gravity). A
				# locked takeoff speed that is merely "fast enough" for arc_t
				# clears the wall fine but keeps travelling at that same
				# speed (no air deceleration in M1 movement - friction is
				# floor-only) for several times longer before an actual
				# landing opportunity exists, easily overshooting a normal-
				# width target. Rather than chase a second, separate speed
				# ceiling for landing accuracy (tried, and fragile - see the
				# M3-1 report's VaultEast section), the target platform
				# itself is now sized generously enough that any speed this
				# formula can produce still lands on it.
				var safe_speed: float = clamp((dist_to_wall - CLEARANCE_SAFETY_MARGIN) / arc_t, 60.0, body.max_speed)
				# TWO ticks of acceleration still land on top of whatever
				# velocity trips this check, not one - the walk phase's own
				# transition tick (still "walk", holds _dir to dodge floor
				# friction) AND the following "jump" phase tick (also holds
				# _dir, same reason) both run before _preserve_air_velocity
				# actually takes over in the "air" phase. Confirmed
				# regression: compensating for only one tick left the locked
				# takeoff speed (and therefore the whole-flight landing
				# distance, since there is no air deceleration in M1
				# movement - friction is floor-only) still measurably higher
				# than intended, overshooting a normal-width landing target.
				should_jump = abs(body.velocity.x) >= safe_speed - (2.0 * body.acceleration / 60.0)
			if should_jump:
				# Hold direction on this exact transition tick too - leaving
				# horizontal_intent at tick()'s reset value of 0 here (as an
				# earlier version of this code did) costs one tick of floor
				# friction (3500/s) right before takeoff, silently bleeding
				# speed off the carefully-creeped takeoff velocity.
				horizontal_intent = _dir
				if body.is_on_floor():
					_preserve_air_velocity = needs_clearance
					phase = "jump"
				return Status.RUNNING
			if _walk_with_unstick(_dir, delta):
				return Status.FAILED
			return Status.RUNNING
		"jump":
			# is_on_floor() is still stale-true for this exact tick (the jump
			# impulse and move_and_slide haven't run yet), so player.gd would
			# apply a full FRICTION tick (3500/s, not acceleration's 3000/s)
			# if horizontal_intent were 0 here - a much larger loss than the
			# small accel-toward-max_speed nudge (~50/s) that holding _dir
			# risks for an already-at-target-speed narrow jump. Always hold
			# here; _preserve_air_velocity only matters once truly airborne
			# (the "air" phase below), where that one-tick friction risk no
			# longer applies but continued multi-tick acceleration would.
			horizontal_intent = _dir
			jump_flag = true
			phase = "air"
			return Status.RUNNING
		"air":
			# Holding intent through the whole flight keeps ACCELERATING
			# (deceleration is floor-only, but acceleration toward the held
			# direction applies in the air too) - fine for a genuine gap
			# jump approached at full speed already, but it silently adds
			# extra distance beyond a deliberately-calculated below-max
			# takeoff speed (see the adaptive trigger above), which is
			# exactly what overshot VaultEast after the takeoff-speed fix.
			# Releasing intent instead holds velocity exactly at whatever
			# it was at takeoff for the whole arc.
			horizontal_intent = 0.0 if _preserve_air_velocity else float(_dir)
			if body.is_on_floor():
				return Status.SUCCESS if _landed_on_target() else Status.FAILED
			return Status.RUNNING
	return Status.FAILED

# --- vertical-clear jump: a locally-scoped alternate recipe, used ONLY for
# edges explicitly tagged {"vertical_clear": true} (currently
# VaultFloor->VaultEast and VaultEast->A_E - see nav_graph.gd). Reproduces
# the human technique captured via the dev-only traversal recorder
# (Director investigation, 2026-09-08), consistent across two independent
# full demonstrations: walk toward the obstacle, release horizontal, jump
# with ZERO horizontal hold (no attempt to avoid wall contact, unlike
# _advance_jump's adaptive safe-speed model - going straight up beside the
# wall sidesteps the clearance problem instead of timing around it), hold
# zero horizontal all the way to the apex, and only then steer toward the
# target. Does not touch _advance_jump or any other edge's behaviour.
const VERTICAL_CLEAR_APEX_VY := -50.0

func _advance_vertical_clear_jump(delta: float) -> Status:
	var to_aabb: Dictionary = geometry.aabb(edge.to)
	match phase:
		"walk":
			var diff: float = geometry.shortest_diff(to_aabb.center.x, body.global_position.x)
			_dir = 1 if diff >= 0.0 else -1
			var to_near_edge: float = to_aabb.left if _dir > 0 else to_aabb.right
			var dist: float = abs(geometry.shortest_diff(to_near_edge, body.global_position.x))
			if dist <= WALL_SAFETY_MARGIN:
				horizontal_intent = 0.0
				if body.is_on_floor():
					phase = "jump"
				return Status.RUNNING
			horizontal_intent = _dir
			if body.is_on_floor() and abs(body.velocity.x) < 15.0:
				_stuck_timer += delta
			else:
				_stuck_timer = 0.0
			# No unstick-jump here, deliberately - being blocked/stopped by
			# the wall this edge is walking toward is the expected, correct
			# approach state for this recipe, not a stall to escape from.
			return Status.RUNNING
		"jump":
			horizontal_intent = 0.0
			jump_flag = true
			phase = "rise"
			return Status.RUNNING
		"rise":
			horizontal_intent = 0.0
			if body.velocity.y >= VERTICAL_CLEAR_APEX_VY:
				phase = "steer"
			return Status.RUNNING
		"steer":
			horizontal_intent = _dir
			if body.is_on_floor():
				return Status.SUCCESS if _landed_on_target() else Status.FAILED
			return Status.RUNNING
	return Status.FAILED

# --- fixed-trigger ascending jump: a locally-scoped alternate recipe, used
# ONLY for edges explicitly tagged {"fixed_trigger": true} (currently
# Floor->C_M - see nav_graph.gd). Traversal audit fix (smallest
# implementation plan, step 03 / Floor->C_M follow-up): _advance_jump's
# "walk" phase computes an adaptive `safe_speed` ceiling that SHRINKS as the
# body gets closer to the wall (derived to avoid overshooting a narrow
# landing on a genuine gap). For an ASCENDING target with clearance
# underneath, that is backwards - the binding constraint is how much ground
# the body can cover before the fixed ascending-crossing time
# (jump_arc_time(rise), which the target's height and jump_strength/gravity
# alone determine, independent of takeoff speed), and less distance means
# LESS time available, so it needs MORE speed, not less. The old rule let a
# body trigger right up against the wall at a slow, shrunken speed and clip
# it every time (audit-confirmed: Floor->C_M passed only 1/5 spread
# positions).
#
# The fix, per the audit's own model (validated 5/5 across trigger
# distances 60-100px): approach at full speed, and take off from a FIXED
# distance window before the wall rather than letting the wall itself set
# the trigger. Both the window and the required approach speed are edge
# metadata, not hardcoded here - only Floor->C_M's own entry in
# nav_graph.gd sets them, so this generalises to any future
# fixed-trigger edge without a code change.
const FIXED_TRIGGER_FAR_DEFAULT := 100.0
const FIXED_TRIGGER_NEAR_DEFAULT := 60.0
const FIXED_TRIGGER_MIN_SPEED_FRAC_DEFAULT := 0.9

# Director directive (2026-09-08, reposition/build-runway fix): a 5-minute
# soak test proved Floor->C_M's remaining failure mode once it became the
# ONLY reliable way up from Floor - the OLD rule below jumped anyway once
# the body crossed inside trigger_near, even with no real approach speed,
# "rather than walk into the wall". That is exactly backwards for a body
# that starts (or is retried) already inside/near the window: a slow-speed
# jump clips C_M's underside, the body falls back to ~the same spot, and
# the very next retry starts from the identical bad position - a
# self-reinforcing loop with no exit, confirmed live (slot 4: 0 arrivals,
# ~83 stall events, permanently parked near CoverE for the length of a
# 90s run). Removing the fallback without replacing it would just turn
# that same case into an outright immediate FAILED every time.
#
# The fix mirrors the human technique already recorded on this exact edge
# family (2026-09-08 traversal recorder sessions): when badly positioned
# for a jump, back off and build a real runway rather than jumping from
# where you happen to be. REPOSITION walks AWAY from the target (-_dir)
# until there is provably enough room to reach the required approach speed
# before re-entering the window, then hands back to "walk" to re-approach
# normally - the exact same recipe every other start position already
# uses successfully. The runway distance is derived entirely from this
# edge's own trigger_far/min_speed_frac and the body's own acceleration/
# max_speed (kinematic d = v^2/(2a) to reach min_speed from rest, plus a
# fixed safety margin) - never a hardcoded coordinate, so this generalises
# to any future fixed_trigger edge exactly like the window itself does.
const FIXED_TRIGGER_REPOSITION_MARGIN := 40.0
const FIXED_TRIGGER_REPOSITION_TIMEOUT := 3.0
const FIXED_TRIGGER_MAX_REPOSITION_ATTEMPTS := 2
# How long the body may sit near-motionless while "walk" holds an intent
# before treating it as physically blocked rather than merely accelerating -
# matches _walk_with_unstick's own 0.25s stall threshold elsewhere in this
# file, for the same reason: a couple of physics ticks of low speed off a
# standing start is normal, a quarter-second of it is not.
const FIXED_TRIGGER_WALK_STALL_TIME := 0.25

var _reposition_attempts: int = 0
var _reposition_target_dist: float = 0.0
var _reposition_elapsed: float = 0.0
var _walk_stall_timer: float = 0.0

func _advance_fixed_trigger_jump(delta: float) -> Status:
	var to_aabb: Dictionary = geometry.aabb(edge.to)
	var trigger_far: float = float(edge.get("trigger_far", FIXED_TRIGGER_FAR_DEFAULT))
	var trigger_near: float = float(edge.get("trigger_near", FIXED_TRIGGER_NEAR_DEFAULT))
	var min_speed: float = body.max_speed * float(edge.get("min_speed_frac", FIXED_TRIGGER_MIN_SPEED_FRAC_DEFAULT))
	match phase:
		"walk":
			# Approach side is read from the body's CURRENT position each
			# time this recipe starts (not the target's centre alone),
			# exactly like every other jump/drop recipe's `_dir` latch -
			# whichever side of the target the body is currently on is the
			# side it approaches from. Latched once so it cannot oscillate.
			if _dir == 0:
				var diff: float = geometry.shortest_diff(to_aabb.center.x, body.global_position.x)
				_dir = 1 if diff >= 0.0 else -1
			var near_edge: float = to_aabb.left if _dir > 0 else to_aabb.right
			var dist_to_wall: float = abs(geometry.shortest_diff(near_edge, body.global_position.x))
			# Direction-aware, not just magnitude: a body already moving
			# fast in the WRONG direction (e.g. carried backwards by a
			# previous correction) must not read as "speed ok" just because
			# abs(velocity) is high - confirmed necessary for the
			# inside-window-wrong-direction-velocity test case.
			var velocity_toward: float = body.velocity.x * _dir
			var speed_ok: bool = velocity_toward >= min_speed
			# Has the body already crossed near_edge, in the direction of
			# travel? Positive while still correctly approaching (has not
			# reached near_edge yet); negative once past it. Multi-position
			# testing found a second, distinct unsafe case beyond the
			# original "too close, not enough speed" one: a position ALREADY
			# past near_edge (e.g. carried there by momentum, or a residual
			# velocity from something else entirely) can satisfy
			# dist_to_wall<=trigger_far and speed_ok on the very first tick
			# and jump immediately - with no walk-phase ticks in between for
			# the stall/obstruction check above to ever run. Both the east
			# and west "already past the edge" test positions land the body
			# on CoverE (confirmed: the ascent from there has far less
			# clearance height than the same trigger distance measured on
			# the correct/not-yet-crossed side, since CoverE sits inside
			# C_M's own span - the two are not symmetric). A body can only
			# reach this crossed state by starting there already or via
			# residual velocity from an unrelated prior state - never by
			# this recipe's own walk phase, which always jumps at the
			# farthest qualifying point before ever crossing near_edge.
			var signed_progress: float = geometry.shortest_diff(near_edge, body.global_position.x) * _dir
			if dist_to_wall <= trigger_far and speed_ok and signed_progress >= 0.0:
				horizontal_intent = _dir
				if body.is_on_floor():
					phase = "jump"
				return Status.RUNNING
			# Stall/obstruction check (soak-test finding, 2026-09-08): the
			# ORIGINAL diagnosis for the trigger_near case assumed the only
			# failure mode was "too little runway left to reach speed in
			# time" - true in general, but the actual reproduced Slot 4
			# trace showed a DIFFERENT concrete cause at this exact
			# real-world bad-start range (x~1345-1358, approaching C_M's
			# east side): the body never even reaches trigger_near (60px) -
			# it walks straight into CoverE's solid face (which sits
			# entirely inside C_M's own footprint) and sticks there at
			# dist_to_wall~90px, forever short of the distance check, for
			# the rest of the edge's timeout. Held intent producing no real
			# velocity for a sustained stretch is exactly the same physical
			# signal edge_executor.gd already uses elsewhere
			# (_walk_with_unstick) to detect a blocked path - reused here as
			# a second, independent trigger into REPOSITION alongside the
			# distance-based one, since jumping over the obstruction here
			# risks clipping C_M's underside from directly beneath it (the
			# same reason Floor->CoverE is skill-tagged), so an unstick-jump
			# is not a safe answer on this specific edge.
			if body.is_on_floor() and abs(body.velocity.x) < 15.0:
				_walk_stall_timer += delta
			else:
				_walk_stall_timer = 0.0
			var blocked: bool = _walk_stall_timer > FIXED_TRIGGER_WALK_STALL_TIME
			if dist_to_wall <= trigger_near or blocked or signed_progress < 0.0:
				# Too close/inside the window without the required approach
				# speed, or physically unable to make progress toward it at
				# all. The old rule jumped anyway once inside trigger_near -
				# "the unsafe fallback" - which is the confirmed root cause
				# of the original self-reinforcing failure loop. A RELIABLE
				# road must not knowingly execute a jump when its own
				# takeoff requirement is false (or unreachable), so this
				# backs off and builds a runway instead - the human
				# technique already recorded for this edge family.
				if _reposition_attempts >= FIXED_TRIGGER_MAX_REPOSITION_ATTEMPTS:
					return Status.FAILED
				_reposition_attempts += 1
				var runway: float = (min_speed * min_speed) / (2.0 * body.acceleration)
				_reposition_target_dist = trigger_far + runway + FIXED_TRIGGER_REPOSITION_MARGIN
				_reposition_elapsed = 0.0
				_walk_stall_timer = 0.0
				phase = "reposition"
				horizontal_intent = -_dir
				return Status.RUNNING
			horizontal_intent = _dir
			return Status.RUNNING
		"reposition":
			_reposition_elapsed += delta
			var near_edge2: float = to_aabb.left if _dir > 0 else to_aabb.right
			var dist_to_wall2: float = abs(geometry.shortest_diff(near_edge2, body.global_position.x))
			# Enough clearance re-established - hand back to "walk", which
			# re-approaches and accelerates exactly like a fresh far start
			# already does (proven 5/5 for well-left/well-right positions,
			# and this exact re-approach segment - from beyond the far
			# trigger boundary down to the takeoff window - is precisely
			# what those already-passing tests exercise).
			if dist_to_wall2 >= _reposition_target_dist:
				phase = "walk"
				return Status.RUNNING
			if _reposition_elapsed >= FIXED_TRIGGER_REPOSITION_TIMEOUT:
				# Bounded: never back off indefinitely (e.g. a runway that
				# cannot physically be built from where this edge started).
				return Status.FAILED
			horizontal_intent = -_dir
			return Status.RUNNING
		"jump":
			# Same reasoning as _advance_jump's "jump" phase: is_on_floor()
			# is still stale-true this exact tick, so holding _dir here
			# avoids one tick of floor friction (3500/s) bleeding off the
			# carefully-built takeoff speed right before liftoff.
			horizontal_intent = _dir
			jump_flag = true
			phase = "air"
			return Status.RUNNING
		"air":
			# Hold direction through the whole ascent/landing, same as a
			# genuine-gap jump: this is accepted M1 physics doing the work
			# (continued acceleration in the air, and move_and_slide's
			# ordinary contact handling if the body's leading edge is still
			# short of the wall at any point) rather than a special
			# collision-avoidance exemption for this recipe.
			horizontal_intent = _dir
			if body.is_on_floor():
				return Status.SUCCESS if _landed_on_target() else Status.FAILED
			return Status.RUNNING
	return Status.FAILED

# --- drop: a real player walks off a ledge slowly, not at a dead sprint.
# Deceleration is floor-only (player.gd), so any horizontal speed still
# carried at the moment the origin leaves the platform survives untouched
# through the whole fall - a full-speed approach drifts ~240px on a ~260px
# drop, easily overshooting a narrow target below. Once close enough to
# depart, this creeps at a low speed cap (bang-bang: accelerate below it,
# release above it) rather than holding one direction the whole way, so the
# body still has just enough residual momentum to clear the edge but drifts
# only a fraction as far during the fall.
const CREEP_SPEED_CAP := 80.0
const CREEP_RANGE := 120.0

func _advance_drop(delta: float) -> Status:
	var from_aabb: Dictionary = geometry.aabb(edge.from)
	var run_drop: bool = edge.get("run_drop", false)
	match phase:
		"walk":
			# `_dir` is decided ONCE (on the first tick of this attempt), not
			# recomputed every tick from the target's centre - confirmed
			# regression: B_W -> C_W's target centre (650) sits inside B_W's
			# own narrow extent (460-740), so as the body's natural approach
			# carried it across x=650, the direction flipped, which flips
			# which of B_W's two edges it is departing from (edge_x), which
			# reverses course again next tick - an oscillation around the
			# target's centre that never actually departs either edge.
			#
			# Traversal audit fix (Arena01_Traversal_Audit.docx, step 01):
			# even latched once, computing _dir from the TARGET's centre is
			# still the wrong question whenever the target's centre lies
			# inside the source platform's own extent - it answers "which
			# way is the destination" rather than "which edge of THIS
			# platform can I actually depart from" (B_W's east side is a
			# solid Pier wall, not an edge, so the only real departure is
			# west, but a target-centre comparison from most starting
			# positions on B_W previously said "east"). An edge now declares
			# its departure side as authored data ("side": "left"/"right" in
			# nav_graph.gd); the target-centre comparison remains only as a
			# fallback for edges that never specify one, preserving their
			# already-proven behaviour exactly.
			if _dir == 0:
				var side: String = edge.get("side", "")
				if side == "left":
					_dir = -1
				elif side == "right":
					_dir = 1
				else:
					var to_aabb: Dictionary = geometry.aabb(edge.to)
					var diff: float = geometry.shortest_diff(to_aabb.center.x, body.global_position.x)
					_dir = 1 if diff >= 0.0 else -1
			var edge_x: float = from_aabb.right if _dir > 0 else from_aabb.left
			var dist_to_edge: float = abs(geometry.shortest_diff(edge_x, body.global_position.x))
			# RUN_DROP (step 02): a small number of drops need a full-speed
			# departure to carry across a real horizontal gap as well as the
			# fall (e.g. A_E_Bridge->B_Seam's 130px gap) - the ordinary creep
			# cap is what a narrow-target landing needs, but it is exactly
			# wrong here, since it would leave the body short of the gap
			# entirely. Skip the creep speed cap and just walk to the edge at
			# full speed; the "cleared" check below is unchanged, and the
			# "fall" phase already holds zero horizontal intent for every
			# drop, so the full takeoff speed alone (no continued air
			# acceleration) carries the extra distance.
			if run_drop:
				if _walk_with_unstick(_dir, delta):
					return Status.FAILED
			elif dist_to_edge <= CREEP_RANGE:
				horizontal_intent = 0.0 if abs(body.velocity.x) >= CREEP_SPEED_CAP else float(_dir)
				if _check_creep_stall(delta):
					return Status.FAILED
			elif _walk_with_unstick(_dir, delta):
				return Status.FAILED
			# Wrap-aware (traversal audit, step 01/02 regression finding):
			# B_Seam is the first drop source whose own extent straddles the
			# wrap boundary (x1780-2140, arena width 1920). A body starting
			# on its far side can already be sitting on the wrapped mirror
			# copy (e.g. raw x~151, the wrap of ~2071) by the time this phase
			# starts - comparing that raw x directly against edge_x=1780
			# said "already past the edge" on the very first tick (151 is
			# far less than edge_x - buffer), when physically the body had
			# not moved at all. shortest_diff resolves the true distance
			# around the wrap the same way every other direction check in
			# this file already does; no other existing drop's source
			# platform ever reaches the wrap boundary, so this is a pure bug
			# fix with zero behaviour change for them (confirmed by the
			# unchanged regression results on all other drop edges).
			var clear_buffer: float = geometry.player_half_w + 4.0
			var diff_to_edge: float = geometry.shortest_diff(edge_x, body.global_position.x)
			var cleared: bool = (_dir > 0 and diff_to_edge <= -clear_buffer) or (_dir < 0 and diff_to_edge >= clear_buffer)
			if cleared:
				phase = "fall"
			return Status.RUNNING
		"fall":
			horizontal_intent = 0.0
			if body.is_on_floor():
				return Status.SUCCESS if _landed_on_target() else Status.FAILED
			return Status.RUNNING
	return Status.FAILED

# --- ladder: walk into the zone, release horizontal, hold vertical until the
# edge's stored target_y, release, step off in exit_dir. climb_dir -1 climbs
# up (matches player.gd's vertical_intent_up = -1 convention), +1 climbs
# down. A downward climb also completes the moment is_on_floor() goes true -
# there is no lower clamp symmetric to climb_top_limit, so a climber going
# down simply lands on whatever solid surface is beneath the ladder.
func _advance_ladder(delta: float) -> Status:
	var lad: Dictionary = geometry.ladders.get(edge.ladder, {})
	if lad.is_empty():
		return Status.FAILED
	var climb_dir: int = int(edge.climb_dir)
	match phase:
		"approach":
			var diff: float = geometry.shortest_diff(lad.center.x, body.global_position.x)
			var dir: int = 1 if diff > 0.0 else -1
			var in_zone: bool = body.in_traversal_zone and body.global_position.x >= lad.left and body.global_position.x <= lad.right
			if in_zone:
				phase = "climb"
				_climb_start_y = body.global_position.y
			elif _walk_with_unstick(dir, delta):
				return Status.FAILED
			return Status.RUNNING
		"climb":
			vertical_intent = climb_dir
			var target_y: float = float(edge.target_y)
			var reached: bool
			if climb_dir < 0:
				reached = body.global_position.y <= target_y + 4.0
			else:
				# is_on_floor() is already true at the moment a downward
				# climb starts (the body enters the zone from solid ground)
				# - only treat it as "reached bottom" once real downward
				# progress has actually happened, or it fires on tick one.
				var descended: bool = body.global_position.y >= _climb_start_y + 20.0
				reached = body.global_position.y >= target_y - 4.0 or (descended and body.is_on_floor())
			if reached:
				phase = "exit"
			return Status.RUNNING
		"exit":
			horizontal_intent = int(edge.exit_dir)
			if body.is_on_floor():
				return Status.SUCCESS if _landed_on_target() else Status.FAILED
			return Status.RUNNING
	return Status.FAILED

# --- launch: walk onto the pad, wait for the trigger and for airborne state,
# hold 12 physics ticks before steering (matches _route_launcher's proven
# delay exactly - clears B_Seam's underside on the way up), then steer.
# A fixed tick count is used here deliberately, not delta seconds: physics
# ticks run at a fixed rate regardless of Engine.time_scale, so this stays
# time_scale-safe by construction, same as the checker's own proven version.
func _advance_launch(delta: float) -> Status:
	var pad: Dictionary = geometry.pads.get(edge.pad, {})
	if pad.is_empty():
		return Status.FAILED
	match phase:
		"approach":
			# The pad's own Area2D can trigger the real launch as soon as any
			# part of the body overlaps it, which is a wider region than
			# this "close enough to centre" check - if that already fired,
			# follow it into "wait_air" instead of continuing to steer
			# toward a centre point the body has already flown past.
			if body.velocity.y < -1000.0:
				phase = "wait_air"
				return Status.RUNNING
			var diff: float = geometry.shortest_diff(pad.center.x, body.global_position.x)
			if abs(diff) < 6.0:
				phase = "wait_trigger"
			elif _walk_with_unstick(1 if diff > 0.0 else -1, delta):
				return Status.FAILED
			return Status.RUNNING
		"wait_trigger":
			if body.velocity.y < -1000.0:
				phase = "wait_air"
			return Status.RUNNING
		"wait_air":
			if not body.is_on_floor():
				phase = "delay"
			return Status.RUNNING
		"delay":
			_delay_ticks += 1
			if _delay_ticks >= 12:
				phase = "steer"
			return Status.RUNNING
		"steer":
			horizontal_intent = int(edge.steer_dir)
			if body.is_on_floor():
				return Status.SUCCESS if _landed_on_target() else Status.FAILED
			return Status.RUNNING
	return Status.FAILED

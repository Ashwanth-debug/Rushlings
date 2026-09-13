extends Area2D

# M4-2 - the smallest reusable authored danger-zone system (docs/plans/
# M04_0_MATCH_SHAPE_DESIGN.md S05.5: "escalating danger zones... a mandatory
# readable warning -> active -> safe cycle. No invisible damage."). One
# script reused for every authored zone (scene instances differ only by
# position/size/timing/phase_offset), the same convention power_pickup.gd
# already uses for its three power types - not a generalized hazard
# framework for future creatures/wind/etc.
#
# Dormant by construction: a zone is created locked in SAFE and never
# advances its own clock or deals damage until arm(true) is called
# (arena_01.gd, only when Arena Bites Lab is entered). This is what keeps
# the normal M3 match, M4-1 Contact Lab, and every existing checker
# (tools/arena_check.gd, tools/m3_check.gd, tools/m4_1_check.gd) byte-for-
# byte unaffected by this file's existence - none of them arm anything.
#
# Damage rule (CLAUDE.md M4-2 brief S2): exactly one hazard hit per player
# per ACTIVE activation, not a frame-by-frame drain. _hit_this_activation is
# cleared the instant a new ACTIVE window begins (not on WARNING or SAFE),
# so a player who stays inside for the whole ACTIVE duration takes exactly
# 1 pip, and the same player is a valid target again on the zone's next
# ACTIVE cycle. Damage always routes through HealthSystem.apply_damage() -
# exactly like a Rocket hit or the debug damage key - so spawn protection
# and the Defeated state are honoured automatically via player.gd's own
# take_damage() gate, with zero special-casing here.
#
# Visual - two rounds of Game Director playtest revision, both preserved
# here so a future session understands why the treatment looks the way it
# does rather than re-litigating either finding:
#
# Round 1 (2026-09-12): the original translucent green SAFE fill read as
# ordinary harmless terrain rather than dormant dangerous machinery. Tried a
# custom-drawn (_draw()) dark metal frame plus a row of teeth along the top/
# bottom edges, always visible regardless of state.
#
# Round 2 (2026-09-13): the frame+teeth treatment overcorrected - it read as
# "another platform/block to jump onto" rather than an environmental area/
# effect, damaging spatial readability (the original translucent footprint
# read better spatially precisely because it did NOT look like traversal
# geometry). REVERTED to a translucent fill, no frame, no teeth. What
# survives from round 1: SAFE is still a dull rust/amber rather than
# harmless green, just at low opacity instead of a solid panel - "SAFE may
# remain subtle... does NOT need to look aggressively dangerous while
# dormant if that damages spatial readability" (Director, round 2). A thin,
# lightweight outline stroke (not a filled border, not spikes) is the only
# structural cue retained, so the zone still reads as *something* rather
# than empty air, without reading as *solid*. Still pure _draw() (no new
# CollisionShape2D), still zero production art, still zero collision/
# traversal change either way.
#
# Phase offsets (round 1 playtest, unaffected by round 2): three zones all
# on identical timings read as one synchronized global timer rather than
# separate parts of the arena waking up independently. phase_offset is a
# deterministic seed only - never runtime randomness - consumed once in
# arm(true) to fast-forward this zone's state/clock as if it had already
# been cycling for phase_offset seconds, so tools/m4_2_check.gd stays fully
# deterministic.

enum State { SAFE, WARNING, ACTIVE }

## Diagnostic-only, mirroring PowerSystem's own power_hit signal shape - lets
## a soak/report tool count hazard-caused pips separately from power-caused
## ones (CLAUDE.md M4-2 S9: "damage pips from hazards"). Never used to decide
## any behaviour; HealthSystem.apply_damage() is still the one damage path.
signal hazard_hit(target_slot_id: int)

## Rectangle size in pixels, centered on this node's position. Deliberately
## a plain export rather than reading a CollisionShape2D authored in the
## editor, so one script + one scene can be instanced at different sizes per
## authored location without per-instance shape resources.
@export var zone_size: Vector2 = Vector2(200.0, 90.0)

## Prototype tuning values, reported at the M4-2 handoff - not production
## timings. Chosen so a human can notice WARNING and react with plain M1
## movement (docs/plans/M04_0_MATCH_SHAPE_DESIGN.md S05.5's mandatory
## telegraph) before ACTIVE begins. Unchanged by the phase-offset revision -
## only WHEN each zone starts its cycle differs, not how long each state is.
@export var warning_duration: float = 1.2
@export var active_duration: float = 1.5
@export var safe_duration: float = 3.0

## Deterministic seconds to fast-forward into this zone's own cycle the
## moment it is armed (Game Director playtest finding, 2026-09-12: three
## zones on identical timings felt like one global timer). A plain export,
## not runtime randomness - two zones with the same phase_offset and
## timings are still guaranteed to reach the same state at the same tick,
## which is what keeps this deterministic for tools/m4_2_check.gd.
@export var phase_offset: float = 0.0

## Translucent fill colours - greybox readability only, no production VFX.
## Chosen to sit far from every power/pickup colour in power_type.gd's
## COLORS so a zone is never mistaken for a pickup or a power-hit flash.
## SAFE_COLOR is a dull rust/amber (not harmless green) at LOW opacity - a
## subtle footprint, not a solid panel (round 2 revision, 2026-09-13).
## WARNING/ACTIVE are unchanged from round 1 - both already read correctly
## in playtesting and neither was part of the "too boxy" finding.
const SAFE_COLOR := Color(0.5, 0.38, 0.16, 0.28)
const WARNING_COLOR := Color(1.0, 0.62, 0.05, 0.6)
const ACTIVE_COLOR := Color(0.8, 0.08, 0.08, 0.88)
const WARNING_PULSE_HZ := 6.0

## The one lightweight structural cue retained from round 1's frame/teeth
## experiment (Director, round 2: "if useful, retain only very lightweight
## hazard markings... prioritize reading as an area/effect, not an object/
## platform") - a thin unfilled outline stroke, same colour family as the
## fill, never a filled border and never spikes.
const OUTLINE_WIDTH := 2.0

const HealthSystemScript := preload("res://scripts/health_system.gd")

@onready var _shape: CollisionShape2D = $CollisionShape2D

var health_system = null

var armed: bool = false
var state: int = State.SAFE
var _clock: float = 0.0
var _warning_pulse_t: float = 0.0
## CharacterBody2D -> true, cleared every time a new ACTIVE window begins.
## Not per-slot-id, same reasoning as HealthSystem's own timers: a body
## fully replaced (rematch) can never be misread via a stale key.
var _hit_this_activation: Dictionary = {}

func _ready() -> void:
	# collision_layer = 0: a hazard is never itself detectable by anything
	# else's mask (world-geometry checks like rocket_projectile.gd's own
	# layer-1 probe, or a future system) - Area2D's engine default is layer
	# 1, which would otherwise make every hazard silently look like world
	# geometry to a Rocket flying through it.
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(2, true)  # players layer only, per player.gd
	monitoring = true
	# A fresh, per-instance shape rather than mutating the .tscn's shared
	# sub_resource in place - three authored zones (or any two DangerZone
	# instances from the same PackedScene) would otherwise all silently
	# adopt whichever instance's zone_size happened to run _ready() last,
	# since Godot shares an un-flagged sub_resource across every
	# instantiate() of one PackedScene.
	var shape := RectangleShape2D.new()
	shape.size = zone_size
	_shape.shape = shape
	queue_redraw()

## Called once by arena_01.gd after building HealthSystem, exactly the same
## explicit-configure() pattern PowerSystem/HealthSystem themselves use.
func configure(p_health_system) -> void:
	health_system = p_health_system

## arena_01.gd's Arena Bites Lab toggle. Arming seeds this zone's state/
## clock from phase_offset (see _seed_phase) instead of always starting at
## a bare SAFE/0 - deterministically, since phase_offset is an authored
## export, not a random draw. Disarming resets to a clean SAFE state rather
## than freezing mid-cycle, so re-entering the lab always starts from a
## known state instead of wherever the clock happened to be when it was
## last turned off.
func arm(v: bool) -> void:
	armed = v
	if armed:
		_seed_phase(phase_offset)
	else:
		state = State.SAFE
		_clock = 0.0
		_warning_pulse_t = 0.0
		queue_redraw()

## Deterministically fast-forwards state/_clock as if this zone had already
## been cycling, unarmed, for `t` seconds - the entire phase-offset feature.
## No randomness: the same phase_offset and timings always produce the same
## seeded state, which is what keeps tools/m4_2_check.gd's offset tests
## reproducible.
func _seed_phase(t: float) -> void:
	var total := safe_duration + warning_duration + active_duration
	if total <= 0.0:
		state = State.SAFE
		_clock = 0.0
		queue_redraw()
		return
	t = fmod(max(t, 0.0), total)
	if t < safe_duration:
		state = State.SAFE
		_clock = t
	elif t < safe_duration + warning_duration:
		state = State.WARNING
		_clock = t - safe_duration
		_warning_pulse_t = _clock * WARNING_PULSE_HZ
	else:
		state = State.ACTIVE
		_clock = t - safe_duration - warning_duration
		_hit_this_activation.clear()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not armed:
		return
	_clock += delta
	match state:
		State.SAFE:
			if _clock >= safe_duration:
				_set_state(State.WARNING)
		State.WARNING:
			_warning_pulse_t += delta * WARNING_PULSE_HZ
			queue_redraw()
			if _clock >= warning_duration:
				_set_state(State.ACTIVE)
		State.ACTIVE:
			_check_hits()
			if _clock >= active_duration:
				_set_state(State.SAFE)

func _set_state(new_state: int) -> void:
	state = new_state
	_clock = 0.0
	if new_state == State.ACTIVE:
		_hit_this_activation.clear()
	if new_state != State.WARNING:
		_warning_pulse_t = 0.0
	queue_redraw()

## The zone's current fill colour - SAFE/WARNING/ACTIVE's whole signal.
func _current_fill_color() -> Color:
	match state:
		State.WARNING:
			var c := WARNING_COLOR
			c.a = 0.55 + 0.45 * sin(_warning_pulse_t)
			return c
		State.ACTIVE:
			return ACTIVE_COLOR
		_:
			return SAFE_COLOR

## Round 2 revision (2026-09-13): a single translucent rect plus a thin
## outline stroke - no frame, no teeth, no filled border. Deliberately
## minimal so the zone reads as an area/effect over the existing platform
## rather than an object sitting on top of it. Pure drawing either way:
## geometry/traversal are unaffected by this function's existence (verified
## in tools/m4_2_check.gd's geometry-unaffected test).
func _draw() -> void:
	var half := zone_size * 0.5
	var fill := _current_fill_color()
	draw_rect(Rect2(-half, zone_size), fill, true)
	var outline := fill
	outline.a = min(1.0, fill.a + 0.35)
	draw_rect(Rect2(-half, zone_size), outline, false, OUTLINE_WIDTH)

## Polling, not body_entered/body_exited signals - the same reasoning
## rocket_projectile.gd's own header gives: this only needs "is a valid,
## not-yet-hit target overlapping right now", and get_overlapping_bodies()
## already gives that for free without tracking enter/exit state across a
## state transition that can happen mid-overlap.
func _check_hits() -> void:
	if health_system == null:
		return
	for body in get_overlapping_bodies():
		if not (body is CharacterBody2D) or not ("slot_id" in body):
			continue
		if _hit_this_activation.has(body):
			continue
		_hit_this_activation[body] = true
		if health_system.apply_damage(body, HealthSystemScript.HAZARD_SOURCE):
			hazard_hit.emit(body.slot_id)

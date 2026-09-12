extends Node2D

# M3-2 Step 2 - the gate is now state-driven off MatchDirector, which is
# authoritative. See docs/plans/M03_2_CORE_MATCH_LOOP_PLAN.md S05 and S19
# Step 2.
#
# SETUP     bars DOWN, VaultSealW/VaultSealE collision ON, Relic dim.
# UNLOCKING vault stays physically sealed for the whole state; the bars
#           visibly rise, continuously, driven by director.unlocking_progress()
#           (delta-driven via MatchDirector's clock, so it is
#           Engine.time_scale-safe like the timer itself). Collision is only
#           ever touched by the SETUP/OPEN handlers below, never here - the
#           seal must not weaken just because the bars have started moving.
# OPEN      one authoritative transition: bars fully clear, both seal shapes
#           disabled and hidden, Relic bright. Relic collection itself is
#           still out of scope (Step 3).
#
# Collision is toggled with set_deferred("disabled", ...), never freed - the
# seals must be able to return for a future SETUP/rematch.

const BAR_CLOSED_BOTTOM := 460.0
const BAR_OPEN_BOTTOM := 376.0

const RELIC_DIM := Color(0.45, 0.45, 0.45, 1)
const RELIC_BRIGHT := Color(1, 1, 1, 1)

@onready var _bars: Array[ColorRect] = [$Bar1, $Bar2, $Bar3, $Bar4, $Bar5, $Bar6]
@onready var _relic: ColorRect = get_parent().get_node("RelicPlaceholder")
@onready var _seal_w: StaticBody2D = get_parent().get_node("Geometry/VaultSealW")
@onready var _seal_e: StaticBody2D = get_parent().get_node("Geometry/VaultSealE")
@onready var _seal_w_shape: CollisionShape2D = _seal_w.get_node("CollisionShape2D")
@onready var _seal_e_shape: CollisionShape2D = _seal_e.get_node("CollisionShape2D")
@onready var _director: MatchDirector = get_parent().get_node("MatchDirector")

func _ready() -> void:
	_director.state_changed.connect(_on_state_changed)
	_apply_sealed_state()

func _process(_delta: float) -> void:
	if _director.state == MatchDirector.State.UNLOCKING:
		var bottom: float = lerp(BAR_CLOSED_BOTTOM, BAR_OPEN_BOTTOM, _director.unlocking_progress())
		for bar in _bars:
			bar.offset_bottom = bottom

func _on_state_changed(new_state: int) -> void:
	match new_state:
		MatchDirector.State.SETUP:
			_apply_sealed_state()
		MatchDirector.State.UNLOCKING:
			pass  # bars animate continuously in _process; seal stays fully solid
		MatchDirector.State.OPEN:
			_apply_open_state()

func _apply_sealed_state() -> void:
	for bar in _bars:
		bar.offset_bottom = BAR_CLOSED_BOTTOM
	_relic.modulate = RELIC_DIM
	_set_seal_collision(true)

func _apply_open_state() -> void:
	for bar in _bars:
		bar.offset_bottom = BAR_OPEN_BOTTOM
	_relic.modulate = RELIC_BRIGHT
	_set_seal_collision(false)

func _set_seal_collision(sealed: bool) -> void:
	_seal_w_shape.set_deferred("disabled", not sealed)
	_seal_e_shape.set_deferred("disabled", not sealed)
	_seal_w.visible = sealed
	_seal_e.visible = sealed

extends Area2D

# M4-1 STOP 1 - touch-to-collect world power pickup. One Area2D entity reused
# for all three powers (power_type set per scene instance in
# scenes/arena_01/arena_01.tscn), not three separate scripts - the pickup/
# replace/respawn behaviour is identical regardless of which power it hands
# out.
#
# Collection rule (docs/plans/M04_0_MATCH_SHAPE_DESIGN.md S08): touching a
# pickup always calls receive_power() on the toucher - empty -> receives,
# already carrying -> replaces. No inventory, no drop of the old power (that
# is explicitly deferred past STOP 1).
#
# Respawn is a test-harness convenience, not a designed mechanic: with only
# one-use powers and no other loot source, a pickup that vanished forever
# after one use would make "collect again" impossible to test at all past
# the first few seconds. respawn_delay is a prototype tuning knob (per
# CLAUDE.md M4-1 S06 caveat 2: "pickup density is an M4-1 tuning knob, not a
# shipping value"), reported at STOP 1/2, not a settled value.

const PowerTypeScript := preload("res://scripts/power_type.gd")

@export var power_type: int = PowerTypeScript.Type.PUSH
## Which nav-graph node (scripts/nav_graph.gd) this pickup physically sits
## on - authored once per instance, read by PickupField so BotBrain can
## target it through the existing RELIABLE-only routing policy without any
## new spatial-query code.
@export var nav_node: String = ""
@export var respawn_delay: float = 6.0
## M4-1 STOP 4 - false for a spilled pickup (scripts/health_system.gd's
## _spill_power()): a one-off world object tied to a specific defeat, not
## part of the authored, persistent pickup set - it disappears for good once
## collected rather than respawning at the old defeat position forever.
@export var respawns: bool = true

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: ColorRect = $ColorRect
@onready var _label: Label = $Label

var _collected: bool = false
var _respawn_timer: float = 0.0

func _ready() -> void:
	# Players live on collision layer 2 only (see player.gd) - every other
	# Area2D in the arena adds this bit for exactly the same reason.
	set_collision_mask_value(2, true)
	monitoring = true
	body_entered.connect(_on_body_entered)
	_apply_visual()

func is_available() -> bool:
	return not _collected

func _apply_visual() -> void:
	_visual.color = PowerTypeScript.color(power_type)
	_label.text = PowerTypeScript.label(power_type)

func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body.has_method("receive_power"):
		return
	body.receive_power(power_type)
	_collect()

func _collect() -> void:
	_collected = true
	visible = false
	_shape.set_deferred("disabled", true)
	if respawns:
		_respawn_timer = respawn_delay
	else:
		# One-off spilled pickup - gone once taken. PickupField's own
		# is_instance_valid() guards (pickup_field.gd) mean nothing needs to
		# explicitly unregister this from its pickups array first.
		call_deferred("queue_free")

func _physics_process(delta: float) -> void:
	if not _collected or not respawns:
		return
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_respawn()

func _respawn() -> void:
	_collected = false
	visible = true
	_shape.set_deferred("disabled", false)

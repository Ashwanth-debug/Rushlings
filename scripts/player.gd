extends CharacterBody2D

# Preloaded rather than referenced by global class name so the script resolves
# without depending on the editor's global class cache.
const ArenaWrapScript := preload("res://scripts/arena_wrap.gd")

# --- Movement tuning ----------------------------------------------------
# Single source of truth for Milestone 1 movement feel. The lab scene does
# not override these, so changing a value here changes the game.
@export var max_speed: float = 500.0
@export var acceleration: float = 3000.0
@export var friction: float = 3500.0
@export var gravity: float = 2200.0
@export var climb_speed: float = 400.0
@export var launch_strength: float = 1500.0
## Normal player movement. Deliberately much weaker than launch_strength, which
## is environmental traversal and should reach places a jump cannot.
@export var jump_strength: float = 900.0

var in_traversal_zone: bool = false
var is_climbing: bool = false

# Set when the player jumps off a ladder. Blocks re-engaging the climb while
# still inside the same zone, so a held climb key cannot snap the player back
# mid-jump. Cleared by leaving the zone or by releasing vertical intent, so
# pressing it again is always a deliberate re-engage.
var climb_suppressed: bool = false

# Highest point (smallest Y) this body's origin may reach while climbing.
# Taken from the traversal zone's top edge so a climb finishes level with the
# destination platform instead of overshooting out of the zone and falling.
var climb_top_limit: float = -INF

func _ready() -> void:
	# Opts this body into the arena's horizontal wrapping.
	add_to_group(ArenaWrapScript.WRAPPABLE_GROUP)

func _physics_process(delta: float) -> void:
	var horizontal_intent := _get_horizontal_intent()
	var vertical_intent := _get_vertical_intent()
	var wants_jump := _get_jump_intent()

	_update_climb_state(vertical_intent)

	if horizontal_intent != 0.0:
		velocity.x = move_toward(velocity.x, horizontal_intent * max_speed, acceleration * delta)
	elif is_on_floor() or is_climbing:
		# Deceleration is floor-only. In the air momentum is preserved so a
		# launch keeps its horizontal travel and the player steers it instead.
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if is_climbing and wants_jump:
		# Jump off the ladder. Horizontal velocity is left alone, so a direction
		# held while jumping carries the player away from the ladder naturally.
		is_climbing = false
		climb_suppressed = true
		velocity.y = -jump_strength
	elif is_climbing:
		velocity.y = vertical_intent * climb_speed
		if global_position.y <= climb_top_limit and velocity.y < 0.0:
			global_position.y = climb_top_limit
			velocity.y = 0.0
	elif wants_jump and is_on_floor():
		# Grounded only, so there is no double jump and no wall jump. Horizontal
		# velocity is untouched, so a running jump keeps its speed.
		velocity.y = -jump_strength
	else:
		velocity.y += gravity * delta

	move_and_slide()

func _update_climb_state(vertical_intent: float) -> void:
	if not in_traversal_zone:
		is_climbing = false
		climb_suppressed = false
		return
	if vertical_intent == 0.0:
		# Releasing vertical intent clears a ladder-jump suppression, so the next
		# press is a deliberate re-engage. An already-latched climb holds here.
		climb_suppressed = false
		return
	# Latched: vertical intent engages the climb and it stays engaged while the
	# player remains inside the zone. Zero intent holds position on the ladder.
	if not climb_suppressed:
		is_climbing = true

# --- Input intent -------------------------------------------------------
# The only three places a concrete input device is read. Mobile touch/gesture
# controls (M5) replace these function bodies and nothing else - no movement
# physics below or above depends on which device produced the intent.
#
# Prototype keyboard mapping, deliberately context sensitive:
#   outside a traversal zone   A/Left, D/Right = move   W/Up = jump   Space = jump
#   inside a traversal zone    A/Left, D/Right = move   W/Up = climb up
#                              S/Down = climb down      Space = jump off ladder

func _get_horizontal_intent() -> float:
	return Input.get_axis("move_left", "move_right")

func _get_vertical_intent() -> float:
	var intent := 0.0
	if Input.is_action_pressed("vertical_intent_up"):
		intent -= 1.0
	if Input.is_action_pressed("vertical_intent_down"):
		intent += 1.0
	return intent

func _get_jump_intent() -> bool:
	if Input.is_action_just_pressed("jump"):
		return true
	# Up doubles as jump, but only away from a ladder - inside a traversal zone
	# it means climb up instead.
	return not in_traversal_zone and Input.is_action_just_pressed("vertical_intent_up")

# --- External events ----------------------------------------------------

func enter_traversal_zone(top_y: float) -> void:
	in_traversal_zone = true
	climb_top_limit = top_y

func exit_traversal_zone() -> void:
	in_traversal_zone = false
	is_climbing = false
	climb_suppressed = false
	climb_top_limit = -INF

func receive_launch(direction: Vector2) -> void:
	is_climbing = false
	var dir := direction.normalized()
	# Vertical is set outright so a fast fall onto the pad cannot cancel the
	# launch; horizontal is added so existing run momentum survives it.
	velocity.y = dir.y * launch_strength
	velocity.x += dir.x * launch_strength

func reset_to(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	is_climbing = false
	climb_suppressed = false
	# in_traversal_zone and climb_top_limit are deliberately left alone: they are
	# owned by the traversal zone's enter/exit signals, which re-evaluate overlaps
	# after the move. Clearing them here would desync the flag from reality when a
	# body is moved within the zone it is already inside.

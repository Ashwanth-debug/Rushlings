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

## Assigned at spawn by whoever builds the match (arena_01.gd via
## MatchConfig). player.gd never constructs one itself and never reads Input
## directly - this is the entire human/bot/(reserved)network seam. See
## docs/DECISIONS.md (2026-09-06, "A player slot's controller is data").
var controller: PlayerController

## Identity, set at spawn. slot_id is 1-based (P1-P4).
@export var body_color: Color = Color(0.9, 0.2, 0.2)
var slot_id: int = 1

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
	if controller == null:
		controller = HumanController.new()
	$ColorRect.color = body_color
	if has_node("Label"):
		$Label.text = "P%d" % slot_id
	# BUG FIX (post-A1/A2 playtest): players must leave the default world
	# layer (1) entirely and live ONLY on the dedicated "players" layer (2).
	# The original code added layer 2 on top of the default layer 1 without
	# ever removing layer 1, and left the mask's default layer-1 bit in
	# place too - so every player still matched every other player on the
	# shared layer-1 bit regardless of the layer-2 toggle (Godot collides
	# two bodies if EITHER's mask includes the other's layer, checked in
	# both directions). World detection still works because the mask
	# below always includes layer 1 - world geometry's own layer - so
	# world<->player collision is unaffected; only player<->player
	# collision is now actually gated by layer 2.
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	set_player_collision_enabled(false)

## Ladders and the launch pad are Area2D nodes whose default mask (layer 1)
## no longer matches a player's layer now that players live on layer 2 only
## - see traversal_zone.gd and launch_pad.gd, which both add layer 2 to
## their own mask in _ready() for exactly this reason.
func set_player_collision_enabled(enabled: bool) -> void:
	set_collision_mask_value(2, enabled)

## Called by arena_01.gd after instancing, since a child's _ready() runs
## before its parent's - by the time arena_01.gd can assign real per-slot
## identity, this node's own _ready() has already applied its export
## defaults once. Idempotent, safe to call any time.
func configure(new_slot_id: int, new_color: Color) -> void:
	slot_id = new_slot_id
	body_color = new_color
	$ColorRect.color = body_color
	if has_node("Label"):
		$Label.text = "P%d" % slot_id

func set_label_visible(visible_flag: bool) -> void:
	if has_node("Label"):
		$Label.visible = visible_flag

## Dev-only nav stress test display (Director feedback, iteration 4): shows
## this bot's current commanded destination under the "P%d" name, e.g.
## "P2\nUpper Right (Crown)". suffix == "" restores the plain "P%d" name -
## used both to clear it when returning to NORMAL_ROAM and for the human
## player slot, which never has a stress destination.
func set_debug_suffix(suffix: String) -> void:
	if not has_node("Label"):
		return
	$Label.text = ("P%d\n%s" % [slot_id, suffix]) if suffix != "" else ("P%d" % slot_id)

func _physics_process(delta: float) -> void:
	controller.update(delta)
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
# The only three places movement reads intent from - and since M3-1, all
# three delegate to `controller` rather than reading a device directly. This
# is the human/bot/(reserved)network seam: HumanController reads Input
# exactly as before, BotController reads the nav-graph layer's decisions, and
# nothing in this class or below ever knows which one is driving it.

func _get_horizontal_intent() -> float:
	return controller.horizontal()

func _get_vertical_intent() -> float:
	return controller.vertical()

func _get_jump_intent() -> bool:
	return controller.jump_pressed(in_traversal_zone)

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

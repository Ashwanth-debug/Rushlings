extends CharacterBody2D

# Preloaded rather than referenced by global class name so the script resolves
# without depending on the editor's global class cache.
const ArenaWrapScript := preload("res://scripts/arena_wrap.gd")
const PowerTypeScript := preload("res://scripts/power_type.gd")

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

## M4-1 STOP 1 - carried power identity. Set/cleared only through
## receive_power()/consume_power() below, never assigned directly, so every
## change goes through the same debug-legibility print and indicator update.
## Owned here (alongside slot_id/body_color) rather than by PowerSystem,
## because "what am I carrying" is per-player identity state, exactly like
## those two - PowerSystem only decides WHEN an activation happens.
var carried_power: int = PowerTypeScript.Type.NONE

## Updated whenever horizontal intent is nonzero (see _physics_process).
## Rocket fires in this direction - the only "aim" M4-1 has, per
## docs/plans/M04_0_MATCH_SHAPE_DESIGN.md S06 caveat 1.
var facing_dir: float = 1.0

## M4-1 STOP 3+4 - three coarse pips, per docs/plans/M04_0_MATCH_SHAPE_DESIGN.md
## S04.1 (Healthy(3)->Hurt(2)->Critical(1)->Defeated(0)). Never a percentage;
## an exported tunable rather than a bare const only so a future arena-hazard
## milestone could expose it, not because M4-1 itself needs to vary it.
@export var max_health: int = 3
var health: int = 3

## True for the whole defeat->respawn window. Reuses controller.frozen for
## the exact same input-lock Freeze already validated at STOP 2 (no
## movement, no jump, no power use) - see set_defeated() below - and also
## drops the body off collision layer 2 (players.gd's own "which layer am I
## on" bit, set up in _ready()) so pickups/Relic/Rocket hit-detection, which
## all mask that layer, stop seeing this body at all without any special-
## casing in power_pickup.gd or relic.gd. Health/defeat/respawn is
## orchestrated externally by scripts/health_system.gd; this class only
## holds the state and its own presentation, exactly like carried_power.
var is_defeated: bool = false

## M4-1 STOP 4 - prototype-only post-respawn damage immunity (CLAUDE.md M4-1
## STOP 4 S7). Movement, jumping and power use are completely unaffected -
## only take_damage() reads this.
var spawn_protected: bool = false

## M4-2 defeat-resolution window (Game Director playtest, 2026-09-13): true
## for the short beat between a lethal hit and the moment
## scripts/health_system.gd's _finish_defeat() actually hides the body. Input
## is already locked via controller.frozen (begin_dying() sets it, the same
## primitive Defeated itself uses), but the body stays visible, on-layer and
## physically simulated - a killing Push still visibly displaces, a killing
## Freeze's tint stays up, a killing Rocket's flash still reads - so the
## power that caused the kill gets to finish being seen before the body
## disappears. Separate from is_defeated so take_damage() can refuse a
## second lethal hit landing mid-reaction, which would otherwise re-trigger
## the whole defeat sequence a second time.
var is_dying: bool = false

const PIP_ALIVE_COLOR := Color(0.95, 0.95, 0.95, 1.0)
const PIP_LOST_COLOR := Color(0.15, 0.15, 0.15, 0.5)

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
	health = max_health
	_update_health_indicator()

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

# --- M4-1 STOP 1+2 power state and readability -----------------------------
# receive_power()/consume_power() are the entire carry-one/one-use contract:
# a pickup calls receive_power() (scripts/power_pickup.gd), PowerSystem calls
# consume_power() the instant an activation succeeds (scripts/power_system.gd).
# Neither ever touches carried_power directly, so the print + indicator here
# can never go stale.

func has_power() -> bool:
	return carried_power != PowerTypeScript.Type.NONE

func receive_power(new_type: int) -> void:
	if has_power() and carried_power != new_type:
		print("[Player] P%d power replaced: %s -> %s" % [slot_id, PowerTypeScript.label(carried_power), PowerTypeScript.label(new_type)])
	else:
		print("[Player] P%d picked up %s" % [slot_id, PowerTypeScript.label(new_type)])
	carried_power = new_type
	_update_power_indicator()

func consume_power() -> void:
	if not has_power():
		return
	print("[Player] P%d power slot empty" % slot_id)
	carried_power = PowerTypeScript.Type.NONE
	_update_power_indicator()

func _update_power_indicator() -> void:
	if not has_node("PowerIndicator"):
		return
	var indicator: ColorRect = $PowerIndicator
	if has_power():
		indicator.visible = true
		indicator.color = PowerTypeScript.color(carried_power)
	else:
		indicator.visible = false

## Brief feedback so a Push/Rocket-hit reads clearly at full-arena scale
## without a HUD - a fast flash to white and back on the body itself.
func flash_push() -> void:
	_flash_color(Color(1, 1, 0.6))

func flash_hit() -> void:
	_flash_color(Color(1, 1, 1))

func _flash_color(flash: Color) -> void:
	var original: Color = body_color
	$ColorRect.color = flash
	var tw := create_tween()
	tw.tween_property($ColorRect, "color", original, 0.25)

## Freeze's visual: a cool tint over the body colour for the lock's duration,
## restored on expiry - PowerSystem calls this alongside controller.set_frozen()
## (scripts/power_system.gd) so the visual and the actual input-lock can never
## desync from each other.
func set_frozen_visual(active: bool) -> void:
	$ColorRect.modulate = Color(0.55, 0.85, 1.0) if active else Color(1, 1, 1)

# --- M4-1 STOP 3+4 health / defeat / respawn --------------------------------
# The whole contract in three functions: take_damage() is the ONLY way health
# ever drops (scripts/health_system.gd calls it, never assigns .health
# directly), set_defeated()/set_spawn_protected() are the only way those two
# flags change. Every effect of being Defeated - input lock, invisibility,
# uncollectable - falls out of two existing primitives (controller.frozen,
# collision layer 2) rather than new special-casing spread across
# power_pickup.gd/relic.gd/rocket_projectile.gd.

func is_alive() -> bool:
	return not is_defeated

## Returns true if damage was actually applied - false while Defeated (already
## at zero, nothing to lose) or spawn_protected (the whole point of the
## window). health_system.gd uses the return value to decide whether a defeat
## transition follows.
func take_damage() -> bool:
	if is_dying or is_defeated or spawn_protected:
		return false
	health = max(0, health - 1)
	_update_health_indicator()
	print("[Player] P%d took 1 damage - health=%d/%d" % [slot_id, health, max_health])
	return true

## M4-2 - the whole "reaction window" contract: lock input immediately (the
## same primitive Defeated uses) without touching visibility, collision
## layer or velocity, so whatever the lethal hit already did (a Push's
## receive_launch(), a Freeze's set_frozen_visual(), a Rocket's flash_hit())
## keeps playing out physically/visually for the reaction duration.
func begin_dying() -> void:
	is_dying = true
	controller.set_frozen(true)

func end_dying() -> void:
	is_dying = false

func reset_health() -> void:
	health = max_health
	_update_health_indicator()

func _update_health_indicator() -> void:
	if not has_node("Pip1"):
		return
	var pips: Array = [$Pip1, $Pip2, $Pip3]
	for i in range(pips.size()):
		pips[i].color = PIP_ALIVE_COLOR if i < health else PIP_LOST_COLOR

## Defeated is deliberately built from two primitives that already exist and
## are already validated (STOP 2's Freeze, and the collision-layer split from
## the M3-1 player<->player fix) rather than new rules threaded through every
## other system:
##  - controller.set_frozen(true): identical input lock to Freeze - no
##    movement, no jump, no power use. Also stops a BotController from ever
##    calling brain.tick() while defeated (bot_controller.gd), so a defeated
##    bot's behaviour cleanly stops rather than needing its own pause flag.
##  - collision layer 2 off: every Area2D that can affect a player (pickups,
##    Relic, a Rocket's own hit detection) already masks layer 2 to find
##    players at all - turning it off makes this body invisible to all three
##    at once, with zero changes to power_pickup.gd/relic.gd/rocket_projectile.gd.
## visible = false is the whole "defeat" visual treatment - deliberately the
## simplest possible greybox: gone, not present, for exactly defeat_duration.
func set_defeated(v: bool) -> void:
	is_defeated = v
	controller.set_frozen(v)
	set_collision_layer_value(2, not v)
	visible = not v

## Deliberately the ONLY thing spawn_protected touches - movement, jumping
## and power use are all fully available, per CLAUDE.md M4-1 STOP 4 S7.
## modulate.a (translucency) is the visual: distinct from Frozen's blue tint
## and from Defeated's full invisibility, and cheap to remove later if this
## prototype hypothesis doesn't survive human judgement at STOP 4.
func set_spawn_protected(v: bool) -> void:
	spawn_protected = v
	modulate.a = 0.5 if v else 1.0

func _physics_process(delta: float) -> void:
	controller.update(delta)
	var horizontal_intent := _get_horizontal_intent()
	var vertical_intent := _get_vertical_intent()
	var wants_jump := _get_jump_intent()

	if horizontal_intent != 0.0:
		facing_dir = signf(horizontal_intent)

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

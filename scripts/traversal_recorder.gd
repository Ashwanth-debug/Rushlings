class_name TraversalRecorder
extends RefCounted

# Dev-only instrument for the vault-exit investigation (Director request,
# 2026-09-07): capture the actual input/movement recipe a human uses to
# perform VaultFloor -> exit -> A_E/Crown, so it can be compared against
# BotController/EdgeExecutor's failed attempt. NOT game telemetry - a small,
# local debugging tool for P1 only, toggled by a single dev key
# (debug_record_traversal), with no persistence beyond the current run.

var body: CharacterBody2D
var geometry: ArenaGeometry
var recording: bool = false
var samples: Array = []
var _tick: int = 0
var _was_on_floor: bool = true
var _last_platform: String = ""

func _init(p_body: CharacterBody2D, p_geometry: ArenaGeometry) -> void:
	body = p_body
	geometry = p_geometry

func toggle() -> void:
	if recording:
		stop()
	else:
		start()

func start() -> void:
	recording = true
	samples.clear()
	_tick = 0
	_was_on_floor = body.is_on_floor()
	_last_platform = geometry.canonical_platform(body)
	print("[TraversalRecorder] RECORDING STARTED - perform VaultFloor -> exit -> A_E/Crown, then press the record key again to stop")

func stop() -> void:
	recording = false
	print("[TraversalRecorder] RECORDING STOPPED - %d samples over %.2fs" % [samples.size(), float(_tick) / Engine.physics_ticks_per_second])
	_print_trace()

func tick(_delta: float) -> void:
	if not recording:
		return
	_tick += 1
	var on_floor := body.is_on_floor()
	var platform: String = geometry.canonical_platform(body) if on_floor else ""
	var horizontal_intent := Input.get_axis("move_left", "move_right")
	var jump_intent := Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("vertical_intent_up")

	var event := ""
	if _was_on_floor and not on_floor:
		event = "TAKEOFF from '%s'" % _last_platform
	elif not _was_on_floor and on_floor:
		event = "LANDING on '%s'" % platform

	samples.append({
		"tick": _tick,
		"pos": body.global_position,
		"vel": body.velocity,
		"on_floor": on_floor,
		"platform": platform,
		"h_intent": horizontal_intent,
		"jump_intent": jump_intent,
		"event": event,
	})

	_was_on_floor = on_floor
	if platform != "":
		_last_platform = platform

func _print_trace() -> void:
	print("--- TraversalRecorder trace (tick, pos, vel, on_floor, h_intent, jump, platform, event) ---")
	for s in samples:
		var line := "t=%d pos=(%.1f,%.1f) vel=(%.1f,%.1f) floor=%s h=%.2f jump=%s plat=%s" % [
			s.tick, s.pos.x, s.pos.y, s.vel.x, s.vel.y, s.on_floor, s.h_intent, s.jump_intent, s.platform
		]
		if s.event != "":
			line += "  <<< %s" % s.event
		print(line)
	print("--- end trace ---")

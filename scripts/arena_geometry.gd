class_name ArenaGeometry
extends RefCounted

# Runtime geometry extraction for bots and the nav graph, at match start.
# Deliberately a separate, self-contained copy of tools/arena_check.gd's
# _aabb_of/_shortest_diff logic rather than a shared dependency - the checker
# is the permanent, already-tuned regression gate, and giving it a runtime
# dependency risks destabilising it for a M3-1 convenience. Both read the
# same live scene, so they cannot drift on what the geometry actually is,
# only (in principle) on how they interpret it, and the interpretation here
# is intentionally identical.

var geom: Dictionary = {}     # platform name -> {left, right, top, bottom, center}
var ladders: Dictionary = {}  # ladder name -> aabb
var pads: Dictionary = {}     # pad name -> aabb
var player_half_w: float
var player_half_h: float
var arena_width: float = 1920.0

func _init(arena: Node2D, half_w: float, half_h: float) -> void:
	player_half_w = half_w
	player_half_h = half_h
	_extract(arena)

func _extract(arena: Node2D) -> void:
	var geo := arena.get_node("Geometry")
	for child in geo.get_children():
		if child.name == "SeamMirror":
			for seam_child in child.get_children():
				geom[seam_child.name] = _aabb_of(seam_child)
			continue
		geom[child.name] = _aabb_of(child)
	var trav := arena.get_node("Traversal")
	for child in trav.get_children():
		# Named zone_aabb, not aabb - the latter shadows this class's own
		# aabb() method (harmless here since nothing in this loop calls it,
		# but shadowing a method name always warns and reads as a real bug
		# waiting to happen at the next edit).
		var zone_aabb := _aabb_of(child)
		if child.name.begins_with("Lad"):
			ladders[child.name] = zone_aabb
		elif child.name.begins_with("Pad"):
			pads[child.name] = zone_aabb

func _aabb_of(body: Node2D) -> Dictionary:
	var cs := body.get_node("CollisionShape2D") as CollisionShape2D
	var rect := cs.shape as RectangleShape2D
	if rect == null:
		var pos: Vector2 = cs.global_position
		return {"left": pos.x, "right": pos.x, "top": pos.y, "bottom": pos.y, "center": pos}
	var c: Vector2 = cs.global_position
	var hw: float = rect.size.x * 0.5
	var hh: float = rect.size.y * 0.5
	var angle: float = cs.global_rotation
	if abs(angle) > 0.0001:
		var corners: Array[Vector2] = [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
		var min_x: float = INF
		var max_x: float = -INF
		var min_y: float = INF
		var max_y: float = -INF
		for corner in corners:
			var world: Vector2 = c + corner.rotated(angle)
			min_x = min(min_x, world.x)
			max_x = max(max_x, world.x)
			min_y = min(min_y, world.y)
			max_y = max(max_y, world.y)
		return {"left": min_x, "right": max_x, "top": min_y, "bottom": max_y, "center": Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)}
	return {"left": c.x - hw, "right": c.x + hw, "top": c.y - hh, "bottom": c.y + hh, "center": c}

func aabb(name: String) -> Dictionary:
	return geom.get(name, {})

func has(name: String) -> bool:
	return geom.has(name)

func shortest_diff(target_x: float, from_x: float) -> float:
	var raw := target_x - from_x
	var half := arena_width * 0.5
	while raw > half:
		raw -= arena_width
	while raw < -half:
		raw += arena_width
	return raw

func on_platform(body: CharacterBody2D, name: String) -> bool:
	if not geom.has(name):
		return false
	var p: Dictionary = geom[name]
	var pos := body.global_position
	var x_tol: float = player_half_w + 4.0
	return body.is_on_floor() and pos.x >= p.left - x_tol and pos.x <= p.right + x_tol and abs(pos.y - (p.top - player_half_h)) <= 6.0

# Accepts a seam-mirror copy ("C_Seam_east"/"_west") or the vault-floor
# connectivity patch as a match for their canonical name, since both are the
# same walkable surface as the canonical node for every gameplay purpose.
func on_platform_like(body: CharacterBody2D, name: String) -> bool:
	if on_platform(body, name):
		return true
	if on_platform(body, name + "_east") or on_platform(body, name + "_west"):
		return true
	if name == "VaultFloor" and on_platform(body, "VaultFloor_Bridge"):
		return true
	if (name == "A_W" or name == "A_E") and on_platform(body, name + "_Bridge"):
		return true
	return false

func canonical_platform(body: CharacterBody2D) -> String:
	for name in geom:
		if on_platform(body, name):
			if name.ends_with("_east") or name.ends_with("_west"):
				return name.substr(0, name.length() - 5)
			if name == "VaultFloor_Bridge":
				return "VaultFloor"
			return name
	return ""

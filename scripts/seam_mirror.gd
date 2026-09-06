extends Node2D

# Duplicates every direct child at +/- arena_width so seam-crossing collision
# geometry exists on both sides of the wrap. Without this, a body whose
# origin is between the wrap edge and the wrap trigger margin (see
# arena_wrap.gd's exit_margin) would be over a gap with no floor - a body is
# only actually moved to the other side once it has fully exited, so the
# geometry itself must already be there on both sides before that happens.
#
# Author seam-crossing platforms once, positioned on whichever side reads
# naturally in the editor; this makes the collision structural rather than a
# hand-authored pair that can drift out of sync.

@export var arena_width: float = 1920.0

func _ready() -> void:
	for child in get_children():
		if not (child is Node2D):
			continue
		_duplicate_at_offset(child, arena_width)
		_duplicate_at_offset(child, -arena_width)

func _duplicate_at_offset(source: Node2D, offset_x: float) -> void:
	var copy := source.duplicate()
	# Deterministic, greppable name for tooling (e.g. tools/arena_check.gd).
	# Godot's Node.name sanitises "@", so spell the sign out instead of
	# encoding it with one - avoids a silent name mismatch.
	copy.name = "%s_east" % source.name if offset_x > 0.0 else "%s_west" % source.name
	add_child(copy)
	copy.position = source.position + Vector2(offset_x, 0.0)

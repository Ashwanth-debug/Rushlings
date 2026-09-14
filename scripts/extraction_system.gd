class_name ExtractionSystem
extends Node

# M4-3 - extraction anchor SELECTION only (CLAUDE.md M4-3 S3, docs/plans/
# M04_0_MATCH_SHAPE_DESIGN.md S05.7). Win detection lives on each
# scripts/extraction_anchor.gd instance itself, mirroring danger_zone.gd's
# "the entity owns its own state/presentation" split - this system only
# decides WHICH anchor is selected and WHEN, exactly like HealthSystem only
# decides WHEN a hit lands as real damage.
#
# Selected exactly once per round, at the first successful Relic pickup:
# the carrier's current region -> the anchor at MAXIMUM region-distance
# (ArenaRegions.region_distance, already ships from M3-1's roaming-bias
# work) -> ties resolved by a per-round DETERMINISTIC seed (never runtime
# randomness - the same convention BotBrain's own match_seed +
# round_index*101 already uses). Once locked, NEVER recalculated - not on
# carrier defeat, Relic drop, ownership change, or respawn. A fresh
# selection happens only after reset() (a new round) sees the NEXT pickup.

var anchors: Array = []   # Array[Area2D] (extraction_anchor.gd instances)
var geometry = null
var players: Array = []
## Set once per round by arena_01.gd (the same _round_base_seed() + a
## distinct offset every other per-round RNG in this codebase already uses)
## - read at the moment of selection, not at configure() time, so a fresh
## round's seed is always current even though configure() itself only runs
## once at startup.
var round_seed: int = 1

var locked: bool = false
var active_region: String = ""
var active_node: String = ""
## The activated extraction_anchor.gd instance itself, so arena_01.gd can
## read its live global_position.x for BotBrain's set_extraction_target()
## without this system having to duplicate that lookup.
var active_anchor = null
var _rng := RandomNumberGenerator.new()

func configure(p_anchors: Array, p_geometry, p_players: Array, p_director: MatchDirector) -> void:
	anchors = p_anchors
	geometry = p_geometry
	players = p_players
	for a in anchors:
		a.configure(p_director)
		a.deactivate()
	locked = false
	active_region = ""
	active_node = ""
	active_anchor = null

## Wired from scripts/relic.gd's `picked_up` signal (arena_01.gd). Ignored
## once locked - "must NOT recalculate... on another player picking up the
## Relic" (CLAUDE.md M4-3 S3) covers every pickup after the first by
## construction, since the first one is exactly what sets locked=true.
func on_relic_picked_up(slot_id: int) -> void:
	if locked:
		return
	var carrier := _find_player(slot_id)
	if carrier == null:
		return
	var carrier_node: String = geometry.canonical_platform(carrier) if carrier.is_on_floor() else ""
	var carrier_region: String = ArenaRegions.region_of(carrier_node)
	if carrier_region == "":
		# Best-effort fallback for the rare case of picking the Relic up
		# mid-air/ungrounded (e.g. a jump-through touch) - "central" is
		# where the Relic pedestal itself lives, the overwhelmingly likely
		# real position for a first pickup.
		carrier_region = "central"
	_select_extraction(carrier_region)

func _select_extraction(carrier_region: String) -> void:
	var best_dist := -1
	var candidates: Array = []
	for region in ArenaRegions.REGIONS:
		var d: int = ArenaRegions.region_distance(carrier_region, region)
		if d > best_dist:
			best_dist = d
			candidates = [region]
		elif d == best_dist:
			candidates.append(region)
	var chosen: String = candidates[0]
	if candidates.size() > 1:
		_rng.seed = round_seed
		chosen = candidates[_rng.randi_range(0, candidates.size() - 1)]
	active_region = chosen
	locked = true
	var chosen_anchor = null
	for a in anchors:
		if a.region == chosen:
			a.activate()
			chosen_anchor = a
		else:
			a.deactivate()
	active_node = chosen_anchor.nav_node if chosen_anchor != null else ""
	active_anchor = chosen_anchor
	print("[ExtractionSystem] carrier region '%s' -> extraction LOCKED at '%s' (node='%s', candidates=%s)" % [carrier_region, chosen, active_node, candidates])

## arena_01.gd calls this on every transition back to SETUP (both a real
## rematch and the debug_setup_10/15/25 keys), exactly the same "reset on
## SETUP" wiring already applied to bot goals and (via relic.gd's own
## state_changed listener) the Relic itself.
func reset() -> void:
	locked = false
	active_region = ""
	active_node = ""
	active_anchor = null
	for a in anchors:
		a.deactivate()

func _find_player(slot_id: int) -> CharacterBody2D:
	for p in players:
		if is_instance_valid(p) and p.slot_id == slot_id:
			return p
	return null

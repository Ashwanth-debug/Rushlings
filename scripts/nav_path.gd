class_name NavPath
extends RefCounted

# Hand-rolled Dijkstra over the ~17-node nav graph - free at this size, and
# it sidesteps a real footgun: an A* Euclidean heuristic is wrong in a
# wrapping world unless every distance already accounts for the wrap, and
# Dijkstra needs no heuristic at all. cost_fn lets each bot apply its own
# deterministic per-edge-type weighting (docs/plans/M03_CORE_GAME_LOOP.md
# §7.5) without the graph needing to know about bots.

static func shortest_path(graph: NavGraph, from: String, to: String, cost_fn: Callable) -> Array:
	if from == to or not graph.nodes.has(from) or not graph.nodes.has(to):
		return []
	var dist: Dictionary = {}
	var prev_edge: Dictionary = {}
	var visited: Dictionary = {}
	for n in graph.nodes:
		dist[n] = INF
	dist[from] = 0.0
	while true:
		var u := ""
		var best: float = INF
		for n in graph.nodes:
			if not visited.get(n, false) and dist[n] < best:
				best = dist[n]
				u = n
		if u == "":
			break
		if u == to:
			break
		visited[u] = true
		for e in graph.outgoing(u):
			var w: float = cost_fn.call(e)
			var alt: float = dist[u] + w
			if alt < dist.get(e.to, INF):
				dist[e.to] = alt
				prev_edge[e.to] = e
	if not prev_edge.has(to):
		return []
	var path: Array = []
	var cur := to
	while cur != from:
		var e: Dictionary = prev_edge[cur]
		path.push_front(e)
		cur = e.from
	return path

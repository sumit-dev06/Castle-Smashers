class_name Ramp
extends StaticBody2D
## Static slope or ledge for rolling logs, wheels, mine carts and ice slides, and the fulcrum under a
## seesaw. Level JSON: "ramps": [{"points": [[x, y], ...], "kind": "wood"|"rock"|"ice"|"rail"}]
## (a convex outline in world pixels). Friction and colours: balance.json -> ramps.<kind>.

var kind: String = "rock"


func setup(data: Dictionary) -> void:
	kind = String(data.get("kind", "rock"))
	var cfg: Dictionary = Data.balance["ramps"][kind]
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Variant in data["points"]:
		pts.append(Vector2(float(p[0]), float(p[1])))
	collision_layer = int(Data.b("layers", "world"))
	collision_mask = 0
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = float(cfg["friction"])
	pm.bounce = float(cfg.get("bounce", 0.0))
	physics_material_override = pm
	var col: CollisionPolygon2D = CollisionPolygon2D.new()
	col.polygon = pts
	add_child(col)
	var fill: Polygon2D = Polygon2D.new()
	fill.polygon = pts
	fill.color = Color(String(cfg["fill"]))
	add_child(fill)
	var edge: Line2D = Line2D.new()
	var loop: PackedVector2Array = pts.duplicate()
	loop.append(pts[0])
	edge.points = loop
	edge.width = 4.0
	edge.default_color = Color("#3a2212")
	edge.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(edge)
	# Light top edge: the upper-most segment chain (points before the lowest-x/highest-x turn).
	var top: Line2D = Line2D.new()
	top.width = 6.0
	top.default_color = Color(String(cfg["top"]))
	var top_pts: PackedVector2Array = PackedVector2Array()
	for i: int in pts.size():
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % pts.size()]
		if p1.x > p0.x + 0.5:
			if top_pts.is_empty() or top_pts[top_pts.size() - 1] != p0:
				top_pts.append(p0 + Vector2(0, 4))
			top_pts.append(p1 + Vector2(0, 4))
	top.points = top_pts
	add_child(top)
	if kind == "rail":
		var rail: Line2D = Line2D.new()
		rail.points = top_pts
		rail.width = 5.0
		rail.default_color = Color("#8a96a3")
		rail.position = Vector2(0, -3)
		add_child(rail)

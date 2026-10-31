class_name HeroAddons
extends RefCounted
## Decorations (hats, caps, glasses) worn by a hero. Catalogue: balance.cosmetics.hero_addons.
## One addon per slot ("head", "face"). Equipped ids live in Save.data.addons {slot: id} and only
## count while the Play one-time product is owned. Looks only.


static func catalog() -> Dictionary:
	return Data.balance["cosmetics"]["hero_addons"]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in catalog():
		if not k.begins_with("_") and k != "heroes":
			out.append(k)
	return out


static func owns(id: String) -> bool:
	var c: Dictionary = catalog()
	return c.has(id) and Store.owns(String(c[id]["product"]))


static func equipped() -> Dictionary:
	var out: Dictionary = {}
	if OS.is_debug_build() and Game.args.has("addons"):  # debug preview: --addons=crown,shades
		for id: String in String(Game.args["addons"]).split(","):
			if catalog().has(id):
				out[String(catalog()[id]["slot"])] = id
		return out
	var saved: Dictionary = Save.data.get("addons", {})
	for slot: String in saved:
		var id: String = String(saved[slot])
		if owns(id) and String(catalog()[id]["slot"]) == slot:
			out[slot] = id
	return out


static func is_on(id: String) -> bool:
	return equipped().values().has(id)


## Wear id in its slot, or take it off when it is already on.
static func toggle(id: String) -> void:
	var slot: String = String(catalog()[id]["slot"])
	var saved: Dictionary = Save.data.get("addons", {})
	if String(saved.get(slot, "")) == id:
		saved.erase(slot)
	else:
		saved[slot] = id
	Save.data["addons"] = saved
	Save.write()


## Adds the addon sprites as children of a hero sprite built by Art.hero_sprite (the body centre is
## the sprite's local origin). `only` previews a set of ids instead of the equipped ones.
static func attach(s: Sprite2D, hero_kind: String, art_name: String, only: Array = []) -> void:
	if not (catalog()["heroes"] as Array).has(hero_kind):
		return
	var list: Array = only if not only.is_empty() else equipped().values()
	var body_r: float = float(Art.meta(art_name)["body_r"])
	var k: float = body_r / 30.0  # addon art is drawn for a body radius of 30 SVG units
	for id: Variant in list:
		var c: Dictionary = catalog()[String(id)]
		var a: Sprite2D = Art.sprite("addon_" + String(id), k * float(c["scale"]))
		a.position = Vector2(float(c["pos"][0]), float(c["pos"][1])) * body_r
		a.rotation_degrees = float(c["rot"])
		a.z_index = 1 if String(c["slot"]) == "head" else 0
		a.name = "addon_" + String(id)
		s.add_child(a)


## A Control showing Rocky wearing `ids` (shop cards). size = box side in px.
static func preview(hero_kind: String, ids_on: Array, box: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(box, box)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art: String = String(Data.projectiles[hero_kind]["texture"])
	var s: Sprite2D = Art.hero_sprite(art, box * 0.33)
	s.position = Vector2(box * 0.5, box * 0.6)
	if not ids_on.is_empty():
		attach(s, hero_kind, art, ids_on)
	c.add_child(s)
	return c

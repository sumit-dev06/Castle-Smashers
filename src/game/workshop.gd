class_name Workshop
extends RefCounted
## Master Orin introduces heroes at authored campaign levels. Hero power is fixed in
## data/projectiles.json; only siege engines and Vanguard units can be upgraded.


static func config(kind: String) -> Dictionary:
	return (Data.projectiles[kind] as Dictionary).duplicate(true)


static func intro_level(kind: String) -> int:
	return int((Data.projectiles.get(kind, {}) as Dictionary).get("unlock_level", 1))


static func introduced(kind: String) -> bool:
	var level: int = intro_level(kind)
	return level <= 1 or Save.is_unlocked(level)


static func hero_order() -> Array:
	return Data.balance["wizard_workshop"]["hero_order"]

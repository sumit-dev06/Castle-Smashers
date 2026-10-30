extends Node
## Global signal bus. No logic here.

signal block_destroyed(block: Node2D, score: int)
signal archer_defeated(archer: Node2D, score: int)
signal soldier_knocked_out(soldier: Node2D)
signal big_impact(position: Vector2, impulse: float)
signal explosion(position: Vector2, radius: float)
signal quake(position: Vector2, radius: float)
signal mechanism_activated(mechanism: Node2D)
signal captive_rescued(captive: Node2D)
signal projectile_launched(kind: String)
signal level_finished(level_id: int, won: bool, stars: int, score: int)
signal coins_changed(total: int)
signal currency_changed(kind: String, total: int)

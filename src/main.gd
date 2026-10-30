extends Node
## Entry point (scenes/main.tscn). Hands control to the Game autoload.


func _ready() -> void:
	Game.boot(self)

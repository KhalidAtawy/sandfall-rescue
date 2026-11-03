extends Node2D
## A canvas layer whose drawing is supplied by the game script.
var painter: Callable

func _draw() -> void:
	if painter.is_valid():
		painter.call(self)

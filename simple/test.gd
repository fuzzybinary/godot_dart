extends Node2D

var _timePassed = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	_timePassed += delta

	var x = 10.0 + (10.0 * sin(_timePassed * 2.0))
	var y = 10.0 + (10.0 * cos(_timePassed * 2.0))
	var newPosition = Vector2(x, y)
	
	position = newPosition
	pass

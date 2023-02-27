extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	var _simple = Simple.new()
	var ret = _simple.myMethod()
	print(ret)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

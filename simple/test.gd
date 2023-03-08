extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	var _simple = Simple.new()
	var ret = _simple.myMethod()
	print(ret)
	var vec = Vector3(1.0, 3.2, 1.0)
	var ret2 = _simple.paramMethod(vec)
	print(ret2)
	_simple.isSame(_simple)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

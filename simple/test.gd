extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	var ret = $Simple.myMethod()
	print(ret)
	var vec = Vector3(1.0, 3.2, 1.0)
	var ret2 = $Simple.paramMethod(vec)
	print(ret2)
	$Simple.isSame($Simple)
	var viewport = $Simple.doSomething()
	print(viewport)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

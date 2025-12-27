extends Node

func _ready():
	var scene = load("res://Scenes/Login/LoginMenu.tscn")
	add_child(scene.instance(),true)


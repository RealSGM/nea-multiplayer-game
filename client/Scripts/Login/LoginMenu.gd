extends Control

func _ready():
	ClientStats.current_scene = "Login"

func _on_ExitButton_pressed():
	get_tree().quit()

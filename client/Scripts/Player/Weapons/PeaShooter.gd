extends SniperClass

func _input(_event):
	if Input.is_action_just_pressed("fire_weapon"):
		fire_weapon()
	elif Input.is_action_just_pressed("reload"):
		reload_weapon()
	elif Input.is_action_just_pressed("alternate_fire"):
		apply_scope()


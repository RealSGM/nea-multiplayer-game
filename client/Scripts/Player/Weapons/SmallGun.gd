extends WeaponController

var need_reloading = false

func _input(_event):
	if Input.is_action_just_pressed("fire_weapon"):
		fire_weapon()
	elif Input.is_action_just_pressed("reload"):
		reload_weapon()
		
			
func fire_weapon():
	# Overriden function to allow for burst mode
	need_reloading = false
	if !ClientStats.game_paused and currently_equipped and !ClientStats.is_dead:
		for _i in range(2):
			if current_ammo != 0:
				if current_weapon_state == IDLE:
					apply_recoil()
			else:
				need_reloading = true
		if need_reloading:
			reload_weapon()

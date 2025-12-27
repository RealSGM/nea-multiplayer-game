extends WeaponController

var need_reloading = false

func _input(_event):
	if Input.is_action_just_pressed("fire_weapon"):
		fire_weapon()
	elif Input.is_action_just_pressed("reload"):
		reload_weapon()

func fire_weapon():
	need_reloading = false
	# Burst 5 bullets
	for _i in range(5):	
		if current_weapon_state == IDLE and currently_equipped and !ClientStats.game_paused and !ClientStats.is_dead:
			if current_ammo != 0:
				current_weapon_state = SHOOTING
				
				var data_dict = {}
				data_dict["visuals_name"] = "shoot_weapon"
				data_dict["weapon_name"] = self.get_name()
				GameServer.send_visuals(data_dict)
				
				apply_muzzle_flash()
				$Tween.interpolate_property(self,"translation:z",null,resting_position+recoil_distance,recoil_speed,Tween.TRANS_LINEAR,Tween.EASE_IN)
				$Tween.start()
				yield(get_tree().create_timer(recoil_speed),"timeout")				
				$Tween.interpolate_property(self,"translation:z",null,resting_position,recoil_speed,Tween.TRANS_LINEAR,Tween.EASE_IN)
				$Tween.start()
				current_ammo -= 1
				update_counters()
				GameServer.update_client_inventory("bullets_fired",1)
				check_collision()
			else:
				need_reloading = true
				current_weapon_state = IDLE
			yield(get_tree().create_timer(fire_rate),"timeout")
			current_weapon_state = IDLE	
			
	yield(get_tree().create_timer(1),"timeout")
	if need_reloading:
		reload_weapon()

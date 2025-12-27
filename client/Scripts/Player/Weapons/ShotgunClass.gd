extends WeaponController

# Subclass to the base WeaponClass, used by shotguns
class_name ShotgunClass

func fire_weapon():
	# Similar to base class function, reloading can stop if you try to shoot
	if currently_equipped and !ClientStats.game_paused and !ClientStats.is_dead:
		if current_ammo != 0:
			if current_weapon_state == IDLE:
				apply_recoil()
			elif current_weapon_state == RELOADING:
				cancel_reload()
		else:
			reload_weapon()
		
func reload_weapon():
	# Checks to see if can reload
	if currently_equipped and !ClientStats.game_paused and !ClientStats.is_dead:
		if current_ammo < magazine_capacity and current_weapon_state == IDLE and total_magazines > 	0:
			for _i in range(magazine_capacity):
				# Starts reloading to fill entire shotgun capacity
				# Sends reload start state to server
				current_weapon_state = RELOADING
				var data_dict = {}
				data_dict["visuals_name"] = "start_reload"
				data_dict["weapon_name"] = self.get_name()
				GameServer.send_visuals(data_dict)
				$Tween.interpolate_property(self,"rotation_degrees:x",0,180,reload_rate,Tween.TRANS_LINEAR,Tween.EASE_OUT)
				$Tween.start()
				yield(get_tree().create_timer(reload_rate),"timeout")
				# Sends continue reload state to server
				data_dict["visuals_name"] = "continue_reload"
				GameServer.send_visuals(data_dict)
				$Tween.interpolate_property(self,"rotation_degrees:x",180,360,reload_rate,Tween.TRANS_LINEAR,Tween.EASE_OUT)
				$Tween.start()
				yield(get_tree().create_timer(reload_rate),"timeout")
				current_ammo += 1 
				total_magazines -= 1
				update_counters()
				
				# Checks if reloading must be stopped
				if current_ammo >= magazine_capacity:
					current_ammo = magazine_capacity
					update_counters()
					break
				elif total_magazines <= 0:
					break
				elif current_weapon_state == IDLE:
					break
			current_weapon_state = IDLE

extends WeaponController

# Sniper subclass from base WeaponClass
class_name SniperClass

var scoped = false

func apply_scope():
	if currently_equipped and !ClientStats.is_dead and !ClientStats.game_paused:
		scoped = !scoped
		self.visible = !scoped
		ClientStats.player_node.get_node("UI/HUD/Scope").visible = scoped
		ClientStats.player_node.get_node("UI/Crosshair").visible = !scoped
		if scoped:
			ClientStats.player_node.get_node("Head/Camera").fov = 20
			ClientStats.player_node.mouse_sensitivity  = ClientStats.mouse_sensitivity * ClientStats.scope_sensitivity
		else:
			ClientStats.player_node.get_node("Head/Camera").fov = ClientStats.fov
			ClientStats.player_node.mouse_sensitivity = ClientStats.mouse_sensitivity

func hide_weapon():
	# Same functionality, unscopes player if they are
	if scoped:
		apply_scope()
	self.visible = false
	currently_equipped = false
	cancel_reload()
	scoped = false
	
func reload_weapon():
	# Same functionality, unscopes player if they are
	if currently_equipped and !ClientStats.game_paused and !ClientStats.is_dead:
		if current_ammo != magazine_capacity:	
			if total_magazines > 0:
				if current_weapon_state == IDLE and !reload_pressed:			
					if scoped:
						apply_scope()
					current_weapon_state = RELOADING
					reload_timer.start()
					var data_dict = {}
					data_dict["visuals_name"] = "start_reload"
					data_dict["weapon_name"] = self.get_name()
					GameServer.send_visuals(data_dict)
					$Tween.interpolate_property(self,"rotation_degrees:x",0,180,reload_rate/2,Tween.TRANS_LINEAR,Tween.EASE_OUT)
					$Tween.start()
					yield(get_tree().create_timer(reload_rate/2),"timeout")
					if current_weapon_state == RELOADING:
						var data_dict_two = {}
						data_dict_two["visuals_name"] = "continue_reload"
						data_dict_two["weapon_name"] = self.get_name()
						GameServer.send_visuals(data_dict_two)
						$Tween.interpolate_property(self,"rotation_degrees:x",180,360,reload_rate/2,Tween.TRANS_LINEAR,Tween.EASE_OUT)
						$Tween.start()
						yield(get_tree().create_timer(reload_rate/2),"timeout")

extends WeaponController

onready var reset_timer = $ResetTimer
onready var explosion_particle = preload("res://Assets/Other/ExplosionParticlesMaterial.tres")
onready var rocket_projectile = preload("res://Assets/Other/Rocket.tscn")
var rocket_reset = true

func _ready():
	reset_timer.connect("timeout",self,"reset_rocket")
	reset_timer.set_wait_time(fire_rate)

func _input(_event):
	if Input.is_action_just_pressed("fire_weapon"):
		if !ClientStats.round_ended:
			fire_weapon()
	if Input.is_action_just_pressed("reload"):
		if rocket_reset:
			reload_weapon()
	
func fire_weapon():	
	if !ClientStats.game_paused and currently_equipped and !ClientStats.is_dead:
		if current_weapon_state == IDLE:
			if current_ammo != 0 and rocket_reset:
				var data_dict = {}
				data_dict["visuals_name"] = "shoot_weapon"
				data_dict["weapon_name"] = self.get_name()
				GameServer.send_visuals(data_dict)
				current_weapon_state = SHOOTING
				# Apply tween to jerk the launcher back
				$Tween.interpolate_property(self,"translation:z",null,resting_position+recoil_distance,recoil_speed,Tween.TRANS_LINEAR,Tween.EASE_OUT)
				$Tween.start()
				check_collision()
				yield(get_tree().create_timer(recoil_speed),"timeout")		
				# Update inventory		
				current_ammo -= 1
				update_counters()
				GameServer.update_client_inventory("bullets_fired",1)			
				rocket_reset = false
				reset_timer.start()
				# Aply tween to transition the launcher back to resting position
				$Tween.interpolate_property(self,"translation:z",null,resting_position,fire_rate,Tween.TRANS_LINEAR,Tween.EASE_OUT)
				$Tween.start()
				yield(get_tree().create_timer(fire_rate),"timeout")
				current_weapon_state = IDLE	
			else:
				if rocket_reset:
					reload_weapon()

func check_collision():
	# Send request to server to show for others
	if weapon_raycast.is_colliding():
		var data_dict = {}
		data_dict["visuals_name"] = "shoot_rocket"
		data_dict["weapon_name"] = self.get_name()
		data_dict["collision_point"] = weapon_raycast.get_collision_point()
		data_dict["grav_dir"] = ClientStats.player_node.gravity_direction
		GameServer.spawn_new_rigid_body(data_dict)
		
func spawn_new_rocket(data_dict):
	# Spawn new rocket in front of the launcher
	var rocket_instance = rocket_projectile.instance()
	rocket_instance.set_script(load("res://Scripts/Other/Rocket.gd"))
	rocket_instance.base_damage = data_dict["base_damage"]
	rocket_instance.get_node("Explosion").set_process_material(explosion_particle)		
	get_node("RocketSpawnPoint").add_child(rocket_instance,true)		
	rocket_instance.look_at(data_dict["collision_point"],data_dict["grav_dir"])

	rocket_instance.add_impulse()
	ClientStats.ability_instances.append(rocket_instance)
	
func reset_rocket():
	rocket_reset = true

func hide_weapon():
	# Hide each invidual mesh instance, as rocket node, despite being on top level
	# is still apart of the launcher subtree, therefore should not get hidden
	for child in get_children():
		if child is MeshInstance:
			child.hide()
	currently_equipped = false
	cancel_reload()
	
func show_weapon():
	# Since each individual mesh instance is hidden, each must be shown when this is called
	for child in get_children():
		if child is MeshInstance:
			child.show()
	currently_equipped = true

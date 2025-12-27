extends WeaponController

var charge_timer 
var l_particles
onready var laser_particles = preload("res://Assets/Other/LaserRifleParticles.tscn")

func _ready():
	set_process_input(false)
	# Setup laser line, same method as grapple hook
	charge_timer = Timer.new()
	charge_timer.set_name("ChargeTimer")
	add_child(charge_timer,true)
	while fire_rate == null:
		yield(get_tree().create_timer(0.1),"timeout")
	charge_timer.set_wait_time(fire_rate*0.9)
	charge_timer.connect("timeout",self,"fire_weapon")
	
	var laser_particles_instance = laser_particles.instance()
	l_particles = laser_particles_instance
	laser_particles_instance.set_emitting(false)
	laser_particles_instance.set_translation(Vector3(0,0,-1.125))
	add_child(laser_particles_instance,true)

	var laser_ray = Spatial.new()
	laser_ray.set_name("LaserAnchorPoint")
	add_child(laser_ray,true)
	
	var laser_line = CSGCylinder.new()
	laser_line.set_name("LaserLine")
	laser_line.set_radius(0.05)
	laser_line.set_rotation_degrees(Vector3(90,0,0))
	laser_ray.set_as_toplevel(true)
	laser_ray.hide()
	laser_line.show()
	laser_line.set_material_override(load("res://Materials/lasershader.tres"))
	laser_ray.add_child(laser_line,true)

	set_process_input(true)

func _input(_event):
	if Input.is_action_just_pressed("fire_weapon"):
		start_charge()
	elif Input.is_action_just_released("fire_weapon"):
		reset_charge()
	elif Input.is_action_just_pressed("reload"):
		reload_weapon()
	
	if ClientStats.game_paused:
		reset_charge()

func start_charge():
	if currently_equipped and !ClientStats.game_paused and !ClientStats.is_dead:	
		if current_ammo != 0:
			if current_weapon_state == IDLE:
				current_weapon_state = SHOOTING
				charge_timer.start()
				var data_dict = {}
				data_dict["visuals_name"] = "start_charge"
				data_dict["weapon_name"] = self.get_name()
				GameServer.send_visuals(data_dict)
				l_particles.set_emitting(true)
				l_particles.get_node("AP").play("start_charge")
				$Tween.interpolate_property(self,"translation:z",resting_position,resting_position+recoil_distance,fire_rate * 0.9,Tween.TRANS_LINEAR,Tween.EASE_OUT)
				$Tween.start()
				yield(get_tree().create_timer(fire_rate * 0.9),"timeout")				
				
		else:
			reload_weapon()
	
func reset_charge():
	var data_dict = {}
	data_dict["visuals_name"] = "reset_charge"
	data_dict["weapon_name"] = self.get_name()
	GameServer.send_visuals(data_dict)
	l_particles.get_node("AP").stop(true)
	l_particles.set_emitting(false)
	charge_timer.stop()
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property(self,"translation:z",null,resting_position,fire_rate * 0.1,Tween.TRANS_LINEAR,Tween.EASE_OUT)
	$Tween.start()
	yield(get_tree().create_timer(fire_rate*0.1),"timeout")
	current_weapon_state = IDLE

func fire_weapon():
	check_collision()
	charge_timer.stop()
	l_particles.get_node("AP").stop(true)
	l_particles.set_emitting(false)
	$Tween.interpolate_property(self,"translation:z",null,resting_position,fire_rate * 0.1,Tween.TRANS_LINEAR,Tween.EASE_OUT)
	$Tween.start()
	current_ammo -= 1
	GameServer.update_client_inventory("bullets_fired",1)
	update_counters()
	yield(get_tree().create_timer(fire_rate),"timeout")
	current_weapon_state = IDLE

func check_collision():
	# Check if the bullet shot has hit a player within appropriate range
	if weapon_raycast.is_colliding():	
		var collider = weapon_raycast.get_collider().get_name()
		var collision_point = weapon_raycast.get_collision_point()
		GameServer.send_player_collision_check_request(collider,collision_point,ClientStats.player_node.get_translation(),ClientStats.player_node.selected_gun)
		calculate_trajectory(collider,collision_point)

func calculate_trajectory(_collider,collision_point):
	var gun_location = $MuzzleFlash.get_global_transform().origin 
	var length  = (gun_location - collision_point).length()
	var anchor = get_node("LaserAnchorPoint")
	var line = anchor.get_node("LaserLine")
	anchor.set_translation(gun_location)
	anchor.look_at(collision_point,Vector3.UP)
	line.set_height(length)
	line.translation.z = length / -2
	anchor.show()
	yield(get_tree().create_timer(0.2),"timeout")
	anchor.hide()

	var data_dict = {}
	data_dict["visuals_name"] = "fire_charge"
	data_dict["weapon_name"] = self.get_name()
	data_dict["length"] = length
	data_dict["collision_point"] = collision_point
	GameServer.send_visuals(data_dict)
	
func hide_weapon():
	self.visible = false
	currently_equipped = false
	cancel_reload()
	reset_charge()

extends KinematicBody


var gun_names = []
var selected_gun = ""
var gun_details = []

onready var player_head = preload("res://Assets/Other/ServerPlayerHead.tres")
onready var explosion_particle = preload("res://Assets/Other/ExplosionParticlesMaterial.tres")
onready var rocket_projectile = preload("res://Assets/Other/Rocket.tscn")
onready var smoke_projectile = preload("res://Assets/Other/Smoke.tscn")
onready var smoke_particle = preload("res://Assets/Other/SmokeParticlesMaterial.tres")
onready var magic_shield = preload("res://Assets/Other/MagicShield.tscn")
onready var head = $Head
onready var l_particles

var has_moved = true

func _ready():
	$AnchorPoint.hide()
	$Head/ProjectileSpawn.show()

func move_player(new_position,new_rotation,new_player_rotation):
	# Move and rotate the player
	set_translation(new_position)
	rotation_degrees.y = new_player_rotation	
	$Head.set_rotation(new_rotation)
	has_moved = true

func instance_guns(player_guns,details):
	# Instance the guns, store selected gun
	gun_names = player_guns
	gun_details = details
	selected_gun = gun_names[0]
	
	for weapon in gun_names:
		var weapon_type = gun_details[weapon]["weapon_type"]
		var weapon_instance = load("res://Assets/GunModels/"+ weapon_type +".tscn").instance()
		var colour = gun_details[weapon]["colour"]
		var rejected_list = ["Tween","ResetTimer","ReloadTimer","ChargeTimer","MuzzleFlash","MuzzleFlash2","LaserRifleParticles","LaserAnchorPoint","RocketSpawnPoint"]

		gun_details[weapon]["resting_position"] = weapon_instance.translation.z
		weapon_instance.set_name(weapon)
		weapon_instance.hide()	
		
		# Update the colour of the gun
		for mesh in weapon_instance.get_children():
			if not(mesh.get_name() in rejected_list):	
				mesh.set_layer_mask(1)
				mesh.set_surface_material(0,load("res://Materials/" + colour +".tres"))
		# Setting up the laser rifle
		if weapon == "LaserRifle":
			var laser_particles = load("res://Assets/Other/LaserRifleParticles.tscn")
			var laser_particles_instance = laser_particles.instance()
			laser_particles_instance.set_name("LaserParticles")
			l_particles = laser_particles_instance
			laser_particles_instance.set_emitting(false)
			laser_particles_instance.set_translation(Vector3(0,0,-1.125))
			var laser_ray = Spatial.new()
			laser_ray.set_name("LaserAnchorPoint")
			add_child(laser_ray,true)		
			laser_ray.set_as_toplevel(true)
			laser_ray.show()
			var laser_line = CSGCylinder.new()
			laser_line.set_name("LaserLine")
			laser_line.set_radius(0.05)
			laser_line.set_rotation_degrees(Vector3(90,0,0))
			laser_line.set_material_override(load("res://Materials/lasershader.tres"))
			laser_line.hide()
			laser_ray.add_child(laser_line,true)
			
		head.add_child(weapon_instance,true)
		if weapon == "LaserRifle":
			head.get_node(weapon).add_child(l_particles,true)		
		
	set_current_weapon(selected_gun)
		
func apply_visuals(data_dict):
	# Runs the function based on the visual name
	var visuals_name = data_dict["visuals_name"]
	var weapon_name = data_dict["weapon_name"]
	match visuals_name:
		"shoot_weapon":
			shoot_weapon(weapon_name)
		"start_reload":
			start_reload(weapon_name)
		"continue_reload":
			continue_reload(weapon_name)
		"cancel_reload":
			cancel_reload(weapon_name)
		"start_charge":
			start_charge(weapon_name)
		"reset_charge":
			reset_charge(weapon_name)
		"fire_charge":
			fire_laser(data_dict)
		"shoot_rocket":
			shoot_rocket(data_dict)
		"apply_hook":
			apply_hook(data_dict)
		"break_hook":
			break_hook()
		"switch_weapon":
			set_current_weapon(weapon_name)
		"hide_player":
			hide_player()
		"show_player":
			show_player()
		"throw_smoke":
			throw_smoke(data_dict)
		"activate_magic_shield":
			activate_magic_shield(weapon_name)
		"despawn_player":
			queue_free()
		"instance_guns":
			var player_guns = data_dict["player_guns"]
			var details = data_dict["details"]
			instance_guns(player_guns,details)

func apply_muzzle_flash(weapon_name):
	if head.has_node(weapon_name + "/MuzzleFlash"):
		if head.get_node(weapon_name + "/MuzzleFlash").is_emitting():
			head.get_node(weapon_name + "/MuzzleFlash2").set_emitting(true)				
		else:	
			head.get_node(weapon_name + "/MuzzleFlash").set_emitting(true)	

func apply_recoil(weapon_name):
	if !gun_details.empty():
		$Tween.interpolate_property(head.get_node(weapon_name),"translation:z",null,gun_details[weapon_name]["recoil_distance"],gun_details[weapon_name]["return_speed"],Tween.TRANS_LINEAR,Tween.EASE_IN)
		$Tween.start()
		yield(get_tree().create_timer(gun_details[weapon_name]["return_speed"]),"timeout")		
		$Tween.interpolate_property(head.get_node(weapon_name),"translation:z",null,gun_details[weapon_name]["resting_position"],gun_details[weapon_name]["return_speed"],Tween.TRANS_LINEAR,Tween.EASE_IN)
		$Tween.start()

func set_current_weapon(current_gun):
	for child in head.get_children():
		if not "Spawn" in child.get_name():
			child.hide()
	if head.has_node(current_gun):
		head.get_node(current_gun).show()	
		
	if $Head.has_node("RocketLauncher"):
		get_node("Head/RocketLauncher/RocketSpawnPoint").set_visible(true)
	
func shoot_weapon(weapon_name):
	if weapon_name != "RocketLauncher":
		apply_muzzle_flash(weapon_name)
	apply_recoil(weapon_name)
	
func start_reload(weapon_name):
	$Tween.reset_all()
	$Tween.interpolate_property(head.get_node(weapon_name),"rotation_degrees:x",0,180,gun_details[weapon_name]["reload_rate"]/2,Tween.TRANS_LINEAR,Tween.EASE_OUT)
	$Tween.start()

func continue_reload(weapon_name):
	$Tween.interpolate_property(head.get_node(weapon_name),"rotation_degrees:x",180,360,gun_details[weapon_name]["reload_rate"]/2,Tween.TRANS_LINEAR,Tween.EASE_OUT)
	$Tween.start()

func cancel_reload(weapon_name):
	$Tween.stop_all()
	$Tween.remove_all()
	if head.has_node(weapon_name):
		head.get_node(weapon_name).rotation_degrees.x = 0

func start_charge(weapon_name):
	l_particles.set_emitting(true)
	l_particles.get_node("AP").play("start_charge")
	$Tween.interpolate_property(head.get_node(weapon_name),"translation:z",null,gun_details[weapon_name]["resting_position"]+gun_details[weapon_name]["recoil_distance"],gun_details[weapon_name]["fire_rate"] * 0.9,Tween.TRANS_LINEAR,Tween.EASE_OUT)
	$Tween.start()

func reset_charge(weapon_name):
	if has_node("Head/"+weapon_name+"/LaserParticles"):
		l_particles.get_node("AP").stop(true)
		l_particles.set_emitting(false)
	if head.has_node(weapon_name):
		$Tween.stop_all()
		$Tween.interpolate_property(head.get_node(weapon_name),"translation:z",null,gun_details[weapon_name]["resting_position"],gun_details[weapon_name]["fire_rate"] * 0.1,Tween.TRANS_LINEAR,Tween.EASE_OUT)
		$Tween.start()

func fire_laser(data_dict):
	var weapon_name = data_dict["weapon_name"]
	var collision_point = data_dict["collision_point"]
	var length = data_dict["length"]
	var gun_location = head.get_node(weapon_name + "/MuzzleFlash").get_global_transform().origin 
	var anchor = get_node("LaserAnchorPoint")
	var line = anchor.get_node("LaserLine")

	anchor.set_translation(gun_location)
	anchor.look_at(collision_point,Vector3.UP)
	line.set_height(length)
	line.translation.z = length / -2
	l_particles.get_node("AP").stop(true)
	l_particles.set_emitting(false)
	$Tween.interpolate_property(head.get_node(weapon_name),"translation:z",null,gun_details[weapon_name]["resting_position"],gun_details[weapon_name]["fire_rate"] * 0.1,Tween.TRANS_LINEAR,Tween.EASE_OUT)
	$Tween.start()
	
	line.show()
	yield(get_tree().create_timer(0.2),"timeout")
	line.hide()
	
func shoot_rocket(data_dict):
	var rocket_instance = rocket_projectile.instance()
	var collision_point = data_dict["collision_point"]
	var grav_dir = data_dict["grav_dir"]
	var weapon_name = data_dict["weapon_name"]
	var base_damage = data_dict["base_damage"]
	var rocket_spawn = head.get_node(weapon_name + "/RocketSpawnPoint")		
	rocket_spawn.translation.z = -4

	ClientStats.ability_instances.append(rocket_instance)	
	rocket_instance.get_node("Explosion").set_process_material(explosion_particle)		
	rocket_spawn.add_child(rocket_instance,true)
	rocket_instance.get_node("ExplosionArea").set_monitoring(false)
	rocket_instance.get_node("RocketArea").set_monitoring(true)
	rocket_instance.set_as_toplevel(true)
	rocket_instance.look_at(collision_point,grav_dir)
	rocket_instance.apply_impulse(rocket_instance.transform.basis.z,-rocket_instance.transform.basis.z*2.5)
	
	rocket_instance.get_node("RocketArea").connect("body_entered",self,"explode_rocket",[weapon_name,base_damage])

func explode_rocket(body,weapon_name,base_damage):
	if not "Rocket" in body.get_name():
		var rocket_path = "Head/" + weapon_name + "/RocketSpawnPoint"
		for rocket in get_node(rocket_path).get_children():
			rocket.get_node("Trail").set_emitting(false)
			rocket.get_node("MeshInstance").hide()
			rocket.get_node("AP").play("explode")
			rocket.set_sleeping(true)
			rocket.get_node("ExplosionArea").set_monitoring(true)
			rocket.get_node("ExplosionArea").connect("body_entered",self,"entered_explosion",[base_damage])
			rocket.get_node("AP").connect("animation_finished",self,"_on_AP_animation_finished")
		yield(get_tree().create_timer(2.0),"timeout")
		for rocket in get_node(rocket_path).get_children():
			rocket.hide()
		
func entered_explosion(body,base_damage):
	if body == ClientStats.player_node:
		var attacker_id = self.get_name()
		ClientStats.player_node.player_attacked(base_damage,attacker_id)

func apply_hook(data_dict):
	var hook_collision_point = data_dict["hook_collision_point"]
	var grav_dir = data_dict["grav_dir"]
	var hook_length = data_dict["hook_length"]
	$AnchorPoint.look_at(hook_collision_point,grav_dir)
	$AnchorPoint/HookLine.translation.z = hook_length / -2
	$AnchorPoint/HookLine.set_height(hook_length)
	$AnchorPoint.show()
	
func break_hook():
	$AnchorPoint.hide()

func hide_player():
	self.hide()
	self.get_node("CollisionShape").set_disabled(true)
	if $Head.has_node("RocketLauncher"):
		get_node("Head/RocketLauncher/RocketSpawnPoint").set_visible(true)
	
func show_player():
	self.show()
	self.get_node("CollisionShape").set_disabled(false)
	if $Head.has_node("RocketLauncher"):
		get_node("Head/RocketLauncher/RocketSpawnPoint").set_visible(true)
	
func throw_smoke(data_dict):
	var collision_point = data_dict["collision_point"]
	var grav_direction = data_dict["grav_dir"]
	var speed = data_dict["speed"]
	var smoke_instance = smoke_projectile.instance()
	smoke_instance.get_node("SmokeParticles").set_process_material(smoke_particle)
	head.get_node("ProjectileSpawn").add_child(smoke_instance,true)
	ClientStats.ability_instances.append(smoke_instance)
	smoke_instance.set_as_toplevel(true)
	smoke_instance.get_node("SmokeCanister").show()
	smoke_instance.get_node("SmokeParticles").hide()
	smoke_instance.get_node("CanisterArea").connect("body_entered",self,"release_smoke",[smoke_instance.get_name()])
	smoke_instance.look_at(collision_point,grav_direction)	
	smoke_instance.apply_impulse(smoke_instance.transform.basis.z,-smoke_instance.transform.basis.z*speed)
	
func release_smoke(body,weapon_name):
	if not "Smoke" in body.get_name():
		var smoke = head.get_node("ProjectileSpawn/"+weapon_name)
		var particles = smoke.get_node("SmokeParticles")
		var canister = smoke.get_node("SmokeCanister")
		smoke.set_sleeping(true)
		particles.show()
		particles.set_emitting(true)
		canister.hide()
		yield(get_tree().create_timer(10),"timeout")
		remove_smoke(weapon_name)

func remove_smoke(weapon_name):
	if head.get_node("ProjectileSpawn").has_node(weapon_name):
		var smoke = head.get_node("ProjectileSpawn/"+weapon_name)
		if smoke.has_node("SmokeParticles"):
			var particles = smoke.get_node("SmokeParticles")
			particles.set_emitting(false)
			yield(get_tree().create_timer(1),"timeout")
			smoke.hide()

func activate_magic_shield(weapon_name):
	if not $Head/ShieldSpawn.has_node(weapon_name):
		var shield_instance = magic_shield.instance()
		shield_instance.get_node("ShieldBody/CollisionShape").set_disabled(false)
		$Head/ShieldSpawn.add_child(shield_instance,true)
		yield(get_tree().create_timer(5),"timeout")
		shield_instance.queue_free()

func _on_AP_animation_finished(anim_name):
	if anim_name == "explode":
		for node in get_node("Head/ProjectileSpawn").get_children():
			node.hide()

func _on_Timer_timeout():
	if has_moved:
		has_moved = false
	else:
		queue_free()

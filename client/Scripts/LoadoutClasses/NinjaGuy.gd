extends Node

onready var smoke_grenade
onready var smoke_particles 
var weapon_raycast
var projectile_spawn

func prepare_class():
	# Preload smoke particles to prevent lag on use
	# Store weapon raycast reference and creates projectile spawn location node
	smoke_grenade = preload("res://Assets/Other/Smoke.tscn")
	smoke_particles = preload("res://Assets/Other/SmokeParticlesMaterial.tres")
	weapon_raycast = get_parent().camera.get_node("WeaponRayCast")
	projectile_spawn = Spatial.new()
	projectile_spawn.set_name("ProjectileSpawn")
	projectile_spawn.set_translation(Vector3(0,-0.8,-2))
	get_parent().camera.add_child(projectile_spawn,true)
	
func activate_ability():
	# Send request to spawn a new smoke
	if weapon_raycast.is_colliding():	
		var data_dict = {}
		data_dict["visuals_name"] = "throw_smoke"
		data_dict["speed"] = 5
		data_dict["weapon_name"] = ""
		data_dict["collision_point"] = weapon_raycast.get_collision_point()
		data_dict["grav_dir"] = get_parent().gravity_direction
		GameServer.spawn_new_rigid_body(data_dict)

		get_parent().speed = 16
		get_parent().jump_power = 12

func check_event():
	pass
	
func reset_ability():
	# Reset movement variables back to original
	get_parent().speed = 12
	get_parent().jump_power = 10
	
func spawn_new_smoke(data_dict):
	# Instance a new smoke grenade, apply impulse to get it moving
	var smoke_instance = smoke_grenade.instance()
	smoke_instance.set_script(load("res://Scripts/Other/Smoke.gd"))
	smoke_instance.get_node("SmokeParticles").set_process_material(smoke_particles)
	projectile_spawn.add_child(smoke_instance,true)
	ClientStats.ability_instances.append(smoke_instance)
	smoke_instance.look_at(data_dict["collision_point"],data_dict["grav_dir"])
	smoke_instance.add_impulse()
	

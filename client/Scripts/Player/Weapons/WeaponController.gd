extends Spatial

# Base class for all weapons
class_name WeaponController

# Data retrieved from database
var weapon_type = ""
var fire_mode = "" 
var fire_rate = 1.0
var description = ""
var magazine_capacity = 1
var total_magazines = 1
var reload_rate = 1.0
var colour = "R"
var recoil_distance = 1.0
var recoil_speed = 0.1

var resting_position 
var current_ammo = 0
var currently_equipped = false
var reload_pressed = false
onready var weapon_raycast 
onready var reload_timer

# Different weapon states
enum{
	RELOADING,
	SHOOTING,
	IDLE}
var current_weapon_state = IDLE

func update_weapon(weapon_details):
	#Makes sure _ready function of player script has run first
	while ClientStats.player_node == null:
		yield(get_tree().create_timer(0.1),"timeout")
	# Variable assignment
	weapon_raycast = ClientStats.player_node.get_node("Head/Camera/WeaponRayCast")
	reload_timer = self.get_node("ReloadTimer")
	# Connects the indiviual guns reload timers to the scripts
	if self.get_name() != "WeaponClass" and !reload_timer.is_connected("timeout",self,"reload_finished"):
		reload_timer.connect("timeout",self,"reload_finished")
	# Accompanies database fields to the script variables
	weapon_type = weapon_details["weapon_type"]
	fire_mode = weapon_details["fire_mode"]
	description = weapon_details["description"]
	magazine_capacity = weapon_details["magazine_capacity"]
	total_magazines = int(weapon_details["total_magazines"])
	fire_rate = float(weapon_details["fire_rate"])
	reload_rate = float(weapon_details["reload_rate"])
	colour = weapon_details["colour"]
	recoil_distance = float(weapon_details["recoil_distance"])
	recoil_speed = float(weapon_details["return_speed"])
	# Other preparation
	current_ammo = magazine_capacity
	reload_timer.set_wait_time(reload_rate)
	resting_position = self.translation.z
		
func fire_weapon():
	# Check if can fire, then shoot weapon
	if !ClientStats.game_paused  and !ClientStats.is_dead and currently_equipped:
		if current_weapon_state == IDLE:
			if current_ammo != 0:
				apply_recoil()	
			else: 
				# Reload if no bullets and player tries to shoot
				reload_weapon()

func apply_recoil():
	# Send visual update to server
	var data_dict = {}
	data_dict["visuals_name"] = "shoot_weapon"
	data_dict["weapon_name"] = self.get_name()
	GameServer.send_visuals(data_dict)
	# Change weapon state
	current_weapon_state = SHOOTING
	apply_muzzle_flash()
	# Interpolate recoil effect of a gun
	$Tween.interpolate_property(self,"translation:z",null,resting_position+recoil_distance,recoil_speed,Tween.TRANS_LINEAR,Tween.EASE_IN)
	$Tween.start()
	yield(get_tree().create_timer(recoil_speed),"timeout")		
	$Tween.interpolate_property(self,"translation:z",null,resting_position,recoil_speed,Tween.TRANS_LINEAR,Tween.EASE_IN)
	$Tween.start()
	# Reduce ammo
	current_ammo -= 1
	GameServer.update_client_inventory("bullets_fired",1)
	check_collision()
	update_counters()
	yield(get_tree().create_timer(fire_rate),"timeout")
	current_weapon_state = IDLE
	
func check_collision():
	# Check if the bullet shot has hit a player within appropriate range
	if weapon_raycast.is_colliding():	
		var collider = weapon_raycast.get_collider().get_name()
		var collision_point = weapon_raycast.get_collision_point()
		GameServer.send_player_collision_check_request(collider,collision_point,ClientStats.player_node.get_translation(),ClientStats.player_node.selected_gun)

func reload_weapon():
	# Check that player can reload their weapon
	if currently_equipped and !ClientStats.game_paused and !ClientStats.is_dead:
		if current_ammo != magazine_capacity and total_magazines > 0:	
			if current_weapon_state == IDLE and !reload_pressed:
				# Start reloading
				var data_dict = {}
				data_dict["visuals_name"] = "start_reload"
				data_dict["weapon_name"] = self.get_name()
				GameServer.send_visuals(data_dict)
				current_weapon_state = RELOADING
				reload_pressed = true
				reload_timer.start()
				$Tween.reset_all()
				$Tween.remove_all()
				$Tween.interpolate_property(self,"rotation_degrees:x",0,180,reload_rate/2,Tween.TRANS_LINEAR,Tween.EASE_OUT)
				$Tween.start()
				yield(get_tree().create_timer(reload_rate/2),"timeout")
				if current_weapon_state == RELOADING:
					var data_dict_two = {}
					data_dict_two["visuals_name"] = "continue_reload"
					data_dict_two["weapon_name"] = self.get_name()
					GameServer.send_visuals(data_dict_two)
					$Tween.reset_all()
					$Tween.remove_all()
					$Tween.interpolate_property(self,"rotation_degrees:x",180,360,reload_rate/2,Tween.TRANS_LINEAR,Tween.EASE_OUT)
					$Tween.start()
					yield(get_tree().create_timer(reload_rate/2),"timeout")
			
func cancel_reload():
	# Cancel a reload if a user switches to the other weapon while reloading
	reload_timer.stop()
	$Tween.stop_all()
	$Tween.reset_all()
	$Tween.remove_all()
	self.rotation_degrees.x = 0
	self.translation.z = resting_position
	current_weapon_state = IDLE
	reload_pressed = false	
	var data_dict = {}
	data_dict["visuals_name"] = "cancel_reload"
	data_dict["weapon_name"] = self.get_name()
	GameServer.send_visuals(data_dict)

func reload_finished():
	if currently_equipped and current_weapon_state == RELOADING:
		total_magazines -= 1
		current_ammo = magazine_capacity
		current_weapon_state = IDLE
		update_counters()
		reload_pressed = false
		
func update_counters():
	var hud = ClientStats.player_node.get_node("UI/HUD")
	hud.get_node("VBC/MagazinesLeft").set_text("Magazines Left: " + str(total_magazines))
	hud.get_node("VBC/AmmoRemaining").set_text("Ammo Left: " + str(current_ammo) + " : " + str(magazine_capacity))
	
func apply_muzzle_flash():
	# Emit the muzzle flash particle
	if $MuzzleFlash.is_emitting():
		$MuzzleFlash2.set_emitting(true)				
	else:	
		$MuzzleFlash.set_emitting(true)	
	
func show_weapon():
	self.visible = true
	currently_equipped = true
	
func hide_weapon():
	self.visible = false
	currently_equipped = false
	cancel_reload()
	

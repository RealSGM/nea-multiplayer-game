extends Node

var hook_timer 
var hook_raycast
var ceiling_detection
var anchor_point
var hook_line

const hook_speed = 0.1
var is_hooked = false
var hook_length = 0
var hook_collision_point = Vector3.ZERO
var can_hook = true
var hook_point
var hook_cooldown = false

func prepare_class():
	# Instance raycasts, enable and change cast point
	hook_raycast = RayCast.new()
	hook_raycast.set_exclude_parent_body(true)
	hook_raycast.set_enabled(true)
	hook_raycast.set_cast_to(Vector3(0,0,-200))
	get_parent().camera.add_child(hook_raycast,true)
	
	ceiling_detection = RayCast.new()
	ceiling_detection.set_exclude_parent_body(true)
	ceiling_detection.set_enabled(true)
	ceiling_detection.set_cast_to(Vector3(0,0.5,0))
	ceiling_detection.set_name("CeilingDetection")
	get_parent().camera.add_child(ceiling_detection,true)
	
	# Store hook point reference
	var world_node = get_node("/root/MainScene/World")
	hook_point = world_node.get_node("HookPoint")
	# Add hook timer, connect signal and wait time
	hook_timer = Timer.new()
	hook_timer.set_one_shot(true)
	hook_timer.set_wait_time(2)
	hook_timer.set_name("HookTimer")
	hook_timer.connect("timeout",self,"_on_HookTimer_timeout")
	get_parent().add_child(hook_timer,true)
	# Add anchor point, change node name
	anchor_point = Spatial.new()
	anchor_point.set_name("AnchorPoint")
	get_parent().add_child(anchor_point,true)
	# Add hook line, set radius and rotation of hook line and colour
	hook_line = CSGCylinder.new()
	hook_line.set_name("HookLine")
	hook_line.set_radius(0.05)
	hook_line.set_rotation_degrees(Vector3(90,0,0))
	hook_line.set_material_override(load("res://Materials/outlineshader.tres"))
	hook_line.hide()
	anchor_point.add_child(hook_line,true)
	
func check_event():	
	check_hook()	
	if is_hooked:	
		hook_length = (hook_collision_point-get_parent().get_translation()).length()
		draw_rope()
		# Draw the player closes to the target position
		if hook_length > 3:
			get_parent().transform.origin = lerp(get_parent().transform.origin, hook_collision_point * 0.98, hook_speed)
		else:
			break_hook()
	#If player has hit their head, move player down to prevent them form being stuck		
	if ceiling_detection.is_colliding():
		break_hook()
		can_hook = false
		get_parent().translation = lerp(get_parent().translation, get_parent().translation - Vector3(0,2,0),0.4)
		can_hook = true

func check_hook():
	if hook_raycast.is_colliding() and !is_hooked:		
		hook_collision_point = hook_raycast.get_collision_point()
		hook_point.set_translation(hook_collision_point)
		hook_point.show()	
		if !hook_cooldown:
			if Input.is_action_just_pressed("shoot_hook"):
				is_hooked = true
				get_parent().can_move = false
				hook_line.show()
	else:
		hook_point.hide()

func draw_rope():
	# Calcualte own rope transform, send data to server
	anchor_point.look_at(hook_collision_point,get_parent().gravity_direction)
	hook_line.set_height(hook_length)
	hook_line.translation.z = hook_length / -2
	
	var data_dict = {}
	data_dict["visuals_name"] = "apply_hook"
	data_dict["hook_collision_point"] = hook_collision_point
	data_dict["grav_dir"] = Vector3.UP
	data_dict["hook_length"] = hook_length
	data_dict["weapon_name"] = ""
	GameServer.send_visuals(data_dict)
	
func break_hook():
	is_hooked = false
	get_parent().can_move = true
	hook_line.hide()
	
	# Tell server to hide hook from other players
	var data_dict = {}
	data_dict["visuals_name"] = "break_hook"
	data_dict["weapon_name"] = ""
	GameServer.send_visuals(data_dict)
	
func _on_HookTimer_timeout():
	hook_cooldown = false

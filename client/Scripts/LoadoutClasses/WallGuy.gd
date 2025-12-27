extends Node

var wall_run_left
var wall_run_up_left
var wall_run_right
var wall_run_up_right
var wall_run_end_timer

var is_wall_running = false
var wall_run_direction = NULL
var wall_run_end = true

enum {
	LEFT,
	RIGHT,
	NULL
}

func prepare_class():
	wall_run_left = RayCast.new()
	wall_run_left.set_name("WallRunLeft")
	wall_run_left.set_cast_to(Vector3(-0.8,0,0))
	wall_run_left.set_translation(Vector3(0,-0.5,0))
	wall_run_left.set_enabled(true)
	wall_run_left.set_exclude_parent_body(true)
	get_parent().camera.add_child(wall_run_left,true)
	wall_run_up_left = RayCast.new()
	wall_run_up_left.set_name("WallRunUpLeft")
	wall_run_up_left.set_cast_to(Vector3(-0.8,0,0))
	wall_run_up_left.set_translation(Vector3(0,0.5,0))
	wall_run_up_left.set_enabled(true)
	wall_run_up_left.set_exclude_parent_body(true)
	get_parent().camera.add_child(wall_run_up_left,true)
	wall_run_right = RayCast.new()
	wall_run_right.set_name("WallRunRight")
	wall_run_right.set_cast_to(Vector3(0.8,0,0))
	wall_run_right.set_translation(Vector3(0,-0.5,0))
	wall_run_right.set_enabled(true)
	wall_run_right.set_exclude_parent_body(true)
	get_parent().camera.add_child(wall_run_right,true)
	wall_run_up_right = RayCast.new()
	wall_run_up_right.set_name("WallRunUpRight")
	wall_run_up_right.set_cast_to(Vector3(0.8,0,0))
	wall_run_up_right.set_translation(Vector3(0,0.5,0))
	wall_run_up_right.set_enabled(true)
	wall_run_up_right.set_exclude_parent_body(true)
	get_parent().camera.add_child(wall_run_up_right,true)
	wall_run_end_timer = Timer.new()
	wall_run_end_timer.set_one_shot(true)
	wall_run_end_timer.set_wait_time(0.4)
	wall_run_end_timer.set_name("WallRunEndTimer")
	wall_run_end_timer.connect("timeout",self,"wall_run_end_timer_timeout")
	get_parent().add_child(wall_run_end_timer,true)
	
func activate_ability():
	pass
	
func check_event():
	if wall_run_left != null and wall_run_right != null:
		if !is_wall_running:
			# Requirements for wall running
			if get_parent().camera_x_rotation < 50  and !get_parent().is_on_floor():
				# Detect if the player is trying to collide with wall on their left
				if wall_run_left.is_colliding() and Input.is_action_pressed("move_left"):
					get_parent().tween.interpolate_property(get_parent().camera,"rotation",null,Vector3(get_parent().camera.rotation.x,get_parent().camera.rotation.y,deg2rad(-get_parent().camera_tilt)),0.2,get_parent().tween.TRANS_SINE,get_parent().tween.EASE_IN)
					get_parent().tween.start()
					is_wall_running = true
					wall_run_direction =  LEFT
				# Detect if the player is trying to collide with wall on their right	
				elif wall_run_right.is_colliding() and Input.is_action_pressed("move_right"):
					get_parent().tween.interpolate_property(get_parent().camera,"rotation",null,Vector3(get_parent().camera.rotation.x,get_parent().camera.rotation.y,deg2rad(get_parent().camera_tilt)),0.2,get_parent().tween.TRANS_SINE,get_parent().tween.EASE_IN)
					get_parent().tween.start()
					is_wall_running = true
					wall_run_direction = RIGHT
				
		elif is_wall_running:
			# Checks if player has stopped wall running
			if !wall_run_left.is_colliding() and !wall_run_right.is_colliding() or get_parent().camera_x_rotation > 50:
				reset_wall_run()

		apply_wall_run()

func apply_wall_run():
	if is_wall_running:
		# Reset gravity
		get_parent().gravity_vector.y = 0
		get_parent().direction -= get_parent().head_basis.z
		
			
		match wall_run_direction:
			LEFT:
				if Input.is_action_pressed("jump"):
					apply_jump_force(1,2)
					if !wall_run_up_left.is_colliding():
						reset_wall_run()
				if Input.is_action_pressed("move_right"):
					reset_wall_run()
			RIGHT:
				if Input.is_action_pressed("jump"):
					apply_jump_force(1,2)
					if !wall_run_up_right.is_colliding():
						reset_wall_run()
				if Input.is_action_pressed("move_left"):
					reset_wall_run()
	
func reset_wall_run():
	# Occurs when player has stopped wall running
	get_parent().tween.interpolate_property(get_parent().camera,"rotation",null,Vector3(get_parent().camera.rotation.x,get_parent().camera.rotation.y,0),0.25,get_parent().tween.TRANS_SINE,get_parent().tween.EASE_IN)
	get_parent().tween.start()
	is_wall_running = false
	wall_run_direction = NULL
	get_parent().jump_counter = 0
	wall_run_end = true
	wall_run_end_timer.start()
	
func wall_run_end_timer_timeout():
	wall_run_end = false

func apply_jump_force(modifier,extra_jump):
	# Allows for wall scaling
	if wall_run_end and (wall_run_left.is_colliding() or wall_run_right.is_colliding()):
		extra_jump += 3
	get_parent().gravity_vector += (get_parent().gravity_direction * ((get_parent().jump_power * modifier) + extra_jump))

extends KinematicBody

# User Interface
# Enumeration for scoreboard 
enum{
	INT,
	STR,
	FLT,
}
const message_line = preload("res://Scenes/Player/UI/Message.tscn")
onready var scoreboard = $UI/Scoreboard
var chat_opened = false
var notification_count = 0
var selected_sort = "player_name"
# Settings
var mouse_sensitivity = 0.2
# Camera 
onready var camera = $Head/Camera
onready var head = $Head
var camera_x_rotation = 0
var camera_tilt = 20
# Movement 
const NORMAL_ACCELERATION = 5
const NORMAL_GRAVITY = 3*9.81
var head_basis
var normal_speed = 12
var max_jumps = 1
var speed = normal_speed
var gravity = NORMAL_GRAVITY
var movement = Vector3.ZERO
var h_velocity = Vector3.ZERO
var direction = Vector3.ZERO
var gravity_vector = Vector3.ZERO
var gravity_direction = Vector3.UP
var h_acceleration = 8
var air_acceleration = 0.1
var jump_counter = 0
var jump_power = 10
var can_move = true
var temp_distance_travelled = 0.0
# FPS
onready var tween = $Tween
onready var ld = $LoadoutClass
var current_health = 100
var max_health = 100
var gun_names = []
var gun_scenes = []
var selected_gun
var has_ability = false
var ability_reset = true

func _ready():
	# Store reference to the nodepath to the player node
	ClientStats.player_node = self
	ClientStats.current_scene = "World"
	# Connecting Options signal
	$UI/Menu/VBC/Exit.connect("pressed",self,"exit_player")
	$UI/Menu/VBC/Options.connect("pressed",self,"options_menu")
	$UI/Menu/VBC/ExitToLobby.connect("pressed",self,"exit_to_lobby")
	camera.fov = ClientStats.fov
	mouse_sensitivity = ClientStats.mouse_sensitivity
	# Inital prepartion for the player 
	GameServer.fetch_player_inventory("InitialPreparation")
	prepare_classes()
	check_for_abilities()
	spawn_weapons()
	
func _input(event):	
	if !ClientStats.game_paused:
		# What occurs when game is not paused	
		if event is InputEventMouseMotion:
			# Mouse movement of FPS Controller		
			head.rotate_y(deg2rad(-event.relative.x* mouse_sensitivity))
			if !((event.relative.y > 0 and camera.rotation.x <= -1.3) or (event.relative.y < 0 and camera.rotation.x >= 1.3)):
				camera.rotate_x(deg2rad(-event.relative.y * mouse_sensitivity))
			camera.rotation.x = clamp(camera.rotation.x,-PI/2,PI/2)
		# Toggling the Scoreboard on
		if event.is_action_pressed("open_scoreboard"):
			scoreboard.show()
			ClientStats.game_paused = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif ClientStats.game_paused:
		# Toggling the Scoreboard off
		if !$UI/Menu.visible:
			if event.is_action_pressed("open_scoreboard"):
				scoreboard.hide()
				ClientStats.game_paused = false
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Pause Menu
	if event.is_action_pressed("ui_cancel"):
		# UI Elements are hidden
		ClientStats.game_paused = !ClientStats.game_paused
		$UI/Crosshair.visible = !ClientStats.game_paused
		$UI/Menu.visible = ClientStats.game_paused
		$UI/Options.hide()
		scoreboard.hide()
		$UI/Chat.hide()
		if ClientStats.game_paused:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Code which applies when not paused and not dead
	if !ClientStats.game_paused and !ClientStats.is_dead:
		# Close Chat if open whilst not paused
		if event.is_action_pressed("ui_cancel"):
			close_chat()
		# Weapon Selection
		if Input.is_action_just_pressed("primary_weapon"):
			weapon_selector(0)
		elif Input.is_action_just_pressed("secondary_weapon"):
			weapon_selector(1)
		# Ability Usage		
		elif Input.is_action_just_pressed("ability") and has_ability:
			if ability_reset and !ClientStats.round_ended:
				var balance = int($UI/HUD/VBC/Balance.get_text())
				if balance > ClientStats.class_details["ability_cost"]:
					activate_ability(balance)
	# Chat Feature
	if chat_opened:
		if event.is_action_pressed("ui_enter"):
			if $UI/Chat/ColorRect/ChatContainer/LineEdit.get_text() == "":
				close_chat()
			else:
				var message = $UI/Chat/ColorRect/ChatContainer/LineEdit.get_text()
				GameServer.send_message(message)
	elif !chat_opened and !ClientStats.game_paused:
		if (Input.is_action_just_pressed("ui_enter") or Input.is_action_just_pressed("open_chat")):
			open_chat()

func _process(_delta):
	if !ClientStats.is_dead:
		# Alligns the gun camera with the FPS Camera
		$Head/Camera/VPC/VC/GunCamera.global_transform = camera.global_transform
		if !$AbilityTimer.is_stopped():
			# Decrease the value of the ability progress bar
			$UI/HUD/Ability/ProgressBar.set_value(int($AbilityTimer.get_time_left()))

func _physics_process(delta):
	if !ClientStats.is_dead:
		# Returns Head Basis
		head_basis = head.get_global_transform().basis
		direction = Vector3()	
		check_jump_force(delta)
		if !ClientStats.game_paused: 
			check_movement()
			ld.check_event()
		apply_movement(delta)
		define_player_state()

func _on_AbilityTimer_timeout():
	get_node("UI/HUD/Ability").set_self_modulate(Color(1,1,1,1))
	ability_reset = true
	
func _on_StatsTimer_timeout():
	GameServer.update_client_inventory("distance_travelled",temp_distance_travelled)
	temp_distance_travelled = 0.0	

func prepare_client(inv)	:
	prepare_hud(inv)
	prepare_scoreboard(inv)
	
func prepare_hud(inv):
	# Ensures gun camera is at same resolution as the screen
	$Head/Camera/VPC/VC.set_size(OS.get_screen_size())
	$Head/Camera/VPC.set_size(OS.get_screen_size())
	# General FPS features
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().set_auto_accept_quit(false)
	# Hide most UI Features
	$UI/Menu.visible = false
	$UI/Chat.hide()
	scoreboard.hide()
	$UI/Options.hide()
	prepare_health()
	update_balance_label(str(inv["balance"]))

func prepare_health():
	# Set health to that of the loadout's property
	max_health = ClientStats.class_details["max_health"]
	current_health = max_health
	$UI/HUD/HealthBar.set_max(max_health)
	$UI/HUD/HealthBar.set_value(current_health)
	$AbilityTimer.set_wait_time(10.0)
	$UI/HUD/Ability/ProgressBar.set_value(10)
	
func weapon_selector(index):
	# Weapon switching code
	selected_gun = gun_names[index]
	camera.get_node(selected_gun).update_counters()
	gun_scenes[index].show_weapon()
	gun_scenes[1-index].hide_weapon()
	var data_dict = {}
	data_dict["weapon_name"] = selected_gun
	data_dict["visuals_name"] = "switch_weapon"
	GameServer.send_visuals(data_dict)
	
func check_jump_force(delta):
	if can_move:
		if !is_on_floor():
			# Appplies gravity when not on the floor
			gravity_vector -= gravity_direction * gravity * delta
			h_acceleration = air_acceleration
		else:
			# Applies gravity in the direction opposite direction of the normal
			jump_counter = 0
			gravity_vector = -get_floor_normal()
			h_acceleration = NORMAL_ACCELERATION
	else:
		# Gravity is "disabled", user cannot fall during events like wall-running or grappling
		gravity_vector.y = 0
	if !ClientStats.game_paused and !ClientStats.is_dead:
		if Input.is_action_pressed("jump"):
			# Regular jump
			if is_on_floor():
				apply_jump_force(1,1)
		if Input.is_action_just_pressed("jump"):
			# Jump mid-air
			if !is_on_floor() and jump_counter <= max_jumps:
				apply_jump_force(1,1)
	
func apply_jump_force(modifier,extra_jump):
	# Applying a jump force away from normal // mid air
	jump_counter += 1
	gravity_vector += (gravity_direction * ((jump_power * modifier) + extra_jump))

func check_movement():
	# Calculates the direction player is moving
	if !ClientStats.game_paused and !ClientStats.is_dead:
		direction += head_basis.z * (Input.get_action_strength("move_backwards") - Input.get_action_strength("move_forwards"))
		direction += head_basis.x * (Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
		# Provides sense of momentum when mid-air / friction on the ground
		if Input.is_action_pressed("move_forwards") or Input.is_action_pressed("move_backwards") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			air_acceleration = 5
		else:
			air_acceleration = 0.1
	
func apply_movement(delta):
	# Calculates the movement vector
	direction = direction.normalized()
	h_velocity = lerp(h_velocity,direction*speed,h_acceleration*delta)
	# Combining the interpolated horizontal velocity and the gravity vector
	movement.z = h_velocity.z + gravity_vector.z
	movement.x = h_velocity.x + gravity_vector.x
	movement.y = gravity_vector.y
	# Current distance from O Vector
	var t1 = translation.length()
	if can_move:
		movement = move_and_slide(movement,gravity_direction,false,4, 0.9)
	# New distance from 0 Vector
	var t2 = translation.length()
	# Calculates change in distance and updates the Client Stats Distance Travelled
	temp_distance_travelled += stepify(abs(t2-t1),0.1)

func send_message(message,_your_message,player_id):
	# Sencing the message to the Chat
	if str(player_id) == str(ClientStats.player_network_id):
		$UI/Chat/ColorRect/ChatContainer/LineEdit.set_text("")
	var new_message = message_line.instance()
	new_message.set_text(str(message))
	$UI/Chat/ColorRect/ChatContainer/HBoxContainer/MessageContainer.add_child(new_message,true)
	var scroll_bar = $UI/Chat/ColorRect/ChatContainer/HBoxContainer/_v_scroll
	yield(get_tree().create_timer(0.1),"timeout")
	scroll_bar.value = scroll_bar.max_value - scroll_bar.page
	player_sent_message()
	
func player_sent_message():
	# Updating the Notification counter
	notification_count += 1
	if chat_opened:
		notification_count = 0
		
	if notification_count >= 1:
		var notification_message = str(notification_count)
		if notification_count > 9:
			notification_message = "9+"
		$UI/Notification.show()
		$UI/Notification/ColorRect/Label.set_text(notification_message)
	else:
		$UI/Notification.hide()

func close_chat():
	# Hiding the Chat and resuming the game
	ClientStats.game_paused = false
	chat_opened = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$UI/Chat.hide()

func open_chat():
	# Opening the Chat
	$UI/Chat/ColorRect/ChatContainer/LineEdit.set_text("")
	notification_count = 0
	chat_opened = true
	ClientStats.game_paused = true
	$UI/Chat/ColorRect/ChatContainer/LineEdit.set_focus_mode(Control.FOCUS_ALL)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Hiding other UI elements
	scoreboard.hide()
	$UI/Notification.hide()
	$UI/Chat.show()
	
func define_player_state():
	# Creating a player state for the game server to receive
	var player_state  = {
		"T": OS.get_system_time_msecs(),
		"P":get_translation(),
		"R1":camera.get_rotation(),
		"R2":head.rotation_degrees.y
		}
	GameServer.send_player_state(player_state)
	
func exit_player():
	# Sending data to the game server before leaving
	GameServer.send_disconnect_player()
	get_tree().quit()

func options_menu():
	# Hide the Pause Menu and show the Options Menu
	$UI/Menu.hide()
	$UI/Options.show()

func spawn_weapons():
	gun_names = ClientStats.player_guns.keys()
	# Instance each weapon and set its respective script,colour and runs update function
	for weapon in gun_names:
		var weapon_type = ClientStats.player_guns[weapon]["weapon_type"]
		var weapon_instance = load("res://Assets/GunModels/"+ weapon_type +".tscn").instance()
		var weapon_script  = load("res://Scripts/Player/Weapons/" + weapon + ".gd")
		var colour = ClientStats.player_guns[weapon]["colour"]
		weapon_instance.set_script(weapon_script)
		weapon_instance.set_name(weapon)
		weapon_instance.update_weapon(ClientStats.player_guns[weapon])
		camera.add_child(weapon_instance,true)
		weapon_instance.hide_weapon()
		gun_scenes.append(weapon_instance)
		# Update the colour of the gun
		for mesh in weapon_instance.get_children():
			if mesh is MeshInstance:
				mesh.set_surface_material(0,load("res://Materials/" + colour +".tres"))
				
	# Show the current weapon and update the HUD 	
	selected_gun = gun_names[0]
	camera.get_node(selected_gun).show_weapon()
	camera.get_node(selected_gun).update_counters()

func player_attacked(damage,attacker_id):
	# Damage player
	current_health = max(0,current_health-damage)
	$UI/HUD/HealthBar.set_value(current_health)
	# Checks for if the player has been killed
	if current_health == 0:
		ClientStats.is_dead = true
		GameServer.update_client_inventory("deaths",1)
		GameServer.player_killed_by_other_player(attacker_id)
		# Hides the weapons
		for weapon in ClientStats.player_guns.keys():
			ClientStats.player_node.camera.get_node(weapon).hide_weapon()
	
func update_balance_label(balance):
	# Updating the players balance
	$UI/HUD/VBC/Balance.set_text("Balance: " + balance)

func prepare_scoreboard(inv):
	# Cleaning the dictionary for Scoreboard representation
	inv.erase("player_id")
	inv["player_name"] = ClientStats.player_name
	inv.erase("inventory_id")	
	add_sorter_buttons(inv)
	add_client_to_scoreboard(inv,ClientStats.player_network_id)
	
func add_sorter_buttons(inv_dict):
	# Preparing the buttons used for sorting	
	var inv = inv_dict.duplicate(true)
	var vbc = scoreboard.get_node("MC/SC/VBC")
	var sorter_container = vbc.get_node("HBC")
	var b1 = Button.new()
	var t1 = "player_name"
	b1.set_text(t1)
	b1.set_name(t1)
	sorter_container.add_child(b1,true)
	b1.connect("pressed",self,"change_sort",[b1.get_name()])
	inv.erase(t1)

	# Adding each button using the inventory keys
	for key in inv.keys():
		var text = key
		var button = Button.new()
		button.set_name(key)
		button.set_text(str(text))
		sorter_container.add_child(button,true)
		button.connect("pressed",self,"change_sort",[button.get_name()])
	
func add_client_to_scoreboard(inv_dict,player_id):
	# Adding clients user details to the Scoreboard
	var inv = inv_dict.duplicate(true)
	var vbc = scoreboard.get_node("MC/SC/VBC")
	var sorter_container = vbc.get_node("HBC")
	var hbc = HBoxContainer.new()
	
	# Ensures player row has not already been added
	if !vbc.has_node(str(player_id)):
		hbc.set_alignment(BoxContainer.ALIGN_CENTER)
		hbc.set_name(str(player_id))
		vbc.add_child(hbc,true)
		while sorter_container.get_child_count() == 0:
			yield(get_tree().create_timer(0.1),"timeout")
		add_label("player_name",inv,sorter_container,hbc)
		inv.erase("player_name")

		for key in inv.keys():
			add_label(key,inv,sorter_container,hbc)
	sort_scoreboard()
	
func add_label(key,inv,sorter_container,hbc):
	# Adds a label with the provided parameters
	var label = Label.new()
	label.set_text(str(inv[key]))
	label.set_name(str(key)	)
	label.set_clip_text(true)
	label.rect_min_size.x = sorter_container.get_node(key).rect_size.x
	label.set_align(Label.ALIGN_CENTER)
	hbc.add_child(label,true)

func remove_player_from_scoreboard(player_id):
	# Removes the player from the scoreboard and then sorts the scoreboard
	if scoreboard.has_node("MC/SC/VBC/" + str(player_id)):
		scoreboard.get_node("MC/SC/VBC/" +str(player_id)).queue_free()
	sort_scoreboard()

func change_sort(new_sort):
	# Changes the sort type and sorts the scoreboard 
	if selected_sort != new_sort:
		selected_sort = new_sort
		sort_scoreboard()

func sort_scoreboard():
	var rows = scoreboard.get_node("MC/SC/VBC").get_children()
	var type_row = []
	var var_type = FLT
	var user_row = []
	# Removes the sorter buttons as they shouldn't be sorted
	rows.remove(0)
	
	# Type check as strings are sorted  checked differently to integers and floats
	if selected_sort == "player_name" or selected_sort == "chosen_class":
		var_type = STR	
	
	# Gets values from each row of the Scoreboard
	for row in rows:
		# Prevents scoreboard from sorting rows that are currently getting added
		if row.get_child_count() == 0:
			yield(get_tree().create_timer(0.1),"timeout")
			
		var row_value = row.get_node(selected_sort).get_text()
		# Converts values into float as they are stored as a string to begin with
		if var_type == FLT:
			row_value = float(row_value)	
		type_row.append(row_value)
		# Allows to keep track of users details without need for dictionary
		user_row.append(row.get_name())
	
	# Bubble sort to sort the details of maximum 10 players (server limit)
	var swapped : bool
	var arr_len = type_row.size()
	
	for i in range(arr_len):
		swapped = false
		for j in range(arr_len-i-1):
			if type_row[j] > type_row[j+1]:
				# Swaps the details
				var temp = type_row[j]
				type_row[j] = type_row[j+1]
				type_row[j+1] = temp
				# Swaps respective user 
				var user_temp = user_row[j]
				user_row[j] = user_row[j+1]
				user_row[j+1] = user_temp
				swapped = true
		if not swapped:
			break
	
	# Using a stack to reverse the order of the array to sort from highest to lowest instead
	var user_stack = []
	for _i in range(user_row.size()):
		user_stack.append(user_row.pop_back())
	user_row = user_stack	


	
	# Repositions the user rows
	var parent = scoreboard.get_node("MC/SC/VBC")
	user_row.insert(0,"HBC")
	for index in range(user_row.size()):
		var user = user_row[index]
		var child = parent.get_node(user)
		parent.move_child(child,index)
	
func update_scoreboard_row(inv,sender_id):
	var player_row = scoreboard.get_node("MC/SC/VBC/" + str(sender_id))
	if player_row != null:
		for child in player_row.get_children():
			var key = child.get_name()
			child.set_text(str(inv[key]))
	sort_scoreboard()
	
func prepare_classes():
	# Instaniates required script and nodes for specific classes:
	max_jumps = 1 + ClientStats.class_details["extra_jumps"]
	normal_speed = 1 + ClientStats.class_details["speed"]
	speed = normal_speed
	match ClientStats.chosen_class:
		"FlightGuy":
			ld.set_script(load("res://Scripts/LoadoutClasses/FlightGuy.gd"))
		"GrappleGuy":
			ld.set_script(load("res://Scripts/LoadoutClasses/GrappleGuy.gd"))
		"GravityGuy":
			ld.set_script(load("res://Scripts/LoadoutClasses/GravityGuy.gd"))
		"MagicGuy":
			ld.set_script(load("res://Scripts/LoadoutClasses/MagicGuy.gd"))
		"NinjaGuy":
			ld.set_script(load("res://Scripts/LoadoutClasses/NinjaGuy.gd"))
		"WallGuy":
			ld.set_script(load("res://Scripts/LoadoutClasses/WallGuy.gd"))
	ld.prepare_class()
	
func check_for_abilities():
	# Prepares which classes have abilities and toggles the display for ability on the hud
	if ClientStats.class_details["ability"] != "none":
		has_ability = true
	if has_ability:
		get_node("UI/HUD/Ability").show()
		get_node("UI/HUD/Ability").set_tooltip(ClientStats.class_details["description"])
	else:
		get_node("UI/HUD/Ability").hide()
		
func activate_ability(inv_balance):
	$AbilityTimer.start()
	get_node("UI/HUD/Ability").set_self_modulate(Color(1,1,1,0.19))
	ability_reset = false
	ld.activate_ability()
	GameServer.update_client_inventory("abilities_used",1)
	GameServer.update_client_inventory("balance",-ClientStats.class_details["ability_cost"])
	ClientStats.player_node.update_balance_label(str(inv_balance-ClientStats.class_details["ability_cost"]))
	
func exit_to_lobby():
	ClientStats.in_game = false
	ClientStats.player_node = null
	ClientStats.current_scene = "Lobby"
	get_node("/root/MainScene/World").queue_free()
	get_node("/root/MainScene").add_child(load("res://Scenes/Player/UI/ClientLobby.tscn").instance(),true)
	GameServer.send_leave_request()

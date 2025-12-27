extends Control

# Account Details
onready var account_details = $BG/FG/AccountDetailsContainer
onready var acc_label = account_details.get_node("VBC/HBC/AccountLabel")
onready var pw_label = account_details.get_node("VBC/HBC2/PWLabel")
onready var change_name_button = account_details.get_node("VBC/HBC/ChangeUsername")
onready var confirm_name_button = account_details.get_node("VBC/HBC/ConfirmChangeUsername")
onready var username_field = account_details.get_node("VBC/HBC/UsernameField")
onready var change_password_button = account_details.get_node("VBC/HBC2/ChangePassword")
onready var confirm_password_change_button = account_details.get_node("VBC/HBC2/ConfirmChangePassword")
onready var old_password_field = account_details.get_node("VBC/HBC2/OldPasswordField")
onready var new_password_field = account_details.get_node("VBC/HBC2/NewPasswordField")
var new_username_text = ""
var old_password_text = ""
var new_password_text = ""

# Controls
onready var controls_container = $BG/FG/ControlsContainer
onready var gc = controls_container.get_node("SC/CC/GC")
onready var selection_label = controls_container.get_node("FG")
onready var controls_node_scene = preload("res://Scenes/Player/UI/ControlsNode.tscn")
onready var client_controls_path = "res://Data/controls.txt"
var action_list = []
var key_list = []
var selecting_key = false
var selected_key 
var current_selection

# Settings
onready var settings_node = $BG/FG/SettingsContainer
onready var settings_container = settings_node.get_node("SC")
onready var vsync_box = $BG/FG/SettingsContainer/SC/CC/VBC/VSYNC/CheckBox
onready var fps_counter = settings_container.get_node("CC/VBC/MAX_FPS/FPSDisplay")
onready var fps_slider = settings_container.get_node("CC/VBC/MAX_FPS/FPSSlider")
onready var fov_counter = settings_container.get_node("CC/VBC/FOV/FovDisplay")
onready var fov_slider = settings_container.get_node("CC/VBC/FOV/FOVSlider")
onready var mouse_sens_slider = settings_container.get_node("CC/VBC/MouseSens/SensSlider")
onready var mouse_sens_counter = settings_container.get_node("CC/VBC/MouseSens/SensDisplay")
onready var zoom_sens_slider = settings_container.get_node("CC/VBC/ZoomPercent/ZoomSensSlider")
onready var zoom_sens_counter = settings_container.get_node("CC/VBC/ZoomPercent/ZoomSensDisplay")
onready var settings_file_path = "res://Data/settings.txt"
var max_fps = 100
var vsync_enabled = true
var fov = 90
var mouse_sensitivity = 1
var zoom_sensitivity_percentage = 1

#General
func _ready():
	ClientStats.options_node = self
	current_selection = account_details
	account_details.show()
	controls_container.hide()
	settings_node.hide()
	selection_label.hide()
	instance_controls()
	load_settings_from_file()
	
func _input(event):
	if selecting_key:
		if event is InputEventKey:
			var key_name = OS.get_scancode_string(event.scancode)
			change_key(key_name)
		elif event is InputEventMouseButton:
			var button_index = event.get_button_index()
			var key_name
			match button_index:
				1:
					key_name = "left_click"
				2:
					key_name = "right_click"
				3:
					key_name = "middle_click"
			change_key(key_name)
	
func show_menu(menu_container):
	current_selection.hide()
	current_selection = menu_container
	current_selection.show()

# Controls	
func _on_Controls_pressed():
	show_menu(controls_container)
	
func instance_controls():
	# Load data from text file instead and use that.
	var load_success = open_controls_from_file()
	if load_success:
		instance_control_node(load_success,action_list)
	else:	
		var controls_list = InputMap.get_actions()
		var new_list = []
		for control in controls_list:
			if !("ui_" in control):
				new_list.append(control)
		action_list = []
		key_list = []
		instance_control_node(load_success,new_list)
	
func change_key(key_name):
	# Linear search to find index as nodes are not sorted
	var index = 0
	for child in gc.get_children():
		if selected_key.get_parent() == child:
			break
		index += 1
	key_list[index] = key_name
	var action = action_list[index]
	# Update the new key name
	selected_key.set_name(key_name)
	selected_key.set_text(key_name)
	selected_key.release_focus()
	selected_key.disconnect("pressed",self,"key_change_pressed")
	selected_key.connect("pressed",self,"key_change_pressed",[key_name,action])
	selecting_key = false
	
	# Stop checking for inputs and re-enable the buttins
	set_process_input(false)
	toggle_keys(false)
	selection_label.hide()
	
func instance_control_node(load_success,list):
	var count = 0
	for control in list:
		var controls_scene = controls_node_scene.instance()
		controls_scene.set_text(control)
		controls_scene.set_name(control)
		gc.add_child(controls_scene,true)
		
		# Get the control's key and find its name
		var event_key 
		var key_name
		if !load_success:
			event_key = InputMap.get_action_list(control)[0]
			if event_key.is_class("InputEventKey"):
				var scan_code = event_key.get_scancode()
				key_name = OS.get_scancode_string(scan_code)
			else:
				var button_index = event_key.get_button_index()
				match button_index:
					1:
						key_name = "left_click"
					2:
						key_name = "right_click"
					3:
						key_name = "middle_click"
		else:
			key_name = key_list[count]
		
		controls_scene.get_node("Button").set_text(key_name)					
		controls_scene.get_node("Button").set_name(key_name)
		controls_scene.get_node(key_name).connect("pressed",self,"key_change_pressed",[key_name,control])		
		count += 1
		if !load_success:
			action_list.append(control)			
			key_list.append(key_name)
			
	_on_ApplyControls_pressed()	

func key_change_pressed(key_name,action_name):
	if !selecting_key:
		selected_key = gc.get_node(action_name).get_node(key_name)
		set_process_input(true)
		selected_key.release_focus()
		selecting_key = true
		selection_label.show()
		toggle_keys(true)
	
func toggle_keys(bool_value):
	if !bool_value:
		yield(get_tree().create_timer(0.1),"timeout")	
	for index in range(len(key_list)):
		gc.get_node(action_list[index]).get_node(key_list[index]).disabled = bool_value
		
func save_controls_to_file():
	var controls_file = File.new()
	controls_file.open(client_controls_path,File.WRITE_READ)
	for index in range(len(key_list)):
		var action = action_list[index]
		var key = key_list[index]
		var line = action + "," + key + "\n"
		controls_file.store_string(line)
	controls_file.close()

func open_controls_from_file():
	var controls_file = File.new()
	if controls_file.file_exists(client_controls_path):
		controls_file.open(client_controls_path,File.READ)
		while not controls_file.eof_reached():
			var line = controls_file.get_line()
			if "," in line:
				var line_array = line.split(",")
				if str(line_array) != "[]":
					var action = line_array[0]
					if !action in InputMap.get_actions():
						return false
						
					var key = line_array[1]
					action_list.append(action)
					key_list.append(key)
			elif !line.length() == 0:
				return false
		if key_list.size() == 14:
			return true
		else:
			return false
	else:
		return false
		
func _on_ApplyControls_pressed():
	for index in range(len(key_list)):
		var action = action_list[index]
		var key = key_list[index]
		var event
		if !(key == "left_click" or key == "right_click" or key == "middle_click"):
			event = InputEventKey.new()
			event.scancode = OS.find_scancode_from_string(key)
		else:
			event = InputEventMouseButton.new()
			match key:
				"left_click":
					event.button_index = 1
				"right_click":
					event.button_index = 2
				"middle_click":
					event.button_index = 3
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action,event)
	save_controls_to_file()

# Account details
func _on_ConfirmChangePassword_pressed():
	# Send new password to authentication server
	GameServer.update_pw(new_password_text)
	confirm_password_change_button.disabled = true
	change_password_button.disabled = false
	old_password_text = ""
	new_password_text = ""		
	old_password_field.set_text(old_password_text)	
	new_password_field.set_text(new_password_text)

func _on_AccountDetails_pressed():
	show_menu(account_details)

func _on_UsernameField_text_changed(new_text):
	new_username_text = new_text
	acc_label.set_text("")
	if change_name_button.disabled:
		change_name_button.disabled = false
		confirm_name_button.disabled = true
		
func _on_ChangeUsername_pressed():
	# Make sure name isn't in the database
	acc_label.set_text("")
	if new_username_text == ClientStats.player_name:
		display_message("Username cannot be the same as before",acc_label)
	elif new_username_text == "":
		display_message("Username cannot be empty",acc_label)
	elif new_username_text.length() > 16:
		display_message("Username is too long",acc_label)
	else:
		change_name_button.disabled = true
		GameServer.check_if_name_taken(new_username_text)

func _on_ConfirmChangeUsername_pressed():
	# Update the player name in the game server and authentication server
	GameServer.send_new_username(new_username_text,ClientStats.player_name)	
	ClientStats.player_name = new_username_text
	new_username_text = ""
	username_field.set_text(new_username_text)
	change_name_button.disabled = false
	confirm_name_button.disabled = true

func _on_OldPasswordField_text_changed(new_text):
	old_password_text = new_text
	if change_password_button.disabled:
		change_password_button.disabled = false
		confirm_password_change_button.disabled = true

func _on_NewPasswordField_text_changed(new_text):
	new_password_text = new_text
	if change_password_button.disabled:
		change_password_button.disabled = false
		confirm_password_change_button.disabled = true

func _on_ChangePassword_pressed():
	# Verify old password
	if new_password_text == "" or old_password_text == "":
		display_message("Passwords cannot be blank",pw_label)
	elif new_password_text == old_password_text:
		display_message("Inputs cannot be equal",pw_label)
	elif new_password_text.length() < 4:
		display_message("New password is too short",pw_label)
	else:
		change_password_button.disabled = true
		GameServer.verify_old_password(old_password_text)

func _on_username_check_results_received(results):
	if results:
		if new_username_text != "":
			change_name_button.disabled = true
			confirm_name_button.disabled = false
		display_message("Username is available",acc_label)
	else:
		display_message("Username is taken",acc_label)

func _on_old_password_confirmed(success):
	if success:
		confirm_password_change_button.disabled = false
		change_password_button.disabled = true
	else:
		display_message("Password change unsuccessful.",pw_label)

func display_message(message,label):
	label.set_text(message)
	yield(get_tree().create_timer(4),"timeout")
	label.set_text("")

# Settings
func save_settings_to_file():
	var settings_file = File.new()
	settings_file.open(settings_file_path,File.WRITE)
	settings_file.store_string("vsync," + str(vsync_enabled) + "\n")
	settings_file.store_string("max_fps," + str(max_fps) + "\n")
	settings_file.store_string("fov," + str(fov) + "\n")
	settings_file.store_string("mouse_sensitivity," + str(mouse_sensitivity).pad_decimals(1) + "\n")
	settings_file.store_string("zoom_sensitivity_percentage," + str(zoom_sensitivity_percentage).pad_decimals(1))
	settings_file.close()

func apply_default_settings():
	vsync_enabled = true
	max_fps = 120
	fov = 90
	mouse_sensitivity = 1.0
	zoom_sensitivity_percentage = 1.0
	
func load_settings_from_file():
	# Load values from text file
	var settings_file = File.new()
	var names_list = []
	var values_list = []
	var accepted = true
	if settings_file.file_exists(settings_file_path):	
		settings_file.open(settings_file_path,File.READ)
		while not settings_file.eof_reached():
			var line = settings_file.get_line()
			if "," in line:
				var line_array = line.split(",")
				if line_array[0] in ClientStats.required_settings:
					names_list.append(line_array[0])
					values_list.append(line_array[1])
				else:
					accepted = false
					break
			else:
				accepted = false
				break
	else:
		accepted = false
	if accepted:
		vsync_enabled = bool(values_list[0])
		max_fps = int(values_list[1])
		fov = int(values_list[2])
		mouse_sensitivity = float(values_list[3])
		zoom_sensitivity_percentage = float(values_list[4])
	else:
		apply_default_settings()	

	vsync_box.set_pressed(vsync_enabled)
	_on_FPSSlider_value_changed(max_fps)
	_on_FOVSlider_value_changed(fov)
	_on_SensSlider_value_changed(mouse_sensitivity)
	_on_ZoomSensSlider_value_changed(zoom_sensitivity_percentage)
	zoom_sens_slider.set_value(zoom_sensitivity_percentage)
	mouse_sens_slider.set_value(mouse_sensitivity)
	fov_slider.set_value(fov)
	fps_slider.set_value(max_fps)	
	_on_ApplySettings_pressed()
	
func _on_ApplySettings_pressed():
	ClientStats.fov = fov
	ClientStats.mouse_sensitivity = mouse_sensitivity
	ClientStats.scope_sensitivity = zoom_sensitivity_percentage
	OS.set_use_vsync(vsync_enabled)
	Engine.set_target_fps(max_fps)
	if ClientStats.player_node != null:
		ClientStats.player_node.camera.set_fov(fov)
		ClientStats.player_node.mouse_sensitivity = mouse_sensitivity
	save_settings_to_file()

func _on_Settings_pressed():
	show_menu(settings_node)

func _on_FPSSlider_value_changed(value):
	max_fps = value
	fps_counter.set_text("[" + str(max_fps) + "]")

func _on_CheckBox_toggled(button_pressed):
	vsync_enabled = button_pressed

func _on_FOVSlider_value_changed(value):
	fov = value
	fov_counter.set_text("[" + str(fov) + "]")
	
func _on_SensSlider_value_changed(value):
	mouse_sensitivity = value
	mouse_sens_counter.set_text("[" + str(mouse_sensitivity) + "]")

func _on_ZoomSensSlider_value_changed(value):
	zoom_sensitivity_percentage = value
	zoom_sens_counter.set_text("[" + str(zoom_sensitivity_percentage) + "]")

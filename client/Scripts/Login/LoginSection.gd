extends VBoxContainer

onready var register_section = preload("res://Scenes/Login/RegisterSection.tscn")
onready var message_label = preload("res://Scenes/Login/MessageLabel.tscn")
onready var username_input = $GridContainer/UserNameEdit
onready var password_input = $GridContainer/PasswordEdit
onready var enter_button = $EnterButton
onready var register_button = $Register

func _on_EnterButton_pressed():
	# Checking basic inputs 
	var accepted = true
	if username_input.get_text() == "" or password_input.get_text() == "":
		display_message("Inputs cannot be blank")
		accepted = false
	# Disables buttons and attempts gateway connection
	if accepted:
		enter_button.disabled = true
		register_button.disabled = true
		var username = username_input.get_text()
		var password = password_input.get_text()
		display_message("Attempting to Login...")
		# Send username and password to gateway
		Gateway.connect_to_server(username,password)
	
func _on_Register_pressed():
	queue_free()
	get_parent().add_child(register_section.instance(),true)
	ClientStats.current_scene = "Register"

func display_message(message): 
	var new_message = message_label.instance()
	add_child(new_message,true)
	new_message.set_text(message)
	yield(get_tree().create_timer(4),"timeout")
	new_message.queue_free()

extends VBoxContainer

onready var login = load("res://Scenes/Login/LoginSection.tscn")
onready var message_label = preload("res://Scenes/Login/MessageLabel.tscn")

onready var password_input = $GridContainer/PasswordEdit
onready var confirm_input = $GridContainer/ConfirmPWEdit
onready var username_input = $GridContainer/UserNameEdit
onready var register_button = $Register
onready var back = $Back	

var register = false

func _on_Back_pressed():
	queue_free()
	get_parent().add_child(login.instance(),true)
	ClientStats.current_scene = "Login"
		
func _on_Register_pressed():
	# Checking basic inputs before sending to gateway
	var accepted = true
	if !(password_input.get_text() == confirm_input.get_text()):
		display_message("Passwords are not equal")
		accepted = false
	if password_input.get_text() == "" or confirm_input.get_text() == "" or username_input.get_text() == "":
		display_message("Inputs cannot be blank")	
		accepted = false
		
	# Disabled buttons and attempts gateway connection
	if accepted:
		register_button.disabled = true
		back.disabled = true
		var username = username_input.get_text()
		var password = password_input.get_text()
		display_message("Attempting to Register...")
		Gateway.connect_to_server(username,password)
		
func display_message(message):
	var new_message = message_label.instance()
	add_child(new_message,true)
	new_message.set_text(message)
	yield(get_tree().create_timer(4),"timeout")
	new_message.queue_free()

extends Node

var network = NetworkedMultiplayerENet.new()
var gateway_api = MultiplayerAPI.new()
#var ip = "82.41.231.179"
var ip = "127.0.0.1"
var port = 50002

var stored_username
var stored_password

onready var login_node 

func _process(_delta):
	if get_custom_multiplayer() == null:
		return
	if not custom_multiplayer.has_network_peer():
		return;
	custom_multiplayer.poll();

func connect_to_server(username,password):
	# Set up server and peer connections
	network = NetworkedMultiplayerENet.new()
	gateway_api = MultiplayerAPI.new()

	network.create_client(ip,port)
	set_custom_multiplayer(gateway_api)
	custom_multiplayer.set_root_node(self)
	custom_multiplayer.set_network_peer(network)
	
	network.connect("connection_failed",self,"_on_connection_failed")
	network.connect("connection_succeeded",self,"_on_connection_succeeded")
	
	login_node = get_node("/root/MainScene/LoginMenu/BG/FG/CC/" + ClientStats.current_scene)
	# Temporarily store username and password
	stored_username = username
	stored_password = password
	
func _on_connection_failed():
	# Reset login buttons on unsuccessful connections
	if ClientStats.current_scene == "Register":
		login_node.register_button.disabled = false	
		login_node.back.disabled = false
	elif ClientStats.current_scene == "Login":
		login_node.register_button.disabled = false
		login_node.enter_button.disabled = false
	login_node.display_message("Failed to connect to the gateway server.")	

func _on_connection_succeeded():
	# Proceed to connection to authentication server
	if ClientStats.current_scene == "Register":
		request_to_create_account()
	elif ClientStats.current_scene == "Login":	
		request_to_login()
	
func request_to_create_account():
	# Sending an account creation request to the gateway 
	login_node.display_message("Sending create account request to gateway")
	rpc_id(1,"create_account_request",stored_username,stored_password)
	stored_username = ""
	stored_password = ""
	
func request_to_login():
	# Sending a login request to the gateway
	login_node.display_message("Sending login request to gateway.")
	rpc_id(1,"login_request",stored_username,stored_password)
	stored_username = ""
	stored_password = ""
	
remote func return_login_request(results,token,message):
	login_node.display_message("Results received from Gateway")
	if results:
		GameServer.token = token
		GameServer.connect_to_server()
	else:
		if ClientStats.current_scene == "Register":
			login_node.register_button.disabled = false	
		elif ClientStats.current_scene == "Login":
			login_node.register_button.disabled = false
			login_node.enter_button.disabled = false
		login_node.display_message(message)

	network.disconnect("connection_failed",self,"_on_connection_failed")
	network.disconnect("connection_succeeded",self,"_on_connection_succeeded")
	
remote func return_create_account_request(_result,message):
	login_node.register_button.disabled = false
	login_node.back.disabled = false
	login_node.username_input.set_text("")
	login_node.password_input.set_text("")
	login_node.confirm_input.set_text("")
	login_node.display_message(message)
	network.disconnect("connection_failed",self,"_on_connection_failed")
	network.disconnect("connection_succeeded",self,"_on_connection_succeeded")

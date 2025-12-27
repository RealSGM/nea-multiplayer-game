extends Node

onready var gateway = get_node("/root/Gateway")

var network = NetworkedMultiplayerENet.new()
var gateway_api = MultiplayerAPI.new()

var max_players = 100
var port = 50002

func _ready():
	set_process(false)
	yield(get_tree().create_timer(1),"timeout")
	start_server()
	set_process(true)

func _process(_delta):
	if not custom_multiplayer.has_network_peer():
		return;
	custom_multiplayer.poll();

func start_server():
	# create server for clients to connect to
	network.create_server(port,max_players)
	set_custom_multiplayer(gateway_api)
	custom_multiplayer.set_root_node(self)
	custom_multiplayer.set_network_peer(network)
	gateway.send_message_to_console("Gateway server has started.")	
	network.connect("peer_connected",self,"_peer_connected")
	network.connect("peer_disconnected",self,"_peer_disconnected")
	
func _peer_connected(player_id):
	gateway.send_message_to_console("Player ID: " + str(player_id) + " has connected to the gateway.")
	
func _peer_disconnected(player_id):
	gateway.send_message_to_console("Player ID: " + str(player_id) + " has disconnected from the gateway.")
	
func return_login_request(player_id,result,token,message):
	gateway.send_message_to_console("Returning login request to Player ID: " + str(player_id))
	rpc_id(player_id,"return_login_request",result,token,message)
	network.disconnect_peer(player_id)

func return_create_account_request(player_id,result,message):
	# Return results
	gateway.send_message_to_console("Returning create account request to Player ID: " + str(player_id))
	rpc_id(player_id,"return_create_account_request",result,message)
	network.disconnect_peer(player_id)	

remote func login_request(username,password):
	# Receive login request from gateway
	gateway.send_message_to_console("Login request received.")
	var player_id = custom_multiplayer.get_rpc_sender_id()
	if AuthenticationServer.connected_to_auth:
		AuthenticationServer.request_player_authentication(username,password,player_id)
	else:
		return_login_request(player_id,false,null,"Authentication server is not online.")
	
remote func create_account_request(username,password):
	var player_id = custom_multiplayer.get_rpc_sender_id()
	var valid_request = true
	var message = ""
	if !AuthenticationServer.connected_to_auth:
		valid_request = false
		message = message + "Authentication server is offline.\n"
	if username == "" or password == "":
		valid_request = false
		message = message + "Username / Password cannot be empty.\n"
	if username.length() > 16:
		valid_request = false
		message = message + "Username length is too long.\n"
	if password.length() < 4:
		valid_request = false
		message = message + "Password too short.\n"
	if !valid_request:
		return_create_account_request(player_id,valid_request,message)
	else:
		AuthenticationServer.request_create_account(username,password,player_id)

extends Node

onready var label_message = preload("res://Scenes/Message.tscn")
onready var container = $ColorRect/ScrollContainer/VBoxContainer
export var console_enabled = true
var network = NetworkedMultiplayerENet.new()
var port = 50003
var max_servers = 5
var game_server_list = {}
var active_players = []

func _ready():
	start_server()
	
func start_server():
	network.create_server(port,max_servers)
	get_tree().set_network_peer(network)
	send_message_to_console("Authentication server has started.")

	network.connect("peer_connected",self,"_peer_connected")
	network.connect("peer_disconnected",self,"_peer_disconnected")
	
func _peer_connected(gateway_id):
	send_message_to_console("Gateway " + str(gateway_id) + " has connected.")
	
func _peer_disconnected(gateway_id):
	send_message_to_console("Gateway " + str(gateway_id) + " has disconnected.")

func generate_salt():
	randomize()
	var salt = str(randi()).sha256_text()
	return salt
	
func generate_hashed_password(password,salt):
	# Generate a hashed password 
	# Uses sha256 with 2^18 rounds of hashing + salting 
	var hashed_password = password
	var rounds = pow(2,18)
	while rounds > 0:
		hashed_password = (hashed_password + salt).sha256_text()
		rounds -= 1
	return hashed_password
	
func send_message_to_console(new_message):
	if console_enabled:
		var new_message_label = label_message.instance()
		new_message_label.set_text(new_message + "\n")
		container.add_child(new_message_label,true)
		
func new_player_login(player_name):
	if !(player_name in active_players):
		active_players.append(player_name)
		send_message_to_console("Active Players: " + str(active_players))

func new_player_logout(player_name):
	if player_name in active_players:
		active_players.erase(player_name)
		send_message_to_console("Active Players: "+str(active_players))

func change_player_name_from_active_players_list(username,old_name):
	var index = active_players.find(str(old_name))
	active_players[index] = username
	
remote func player_authentication_request(username,password,player_id):
	# Authenticate player login
	var token
	var hashed_password
	var gateway_id = get_tree().get_rpc_sender_id()
	var result = true
	var message = ""
	send_message_to_console("Authentication request received from Gateway:" + str(gateway_id))
	# Series of checks required before authenticating login request
	if GameServers.game_server_list.empty():
		result = false
		message = message + "No available game servers online.\n"
	elif username in active_players:
		result = false
		message = message + "User is already online.\n"
	else:
		var user_account = DataBase.retrieve_user_details(username)
		if user_account == [] or str(user_account) == "" or user_account == null:
			message = message + "User not registered into database.\n"
			result = false
		else:
			# Verify account details
			user_account = user_account[0]
			var retrieved_salt = user_account["salt"]
			hashed_password = generate_hashed_password(password,retrieved_salt)	
			if not user_account["hashed_password"] == hashed_password:
				result = false
				message = message + "Please enter correct details.\n"
			else:
				# generate auth token
				token = str(randi()).sha256_text() + str(OS.get_unix_time()) 
				var game_server = "GameServer"
				user_account["hashed_password"] = ""
				user_account["salt"] = ""
				GameServers.distribute_login_token(token,game_server)
				GameServers.send_player_details(game_server,user_account)
	send_message_to_console("Authentication results sent back to Gateway: " + str(gateway_id))
	rpc_id(gateway_id,"return_authentication_results",result,player_id,token,message)
	
remote func create_account_request(username,password,player_id):
	var gateway_id = get_tree().get_rpc_sender_id()
	var result
	var message
	if !DataBase.retrieve_user_details(username) == []:
		result = false
		message = "User already exists in database"
	else:
		result = true
		message = "Successful registration"
		var salt = generate_salt()
		var hashed_password = generate_hashed_password(password,salt)
		DataBase.register_user(username,hashed_password,salt)
	rpc_id(gateway_id,"return_create_account_results",result,player_id,message)
	

extends Node

var network = NetworkedMultiplayerENet.new()
var port = 50001
var max_players = 10
var player_count = 0
var expected_tokens = []
var player_state_collection = {}
var console_enabled = true

onready var mm = $MatchMaking
onready var mm_queue_label = $ColorRect/HBoxContainer/ServerInfo/VBoxContainer/MatchmakingQueue/UpdateLabel
onready var in_lobby_label = $ColorRect/HBoxContainer/ServerInfo/VBoxContainer/InLobby/UpdateLabel
onready var in_game_label = $ColorRect/HBoxContainer/ServerInfo/VBoxContainer/InGame/UpdateLabel
onready var alive_label = $ColorRect/HBoxContainer/ServerInfo/VBoxContainer/Alive/UpdateLabel
onready var player_counter_label = $ColorRect/HBoxContainer/ServerInfo/VBoxContainer/PlayerCounter/UpdateLabel
onready var player_verification_process = $PlayerVerification
onready var update_container = $ColorRect/HBoxContainer/ServerUpdate/VBoxContainer #for new incoming information
onready var message = preload("res://Scenes/Message.tscn")

func _ready():
	# Connect server signals
	var _connection_error = get_tree().connect("network_peer_connected", self, "_player_connected")
	var _disconnection_error = get_tree().connect("network_peer_disconnected", self, "_player_disconnected")	
	yield(get_tree().create_timer(1),"timeout")
	start_server()
	
func start_server():
	# Configure the server and start it
	network.create_server(port,max_players)
	get_tree().set_network_peer(network)
	send_message_to_console("Server has started!")
	
func _player_connected(player_id): 
	# Start player verification for a new connected player
	player_verification_process.start(player_id)
	
func _player_disconnected(player_id):
	# Save player's inventory, send message to chat, remove player from the world and scoreboard
	update_player_inventory(player_id)
	if has_node(str(player_id)):
		var player_name = get_node(str(player_id)).player_name
		var _message = "Server | " + player_name + " has disconnected"
		HubConnections.player_log_out(player_name)
		rpc_id(0,"send_player_message",_message,1)
	remove_player(str(player_id))
	
	#save data to authentication server / database
	if has_node(str(player_id)):
		get_node(str(player_id)).queue_free()
		player_state_collection.erase(player_id)
	request_despawn_player(player_id)	
	
	rpc_id(0,"remove_player_from_scoreboard",player_id)
	update_server_info()

func _on_TokenExpiration_timeout():
	# Remove any expired tokens from the token list
	var current_time = OS.get_unix_time()
	var token_time
	if !(expected_tokens == []):
		for i in range(expected_tokens.size() -1,-1,-1): #goes through list backwards
			token_time = int(expected_tokens[i].right(64))
			if current_time - token_time >= 30:
				expected_tokens.remove(i)
	
func _on_UpdateTimer_timeout():
	# Update each active player's inventory
	for player_id in mm.players_in_game_world:
		update_player_inventory(player_id)
	
func remove_player(player_id):
	#Erase the player from any of the queues, update console status
	player_id = int(player_id)
	
	if player_id in mm.players_in_client_lobby:
		mm.players_in_client_lobby.erase(player_id)	
		if player_id in mm.players_in_mm_queue:
			 mm.players_in_mm_queue.erase(player_id)
	elif player_id in mm.players_in_game_world:
		mm.players_in_game_world.erase(player_id)
		if player_id in mm.players_alive_in_game:
			mm.player_removed(player_id)
		
		if mm.players_in_game_world.size() == 0:
			mm.game_started = false	
			mm.round_in_progress = false

	update_server_info()

func fetch_token(player_id):
	# Receive game token from player
	rpc_id(player_id,"fetch_token")
	send_message_to_console("Fetching token from player")
	
func return_token_verification_results(player_id,result):
	# Send token results back to player, allow successful logins
	rpc_id(player_id,"return_token_verification_results", result)
	send_message_to_console("Returning token verification results to Player ID: " + str(player_id))
	if result:
		mm.players_in_client_lobby.append(player_id)
		var player_name = get_node(str(player_id)).player_name
		HubConnections.new_player_login(player_name)
		rpc_id(player_id,"return_player_name",player_name)
	
func send_world_state(world_state):
	# Use UDP to send the world state to each client
	rpc_unreliable_id(0,"receive_world_state",world_state)

func update_server_info():
	# Update all the labels in the console - used for testing purposes 
	player_count = mm.players_in_client_lobby.size() + mm.players_in_game_world.size()
	mm_queue_label.set_text(str(mm.players_in_mm_queue))
	in_game_label.set_text(str(mm.players_in_game_world))
	alive_label.set_text(str(mm.players_alive_in_game))
	in_lobby_label.set_text(str(mm.players_in_client_lobby))
	player_counter_label.set_text(str(player_count))
	
func send_message_to_console(new_message):
	# Sending a text message to the console - used for testing purposes
	if console_enabled:
		var new_message_label = message.instance()
		new_message_label.set_text(new_message + "\n")
		update_container.add_child(new_message_label,true)

func update_player_inventory(player_id):
	# Sending new player inventory to the database.
	if has_node(str(player_id)):
		var player_inventory = get_node(str(player_id)).player_inventory
		var inv_id = get_node(str(player_id)).player_inventory["inventory_id"]
		HubConnections.request_player_update_inventory(player_inventory,inv_id)
	
func return_player_invs(invs,peer_id):
	# Clean the player invs before sending back to client
	var specific_details = []
	for inv in range(3):
		var details = {}
		if invs.size() != 3:
			invs.append({})			
		if  str(invs[inv]) != "{}":
			var chosen_class = invs[inv]["chosen_class"]
			details = DataBase.retrieve_class_details(chosen_class)
		specific_details.append(details)
	rpc_id(peer_id,"receive_player_invs",invs,specific_details)

func start_new_match(player_id):
	# Send new match request to client
	rpc_id(player_id,"start_match")
		
func send_pw_results(success,player_id):
	# Send password check results to player
	rpc_id(player_id,"receive_pw_results",success)

func player_won_round(winner):
	# Send winner name to client
	var winner_name = get_node(str(winner)).player_name
	var _message = "The winner of the round is: " + winner_name
	rpc_id(0,"send_player_message",_message,winner)
	
	# Update winner's player inventory with rewards
	var pc = get_node(str(winner))
	pc.player_inventory["balance"] += 100
	var experience = pc.player_inventory["experience"]
	experience = min(experience+200,1000)
	if experience == 1000:
		experience = 0
		pc.player_inventory["level"] += 1
	pc.player_inventory["experience"] = experience
	rpc_id(winner,"player_won_round",str(pc.player_inventory["balance"]))
	
func respawn_dead_player(player):
	# Show dead players when new round starts
	var data_dict = {}
	data_dict["player_id"] = player
	data_dict["visuals_name"] = "show_player"
	data_dict["weapon_name"] = ""
	rpc_id(0,"server_player_visual_actions",data_dict)
	rpc_id(player,"respawn_dead_player")
	
func request_despawn_player(player_id):
	# Hide a player who has died
	var data_dict = {}
	data_dict["visuals_name"] = "despawn_player"
	data_dict["weapon_name"] = ""
	data_dict["player_id"] = str(player_id)
	rpc_id(0,"server_player_visual_actions",data_dict)
	
func return_player_balance(player_id):
	# Send back the client's balance
	var balance = str(get_node(str(player_id)).player_inventory["balance"])
	rpc_id(player_id,"receive_player_balance",balance)
	
remote func client_preparation(player_id,rand_pos):
	# Prepare the client for the new round
	rpc_id(player_id,"return_client_preparation_request",rand_pos)
	
remote func request_new_inventory_creation(chosen_class):
	# Create a new inventory, retrieve guns from chosen class
	var player_id = get_tree().get_rpc_sender_id()
	var pc = get_node(str(player_id))
	pc.reset_inv()
	
	var class_details = DataBase.retrieve_class_details(chosen_class)
	var guns = [class_details["gun1"],class_details["gun2"]]
	var class_guns = {}
	for gun in guns:	
		class_guns[gun] = DataBase.retrieve_gun_details(gun)
	pc.player_guns = class_guns
	pc.player_inventory["chosen_class"] = chosen_class
	pc.player_inventory["player_id"] = pc.player_id
	var inv = pc.player_inventory.duplicate(true)
	inv.erase("inventory_id")
	
	# Send inventory to database
	rpc_id(player_id,"receive_class_details",class_guns,class_details)
	HubConnections.add_inventory(player_id,inv)
	
remote func receive_existing_client_stats(inv):
	# Saving the player inventory into the server
	var player_id = get_tree().get_rpc_sender_id()
	var pc = get_node(str(player_id))
	var class_details = DataBase.retrieve_class_details(inv["chosen_class"])
	var guns = [class_details["gun1"],class_details["gun2"]]
	var class_guns = {}
	for gun in guns:	
		class_guns[gun] = DataBase.retrieve_gun_details(gun)
	pc.player_inventory = inv
	pc.player_guns = class_guns
	pc.inventory_id = int(inv["inventory_id"])
	rpc_id(player_id,"receive_class_details",class_guns,class_details)

remote func receive_player_message(_message):
	# Receive a client's message, return message to all players
	var player_id = get_tree().get_rpc_sender_id()
	if has_node(str(player_id)):
		_message = get_node(str(player_id)).player_name + ": " + _message
	rpc_id(0,"send_player_message",_message,player_id)
	send_message_to_console("Message Sent: "+ _message)

remote func receive_player_state(player_state):
	var player_id = get_tree().get_rpc_sender_id()
	if player_state_collection.has(player_id):
		# Updates the state collection with the most recent state
		if player_state_collection[player_id]["T"] < player_state["T"]:
			player_state_collection[player_id] = player_state
	else:
		# Creates a key for new players, if not in the dictionary
		player_state_collection[player_id] = player_state

remote func disconnect_player():
	# Disconnecting a player who has left
	var player_id = get_tree().get_rpc_sender_id()
	request_despawn_player(player_id)

remote func return_token(token):
	# Receive token, use token for verification
	var player_id = get_tree().get_rpc_sender_id()
	player_verification_process.verify(player_id,token)

remote func new_player():
	# Send message to all clients
	var player_id = get_tree().get_rpc_sender_id()
	var player_name = get_node(str(player_id)).player_name
	var _message = "Server | " + player_name  +" has connected "
	send_message_to_console(_message)
	mm.players_in_client_lobby.erase(player_id)
	update_server_info()
	
	# Clean inventory for scoreboard
	var inv = get_node(str(player_id)).player_inventory.duplicate(true)
	inv.erase("player_id")
	inv["player_name"] = get_node(str(player_id)).player_name
	inv.erase("inventory_id")
	rpc_id(0,"send_player_message",_message,1)
	rpc_id(0,"spawn_new_player",player_id,Vector3(0,10,0))
	rpc_id(0,"return_inv_for_scoreboard",player_id,inv)
	
	var peer_list = get_tree().get_network_connected_peers()
	for peer in peer_list:
		if peer != player_id:
			var pc = get_node(str(peer))
			var inventory = pc.player_inventory.duplicate(true)
			inventory["player_name"] = pc.player_name
			inventory.erase("player_id")
			inventory.erase("inventory_id")
			rpc_id(player_id,"return_inv_for_scoreboard",peer,inventory)
	
remote func retrieve_player_inv():
	# Get player name, send request to database to receive player inventory
	var peer_id = get_tree().get_rpc_sender_id()
	var player_name = ""
	while !get_node("/root/GameServer").has_node(str(peer_id)):
		yield(get_tree().create_timer(0.1),"timeout")
	player_name = get_node("/root/GameServer/" + str(peer_id)).player_name
	HubConnections.retrieve_player_inv(player_name,peer_id)
	
remote func retrieve_all_loadouts():
	# Get all possible loadouts from database, send back to client
	var loadouts_list = DataBase.retrieve_all_loadouts()
	var peer_id = get_tree().get_rpc_sender_id()
	rpc_id(peer_id,"receive_all_loadouts",loadouts_list)
	
remote func receive_deletion_request(inv_id):
	# Request inventory deletion
	HubConnections.send_deletion_request(inv_id)

remote func receive_matchmaking_request():
	# Add a new player to the matchmaking queue
	var player_id = get_tree().get_rpc_sender_id()
	mm.players_in_mm_queue.append(player_id)
	update_server_info()	

remote func receive_matchmaking_cancellation():
	# Remove a player from the matchmaking queue
	var player_id = get_tree().get_rpc_sender_id()
	mm.players_in_mm_queue.erase(player_id)
	update_server_info()		

remote func receive_username_request(username,old_name):
	# Change a user's name, display name change in chat
	HubConnections.send_username(username,old_name)
	var player_id = get_tree().get_rpc_sender_id()
	get_node(str(player_id)).player_name = username
	var _message = old_name + " has changed their name to: " + username
	rpc_id(0,"send_player_message",_message,1)
	
remote func receive_username_check(username):
	# Send request to see if username is available
	var player_id = get_tree().get_rpc_sender_id()
	HubConnections.request_username_check(username,player_id)
	
remote func send_username_check_results(results,player_id):
	# Send username check results back to the client
	rpc_id(player_id,"receive_username_check_results",results)

remote func receive_verify_pw_request(pw):
	# Send request to verify the password change
	var player_id = get_tree().get_rpc_sender_id()
	HubConnections.send_verify_pw_request(pw,player_id)
	
remote func receive_pw_update_request(pw):
	# Send request to update the player's password
	var player_id = get_tree().get_rpc_sender_id()
	HubConnections.send_pw_update_request(pw,player_id)
	
remote func request_new_player_guns(joining_player_id):
	
	if has_node(str(joining_player_id)):
		var player_guns = get_node(str(joining_player_id)).player_guns.keys()
		var gun_details = {}
		for gun in player_guns:
			gun_details[gun] = DataBase.retrieve_gun_details(gun)
		var sender_id = get_tree().get_rpc_sender_id()	
		var data_dict = {}
		# Send update to all existing clients to instance the new player's weapons
		data_dict["visuals_name"] = "instance_guns"
		data_dict["weapon_name"] = ""
		data_dict["player_guns"] = player_guns
		data_dict["details"] = gun_details
		data_dict["player_id"] = str(joining_player_id)
		rpc_id(0,"server_player_visual_actions",data_dict)
		# Send other client's weapons to the new player
		rpc_id(joining_player_id,"retrieve_other_player_current_gun",sender_id)

remote func receive_other_player_current_gun(current_gun,player_id):
	# Show each player's currently equipped weapon, send back to joining player
	var sender_id = get_tree().get_rpc_sender_id()
	var data_dict = {}
	data_dict["weapon_name"] = current_gun
	data_dict["visuals_name"] = "switch_weapon"
	data_dict["player_id"] = sender_id
	rpc_id(player_id,"server_player_visual_actions",data_dict)
	
remote func receive_visuals(data_dict):
	# Receive visual state from specifc player, send state back to all other players
	var sender_id = get_tree().get_rpc_sender_id()	
	data_dict["player_id"] = sender_id
	rpc_id(0,"server_player_visual_actions",data_dict)

remote func request_player_attacking_other_player(player_id,damage):
	# Forward request for player attack, to the player being attacked
	var attacker_id = get_tree().get_rpc_sender_id()
	rpc_id(player_id,"other_player_attacked_player",damage,attacker_id)

remote func request_player_achieved_kill(attacker_id):
	# Check which player is killed, remove player from game
	# Update attacker's inventory with rewards, update their balance
	var killed_player = get_tree().get_rpc_sender_id()
	$MatchMaking.player_removed(killed_player)
	if str(attacker_id) != str(killed_player):
		var pc = get_node(str(attacker_id))
		var experience = pc.player_inventory["experience"]
		experience = min(experience+10,1000)
		if experience == 1000:
			experience = 0
			pc.player_inventory["level"] += 1
		pc.player_inventory["experience"] = experience
		pc.player_inventory["player_kills"] += 1
		pc.player_inventory["balance"] += 50
		rpc_id(int(attacker_id),"receive_player_balance",str(pc.player_inventory["balance"]))
	
	var data_dict = {}
	data_dict["player_id"] = killed_player
	data_dict["visuals_name"] = "hide_player"
	data_dict["weapon_name"] = ""
	
	rpc_id(0,"server_player_visual_actions",data_dict)

remote func receive_player_inventory_from_client(requester_id,inv):
	# Forward inventory from player to client
	var sender_id = get_tree().get_rpc_sender_id()	
	rpc_id(requester_id,"retrieve_inventory_for_scoreboard",sender_id,inv)

remote func receive_gravity_shift_request():
	# Force gravity shift to all players (excluding sender) for 5 seconds
	var sender_id = get_tree().get_rpc_sender_id()
	rpc_id(0,"apply_gravity_shift",sender_id)
	yield(get_tree().create_timer(5),"timeout")
	rpc_id(0,"revert_gravity_shift",sender_id)

remote func receive_fetch_inventory_request(reason):
	# Return player inventory to client
	var player_id = get_tree().get_rpc_sender_id()
	var inv = get_node(str(player_id)).player_inventory
	rpc_id(player_id,"return_player_inventory",inv,reason)

remote func receive_inventory_update_request(key,value):
	# Update a specific value in player inventory
	var player_id = get_tree().get_rpc_sender_id()
	if "." in str(value):
		value = float(value)
	else:
		value = int(value)
	get_node(str(player_id)).player_inventory[key] += value
	
	var inv = get_node(str(player_id)).player_inventory.duplicate(true)
	inv.erase("player_id")
	inv["player_name"] = get_node(str(player_id)).player_name
	rpc_id(0,"receive_other_player_updated_inventory",inv,player_id)

remote func player_left_game():
	# Remove player from game, scoreboard, lists
	var player_id = get_tree().get_rpc_sender_id()
	update_player_inventory(player_id)
	var player_name = get_node(str(player_id)).player_name
	var _message = "Server | " + player_name + " has left the game."
	if has_node(str(player_id)):
		player_state_collection.erase(player_id)

	request_despawn_player(player_id)
	rpc_id(0,"send_player_message",_message,1)
	rpc_id(0,"remove_player_from_scoreboard",player_id)	

	if player_id in mm.players_in_game_world:
		mm.players_in_game_world.erase(player_id)
		if player_id in mm.players_alive_in_game:
			mm.players_alive_in_game.erase(player_id)
	mm.players_in_client_lobby.append(player_id)

	update_server_info()
	
	mm.check_round_end()
	
remote func receive_player_attack_request(collider,collision_point,player_position,gun):
	# Receive player attack request, check if damage can be done
	# Forward damage dealt to the attacked player
	var attacker_id = get_tree().get_rpc_sender_id()
	var pc = get_node(str(attacker_id))
	var selected_gun = pc.player_guns[gun]
	var fire_range = selected_gun["fire_range"]
	var damage = selected_gun["base_damage"]
	var distance = player_position.distance_to(collision_point)
	if int(collider) in get_tree().get_network_connected_peers():
		if distance < fire_range:
			rpc_id(int(collider),"other_player_attacked_player",damage,attacker_id)

remote func receive_spawn_rigid_body_request(data_dict):
	# Spawn a new rigid body for other clients
	var sender_id = get_tree().get_rpc_sender_id()
	data_dict["player_id"] = sender_id
	if data_dict["visuals_name"] == "shoot_rocket":
		data_dict["base_damage"] = get_node(str(sender_id)).player_guns["RocketLauncher"]["base_damage"]
	
	for player_id in get_tree().get_network_connected_peers():
		if player_id == sender_id:
			rpc_id(player_id,"return_spawn_rigid_body",data_dict)
		else:
			rpc_id(player_id,"server_player_visual_actions",data_dict)

remote func receive_player_check_request(player_id):
	# Check that player hasn't timed out irregularly
	if player_id in mm.players_in_game_world:
		var sender_id = get_tree().get_rpc_sender_id()
		rpc_id(sender_id,"return_player_check",player_id)		
	else:
		yield(get_tree().create_timer(0.25),"timeout")
		if player_state_collection.has(str(player_id)):
			player_state_collection.erase(str(player_id))
			
		var data_dict = {}
		data_dict["player_id"] = player_id
		data_dict["visuals_name"] = "despawn_player"
		data_dict["weapon_name"] = ""
		rpc_id(0,"server_player_visual_actions",data_dict)

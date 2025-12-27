extends Node

var network = NetworkedMultiplayerENet.new()
var gateway_api = MultiplayerAPI.new()
var max_players = 100
var port = 50004
var game_server_list = {}
onready var auth

func _ready():
	set_process(false)
	yield(get_tree().create_timer(1),"timeout")
	server_start()
	set_process(true)

func _process(_delta):
	if not custom_multiplayer.has_network_peer():
		return;
	custom_multiplayer.poll();
	
func server_start():
	network.create_server(port,max_players)
	set_custom_multiplayer(gateway_api)
	custom_multiplayer.set_root_node(self)
	custom_multiplayer.set_network_peer(network)
	auth = get_node("../AuthenticationServer")
	auth.send_message_to_console("Game Server Hub has started.")
	network.connect("peer_connected",self,"_peer_connected")
	network.connect("peer_disconnected",self,"_peer_disconnected")

func _peer_connected(game_server_id):
	auth.send_message_to_console("Game Server: " + str(game_server_id) + " has connected,")
	game_server_list["GameServer"] = game_server_id
	
func _peer_disconnected(game_server_id):
	auth.send_message_to_console("Game Server: " + str(game_server_id) + " has disconnected,")
	auth.active_players = []
	game_server_list.erase("GameServer")

func distribute_login_token(token,game_server):
	# Send token to game server
	auth.send_message_to_console("Sending token to Game Server.")
	var gameserver_peer_id = game_server_list[game_server]
	rpc_id(gameserver_peer_id,"receive_login_token",token)
	
func send_player_details(game_server,player_details):
	# Send player details to game servers
	var gameserver_peer_id = game_server_list[game_server]
	rpc_id(gameserver_peer_id,"receive_player_details",player_details)
	
func send_inv_id(peer_id,new_inv_id):
	var gameserver_peer_id = game_server_list["GameServer"]
	rpc_id(gameserver_peer_id,"receive_inv_id",peer_id,new_inv_id)

remote func receive_inv_update_request(inv,inv_id):
	DataBase.update_inventory(inv,inv_id)

remote func retrieve_player_inv(player_name,peer_id):
	#Retrieve every inventory for a specific player id
	var player_id = DataBase.get_player_id(player_name,false)
	var inventory = DataBase.retrieve_player_inventory(player_id)
	var gameserver_peer_id = game_server_list["GameServer"]
	rpc_id(gameserver_peer_id,"receive_player_invs",inventory,peer_id)
	
remote func request_add_inventory(peer_id,inv):
	DataBase.add_inventory(peer_id,inv)	
	
remote func receive_deletion_request(inv_id):
	DataBase.delete_inv(inv_id)
	
remote func receive_new_player_login(player_name):
	get_node("/root/AuthenticationServer").new_player_login(player_name)
	
remote func receive_new_player_logout(player_name):
	get_node("/root/AuthenticationServer").new_player_logout(player_name)

remote func receive_new_username_request(username,old_name):
	DataBase.update_username(username,old_name)
	get_node("/root/AuthenticationServer").change_player_name_from_active_players_list(username,old_name)
	
remote func receive_username_check(username,player_id):
	var game_id = get_tree().get_rpc_sender_id()
	var name_available = false
	if DataBase.retrieve_user_details(username) == []:
		name_available = true
	rpc_id(game_id,"receive_username_check_results",name_available,player_id)
	
remote func receive_verify_pw_request(pw,player_id,db_id):
	var success = DataBase.verify_pw(pw,db_id)
	var game_id = get_tree().get_rpc_sender_id()
	rpc_id(game_id,"receive_pw_results",success,player_id)
	
remote func receive_update_pw_request(pw,db_id):
	DataBase.update_pw(pw,db_id)

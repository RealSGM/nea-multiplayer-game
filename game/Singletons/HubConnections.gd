extends Node

var network = NetworkedMultiplayerENet.new()
var gateway_api = MultiplayerAPI.new()
var ip = "127.0.0.1"
var port = 50004
onready var game_server = get_node("/root/GameServer")

func _ready():
	# Wait 1 second before attempting to connect the server, used for testing purposes
	set_process(false)
	yield(get_tree().create_timer(1),"timeout")
	connect_to_server()
	set_process(true)
	
func _process(_delta):
	if get_custom_multiplayer() == null:
		return
	if not custom_multiplayer.has_network_peer():
		return;
	custom_multiplayer.poll();
	
func connect_to_server():
	# Attempt to connect game server to the authentication server
	network.create_client(ip,port)
	set_custom_multiplayer(gateway_api)
	custom_multiplayer.set_root_node(self)
	custom_multiplayer.set_network_peer(network)
	
	network.connect("connection_failed",self,"_on_connection_failed")
	network.connect("connection_succeeded",self,"_on_connection_succeeded")
	
func _on_connection_failed():
	# Send to console, stating that connection failed
	game_server.send_message_to_console("Failed to connect to the game server hub.")

func _on_connection_succeeded():
	# Send to console, stating successful connection
	game_server.send_message_to_console("Successfully connected to the game server hub.")

func request_player_update_inventory(inv,inv_id):
	# Send request to update inv
	rpc_id(1,"receive_inv_update_request",inv,inv_id)

func retrieve_player_inv(player_name,peer_id):
	# Request inventory retrieval
	rpc_id(1,"retrieve_player_inv",player_name,peer_id)

func add_inventory(peer_id,inv):
	rpc_id(1,"request_add_inventory",peer_id,inv)

func send_deletion_request(inv_id):
	rpc_id(1,"receive_deletion_request",inv_id)

func new_player_login(player_name):
	rpc_id(1,"receive_new_player_login",player_name)

func player_log_out(player_name):
	rpc_id(1,"receive_new_player_logout",player_name)

func send_username(username,old_name):
	rpc_id(1,"receive_new_username_request",username,old_name)
	
func request_username_check(username,player_id ):
	rpc_id(1,"receive_username_check",username,player_id)
	
func send_verify_pw_request(pw,player_id):
	var player_db_id = get_node("/root/GameServer/" + str(player_id)).player_id
	rpc_id(1,"receive_verify_pw_request",pw,player_id,player_db_id)
	
func send_pw_update_request(pw,player_id):
	var player_db_id = get_node("/root/GameServer/" + str(player_id)).player_id
	rpc_id(1,"receive_update_pw_request",pw,player_db_id)	

remote func receive_login_token(token):
	game_server.expected_tokens.append(token)

remote func receive_player_details(player_details):
	get_node("/root/GameServer/PlayerVerification").latest_player_details = player_details

remote func receive_player_invs(inventory,peer_id):
	get_node("/root/GameServer").return_player_invs(inventory,peer_id)

remote func receive_inv_id(peer_id,inv_id):
	get_node("/root/GameServer/" + str(peer_id)).inventory_id = int(inv_id)

remote func receive_username_check_results(results,player_id):
	get_node("/root/GameServer").send_username_check_results(results,player_id)

remote func receive_pw_results(success,player_id):
	get_node("/root/GameServer").send_pw_results(success,player_id)

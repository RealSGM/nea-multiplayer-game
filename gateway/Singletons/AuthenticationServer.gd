extends Node

onready var gateway = get_node("/root/Gateway")
var network = NetworkedMultiplayerENet.new()
#var ip = "82.41.231.179"
var ip = "127.0.0.1"
var port = 50003
var connected_to_auth = false

func _ready():
	connect_to_server()
	
func connect_to_server():
	network.create_client(ip,port)
	get_tree().set_network_peer(network)
	network.connect("connection_failed",self,"_on_connection_failed")
	network.connect("connection_succeeded",self,"_on_connection_succeeded")
	network.connect("server_disconnected", self, "_server_disconnected")
	
func _on_connection_failed():
	gateway.send_message_to_console("Failed to connect to the authentication server.")
	connected_to_auth = false
	
func _on_connection_succeeded():
	gateway.send_message_to_console("Successfully connected to the authentication server.")
	connected_to_auth = true
	
func server_disconnected():
	gateway.send_message_to_console("Disconnected from the authentication server.")
	connected_to_auth = false
	
func request_player_authentication(username,password,player_id):
	# Send request to auth server for player authentication
	gateway.send_message_to_console("Sending out authentication request for " + str(player_id))
	rpc_id(1,"player_authentication_request",username,password,player_id)

func request_create_account(username,password,player_id):
	# Send request to auth server to create a new acount
	gateway.send_message_to_console("Sending out create account request for Player: " + str(player_id))
	rpc_id(1,"create_account_request",username,password,player_id)
	
remote func return_authentication_results(result,player_id,token,message):
	gateway.send_message_to_console("Results received to gateway")
	GatewayServer.return_login_request(player_id,result,token,message)
	
remote func return_create_account_results(result,player_id,message):
	gateway.send_message_to_console("Results received, sending to player " + str(player_id) + " to create account.")
	GatewayServer.return_create_account_request(player_id,result,message)

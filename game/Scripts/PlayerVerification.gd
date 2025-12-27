extends Node

onready var main_interface = get_parent()
onready var player_container_scene = load("res://Scenes/PlayerContainer.tscn")
var awaiting_verification = {}
var latest_player_details = {}
var latest_player_inventory = {}

func start(player_id):
	# Add the time of the verification start process, fetch the player's token
	awaiting_verification[player_id] = {"time_stamp": OS.get_unix_time()}
	main_interface.fetch_token(player_id)
	
func create_player_container(id):
	# Instance a new player container scene, fill the contents of the player container
	var new_player_container = player_container_scene.instance()
	new_player_container.name = str(id)
	fill_player_container(new_player_container)
	get_parent().add_child(new_player_container,true)
	
func fill_player_container(npc):
	# Find latest player details and store them into the new player container
	if latest_player_details != {}:
		npc.player_name = latest_player_details["username"]		
		npc.player_id = latest_player_details["id"]
	
func verify(player_id,token):
	# Verify token, see if the token process took less than 30 seconds and that the tokens match
	var token_verification = false
	while OS.get_unix_time() - int(token.right(64)) <= 30:
		if main_interface.expected_tokens.has(token):
			token_verification = true
			create_player_container(player_id)
			awaiting_verification.erase(player_id)
			main_interface.expected_tokens.erase(token)
			break
		else:
			yield(get_tree().create_timer(2),"timeout")
			
	main_interface.return_token_verification_results(player_id,token_verification)
	if !token_verification:
		awaiting_verification.erase(player_id)
		main_interface.network.disconnect_peer(player_id)
	
func _on_VerificationExpiration_timeout():
	# Disconnect any users whose tokens took too long to verify
	var current_time = OS.get_unix_time()
	var start_time
	if !(awaiting_verification == {}):
		for key in awaiting_verification.keys():
			start_time = awaiting_verification[key].time_stamp
			if current_time - start_time >= 30:
				awaiting_verification.erase(key)
				var connected_peers = Array(get_tree().get_network_connected_peers())
				if connected_peers.has(key):
					main_interface.return_token_verification_results(key, false)
					main_interface.network.disconnect_peer(key)			
	

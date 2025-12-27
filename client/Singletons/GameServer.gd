extends Node

onready var loadout_selection = preload("res://Scenes/Player/UI/LoadoutSelection.tscn")
var main_world = preload("res://Scenes/World.tscn")

var network = NetworkedMultiplayerENet.new()
#var ip = "82.41.231.179" 
var ip = "127.0.0.1"
var port = 50001
var token 
	
func _ready():
	get_tree().connect("server_disconnected",self,"_server_disconnected")	
	
func connect_to_server():
	network.create_client(ip,port)
	get_tree().set_network_peer(network)
	
func _server_disconnected():
	get_tree().quit()
			
func load_world():
	# Loading the world, updating variables, setting request to the game server that client has joined
	var world = main_world.instance()
	get_node("/root/MainScene").add_child(world,true)
	var player = preload("res://Scenes/Player/ClientPlayer.tscn").instance()
	ClientStats.player_network_id = get_tree().get_network_unique_id()
	player.set_name(str(get_tree().get_network_unique_id()))
	player.set_network_master(get_tree().get_network_unique_id())
	player.translation = world.get_node("Spawn").translation
	get_node("/root/MainScene/World/ClientPlayer").add_child(player,true)
	rpc_id(1,"new_player")
	ClientStats.in_game = true

func send_disconnect_player():
	rpc_id(1,"disconnect_player")
	
func send_message(message):
	rpc_id(1,"receive_player_message",message)
	
func load_loadout_selection():
	var loadout_instance = loadout_selection.instance()
	get_node("/root/MainScene").add_child(loadout_instance,true)
	
func get_player_invs():
	rpc_id(1,"retrieve_player_inv")

func request_all_loadouts():
	rpc_id(1,"retrieve_all_loadouts")

func send_client_stats(inv):
	rpc_id(1,"receive_existing_client_stats",inv)

func send_player_state(player_state):
	rpc_id(1,"receive_player_state", player_state)

func send_deletion_requestion(inv_id):
	rpc_id(1,"receive_deletion_request",inv_id)
	
func join_matchmaking_queue():
	rpc_id(1,"receive_matchmaking_request")

func leave_matchmaking_queue():
	rpc_id(1,"receive_matchmaking_cancellation")

func send_new_username(username,old_name):
	rpc_id(1,"receive_username_request",username,old_name)

func check_if_name_taken(username):
	rpc_id(1,"receive_username_check",username)

func verify_old_password(pw):
	rpc_id(1,"receive_verify_pw_request",pw)

func update_pw(new_pw):
	rpc_id(1,"receive_pw_update_request",new_pw)
		
func request_new_player_guns(joining_player_id):
	rpc_id(1,"request_new_player_guns",joining_player_id)		
	
func send_visuals(data_dict):
	rpc_id(1,"receive_visuals",data_dict)

func player_attacked_other_player(player_id,damage):
	rpc_id(1,"request_player_attacking_other_player",player_id,damage)

func player_killed_by_other_player(attacker_id):
	rpc_id(1,"request_player_achieved_kill",attacker_id)

func send_gravity_shift_request():
	rpc_id(1,"receive_gravity_shift_request")

func create_new_inventory(chosen_class):
	rpc_id(1,"request_new_inventory_creation",chosen_class)
	
func fetch_player_inventory(reason):
	rpc_id(1,"receive_fetch_inventory_request",reason)	
	
func update_client_inventory(key,value):
	rpc_id(1,"receive_inventory_update_request",key,value)
		
func send_leave_request():
	rpc_id(1,"player_left_game")
	
func send_player_collision_check_request(collider,point,player_position,gun):
	rpc_id(1,"receive_player_attack_request",collider,point,player_position,gun)
	
func spawn_new_rigid_body(data_dict):
	rpc_id(1,"receive_spawn_rigid_body_request",data_dict)
	
func check_if_player_exists(player_id):
	rpc_id(1,"receive_player_check_request",player_id)
	
remote func receive_player_invs(inv,class_details):
	get_node("/root/MainScene/LoadoutSelection").receive_inv(inv,class_details)
	
remote func fetch_token():
	rpc_id(1, "return_token",token)
	
remote func return_token_verification_results(result):
	var login_node = get_tree().get_root().get_node("MainScene/LoginMenu/BG/FG/CC/"+ ClientStats.current_scene)
	if result:	
		login_node.display_message("Successful token verification")
		get_tree().get_root().get_node("MainScene/LoginMenu").queue_free()
		load_loadout_selection()
	else:
		login_node.display_message("Login failed, please try again")
		get_tree().get_root().get_node("MainScene/LoginMenu").login_button.disabled = false

remote func spawn_new_player(player_id,_spawn_position):
	if ClientStats.in_game:
		get_node("/root/MainScene/World").spawn_new_player(player_id)
		
remote func receive_world_state(world_state):
	if has_node("../MainScene/World"):
		get_node("../MainScene/World").update_world_state(world_state)

remote func send_player_message(message,player_id):
	if ClientStats.in_game:
		ClientStats.player_node.send_message(message,false,player_id)
	
remote func receive_all_loadouts(loadouts_list):
	get_node("/root/MainScene/LoadoutPicker").loadout_instancing(loadouts_list)

remote func receive_class_details(guns,class_details):
	ClientStats.player_guns = guns	
	ClientStats.class_details = class_details
	
remote func start_match():
	load_world()
	get_node("/root/MainScene/ClientLobby").queue_free()
	
remote func receive_username_check_results(results):
	ClientStats.options_node._on_username_check_results_received(results)

remote func receive_pw_results(success):
	ClientStats.options_node._on_old_password_confirmed(success)

remote func retrieve_other_player_current_gun(player_id):
	if ClientStats.in_game:
		var current_gun = ClientStats.player_node.selected_gun
		rpc_id(1,"receive_other_player_current_gun" ,current_gun,player_id)
		
remote func server_player_visual_actions(data_dict):
	var player_id = data_dict["player_id"]
	# Ensures player is in game
	if ClientStats.in_game:
		# Ensures client is not the one who has performed the action
		if ClientStats.player_network_id != int(player_id):
			var server_players = get_node("/root/MainScene/World/ServerPlayers")
			if server_players != null and server_players.has_node(str(player_id)):
				server_players.get_node(str(player_id)).apply_visuals(data_dict)
	
remote func other_player_attacked_player(damage,attacker_id):
	if ClientStats.in_game:
		ClientStats.player_node.player_attacked(damage,attacker_id)

remote func return_client_preparation_request(rand_pos):
	# Prepares clients for the next round
	while ClientStats.player_node == null:
		yield(get_tree().create_timer(0.1),"timeout")	
	var user = ClientStats.player_node	
	user.set_translation(rand_pos)
	
	# Cancels reloads and resets ability
	user.camera.get_node(user.selected_gun).cancel_reload()
	if user.get_node("LoadoutClass").has_method("reset_ability"):
		 user.get_node("LoadoutClass").reset_ability()
	
	# Resets their HUD
	user.prepare_health()
	for weapon in ClientStats.player_guns.keys():
		user.camera.get_node(weapon).update_weapon(ClientStats.player_guns[weapon])
	user.camera.get_node(user.selected_gun).update_counters()

	# Removes ability and rocket instances after each round
	for instance in ClientStats.ability_instances:
		instance.queue_free()
		ClientStats.ability_instances.erase(instance)
	
	ClientStats.round_ended = false
	
remote func respawn_dead_player():
	ClientStats.is_dead = false
	if ClientStats.player_node != null:
		ClientStats.player_node.camera.get_node(ClientStats.player_node.selected_gun).show_weapon()
		ClientStats.player_node.head.rotation_degrees = Vector3.ZERO
		ClientStats.player_node.camera.rotation_degrees = Vector3.ZERO	
	
remote func player_won_round(balance):
	ClientStats.round_ended = true
	ClientStats.player_node.update_balance_label(balance)
	
remote func return_inv_for_scoreboard(sender_id,inv):
	if ClientStats.in_game and sender_id != ClientStats.player_network_id:
		ClientStats.player_node.add_client_to_scoreboard(inv,sender_id)

remote func remove_player_from_scoreboard(player_id):
	if ClientStats.in_game:
		ClientStats.player_node.remove_player_from_scoreboard(player_id)

remote func receive_other_player_updated_inventory(inv,sender_id):
	if ClientStats.in_game:
		ClientStats.player_node.update_scoreboard_row(inv,sender_id)

remote func apply_gravity_shift(sender_id):
	var player = ClientStats.player_node
	if ClientStats.in_game:
		if ClientStats.player_network_id != sender_id:
			player.gravity = 10 * player.NORMAL_GRAVITY
			player.speed = 0.05 * player.normal_speed
	
remote func revert_gravity_shift(sender_id):
	var player = ClientStats.player_node
	if ClientStats.in_game:
		if ClientStats.player_network_id != sender_id:
			player.gravity = player.NORMAL_GRAVITY
			player.speed = player.normal_speed
	
remote func return_player_name(player_name):
	ClientStats.player_name = player_name

remote func return_player_inventory(inv,reason):
	match reason:
		"InitialPreparation":
			ClientStats.player_node.prepare_client(inv)
		"CheckBalance":
			if inv["balance"] > ClientStats.class_details["ability_cost"]:
				ClientStats.player_node.activate_ability(inv["balance"])

remote func receive_player_balance(balance):
	ClientStats.player_node.update_balance_label(balance)

remote func return_spawn_rigid_body(data_dict):
	match data_dict["visuals_name"]:
		"shoot_rocket":
			ClientStats.player_node.camera.get_node("RocketLauncher").spawn_new_rocket(data_dict)
		"throw_smoke":
			ClientStats.player_node.get_node("LoadoutClass").spawn_new_smoke(data_dict)

remote func return_player_check(player_id):
	if ClientStats.in_game:
		get_node("/root/MainScene/World").spawn_new_player(player_id)


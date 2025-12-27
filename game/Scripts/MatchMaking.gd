extends Node

onready var rng = RandomNumberGenerator.new()

var players_in_mm_queue = []
var players_in_game_world = []
var players_alive_in_game = []
var players_in_client_lobby = []
const WINNING_PLAYER_COUNT = 1
const REQUIRED_PLAYERS = 2
var round_in_progress = false
var game_started = false
var processing = false
var current_round = 0

func _on_MMChecker_timeout():
	check_for_game_status()
	if !processing:
		if !game_started:
			# Called when there are no players in the game
			create_game()
		elif !round_in_progress:
			# Called when game has started as well the round has ended
			start_new_round()	

func check_for_game_status():
	# Removes disconnected players
	for player in players_in_game_world:
		if !get_parent().has_node(str(player)):
			get_parent().remove_player(player)
	# Checks if anyone is in game
	if players_in_game_world.size() == 0:
		game_started = false
		round_in_progress = false
	# Checks if the round has ended
	elif players_alive_in_game.size() <= WINNING_PLAYER_COUNT:
		game_started = true
		round_in_progress = false
	
func create_game():
	# Reset the current cound
	current_round = 1
	processing = true
	# Ensures that there are enough players
	if players_in_mm_queue.size() >= REQUIRED_PLAYERS:
		for _player_index in range(players_in_mm_queue.size()):
			add_player()
		game_started = true
		round_in_progress = true
		reset_positions()
	processing = false
	get_parent().update_server_info()
	
func start_new_round():
	current_round += 1
	processing = true
	if (players_in_game_world.size() + players_in_mm_queue.size()) >= REQUIRED_PLAYERS:
		# Adding new players_into the game
		for _player_index in range(players_in_mm_queue.size()):
			add_player()
		reset_positions()
	elif players_in_game_world.size() == 0:
		game_started = false
		round_in_progress = false
	elif players_in_game_world.size() >= 1 and players_alive_in_game.size() == 0 and round_in_progress:
		round_in_progress = false
		
	processing = false
	get_parent().update_server_info()	

func reset_positions():
	processing = true
	round_in_progress = true

	# Respawns dead players
	for player in players_in_game_world:
		if !(player in players_alive_in_game):
			get_parent().respawn_dead_player(player)
	players_alive_in_game = players_in_game_world.duplicate(true)
	
	for player in players_alive_in_game:
		# Set player positions, temporarily disable movement
		var x = rng.randi_range(-74,74)
		var z = rng.randi_range(-79,79)
		get_parent().client_preparation(player,Vector3(x,30,z))
	processing = false	
	var _message = "Server | Round " + str(current_round) + " is starting!"
	get_parent().rpc_id(0,"send_player_message",_message,1)

func add_player():
	# Dequeues the players from the mm queue
	var player_id = players_in_mm_queue.pop_front()
	players_in_game_world.append(player_id)
	get_parent().start_new_match(player_id)
	get_parent().update_server_info()

func player_removed(player_id):
	players_alive_in_game.erase(player_id)
	get_parent().update_server_info()
	
	if get_parent().has_node(str(player_id)):
		var player_name = get_parent().get_node(str(player_id)).player_name
		var message = "Server | " + player_name + " has been killed!"
		get_parent().rpc_id(0,"send_player_message",message,1)	
	check_round_end()
	
func end_round():
	# Tell players that the round has ended
	round_in_progress = false	
	var winner = players_alive_in_game[0]
	get_parent().player_won_round(winner)
	$MMChecker.start()
	var message = "Server | Round " + str(current_round) + " has ended! Checking for new players."
	get_parent().rpc_id(0,"send_player_message",message,1)
	
func check_round_end():
	# Check if theres one player surviving, if so, declare round end and proceed to next round
	if players_alive_in_game.size() == WINNING_PLAYER_COUNT:
		end_round()
	

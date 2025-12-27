extends Spatial

var other_player = preload("res://Scenes/Player/ServerPlayer.tscn")
var last_world_state = 0
var world_state_buffer = []
const interpolation_offset = 100
onready var spawn = $Spawn

func _physics_process(_delta):
	var render_time = OS.get_system_time_msecs() - interpolation_offset
	if world_state_buffer.size() > 1:
		while world_state_buffer.size() > 2 and render_time > world_state_buffer[2].T:
			world_state_buffer.remove(0)
		if world_state_buffer.size() > 2:
			#There is a future state to interpolate between
			var interpolation_factor = float(render_time - world_state_buffer[1]["T"]) / float(world_state_buffer[2]["T"] - world_state_buffer[1]["T"])
			for player in world_state_buffer[2].keys():
				if str(player) == "T":
					continue
				if player == get_tree().get_network_unique_id():
					continue
				if not world_state_buffer[1].has(player):
					continue
				if get_node("ServerPlayers").has_node(str(player)):
					var new_rotation = lerp(world_state_buffer[1][player]["R1"], world_state_buffer[2][player]["R1"],interpolation_factor)				
					var new_position = lerp(world_state_buffer[1][player]["P"], world_state_buffer[2][player]["P"],interpolation_factor)
					var new_player_rotation = lerp(world_state_buffer[1][player]["R2"], world_state_buffer[2][player]["R2"],interpolation_factor)
					
					get_node("ServerPlayers/" + str(player)).move_player(new_position,new_rotation,new_player_rotation)
				else:
					GameServer.check_if_player_exists(player)
		elif render_time > world_state_buffer[1].T:
			#No future, need to extrapolate
			var diff = float(world_state_buffer[1]["T"] - world_state_buffer[0]["T"] - 1.00)
			if diff == 0:
				diff = 1 
			var extrapolation_factor = float(render_time - world_state_buffer[0]["T"]) / diff
			for player in world_state_buffer[1].keys():
				if str(player) == "T":
					continue
				if player == get_tree().get_network_unique_id():
					continue
				if not world_state_buffer[0].has(player):
					continue	
				if get_node("ServerPlayers").has_node(str(player)):
					var position_delta  = (world_state_buffer[1][player]["P"] - world_state_buffer[0][player]["P"])
					var new_position = world_state_buffer[1][player]["P"] + (position_delta * extrapolation_factor)
					
					var rotation_delta = (world_state_buffer[1][player]["R1"] - world_state_buffer[0][player]["R1"])
					var new_rotation = world_state_buffer[1][player]["R1"] + (rotation_delta * extrapolation_factor)
					
					var player_rotation_delta = (world_state_buffer[1][player]["R2"] - world_state_buffer[0][player]["R2"])
					var new_player_rotation = world_state_buffer[1][player]["R2"] + (player_rotation_delta * extrapolation_factor)
					
					get_node("ServerPlayers/" + str(player)).move_player(new_position,new_rotation,new_player_rotation)

func update_world_state(world_state):
	if world_state["T"] > last_world_state:
		last_world_state = world_state["T"]
		world_state_buffer.append(world_state)	

func spawn_new_player(player_id):
	var new_player = other_player.instance()
	new_player.translation = Vector3(0,80,0)
	new_player.name = str(player_id)
	GameServer.request_new_player_guns(player_id)
	$ServerPlayers.add_child(new_player,true)

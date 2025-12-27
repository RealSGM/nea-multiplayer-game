extends Node

var gravity_shifted = false

func prepare_class():
	pass
	
func check_event():
	pass

func activate_ability():
	# Send request to upate gravity
	GameServer.send_gravity_shift_request()
	
func reset_ability():
	pass

	

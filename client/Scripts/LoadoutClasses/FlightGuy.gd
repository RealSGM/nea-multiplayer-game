extends Node

var flight_timer
var original_gravity = 9.81 * 3
	
func activate_ability():
	# Disable gravity
	get_parent().gravity = 0
	flight_timer.start()
	
func prepare_class():
	# Instance a few flight timer, connect its signal to reset function
	original_gravity = get_parent().gravity
	flight_timer = Timer.new()
	flight_timer.set_name("FlightTimer")
	flight_timer.set_one_shot(true)
	flight_timer.set_wait_time(4)
	flight_timer.connect("timeout",self,"reset_ability")
	get_parent().add_child(flight_timer,true)

func check_event():
	pass
	
func reset_ability():
	# Dsiable flight, stop timer
	flight_timer.stop()
	get_parent().gravity = original_gravity

extends RigidBody

var speed = 5

func _ready():
	# Prepares visuals and collisions for the smoke grenade
	$CanisterArea.connect("body_entered",self,"_on_CanisterArea_body_entered")
	$SmokeTimer.connect("timeout",self,"_on_SmokeTimer_timeout")
	set_as_toplevel(true)
	$SmokeCanister.show()
	$SmokeParticles.hide()

func _on_CanisterArea_body_entered(body):
	# Releases smoke particles when collision detected
	if not "Smoke" in body.get_name():
		$CanisterArea.set_deferred("monitoring",false)
		$SmokeCanister.hide()
		set_sleeping(true)
		$SmokeParticles.show()
		$SmokeParticles.set_emitting(true)
		$SmokeTimer.start()

func add_impulse():
	# Apply force in line with player's head direction
	apply_impulse(transform.basis.z,-transform.basis.z*speed)

func _on_SmokeTimer_timeout():
	# Hides particles after timer ends
	$SmokeParticles.set_emitting(false)
	yield(get_tree().create_timer(1),"timeout")
	hide()
	ClientStats.player_node.get_node("LoadoutClass").reset_ability()

	

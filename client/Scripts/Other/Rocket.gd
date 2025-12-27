 extends RigidBody

var base_damage = 1
var speed = 2.5

func _ready():
	# Prepares the rocket's visuals and collisions
	$AP.connect("animation_finished",self,"_on_AP_animation_finished")
	$RocketArea.connect("body_entered",self,"_on_RocketArea_body_entered")
	set_as_toplevel(true)
	$Trail.set_emitting(true)
	$MeshInstance.set_visible(true)
	sleeping = false

func _on_RocketArea_body_entered(_body):
	# Disables the rocket collisions, shows explosion animation
	$RocketArea.set_deferred("monitoring",false)	
	sleeping = true
	$Trail.hide()
	$MeshInstance.set_visible(false)
	$ExplosionArea.connect("body_entered",self,"_on_ExplosionArea_body_entered")	
	$AP.seek(0,true)
	$AP.play("explode")

func add_impulse():
	# Used to apply a force parallel to the player's head directio
	apply_impulse(transform.basis.z,-transform.basis.z*speed)

func _on_AP_animation_finished(anim_name):
	# Hide the explosion after it finishes
	if anim_name == "explode":
		hide()

func _on_ExplosionArea_body_entered(body):
	# Used when a player ends up in the explosion node
	if body == ClientStats.player_node:
		GameServer.player_attacked_other_player(int(body.get_name()),base_damage)

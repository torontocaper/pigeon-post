extends CharacterBody2D
class_name Pigeon

@export_category("Vertical Motion")
@export var gravity: float = 400.0
@export var flap_impulse: float = 200.0
@export var max_fall_speed: float = 200.0
@export var dive_gravity_multiplier: float = 2.0
@export var dive_max_fall_speed: float = 400.0

@export_category("Horizontal Motion")
@export var air_speed: float = 140.0
@export var ground_speed: float = 80.0
@export var air_control: float = 1.0      # 0..1; <1 = looser in air
@export var ground_friction: float = 0.2  # frame-based lerp toward 0

@export_category("Flap Charges")
@export var max_flaps: int = 5
@export var recharge_interval_ground: float = 0.8  # secs/charge on ground
@export var recharge_interval_air: float = 0.0     # 0 = no air recharge

var flaps: int
var _recharge_accum: float = 0.0

# -------- Nodes / state --------
var input_locked: bool = false
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Explicitly typed; assigned in _ready() to avoid Variant inference
var sfx_flap: AudioStreamPlayer2D = null
var carry_socket: Node2D = null
var interact_area: Area2D = null
var charges_bar: ProgressBar = null

# Carry state (now Node2D to support Sprite2D OR RigidBody2D)
var carried_envelope: Node2D = null
var _near_envelope: Node2D = null
var _near_dropoff: Area2D = null

func _ready() -> void:
	flaps = max_flaps
	anim.play("idle")
	anim.animation_finished.connect(_on_anim_finished)

	# Node lookups (typed)
	sfx_flap = get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
	carry_socket = get_node_or_null(^"%CarrySocket") as Node2D
	if carry_socket == null and has_node("CarrySocket"):
		carry_socket = $"CarrySocket" as Node2D

	interact_area = get_node_or_null("InteractArea") as Area2D
	if interact_area:
		interact_area.area_entered.connect(_on_area_entered)
		interact_area.area_exited.connect(_on_area_exited)
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)

	charges_bar = get_node_or_null(^"%StaminaBar") as ProgressBar
	if charges_bar:
		charges_bar.min_value = 0
		charges_bar.max_value = max_flaps
		charges_bar.value = flaps

func _physics_process(delta: float) -> void:
	var on_floor: bool = is_on_floor()

	# --- Horizontal ---
	var dir: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	var current_speed: float = ground_speed if on_floor else air_speed
	var target_vx: float = dir * current_speed
	var control: float = clamp(air_control if not on_floor else 1.0, 0.0, 1.0)
	velocity.x = lerp(velocity.x, target_vx, control)

	if on_floor and dir == 0.0:
		velocity.x = lerp(velocity.x, 0.0, ground_friction)

	if absf(velocity.x) > 1.0:
		# Faces LEFT by default → flip when moving RIGHT
		anim.flip_h = velocity.x > 0.0

	# --- Vertical (gravity + dive) ---
	var diving: bool = Input.is_action_pressed("dive") and not on_floor
	var g: float = gravity
	var fall_cap: float = max_fall_speed
	if diving:
		g *= dive_gravity_multiplier
		fall_cap = dive_max_fall_speed
	velocity.y = min(velocity.y + g * delta, fall_cap)

	# --- Flap recharge ---
	var interval: float = recharge_interval_ground if on_floor else recharge_interval_air
	if interval > 0.0 and flaps < max_flaps:
		_recharge_accum += delta
		while _recharge_accum >= interval and flaps < max_flaps:
			flaps += 1
			_recharge_accum -= interval
			_update_charges_ui()

	# --- Flap (spend a charge) ---
	if not input_locked and Input.is_action_just_pressed("flap") and flaps > 0:
		flaps -= 1
		velocity.y = -flap_impulse
		input_locked = true
		if anim.animation != "flap":
			anim.play("flap") # one-shot wingbeat
		if sfx_flap:
			sfx_flap.play()
		_update_charges_ui()

	# --- Interact: pick up / deliver / drop ---
	if Input.is_action_just_pressed("interact"):
		_handle_interact()

	move_and_slide()

	# --- Animation ---
	if input_locked:
		return
	_update_anim(Input.is_action_pressed("dive") and not is_on_floor())

func _on_anim_finished(_name: StringName = &"") -> void:
	input_locked = false
	_update_anim(Input.is_action_pressed("dive") and not is_on_floor())

func _update_anim(diving: bool) -> void:
	if is_on_floor():
		if absf(velocity.x) > 1.0:
			if anim.animation != "walk":
				anim.play("walk")
		else:
			if anim.animation != "idle":
				anim.play("idle")
		return
	# Airborne
	if diving:
		if anim.animation != "dive":
			anim.play("dive")   # loop
	else:
		if anim.animation != "glide":
			anim.play("glide")  # loop

# ======================
# Interact system (no groups)
# ======================

func _handle_interact() -> void:
	if carried_envelope:
		if _near_dropoff:
			_try_deliver(_near_dropoff)
		else:
			_drop_carried_to_ground()
	else:
		_try_pickup()

func _on_area_entered(a: Area2D) -> void:
	# Envelope child Area2D → parent is the envelope root (Node2D) with pick_up()
	var p: Node = a.get_parent()
	if p is Node2D and p.has_method("pick_up"):
		_near_envelope = p as Node2D
		return
	# Treat any Area2D with "dropoff" in the name as a delivery target
	var lname: String = a.name.to_lower()
	if lname.find("dropoff") >= 0:
		_near_dropoff = a

func _on_area_exited(a: Area2D) -> void:
	if _near_envelope and a.get_parent() == _near_envelope:
		_near_envelope = null
	if a == _near_dropoff:
		_near_dropoff = null

# If envelopes later become bodies instead of just areas, this stays compatible.
func _on_body_entered(b: Node) -> void:
	if b is Node2D and b.has_method("pick_up"):
		_near_envelope = b as Node2D

func _on_body_exited(b: Node) -> void:
	if b == _near_envelope:
		_near_envelope = null

func _try_pickup() -> void:
	if _near_envelope == null:
		return
	if carry_socket == null:
		push_warning("CarrySocket not found; cannot pick up envelope.")
		return
	if not is_instance_valid(_near_envelope):
		_near_envelope = null
		return
	carried_envelope = _near_envelope
	_near_envelope = null
	carried_envelope.call_deferred("pick_up", self, carry_socket)

func _try_deliver(target: Node) -> void:
	if carried_envelope == null:
		return
	if not is_instance_valid(carried_envelope):
		carried_envelope = null
		return
	carried_envelope.call_deferred("deliver", target)
	carried_envelope = null

func _drop_carried_to_ground() -> void:
	if carried_envelope == null:
		return
	if not is_instance_valid(carried_envelope):
		carried_envelope = null
		return
	var world: Node = get_tree().current_scene
	var drop_pos: Vector2 = global_position + Vector2(0, 8)
	carried_envelope.call_deferred("drop_to_ground", world, drop_pos)
	carried_envelope = null

func _update_charges_ui() -> void:
	if charges_bar:
		charges_bar.max_value = max_flaps
		charges_bar.value = flaps

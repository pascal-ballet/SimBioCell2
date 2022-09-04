# **********************************************************
# NetBioDyn 2
# Pascal BALLET
# pascal.ballet@univ-brest.fr
# University of Brest
# MIT Licence
# **********************************************************

# MVC
# This class is the Controler
# The View is scene called ScBioDyn2.tscn
# The Model is the 3D scene

extends Node

# Param Tabs N°
enum Prop {EMPTY, ENTITY, BEHAVIOR_REACTION,BEHAVIOR_RANDOM_FORCE, GRID, ENV }

# **********************************************************
#                        KEY NODES                         *
# **********************************************************
# 2D important nodes
onready var _listAgents:ItemList 	= find_node("ListAgents")
# 3D simulator nodes
onready var _node_env	:Node 	= find_node("Environment")
onready var _node_behavs	:Node 	= find_node("Behaviors")
onready var _node_status	:Label 	= find_node("LabelStatusbar")
# Simulator time steps
var _step:int = 0
# Env sizes
var _env_min_x:float = -20
var _env_min_y:float =  0
var _env_min_z:float = -20
var _env_max_x:float =  20
var _env_max_y:float =  0
var _env_max_z:float =  20

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# **********************************************************
#                        SCHEDULER                         *
# **********************************************************
func _process(delta):
	# MANAGE Simulator Control (PLAY / STEP / PAUSE / STOP)
	if _sim_play == false:
		return
		
	if _sim_play == true && _sim_pause == true && _sim_play_once == false:
		return
		
	if _sim_play_once == true:
		_sim_play_once = false
		
	# PLAY ONE step
	if _step % 1 == 0:	
		updateStatus()
		
	# Play Behaviors
	for behav in _node_behavs.get_children():
		for agent in _node_env.get_children():
			behav.action(self, agent) # on applique le comportement behav sur l'agent agt

	# Environment constraints
	for agent in _node_env.get_children():
		if agent.global_transform.origin.x < _env_min_x:
			agent.global_transform.origin.x = _env_max_x
		if agent.global_transform.origin.y < _env_min_y:
			agent.global_transform.origin.y = _env_max_y
		if agent.global_transform.origin.z < _env_min_z:
			agent.global_transform.origin.z = _env_max_z
		if agent.global_transform.origin.x > _env_max_x:
			agent.global_transform.origin.x = _env_min_x
		if agent.global_transform.origin.y > _env_max_y:
			agent.global_transform.origin.y = _env_min_y
		if agent.global_transform.origin.z > _env_max_z:
			agent.global_transform.origin.z = _env_min_z
			
	# Next simulation step
	_step = _step + 1

func updateStatus()->void:
	var nb_agents:int = _node_env.get_child_count()
	var nb_behavs:int = _node_behavs.get_child_count()
	_node_status.text = str("step=", _step, " | Nb agents=", nb_agents, " | Nb behaviors=", nb_behavs)













# **********************************************************
#                         AGENTS                           *
# **********************************************************
func addAgent(var name) -> void:	
	# Create new Agent in GUI -----------------------------
	var lst:ItemList = _listAgents
	lst.add_item(name)
	lst.set_item_metadata(lst.get_item_count()-1, "Agent") # type of the item
	
	# Create new Agent Type in 3D Scene -----------------------------
	#print_debug("addAgent")
	var rb:RigidBody = create_rigid_body_agent(name)
	rb.visible = false
	var node_entities:Node = get_node("%Entities")

	#  - add the Agent to the scene
	node_entities.add_child(rb)
	rb.set_owner(get_node("%Simulator"))
	
func create_rigid_body_agent(var name:String) -> RigidBody:
	#  - material
	var mat:SpatialMaterial = SpatialMaterial.new()
	mat.albedo_color = Color(randf(),randf(),randf(), 1.0)
	#  - mesh
	var mh:MeshInstance = MeshInstance.new()
	mh.mesh = SphereMesh.new()
	mh.scale = Vector3(1.3, 1.3, 1.3)
	mh.set_material_override(mat)
	#  - collision
	var col:CollisionShape = CollisionShape.new()
	col.shape = SphereShape.new()
	#  - rigidbody
	var rb:RigidBody = RigidBody.new()
	rb.name = name
	rb.set_gravity_scale(0)
	rb.set_collision_layer_bit(0,true)
	rb.set_collision_mask_bit(0,true)
	rb.contacts_reported = 1
	rb.contact_monitor = true
	rb.set_linear_damp(5.0)
	
	rb.add_child(mh)
	rb.add_child(col)
	
	return rb

func clone_rigid_body_agent(var rb0:RigidBody) -> RigidBody:
	#print_debug(str(" TRY TO clone_rigid_body_agent " ))
	var rb:RigidBody = rb0.duplicate()
	#print_debug(str(" SUCCESS " ))
	return rb 	# warning : parameters are not cloned (same ref)
										# it's ok now, but could be wrong for some param by ref
	
# Add Agent -----------------------------
func _on_ToolPlusAgent_pressed() -> void:
	var name:String = key_name_create()
	#_selected_name = name
	addAgent(name)

# Remove Agent -----------------------------
func _on_BtnDelAgent_pressed() -> void:
	var lst:ItemList = _listAgents
	var sel:PoolIntArray = lst.get_selected_items()
	if sel.size() > 0:
		lst.remove_item(sel[0])

# List of entities -----------------------------
var _selected_name:String = ""
func _on_ListAgents_item_selected(index: int) -> void:
	var sel:PoolIntArray = _listAgents.get_selected_items()
	if sel.size() > 0:
		#_listAgents.remove_item(sel[0])
		var entity_name:String = _listAgents.get_item_text(sel[0])
		var entity:Node = get_entity_from_GUI(entity_name)
		var tabs:TabContainer = get_node("%TabContainer")
		if entity is RigidBody:
			tabs.current_tab = Prop.ENTITY
			_selected_name = entity_name
			_fill_properties_of_agent(entity)
		else:
			tabs = get_node("%TabContainer")	
			if entity is Node:
				tabs.current_tab = Prop.EMPTY
			
func get_entity_from_GUI(var name:String) -> Node:
	var node_entities:Node = get_node("%Entities")
	return node_entities.find_node(name) as Node

# Agent => Properties ----------------------------
func _fill_properties_of_agent(var agt_type:Node):
	if agt_type is RigidBody:
		# name
		var box_name:LineEdit = get_node("%AgentName")
		box_name.text = agt_type.name
		# color
		var box_color:ColorPickerButton = get_node("%ColorAgent")
		var mesh:MeshInstance = agt_type.get_child(0)
		box_color.color = mesh.material_override.albedo_color
		# type
		var opt_type:OptionButton = get_node("%OptionAgentType")
		opt_type.select(0)
		# groups
		agent_group_to_GUI_group()
		# param
		agent_meta_to_param() # TODO rename into agent_meta_to_GUI_param
		
# Properties => Agent -----------------------------
# Agent COLOR
func change_agent_color(rb:RigidBody, color:Color)->void:
	if rb==null:
		return
	var msh:MeshInstance = rb.get_child(0)
	var mat:SpatialMaterial = msh.material_override
	mat.albedo_color = color
	
func _on_ColorAgent_color_changed(color: Color) -> void:
	var rb:RigidBody = find_node(_selected_name)
	if(rb != null):
		change_agent_color(rb, color)
	update_agent_instances(rb)

# Agent NAME
func _on_AgentName_focus_exited() -> void:
	var line_edit:LineEdit = get_node("%AgentName")
	var new_name:String = line_edit.text
	if new_name == _selected_name:
		return
	if key_name_exists(new_name) == false: # The new name doesn't exists => can be applied
		var sel:PoolIntArray = _listAgents.get_selected_items()
		if sel.size() == 0:
			return
		var pos = sel[0] # pos of agent in list
		_listAgents.set_item_text(pos, new_name) # set new name
		# 3D ENV	
		# Agent prototype
		var rb:RigidBody = find_node(_selected_name) # change in ENV
		rb.name = new_name
		# Agent instances
		for agt in _node_env.get_children():
			if agt.get_meta("Name") == _selected_name:
				agt.set_meta("Name", new_name)
		_selected_name = new_name
	else: # the new name EXISTS => cannot be changed
		OS.alert("Ce nom est déjà attribué", "Information")
		line_edit.text = _selected_name

func update_agent_axes_lock():
	var rb:RigidBody = find_node(_selected_name)
	if rb == null:
		return
	var lockX:bool = get_node("%CheckX").is_pressed()
	var lockY:bool = get_node("%CheckY").is_pressed()
	var lockZ:bool = get_node("%CheckZ").is_pressed()
	rb.axis_lock_linear_x = lockX
	rb.axis_lock_linear_y = lockY
	rb.axis_lock_linear_z = lockZ
	update_agent_instances(rb)

func update_agent_instances(var rb:RigidBody)->void:
	# Agent instances
	for agt in _node_env.get_children():
		if agt.get_meta("Name") == _selected_name:
			# update color (already made because color is a ref)
			#var msh:MeshInstance = rb.get_child(0)
			#var mat:SpatialMaterial = msh.material_override
			#var color:Color = mat.albedo_color
			#change_agent_color(agt, color)
			
			# update lock x,y,z
			agt.axis_lock_linear_x = rb.axis_lock_linear_x
			agt.axis_lock_linear_y = rb.axis_lock_linear_y
			agt.axis_lock_linear_z = rb.axis_lock_linear_z
			
			# update groups **********************
			# Clear Group of agt
			var lst_gp_agt = agt.get_groups()
			for gp in lst_gp_agt:
				agt.remove_from_group(gp)
			# Put groups of rb to agt
			var lst_gp_rb = rb.get_groups()
			for gp in lst_gp_rb:
				agt.add_to_group(gp)

			# update Param ************************
			#(TODO + if ref => make param copies when instancing)

func _on_AgentName_text_entered(new_text: String) -> void:
	_on_AgentName_focus_exited()

# Agent GROUPS **************************************
func _on_ButtonAddGroup() -> void:
	# Crete a unique name for the parameter (Meta names are key of dictionnary)
	# Create the line of input boxes
	var vbox_group:	VBoxContainer = get_node("%VBoxAgentGroup")
	var hbox_line :	HBoxContainer = get_node("%HBoxLineGroup")
	var new_line: 	HBoxContainer = hbox_line.duplicate()
	new_line.visible = true
	vbox_group.add_child(new_line)
	# Save to groups
	#agent_GUI_groups_to_groups()

# GUI GROUPS => GROUPS
func agent_GUI_groups_to_groups(new_group: String="") -> void:
	#printerr(str("PARAM => meta for ", _selected_name))
	var rb:RigidBody = find_node(_selected_name)
	if rb==null:
		return
	# Clear Group
	var lst_gp = rb.get_groups()
	for gp in lst_gp:
		rb.remove_from_group(gp)
	var vbox_group:	VBoxContainer = get_node("%VBoxAgentGroup")
	# Fill Group
	for i in vbox_group.get_child_count()-1:
		var line:HBoxContainer = vbox_group.get_child(i+1)
		var group_name :String  	= line.get_child(1).get_text()
		rb.add_to_group(group_name)
	update_agent_instances(rb)

# GROUP => GUI GROUP
func agent_group_to_GUI_group() -> void:
	#printerr(str("meta => PARAM for ", _selected_name))
	var rb:RigidBody = find_node(_selected_name)
	if rb==null:
		return
	var vbox_group:	VBoxContainer = get_node("%VBoxAgentGroup")
	# Clear Group VBox
	for i in vbox_group.get_child_count()-1:
		var line:HBoxContainer = vbox_group.get_child(1)
		vbox_group.remove_child(line)
		line.queue_free()
	# Fill Group VBox
	for m in rb.get_groups().size():
		var group_name :String  	= rb.get_groups()[m]
		#printerr(str(_selected_name , " : meta => PARAM (", meta_name , "," , meta_value))
		_on_ButtonAddGroup()
		var line:HBoxContainer = vbox_group.get_child(vbox_group.get_child_count()-1)
		line.get_child(1).set_text(group_name)

# Remove group
func _on_button_del_group_of_agent() -> void:
	var vbox_group:	VBoxContainer = get_node("%VBoxAgentGroup")
	for i in vbox_group.get_child_count():
		var line:HBoxContainer = vbox_group.get_child(i)
		var btn_del:Button = line.get_child(2)
		if btn_del.has_focus():
			vbox_group.remove_child(line)
			break
	# Save to meta (new_name VALIDATED)
	agent_GUI_groups_to_groups()

# Agent PARAMETERS **************************************
func _on_ButtonAddParam_button_down() -> void:
	# Crete a unique name for the parameter (Meta names are key of dictionnary)
	var key_param:String  = key_param_create()
	# Create the line of input boxes
	var vbox_param:	VBoxContainer = get_node("%VBoxAgentParam")
	var hbox_line :	HBoxContainer = get_node("%HBoxLineParam")
	var new_line: 	HBoxContainer = hbox_line.duplicate()
	new_line.get_child(0).set_text(key_param)
	new_line.visible = true
	vbox_param.add_child(new_line)
	# Save to meta
	agent_param_to_meta()

# Remove param (TODO : change function name to : _on_button_del_param_of_agent)
func _on_Button_button_down() -> void:
	var vbox_param:	VBoxContainer = get_node("%VBoxAgentParam")
	for i in vbox_param.get_child_count():
		var line:HBoxContainer = vbox_param.get_child(i)
		var btn_del:Button = line.get_child(3)
		if btn_del.has_focus():
			vbox_param.remove_child(line)
			break
	# Save to meta (new_name VALIDATED)
	agent_param_to_meta()
	
# META => GUI PARAM
func agent_meta_to_param() -> void:
	#printerr(str("meta => PARAM for ", _selected_name))
	var rb:RigidBody = find_node(_selected_name)
	if rb==null:
		return
	var vbox_param:	VBoxContainer = get_node("%VBoxAgentParam")
	# Clear Param VBox
	for i in vbox_param.get_child_count()-1:
		var line:HBoxContainer = vbox_param.get_child(1)
		vbox_param.remove_child(line)
		line.queue_free()
	# Fill Param VBox
	for m in rb.get_meta_list().size():
		var meta_name :String  	= rb.get_meta_list()[m]
		var meta_value			= rb.get_meta(meta_name)
		#printerr(str(_selected_name , " : meta => PARAM (", meta_name , "," , meta_value))
		_on_ButtonAddParam_button_down()
		var line:HBoxContainer = vbox_param.get_child(vbox_param.get_child_count()-1)
		line.get_child(0).set_text(meta_name)
		line.get_child(2).set_text(meta_value)

# GUI PARAM => META
func agent_param_to_meta() -> void:
	#printerr(str("PARAM => meta for ", _selected_name))
	var rb:RigidBody = find_node(_selected_name)
	if rb==null:
		return
	# Clear Meta
	rb.get_meta_list().empty()
	var vbox_param:	VBoxContainer = get_node("%VBoxAgentParam")
	# Fill Meta
	for i in vbox_param.get_child_count()-1:
		var line:HBoxContainer = vbox_param.get_child(i+1)
		var param_name :String  	= line.get_child(0).get_text()
		var param_value			= line.get_child(2).get_text()
		rb.set_meta(param_name, param_value)

	update_agent_instances(rb)

# get the line number of agent param having possibly the focus
var _selected_param_pos:int = -1
var _selected_param_name:String = ""

func get_param_line_has_focus() -> int :
	var vbox_param:	VBoxContainer = get_node("%VBoxAgentParam")
	for i in vbox_param.get_child_count():
		var line:HBoxContainer = vbox_param.get_child(i)
		var param_edit:LineEdit = line.get_child(0)
		var value_edit:LineEdit = line.get_child(2)
		var btn_del:Button = line.get_child(3)
		if param_edit.has_focus() or value_edit.has_focus() or btn_del.has_focus():
			return i
	return -1

func _on_ParamName_focus_exited() -> void:
	# Verif Name if unique
	var vbox_param:	VBoxContainer = get_node("%VBoxAgentParam")
	var i:int = _selected_param_pos
	var line:HBoxContainer = vbox_param.get_child(i)
	var old_name:String = _selected_param_name
	var new_name:String = line.get_child(0).get_text()
	if old_name==new_name: # Name NOT changed
		return
	if key_param_exists(new_name) == 2: # Name already EXISTS
		OS.alert("Ce nom est deja attribue", "Information")
		line.get_child(0).set_text(old_name)
		return
	# Save to meta (new_name VALIDATED)
	agent_param_to_meta()

# agent param
func _on_ParamValue_focus_exited() -> void:
	# Save to meta
	agent_param_to_meta()

func _on_ParamName_focus_entered() -> void:
	_selected_param_pos = get_param_line_has_focus()
	var vbox_param:	VBoxContainer = get_node("%VBoxAgentParam")
	var line:HBoxContainer = vbox_param.get_child(_selected_param_pos)
	_selected_param_name = line.get_child(0).get_text()

func _on_ParamName_text_entered(new_text: String) -> void:
	_on_ParamName_focus_exited()











# ************************************************************
#                          ENVIRONMENT                       *
# ************************************************************

var _prev_cursor_agent_pos = Vector3(_env_min_x - 1000 , 0 , _env_min_z - 1000)

var _mouse_btn_down:bool = false

# On Mouse Click -----------------------------
func _on_ViewportContainer_gui_input(event: InputEvent) -> void:
		
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				_mouse_btn_down = true
			else:
				_mouse_btn_down = false
				
	if _mouse_btn_down == true:
		if _selected_name == "":
			return
		# Position of the mouse click
		var camera = get_node("%Camera")
		var from = camera.project_ray_origin(event.position)
		var to = camera.project_ray_normal(event.position) * 100
		var cursorPos = Plane(Vector3.UP, 0).intersects_ray(from, to)
		#print(cursorPos)
		
		
		var space_state = camera.get_world().direct_space_state
		var selection:Dictionary = space_state.intersect_ray(from, cursorPos)
		print(from)
		print(cursorPos)
		print(selection)
		
		if selection.size() > 0:
			return
		spawn_agent(self, _selected_name, cursorPos)
		#print(get_object_under_mouse())
				

# cast a ray from camera at mouse position, and get the object colliding with the ray
func get_object_under_mouse():
	var ray_length:float = 100
	var camera = get_node("%Camera")
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_from = camera.project_ray_origin(mouse_pos)
	var ray_to = ray_from + camera.project_ray_normal(mouse_pos) * ray_length
	print(ray_from)
	print(ray_to)
	var space_state = camera.get_world().direct_space_state
	var selection = space_state.intersect_ray(ray_from, ray_to)
	return selection
		
func spawn_agent(var tree:Node, var name:String, var pos:Vector3) -> void:
	# Spawn the new entity
	#print_debug(str("in spawn_agent : name=", name ) )
	var n_agents:Node = tree.get_node("%Environment")
	#print_debug(str("in spawn_agent : n_agents=", n_agents ) )
	var rb:RigidBody = tree.find_node(name)
	#print_debug(str("in spawn_agent : rb=", rb ) )
	var agent:RigidBody  = clone_rigid_body_agent(rb) #load("res://addons/NetBioDyn-2/3-Agents/Agent-Blue.tscn").instance()
	#print_debug(str("in spawn_agent : CLONED agent=", agent ) )
	agent.visible = true
	agent.set_gravity_scale(0)
	n_agents.add_child(agent)
	agent.set_meta("Name", rb.name)
	agent.global_transform.origin = pos  #Vector3(event.position.x-50,0,event.position.y-10)/10 #Vector3(get_parent().get_mouse_position().x,0,get_parent().get_mouse_position().y)/10
	# to be saved as scene, the owner is the simulation "root" node
	#   - see https://godotengine.org/qa/903/how-to-save-a-scene-at-run-time
	#   - see https://github.com/godotengine/godot-proposals/issues/390
	#agent.set_owner(get_node("%Simulator"))


# Show relevant property TAB ------------------------------
func _on_Button_pressed() -> void:
	var tabs:TabContainer = get_node("%TabContainer")
	tabs.current_tab = Prop.ENV

# ************************************************************
#                          Behaviors                         *
# ************************************************************
var _pm:PopupMenu

# Display the Behaviors PopupMenu
func _on_BtnAddBehav_pressed() -> void:
	_pm = $PopupMenu
	var btn_add = get_node("%BtnAddBehav")
	_pm.popup(Rect2(btn_add.get_global_position().x, btn_add.get_global_position().y, _pm.rect_size.x, _pm.rect_size.y))

# Wait for which Behav is selected
func _on_PopupMenu_index_pressed(index: int) -> void:
	if index == 0: # Create Reaction
		addBehavReaction()
	if index == 1: # Create Random Force
		addBehavRandomForce()

# Add REACTION
func addBehavReaction() -> void:	
	# Create new Behavior in GUI --------------------------------
	var lst:ItemList = get_node("%ListBehav")
	lst.add_item("Reaction")
	lst.set_item_metadata(lst.get_item_count()-1, "Reaction") # type of the item
	
	# Create default Behavior Type in 3D Scene -------------------	
	var r1:String = "Agent-1"
	var r2:String = "0"
	var p:String = "0.1"
	var p1:String = "Agent-1"
	var p2:String = "Agent-1"
	
		# Set META
	var node:Node = Node.new()
	node.set_meta("Type", "Reaction")
	node.set_meta("Name", "au choix")
	node.set_meta("R1", r1)
	node.set_meta("R2", r2)
	node.set_meta("p", p)
	node.set_meta("P1", p1)
	node.set_meta("P2", p2)
	
	# Set default Script
	var script:GDScript = GDScript.new()
	script.source_code = behav_script_reaction(r1, r2, p, p1, p2)
	print_debug(script.source_code)
	script.reload()
	node.set_script(script) #load("res://addons/NetBioDyn-2/4-Behaviors/DeathTest.gd"))

	# Add Behavior to Simulator
	var node_behaviors:Node = get_node("%Behaviors")
	node_behaviors.add_child(node)

# Add FORCE ALEATOIRE
func addBehavRandomForce() -> void:	
	# Create new Behavior in GUI --------------------------------
	var lst:ItemList = get_node("%ListBehav")
	lst.add_item("Force Aléatoire")
	lst.set_item_metadata(lst.get_item_count()-1, "Random Force") # type of the item
	
	# Create default Behavior Type in 3D Scene -------------------	
	var agents:String = "Agent-1"
	var dir:String = "0"
	var angle:String = "360"
	var intensity:String = "1"
	
		# Set META
	var node:Node = Node.new()
	node.set_meta("Type", "Random Force")
	node.set_meta("Name", "Au choix")
	node.set_meta("Agents", agents)
	node.set_meta("Dir", dir)
	node.set_meta("Angle", angle)
	node.set_meta("Intensity", intensity)
	
	# Set default Script
	var script:GDScript = GDScript.new()
	script.source_code = behav_script_random_force(agents, dir, angle, intensity)
	print_debug(script.source_code)
	script.reload()
	node.set_script(script)

	# Add Behavior to Simulator
	var node_behaviors:Node = get_node("%Behaviors")
	node_behaviors.add_child(node)

# Remove behavior
func _on_BtnDelBehav_pressed() -> void:
	var lst:ItemList = get_node("%ListBehav")
	var sel:PoolIntArray = lst.get_selected_items()
	if sel.size() > 0:
		lst.remove_item(sel[0])

# Select behavior : META => GUI
func _on_ListBehav_item_selected(index: int) -> void:
	var behav:Node = get_selected_behavior()
	var type = behav.get_meta("Type")
	# Find the Behavior Type
	if type == "Reaction":
		var tabs:TabContainer = get_node("%TabContainer")
		tabs.current_tab = Prop.BEHAVIOR_REACTION
		# Update GUI Behavior
		# Reaction: Set behavior Name
		get_node("%ParamBehavName").set_text(behav.get_meta("Name"))
		get_node("%ParamBehavR1").set_text(behav.get_meta("R1"))
		get_node("%ParamBehavR2").set_text(behav.get_meta("R2"))
		get_node("%ParamBehavProba").set_text(behav.get_meta("p"))
		get_node("%ParamBehavP1").set_text(behav.get_meta("P1"))
		get_node("%ParamBehavP2").set_text(behav.get_meta("P2"))

	if type == "Random Force":
		var tabs:TabContainer = get_node("%TabContainer")
		tabs.current_tab = Prop.BEHAVIOR_RANDOM_FORCE
		# Update GUI Behavior
		# Random Force: Set behavior Name
		get_node("%BehavRndFName").set_text(behav.get_meta("Name"))
		get_node("%BehavRndFAgents").set_text(behav.get_meta("Agents"))
		get_node("%BehavRndFDir").set_text(behav.get_meta("Dir"))
		get_node("%BehavRndFAngle").set_text(behav.get_meta("Angle"))
		get_node("%BehavRndFIntensity").set_text(behav.get_meta("Intensity"))
	
# Update behavior : GUI => META
func behavior_GUI_to_META() -> void:
	var lst:ItemList = get_node("%ListBehav")
	var sel:PoolIntArray = lst.get_selected_items()
	if sel.size() == 0:
		return

	var behav:Node = get_selected_behavior()
	var type:String = behav.get_meta("Type")
	# Find the Behavior Type
	if type == "Reaction":
		# Set the Name in the GUI List
		var pos:int =sel[0]
		lst.set_item_text(pos, get_node("%ParamBehavName").get_text())
		
		# Update behavior GUI => META
		var name:String = get_node("%ParamBehavName").get_text()
		var R1:String = get_node("%ParamBehavR1").get_text()
		var R2:String = get_node("%ParamBehavR2").get_text()
		var proba:String = get_node("%ParamBehavProba").get_text()
		var P1:String = get_node("%ParamBehavP1").get_text()
		var P2:String = get_node("%ParamBehavP2").get_text()
		behav.set_meta("Name", name)
		behav.set_meta("R1", R1)
		behav.set_meta("R2", R2)
		behav.set_meta("p", proba)
		behav.set_meta("P1", P1)
		behav.set_meta("P2", P2)
		
		# Set Script
		var script:GDScript = GDScript.new()
		script.source_code = behav_script_reaction(R1, R2, proba, P1, P2)
		print_debug(script.source_code)
		script.reload()
		behav.set_script(script)

	if type == "Random Force":
		# Set the Name in the GUI List
		var pos:int =sel[0]
		lst.set_item_text(pos, get_node("%BehavRndFName").get_text())
		
		# Update behavior GUI => META
		var name:String 		= get_node("%BehavRndFName").get_text()
		var agents:String 	= get_node("%BehavRndFAgents").get_text()
		var dir:String 		= get_node("%BehavRndFDir").get_text()
		var angle:String 	= get_node("%BehavRndFAngle").get_text()
		var intensity:String = get_node("%BehavRndFIntensity").get_text()
		behav.set_meta("Name", name)
		behav.set_meta("Agents", agents)
		behav.set_meta("Dir", dir)
		behav.set_meta("Angle", angle)
		behav.set_meta("Intensity", intensity)
		
		# Set Script
		var script:GDScript = GDScript.new()
		script.source_code = behav_script_random_force(agents, dir, angle, intensity)
		print_debug(script.source_code)
		script.reload()
		behav.set_script(script)

	#print_debug(param_name)
	#print_debug(param_value)
	#print_debug(behav)

# ************************************************************
#                          Signals                           *
# ************************************************************
func GUI_param_updated(new_text: String="")->void:
	behavior_GUI_to_META()

# ************************************************************
#                           Groups                           *
# ************************************************************
func _on_BtnAddGp_pressed() -> void:
	var lst:ItemList = get_node("%ListGp")
	lst.add_item("Groupe")
	lst.set_item_metadata(lst.get_item_count()-1, "Reaction") # type of the item

func _on_BtnDelGp_pressed() -> void:
	var lst:ItemList = get_node("%ListGp")
	var sel:PoolIntArray = lst.get_selected_items()
	if sel.size() > 0:
		lst.remove_item(sel[0])
# ************************************************************
#                              Grids                         *
# ************************************************************
func _on_BtnAddGrid_pressed() -> void:
	var lst:ItemList = get_node("%ListGrids")
	lst.add_item("Grille")
	lst.set_item_metadata(lst.get_item_count()-1, "Reaction") # type of the item

func _on_BtnDelGrid_pressed() -> void:
	var lst:ItemList = get_node("%ListGrids")
	var sel:PoolIntArray = lst.get_selected_items()
	if sel.size() > 0:
		lst.remove_item(sel[0])

func _on_ListGrids_item_selected(index: int) -> void:
	var tabs:TabContainer = get_node("%TabContainer")
	tabs.current_tab = Prop.GRID
	
# ************************************************
# SIMULATOR CONTROLS
# ************************************************
var _sim_play: bool  = false
var _sim_pause:bool  = false
var _sim_play_once: bool  = false

func _on_BtnPlay_pressed() -> void:
	# TODO : Save initial state
	# ...
	_sim_play = true
	_sim_pause = false
	_sim_play_once = false
	
func _on_BtnStep_pressed() -> void:
	_sim_play = true
	_sim_pause = true
	_sim_play_once = true
	
func _on_BtnPause_pressed() -> void:
	if _sim_pause == true:
		_sim_pause = false
	else:
		_sim_pause = true
		
func _on_BtnStop_pressed() -> void:
	_sim_play = false
	_sim_pause = false
	_sim_play_once = false
	_step = 0
	# TODO : Reload initial state
	# ...
	updateStatus()

# ************************************************************
#                           Utilities                        *
# ************************************************************

# Key name Generator --------------------------
func key_name_create() -> String:
	var prefix:String = "Agent-"
	var simu:Node = get_node("%Simulator")
	for n in range(1,999999):
		var key_name:String = prefix + String(n)
		var exists:bool = key_name_exists(key_name)
		if exists == false:
			return key_name
	return "FULL"
	
func key_name_exists(var key_name:String) -> bool:
		var node:Node = find_node(key_name)
		if node == null:
			return false
		else:
			return true

func key_param_create() -> String:
	var prefix:String = "Param-"
	var vbox:VBoxContainer = get_node("%VBoxAgentParam")
	for n in range(1, 999999):
		var key_name:String = prefix + String(n)
		#printerr(str("Try to create param : ", key_name))
		var exists:int = key_param_exists(key_name)
		if exists == 0:
			return key_name
	return "FULL"

func key_param_exists(var key_name:String) -> int:
	var vbox:VBoxContainer = get_node("%VBoxAgentParam")
	var nb_param:float = vbox.get_child_count()
	#printerr(str("func key_param_exists => ", "nb_param=" , nb_param))
	#printerr(str("range=",range(1,nb_param)))
	var nb:int = 0
	for n in range(1,nb_param):
		#printerr(str("	n=",n))
		var line:HBoxContainer = vbox.get_child(n)
		var name:String = line.get_child(0).get_text()
		#printerr(str("Verify : ", key_name, " with existing :", name))
		if key_name == name:
			nb = nb+1
	return nb	

func get_selected_behavior() -> Node:
	var lst:ItemList = get_node("%ListBehav")
	var sel:PoolIntArray = lst.get_selected_items()
	if sel.size() == 0:
		return null
	
	var pos:int =sel[0]
	
	var node:Node = get_node("%Behaviors").get_child(pos)
	return node

# Window / App control -------------------------
func _on_BtnClose_pressed():
	get_tree().quit()

# ************************************************************
#                     SCRIPTS for Behaviors                  *
# ************************************************************

func in_quote(var s:String)->String:
	return "\""+s+"\""

# Script DEFAULT
func behav_script_default() -> String:
	return """
extends Node
# Default Behavior
func action(tree, agent) -> void:
	pass
"""

# Script RANDOM FORCE
func behav_script_random_force(agents:String, dir:String, angle:String, intensity:String) -> String:
	angle = String(float(angle) * 6.28318530718 / 360.0) # deg to rad
	dir = String(float(dir) * 6.28318530718 / 360.0)	# deg to rad
	return """
extends Node
# Default Behavior
func action(tree, agent) -> void:
	if agent.get_meta("Name") == """+in_quote(agents)+""" || agent.is_in_group("""+in_quote(agents)+"""):
		var alpha:float = randf() * """+angle+""" - """ +angle+ """ /2.0
		agent.apply_impulse(Vector3(0,0,0), Vector3("""+intensity+"""*cos(alpha+"""+dir+"""),0,"""+intensity+"""*sin(alpha+"""+dir+""")))
"""


# Script REACTION
func behav_script_reaction(r1:String, r2:String, p:String, p1:String, p2:String) -> String:
	return """
extends Node

# Reaction
var MAX_AGENTS:int = 500

func action(tree, R1) -> void:
	var proba:float = """+p+"""
	var alea:float = rand_range(0,100)
	#print_debug(str("alea=", alea, ", proba=", proba))
	if alea < proba:
		#print (str("proba ok:",proba))
		if R1.is_queued_for_deletion() == false && (R1.get_meta("Name") == """+in_quote(r1)+""" || R1.is_in_group("""+in_quote(r1)+""")   ): # R1 n'est pas déjà détruit et il appartient au bon groupe:
			#var R1:Spatial 		= collision[0]
			var nb_agents:int 	= R1.get_parent().get_child_count()
			#print ("nb=", nb_agents)
			#print("R1 is in gp : ", inputs[2])
			# Cas avec R2 == 0 ########################################################################################
			if """+in_quote(r2)+""" == "0": # Pas de 2nd réactif => toujours appliqué (à la proba précédente près)
				# si R1 CHANGE en P1 (il n'est ni enlevé, ni prolongé, il est donc remplacé par P1)
				if """+in_quote(p1)+""" != "0" && """+in_quote(p1)+""" != "R1" && """+in_quote(p1)+""" != "R2":
					var P1 = null # et P1 peut être soit un nouvel agent soit du même type que R2 - Mais bon ici r2 = "0" donc ok pas de R2 qui compte
					print_debug("spawn P1...")
					NetBioDyn2gui.spawn_agent(tree,"""+in_quote(p1)+""", Vector3(R1.translation.x,R1.translation.y,R1.translation.z) ) #load(str("res://SimBioCell/3-PreFabAgents/",p1,".tscn")).instance()
					R1.queue_free()
				# si R1 est ENLEVE (il est enlevé ou bien il MIME R2 mais qui vaut "0" aussi)
				if """+in_quote(p1)+""" == "0" || """+in_quote(p1)+""" == "R2":
					R1.queue_free()
				# si P2 APPARAIT (je rappelle qu'ici R2 = 0)
				if """+in_quote(p2)+""" != "0" && """+in_quote(p2)+""" != "R1" && """+in_quote(p2)+""" != "R2" && nb_agents < MAX_AGENTS: # si R2 n'est ni enlevé, ni prolongé, il est donc remplacé par P2
					NetBioDyn2gui.spawn_agent(tree,"""+in_quote(p2)+""", Vector3(R1.translation.x,R1.translation.y,R1.translation.z) ) #load(str("res://SimBioCell/3-PreFabAgents/",p2,".tscn")).instance()
				# si P2 MIME R1 il APPARAIT du meme type que R1
				if """+in_quote(p2)+""" == "R1" && nb_agents < MAX_AGENTS: # si R2 n'est ni enlevé, ni prolongé, il est donc remplacé par P2
					var P2 = R1.duplicate(8) # load(str("res://SimBioCell/3-PreFabAgents/",p2,".tscn")).instance()
					P2.global_translate(Vector3(R1.translation.x,R1.translation.y,R1.translation.z))
					R1.get_parent().add_child(P2)
				return
			# Cas avec un 2nd réactif ########################################################################################
			var bodies = R1.get_colliding_bodies()
			if bodies.size() > 0:
				print (str("collision size:",bodies.size() ))
				#print("R1 is colliding")
				var R2 = bodies[0]
				if R2.is_queued_for_deletion() == false && (R2.get_meta("Name") == """+in_quote(r2)+""" || R2.is_in_group("""+in_quote(r2)+""")): # R2 n'est pas détruit et appartient au bon groupe
					# R1 CHANGE en p1
					if """+in_quote(p1)+""" != "0" && """+in_quote(p1)+""" != "R1" && """+in_quote(p1)+""" != "R2": # si R1 n'est ni enlevé, ni prolongé, il est donc remplacé par P1
						NetBioDyn2gui.spawn_agent(tree,"""+in_quote(p1)+""", Vector3(R1.translation.x,R1.translation.y,R1.translation.z) ) #load(str("res://SimBioCell/3-PreFabAgents/",p1,".tscn")).instance()
						R1.queue_free()
					# R1 est ENLEVE
					if """+in_quote(p1)+""" == "0": # si R1 n'est pas prolongé, il est enlevé (càd soit enlevé soit remplacé)
						R1.queue_free()
					# R1/P1 MIME R2
					if """+in_quote(p1)+""" == "R2": # si R1 devient P1 mais du meme type que R2
						var P1 = R2.duplicate(8) # load(str("res://SimBioCell/3-PreFabAgents/",p1,".tscn")).instance()
						P1.global_translate(Vector3(R1.translation.x,R1.translation.y,R1.translation.z))
						R1.get_parent().add_child(P1)
						R1.queue_free()
					# R2 CHANGE en p2
					if """+in_quote(p2)+""" != "0" && """+in_quote(p2)+""" != "R1" && """+in_quote(p2)+""" != "R2" && nb_agents < MAX_AGENTS: # si R2 n'est ni enlevé, ni prolongé, il est donc remplacé par P2
						NetBioDyn2gui.spawn_agent(tree,"""+in_quote(p2)+""", Vector3(R2.translation.x,R2.translation.y,R2.translation.z) ) #load(str("res://SimBioCell/3-PreFabAgents/",p2,".tscn")).instance()
						R2.queue_free()
					# R2 est ENLEVE
					if """+in_quote(p2)+""" == "0": # si R2 est enlevé tout simplement
						R2.queue_free()
					# R1/P1 MIME R2
					if """+in_quote(p2)+""" == "R1": # si R2 devient P2 mais du meme type que R1
						var P2 = R1.duplicate(8) # load(str("res://SimBioCell/3-PreFabAgents/",p1,".tscn")).instance()
						P2.global_translate(Vector3(R2.translation.x,R2.translation.y,R2.translation.z))
						R1.get_parent().add_child(P2)
						R2.queue_free()

"""

# ************************************************
# WORK in PROGRESS...
# ************************************************


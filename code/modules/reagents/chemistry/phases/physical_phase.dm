/*The "gas" phase of reagents - this is what all reagents that aren't of the gas subtype are converted into upon entering their gas phase
* If they are a datum/reagent/gas type then atmos handles them instead
* Otherwise a mist is made of a certain size - depending on volume. To prevent confusion with air/gas/linda comments will refer to this effect either as mist or gas_phase, with the former being preferred
* Unlike liquids - a single reagent tracks the mist's contents - so gas transferal isn't a thing
* Gas dissipates - reduces in volume at the edges of it's area
* This is not meant to be atmos 2.0 - our granularity is higher compared to atmos so we take steps to ensure we're a much lower cost
* This hooks up the the mist obj which does most of the math with signals - Welcome to signal city
*
* Things to change for optimisation
* * Have update_pressure() check for delta time before updating, if a lot of things are being added it might call it a lot
* * Have a min delta time for process
* * Instead of a moving central cell, just have the inital one as center
*/

/datum/physical_phase
	///This is the holder that holds the current reagents that are in the "air"
	var/datum/reagents/center_holder
	///The location atom we're tied to
	var/atom/source
	///How big our cell cloud is - i.e. the total number of cells we're on - affects diffuse rate
	var/list/atom/movable/phase_object/current_cells = list()
	///The interfacial cells - all cells within the center are considered "stable" so we don't process their movement
	var/list/atom/movable/phase_object/interface_cells = list()
	///The type of phase object we create
	var/phase_object
	///The type of phase we are
	var/phase_type
	///The u/volume capacity of one cell
	var/cell_capacity
	///The x coordinate of the center of the cloud
	var/center_x
	///The y coordinate of the center of the cloud
	var/center_y
	///If we should update pressure and temperature
	var/update_temp_pressure = TRUE

/datum/physical_phase/New(datum/reagent/reagent, volume, atom/reagent_source, turf/location)
	. = ..()
	if(!isopenturf(location))
		stack_trace("Input turf isn't open!")
		return FALSE
	if(volume <= 0.05)
		stack_trace("Attempted to add a reagent to a gas_phase with a volume less than 0.05")
		return FALSE
	center_holder = new /datum/reagents(3000)
	//Flagging our signals
	RegisterSignal(center_holder, COMSIG_REAGENTS_NEW_REAGENT, .proc/on_new_reagent)
	RegisterSignal(center_holder, COMSIG_REAGENTS_DEL_REAGENT, .proc/on_del_reagent)
	RegisterSignal(center_holder, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES, .proc/process)
	//RegisterSignal(center_holder, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES, .proc/process)
	RegisterSignal(center_holder, COMSIG_REAGENTS_UPDATE_PRESSURE, .proc/update_temp_and_pressure)
	//Add reagents
	var/atom/movable/phase_object/new_phase_object = new phase_object(location, center_holder, src)
	//Set atom first - so we know where we are, so we can explode
	center_holder.my_atom = new_phase_object
	//Then add reagent
	center_holder.add_reagent(reagent.type, volume, reagtemp = reagent.holder.chem_temp, added_purity = reagent.purity, added_ph = reagent.ph, phases = phase_type) //Does not remove volume from original holder - should be handled outside of that
	//Update color and alpha
	new_phase_object.recalculate_color(mix_color_from_reagents(center_holder.reagent_list), 150 + (((center_holder.total_volume % cell_capacity)/20) * 100))
	//Track active states for panic destroy/debugging
	SSphase_states.active_state_controllers[phase_type] += src
	//Set our center - though maybe I should make the center based off reagent input (yes do this FERMI_TODO)
	source = new_phase_object
	RegisterSignal(source, COMSIG_PARENT_QDELETING, .proc/on_del_source)
	center_x = new_phase_object.x
	center_y = new_phase_object.y

/datum/physical_phase/Destroy(force, ...)
	UnregisterSignal(source, COMSIG_PARENT_QDELETING)
	UnregisterSignal(center_holder, COMSIG_REAGENTS_NEW_REAGENT)
	UnregisterSignal(center_holder, COMSIG_REAGENTS_DEL_REAGENT)
	//UnregisterSignal(center_holder, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES)
	UnregisterSignal(center_holder, COMSIG_REAGENTS_UPDATE_PRESSURE)
	UnregisterSignal(source, COMSIG_PARENT_QDELETING)
	for(var/atom/movable/phase_object/del_phase_object)
		qdel(del_phase_object)
	for(var/datum/reagent/reagent as anything in center_holder.reagent_list)
		UnregisterSignal(reagent, COMSIG_PHASE_CHANGE_INTO) //Clean up signals
	QDEL_NULL(center_holder)
	SSphase_states.active_state_controllers[phase_type] -= src
	return ..()

///When we lose our origin atom - we backup to the cell on it's location - if there is none then we default backup to any avalible interface
/datum/physical_phase/proc/on_del_source()
	SIGNAL_HANDLER
	if(!current_cells.len)
		qdel(src)
		return FALSE
	var/turf/source_turf = get_turf(source)
	///If we're deleting our source, but can't find where it was, then we recenter to any avalible interface as a backup
	if(!source_turf)
		var/atom/movable/phase_object/cell = pick(current_cells)
		source_turf = locate(center_x, center_y, cell.z)
		if(!source_turf)
			stack_trace("Unable to find backup turf when phase cell of type [phase_type] was destroyed!")
			source = cell
			return FALSE
	//Now we process through the current cells and find the closest replacement
	var/min_dist = 999
	var/atom/movable/phase_object/target
	for(var/atom/movable/phase_object/phasey in current_cells)
		if(QDELETED(phasey)) //Incase an explosion took out a chunk
			continue
		var/phasey_distance = get_dist(source_turf, phasey)
		if(phasey_distance < min_dist)
			target = phasey
			min_dist = phasey_distance
		source = target
		return TRUE
	stack_trace("Unable to find a replacement cell, when we have suitable cells! This may have been because of an explosion.")
	qdel(src)

/**
 * Shifts the center of our controller - so that it'll try to create things near it, and remove things far away from it.
 * That way it shifts around!
 * Passing a negative magnitude will move it away from a point, positive magnitude will move it towards
 * Movement is relative to it's holder volume (i.e. size)
 *
 * arguments:
 * * source_x: the x coord of the area we're moving to
 * * source_x: the x coord of the area we're moving to
 * * source_z: the z level we're on - currently doesn't spread cross z level, but that shouldn't be too hard to do eventually
 * * magnitude: the size of the movement, to move it entirely to the input position, add a magnitude equal to the central_holder volume
 */
/datum/physical_phase/proc/shift_center(source_x, source_y, source_z, magnitude)
	var/delta_x = source_x - center_x
	var/delta_y = source_y - center_y
	center_x = center_x + ((delta_x / center_holder.total_volume) * magnitude)
	center_y = center_y + ((delta_y / center_holder.total_volume) * magnitude)
	var/target_x = round(center_x)
	var/target_y = round(center_y)
	//Are we in the same spot?
	if(source.x == target_x && source.y == target_y)
		return
	//If not, lets move over!
	var/turf/location = locate(target_x, target_y, source_z)
	for(var/atom/movable/phase_object/other_phase in location.contents) //Optimisation possible here, deal with multiple loops over contents in 1 loop
		if(other_phase.phase != phase_type || other_phase.phase_controller != src)
			continue
		source = other_phase


/datum/physical_phase/proc/on_new_reagent(source, datum/reagent/reagent, amount, reagtemp, data, no_react)
	SIGNAL_HANDLER
	RegisterSignal(reagent, COMSIG_PHASE_CHANGE_INTO, .proc/on_phase_change_away)
	reagent.chemical_flags |= REAGENT_STATE_PHYSICAL_PHASE

//Signal works
/datum/physical_phase/proc/on_del_reagent(source, datum/reagent/reagent)
	SIGNAL_HANDLER
	UnregisterSignal(reagent, COMSIG_PHASE_CHANGE_INTO)

/datum/physical_phase/proc/on_phase_change_away(datum/reagent/reagent, amount, phase, datum/reagent_phase/phase)
	SIGNAL_HANDLER
	if(phase_type == phase)
		message_admins("This is being flagged when it shouldn't")
		return
	center_holder.remove_reagent(reagent, amount, phase = phase_type)
	switch(phase)
		if(GAS)
			create_mist(reagent, amount, get_turf(source))
		if(LIQUID)
			create_liquid(reagent, amount, get_turf(source))
			message_admins("creating liquid")
		if(SOLID)
			create_solid(reagent, amount, get_turf(pick(current_cells )))
			message_admins("creating solid")
		if(IONISED)
			var/zap_flags = ZAP_MOB_DAMAGE | ZAP_OBJ_DAMAGE | ZAP_MOB_STUN
			tesla_zap(source, 7, amount*100, zap_flags) //This is a placeholder because I don't like how expensive this is. (i.e. change to reagent "zapping" into people)
		if(POWDER)
			stack_trace("Attemptung to transform INTO powder from [phase_type] in a physical phase. This shouldn't be happening!")
	reagent.quick_remove_phase_volume(amount)
	return COMPONENT_REAGENT_OVERRIDE_PHASE_CHANGE
	//process()

/datum/physical_phase/proc/update_temp_and_pressure()
	if(update_temp_pressure == FALSE)
		return
	var/sum_pressure
	var/sum_temp
	for(var/atom/movable/phase_object/this_phase_object in current_cells)
		sum_pressure += this_phase_object.pressure
		sum_temp += this_phase_object.temperature
	///We hard set here - since we don't want to use the updating proc methods - they call extra things we don't want atm
	///If you're here to copy paste, generally don't do this, unless you don't want your phases updated by setting the temperature
	center_holder.pressure = sum_pressure / current_cells.len
	center_holder.chem_temp = sum_temp / current_cells.len
	return COMPONENT_OVERRIDE_PRESSURE_UPDATE

//Process is tied to the diffusion tick -
/datum/physical_phase/process()
	//SIGNAL_HANDLER
	if(center_holder.total_volume <= 0)
		end_all_physical_phases()
		return FALSE
	var/delta_cell = CEILING(center_holder.total_volume/cell_capacity, 1)
	if(delta_cell == current_cells.len)
		return FALSE
	if(delta_cell > current_cells.len)
		create_new_cell(delta_cell) //Only make 1 cell at a time to make it look like it's spreading!
		//stack_trace("Removal of gas is trying to create more cells!")
	else if(delta_cell < current_cells.len)
		remove_cell(delta_cell)
	update_cells_color()
	return COMPONENT_REAGENT_REQUEST_UPDATE

/datum/physical_phase/proc/update_cells_color()
	var/new_color = mix_color_from_reagents(center_holder.reagent_list)
	var/new_alpha = 150 + (((center_holder.total_volume % cell_capacity)/20) * 100)
	var/atom/movable/phase_object/check = interface_cells[1]
	if(check.color == new_color && check.alpha == new_alpha)
		return
	for(var/atom/movable/phase_object/this_phase_object)
		this_phase_object.recalculate_color(new_color, new_alpha)

/datum/physical_phase/proc/create_new_cell(num_cells)
	var/min_dist = 999
	var/atom/movable/phase_object/target
	for(var/atom/movable/phase_object/phasey in interface_cells)
		var/phasey_distance = get_dist(source, phasey)
		if(phasey_distance < min_dist)
			target = phasey
			min_dist = phasey_distance
	if(!target)
		stack_trace("No target physical phase found! Is the interfacial list empty? Should this be a deleted controller?")
		return
	//we have a target
	var/created_new = FALSE
	for(var/turf/new_turf in target.local_turf.GetAtmosAdjacentTurfs())
		var/atom/movable/phase_object/phasey_boi = locate() in new_turf //Don't spread smoke where there's already smoke!
		if(phasey_boi && phasey_boi?.phase_controller.center_holder != center_holder) //Is there another cell there that's of a different controller? Lets greet them if so
			merge_into(phasey_boi.phase_controller.center_holder, cell_capacity)
			return TRUE
		if(phasey_boi) //if it's occupied - don't enter
			continue
		created_new = TRUE
		new phase_object(new_turf, center_holder, src)
		break
	if(!created_new)//We're stable
		message_admins("We have a physical phase who can't expand but think it's unstable!")
		remove_from_interface(target)
	return created_new

/datum/physical_phase/proc/remove_cell(num_cells) //This isn't working?
	var/max_dist = -999
	var/atom/movable/phase_object/target
	for(var/atom/movable/phase_object/phasey in interface_cells)
		var/phasey_distance = get_dist(source, phasey)
		if(phasey_distance > max_dist)
			target = phasey
			max_dist = phasey_distance
	if(!target)
		stack_trace("No target physical phase found for removal of cells! Is the interfacial list empty? Should this be a deleted controller?")
		return
	//we have a target
	target.begone()//This calls a removal from interface


/datum/physical_phase/proc/merge_into(datum/reagents/target, amount)
	center_holder.trans_to(target, amount)


/datum/physical_phase/proc/end_all_physical_phases()
	if(current_cells.len)
		message_admins("physical phase is being deleted when there's still live cells in it")
	qdel(src)

/datum/physical_phase/proc/add_to_interface(atom/movable/phase_object/phasey)
	if(phasey in interface_cells)
		return
	interface_cells += phasey
	phasey.interfacial = TRUE

/datum/physical_phase/proc/remove_from_interface(atom/movable/phase_object/phasey)
	//debug - should work with this removed
	var/turf/t_loc = get_turf(phasey)
	var/adjacent_filled
	for(var/turf/T in t_loc.GetAtmosAdjacentTurfs())
		var/atom/movable/phase_object/other_phasey = locate() in T //Don't spread smoke where there's already smoke!
		if(other_phasey)
			add_to_interface(other_phasey)
			continue
	if(!adjacent_filled && current_cells.len)
		message_admins("Cell is being removed from active liquid, but has no nearby fellows in an active physical phase! [phase_type]")
	interface_cells -= phasey
	phasey.interfacial = FALSE
	phasey.alpha = 255
	if(!current_cells.len)
		qdel(src)

//		~~~			GAS PHASES			~~~

/datum/physical_phase/gas_phase
	phase_object = /atom/movable/phase_object/mist
	phase_type = GAS
	cell_capacity = 20

/datum/physical_phase/gas_phase/on_new_reagent(source, datum/reagent/reagent, amount, reagtemp, data, no_react)
	RegisterSignal(reagent, COMSIG_REAGENT_DIFFUSE, .proc/override_reagent_diffusion)
	. = ..()

/datum/physical_phase/gas_phase/on_del_reagent(source, datum/reagent/reagent)
	. = ..()
	UnregisterSignal(reagent, COMSIG_REAGENT_DIFFUSE)

///Diffusion creates mist - so we want to stop that! - works
///This is how the phase itself is updated
/datum/physical_phase/gas_phase/proc/override_reagent_diffusion(datum/reagent, volume)
	center_holder.remove_reagent(reagent.type, volume/2)
	process()
	return COMPONENT_REAGENT_OVERRIDE_DIFFUSE //Because diffusion will always occur and require updates

/datum/physical_phase/gas_phase/proc/carbon_breathe(source, mob/living/carbon/carby, delta_time)
	SIGNAL_HANDLER
	center_holder.expose(carby, INGEST) //This should block transfer with a mask.
	center_holder.trans_to(carby, delta_time, methods = INGEST, ignore_stomach = TRUE)

//		~~~			LIQUID PHASES			~~~

///Liquids are processed using their tick() method attached to their reagent_phase datum
///Similar to diffuse - except we do want to stop sometimes
/datum/physical_phase/liquid_phase
	phase_object = /atom/movable/phase_object/liquid
	phase_type = LIQUID
	cell_capacity = 25

/datum/physical_phase/liquid_phase/on_new_reagent(source, datum/reagent/reagent, amount, reagtemp, data, no_react)
	RegisterSignal(reagent, COMSIG_LIQUID_PHASE_TICK, .proc/liquid_tick)
	. = ..()

/datum/physical_phase/liquid_phase/on_del_reagent(source, datum/reagent/reagent)
	. = ..()
	UnregisterSignal(reagent, COMSIG_LIQUID_PHASE_TICK)

/datum/physical_phase/liquid_phase/proc/liquid_tick(source, reagent, phase, delta_time, /datum/reagent_phase/reagent_phase)
	if(process(delta_time))
		return COMPONENT_REAGENT_REQUEST_UPDATE

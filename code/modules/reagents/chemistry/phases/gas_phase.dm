/*The "gas" phase of reagents - this is what all reagents that aren't of the gas subtype are converted into upon entering their gas phase
* If they are a datum/reagent/gas type then atmos handles them instead
* Otherwise a mist is made of a certain size - depending on volume. To prevent confusion with air/gas/linda comments will refer to this effect either as mist or gas_phase, with the former being preferred
* Unlike liquids - a single reagent tracks the mist's contents - so gas transferal isn't a thing
* Gas dissipates - reduces in volume at the edges of it's area
* This is not meant to be atmos 2.0 - our granularity is higher compared to atmos so we take steps to ensure we're a much lower cost
* This hooks up the the mist obj which does most of the math with signals - Welcome to signal city
*/

#define MIST_STANDARD_CELL_CAPACITY 20

/datum/gas_phase
	///This is the holder that holds the current reagents that are in the "air"
	var/datum/reagents/center_holder
	///The location atom we're tied to
	var/atom/source
	///How big our mist cloud is - i.e. the total number of cells we're on - affects diffuse rate
	var/current_cells
	///The sum of the volume in the mist - this is cells * capacity
	//var/sum_volume
	///The interfacial cells - all cells within the center are considered "stable" so we don't process their movement
	var/list/obj/mist/interface_mists = list()

/datum/gas_phase/New(datum/reagent/reagent, volume, atom/reagent_source, turf/location)
	. = ..()
	if(!isopenturf(location))
		stack_trace("Input turf isn't open!")
		return FALSE
	if(SSphase_states.gas_states[reagent_source])
		stack_trace("Attempted to create a phase state that already exists")
		return FALSE
	if(volume <= 0.05)
		stack_trace("Attempted to add a reagent to a gas_phase with a volume less than 0.05")
		return FALSE
	center_holder = new /datum/reagents(3000)
	source = reagent_source
	center_holder.my_atom = source
	RegisterSignal(center_holder, COMSIG_REAGENTS_NEW_REAGENT, .proc/on_new_reagent) //Todo: change these 3 to flag when
	//RegisterSignal(center_holder, COMSIG_REAGENTS_NEW_REAGENT, .proc/on_add_reagent)
	RegisterSignal(center_holder, COMSIG_REAGENTS_DEL_REAGENT, .proc/on_del_reagent)
	RegisterSignal(center_holder, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES, .proc/on_change_reagent)
	//RegisterSignal(center_holder, COMSIG_REAGENTS_REM_REAGENT, .proc/on_remove_reagent)
	RegisterSignal(source, COMSIG_PARENT_QDELETING, .proc/on_del_source)
	center_holder.add_reagent(reagent.type, volume) //Does not remove volume from original holder
	new /obj/mist(location, center_holder, src)
	SSphase_states.gas_states += list(source = src)

/datum/gas_phase/Destroy(force, ...)
	UnregisterSignal(center_holder, COMSIG_REAGENTS_NEW_REAGENT)
	UnregisterSignal(center_holder, COMSIG_REAGENTS_DEL_REAGENT)
	UnregisterSignal(center_holder, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES)
	UnregisterSignal(source, COMSIG_PARENT_QDELETING)
	SEND_SIGNAL(src, COMSIG_PHASE_STATE_DELETE)
	for(var/datum/reagent/reagent as anything in center_holder.reagent_list)
		UnregisterSignal(reagent, COMSIG_PHASE_CHANGE_FROM_GAS) //Clean up signals
	QDEL_NULL(center_holder)
	SSphase_states.gas_states -= list(source)
	..()

///When we lose our origin atom - we backup to the mist on it's location - if there is none then we default backup to any avalible interface
/datum/gas_phase/proc/on_del_source()
	SIGNAL_HANDLER
	var/turf/source_turf = get_turf(source)
	///If we're deleting our source, but can't find where it was, then we recenter to any avalible interface as a backup
	if(!source_turf)
		source = pick(interface_mists)
		return FALSE
	var/obj/mist/misty = locate() in source_turf
	if(misty)
		source = misty
		return TRUE
	source = pick(interface_mists)
	return FALSE

///Adds a reagent to the mist cloud
/datum/gas_phase/proc/add_phase_reagent(datum/reagent/reagent, volume)


/datum/gas_phase/proc/on_new_reagent(datum/reagent/reagent, amount, reagtemp, data, no_react)
	SIGNAL_HANDLER
	RegisterSignal(reagent, COMSIG_PHASE_CHANGE_FROM_GAS, .proc/on_phase_change_from_gas)
	RegisterSignal(reagent, COMSIG_REAGENT_DIFFUSE, .proc/override_reagent_diffusion)
	///Update mist color
	SEND_SIGNAL(src, COMSIG_PHASE_CHANGE_COLOR, mix_color_from_reagents(center_holder.reagent_list))
	//RegisterSignal(reagent, COMSIG_PHASE_CHANGE_TO_GAS, .proc/on_phase_change_to_gas) //Might not be needed

//datum/gas_phase/proc/on_add_reagent(datum/reagent/reagent, amount, reagtemp, data, no_react)
//	SEND_SIGNAL(src, COMSIG_PHASE_CHANGE_COLOR, mix_color_from_reagents(center_holder.reagent_list))

/datum/gas_phase/proc/on_del_reagent(datum/reagent/reagent)
	SIGNAL_HANDLER
	UnregisterSignal(reagent, COMSIG_PHASE_CHANGE_FROM_GAS)
	UnregisterSignal(reagent, COMSIG_REAGENT_DIFFUSE)
	SEND_SIGNAL(src, COMSIG_PHASE_CHANGE_COLOR, mix_color_from_reagents(center_holder.reagent_list))
	//UnregisterSignal(reagent, COMSIG_PHASE_CHANGE_TO_GAS)

//datum/gas_phase/proc/on_remove_reagent(datum/reagent/reagent, amount)
//	SEND_SIGNAL(src, COMSIG_PHASE_CHANGE_COLOR, mix_color_from_reagents(center_holder.reagent_list))

///Diffusion creates mist - so we want to stop that!
/datum/gas_phase/proc/override_reagent_diffusion(volume)
	center_holder.remove_reagent(type, volume/5)
	return COMSIG_REAGENT_BLOCK_DIFFUSE

/datum/gas_phase/proc/on_phase_change_from_gas(datum/reagent/reagent, amount, phase_into)
	SIGNAL_HANDLER
	center_holder.remove_reagent(reagent, amount, phase = GAS)
	switch(phase_into)
		if(LIQUID)
			//Create liquid
			message_admins("creating liquid")
		if(SOLID)
			//Create solid
			message_admins("creating solid")
		if(IONISED)
			var/zap_flags = ZAP_MOB_DAMAGE | ZAP_OBJ_DAMAGE | ZAP_MOB_STUN
			tesla_zap(source, 7, amount*100, zap_flags)
	on_change_reagent()

/datum/gas_phase/proc/on_change_reagent()
	SIGNAL_HANDLER
	if(center_holder.total_volume <= 0)
		end_all_mist()
	var/delta_cell = CEILING(center_holder.total_volume/MIST_STANDARD_CELL_CAPACITY, 1)
	if(delta_cell == current_cells)
		return
	if(delta_cell > current_cells)
		create_new_cell(delta_cell) //Only make 1 cell at a time to make it look like it's spreading!
		//stack_trace("Removal of gas is trying to create more cells!")
	else if(delta_cell < current_cells)
		remove_cell(delta_cell)
		current_cells--
	SEND_SIGNAL(src, COMSIG_PHASE_CHANGE_COLOR, mix_color_from_reagents(center_holder.reagent_list))

/datum/gas_phase/proc/create_new_cell(num_cells)
	var/min_dist = 999
	var/obj/mist/target_mist
	for(var/obj/mist/misty in interface_mists)
		var/misty_distance = get_dist(source, misty)
		if(misty_distance < min_dist)
			target_mist = misty
			min_dist = misty_distance
	if(!target_mist)
		stack_trace("No target mist found! Is the interfacial list empty? Should this be a deleted controller?")
	//we have a target
	var/created_new = FALSE
	for(var/turf/new_turf in target_mist.local_turf.GetAtmosAdjacentTurfs())
		var/obj/mist/misty_boi = locate() in new_turf //Don't spread smoke where there's already smoke!
		if(misty_boi && misty_boi?.phase_controller.center_holder != center_holder) //Is there another cell there that's of a different controller? Lets greet them if so
			merge_into(misty_boi.phase_controller.center_holder, MIST_STANDARD_CELL_CAPACITY)
			return TRUE
		if(misty_boi) //if it's occupied - don't enter
			continue
		created_new = TRUE
		new /obj/mist(new_turf, center_holder, src)
		break
	if(created_new)//We're stable
		current_cells++
	else
		message_admins("We have a mist who can't expand but think it's unstable!")
		remove_from_interface(target_mist)
	return created_new

/datum/gas_phase/proc/remove_cell(num_cells) //This isn't working!
	var/max_dist = 0
	var/obj/mist/target_mist
	for(var/obj/mist/misty in interface_mists)
		var/misty_distance = get_dist(source, misty)
		if(misty_distance > max_dist)
			target_mist = misty
			max_dist = misty_distance
	if(!target_mist)
		stack_trace("No target mist found for removal of cells! Is the interfacial list empty? Should this be a deleted controller?")
		return
	//we have a target
	qdel(target_mist)
	current_cells--

/datum/gas_phase/proc/merge_into(datum/reagents/target, amount)
	center_holder.trans_to(target, amount)


//datum/gas_phase/proc/create_new_mist_cell(turf/turf)
	//var/obj/mist/mist = new obj/mist(turf, center_holder)
	//RegisterSignal(mist, COMSIG_PHASE_STATE_STABLE, .proc/remove_from_interface)
	//RegisterSignal(mist, COMSIG_PHASE_STATE_UNSTABLE, .proc/add_to_interface)

/datum/gas_phase/proc/end_all_mist()
	qdel(src)

/datum/gas_phase/proc/add_to_interface(obj/mist/mist)
	interface_mists += mist
	current_cells++

/datum/gas_phase/proc/remove_from_interface(obj/mist/mist)
	//debug - should work with this removed
	var/turf/t_loc = get_turf(mist)
	var/adjacent_filled
	for(var/turf/T in t_loc.GetAtmosAdjacentTurfs())
		var/obj/mist/misty_boi = locate() in T //Don't spread smoke where there's already smoke!
		if(misty_boi)
			adjacent_filled++
			continue
	if(!adjacent_filled)
		message_admins("I forget why this check is here")
	interface_mists -= mist
	current_cells--
	if(!current_cells)
		qdel(src)


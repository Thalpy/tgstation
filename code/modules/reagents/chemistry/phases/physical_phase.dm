/*The "gas" phase of reagents - this is what all reagents that aren't of the gas subtype are converted into upon entering their gas phase
* If they are a datum/reagent/gas type then atmos handles them instead
* Otherwise a mist is made of a certain size - depending on volume. To prevent confusion with air/gas/linda comments will refer to this effect either as mist or gas_phase, with the former being preferred
* Unlike liquids - a single reagent tracks the mist's contents - so gas transferal isn't a thing
* Gas dissipates - reduces in volume at the edges of it's area
* This is not meant to be atmos 2.0 - our granularity is higher compared to atmos so we take steps to ensure we're a much lower cost
* This hooks up the the mist obj which does most of the math with signals - Welcome to signal city
*/

/datum/physical_phase
	///This is the holder that holds the current reagents that are in the "air"
	var/datum/reagents/center_holder
	///The location atom we're tied to
	var/atom/source
	///How big our cell cloud is - i.e. the total number of cells we're on - affects diffuse rate
	var/current_cells = 0
	///The sum of the volume in the mist - this is cells * capacity
	//var/sum_volume
	///The interfacial cells - all cells within the center are considered "stable" so we don't process their movement
	var/list/obj/phase_object/interface_cells = list()
	///The type of phase object we create
	var/phase_object
	///The type of phase we are
	var/phase_type
	///The u/volume capacity of one cell
	var/cell_capacity

/datum/physical_phase/New(datum/reagent/reagent, volume, atom/reagent_source, turf/location)
	. = ..()
	if(!isopenturf(location))
		stack_trace("Input turf isn't open!")
		return FALSE
	if(volume <= 0.05)
		stack_trace("Attempted to add a reagent to a gas_phase with a volume less than 0.05")
		return FALSE
	center_holder = new /datum/reagents(3000)
	source = reagent_source
	//Flagging our signals
	RegisterSignal(center_holder, COMSIG_REAGENTS_NEW_REAGENT, .proc/on_new_reagent) //Todo: change these 3 to flag when
	RegisterSignal(center_holder, COMSIG_REAGENTS_DEL_REAGENT, .proc/on_del_reagent)
	RegisterSignal(center_holder, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES, .proc/process)
	RegisterSignal(source, COMSIG_PARENT_QDELETING, .proc/on_del_source)
	//Add reagents
	center_holder.my_atom = new phase_object(location, center_holder, src)
	center_holder.add_reagent(reagent.type, volume, reagtemp = reagent.holder.chem_temp, added_purity = reagent.purity) //Does not remove volume from original holder - should be handled outside of that
	SSphase_states.active_state_controllers[phase_type] += src

/datum/physical_phase/Destroy(force, ...)
	UnregisterSignal(center_holder, COMSIG_REAGENTS_NEW_REAGENT)
	UnregisterSignal(center_holder, COMSIG_REAGENTS_DEL_REAGENT)
	UnregisterSignal(center_holder, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES)
	UnregisterSignal(source, COMSIG_PARENT_QDELETING)
	SEND_SIGNAL(src, COMSIG_PHASE_STATE_DELETE)
	for(var/datum/reagent/reagent as anything in center_holder.reagent_list)
		UnregisterSignal(reagent, COMSIG_PHASE_CHANGE_AWAY) //Clean up signals
	QDEL_NULL(center_holder)
	SSphase_states.active_state_controllers[phase_type] -= src
	return ..()

///When we lose our origin atom - we backup to the cell on it's location - if there is none then we default backup to any avalible interface
/datum/physical_phase/proc/on_del_source()
	SIGNAL_HANDLER
	var/turf/source_turf = get_turf(source)
	///If we're deleting our source, but can't find where it was, then we recenter to any avalible interface as a backup
	if(!source_turf)
		source = pick(interface_cells)
		return FALSE
	var/obj/phase_object/phasey = locate() in source_turf
	if(phasey)
		source = phasey
		return TRUE
	source = pick(interface_cells)
	return FALSE

/datum/physical_phase/proc/on_new_reagent(source, datum/reagent/reagent, amount, reagtemp, data, no_react)
	SIGNAL_HANDLER
	RegisterSignal(reagent, COMSIG_PHASE_CHANGE_AWAY, .proc/on_phase_change_away)
	reagent.chemical_flags &= REAGENT_STATE_PHYSICAL_PHASE
	///Update mist color
	SEND_SIGNAL(src, COMSIG_PHASE_CHANGE_COLOR, mix_color_from_reagents(center_holder.reagent_list))

/datum/physical_phase/proc/on_del_reagent(source, datum/reagent/reagent)
	SIGNAL_HANDLER
	UnregisterSignal(reagent, COMSIG_PHASE_CHANGE_AWAY)
	SEND_SIGNAL(src, COMSIG_PHASE_CHANGE_COLOR, mix_color_from_reagents(center_holder.reagent_list))
	//UnregisterSignal(reagent, COMSIG_PHASE_CHANGE_TO_GAS)

/datum/physical_phase/proc/on_phase_change_away(datum/reagent_phase/phase, datum/reagent/reagent, amount, phase_from, phase_into)
	SIGNAL_HANDLER
	if(phase_from == phase_into)
		message_admins("This is being flagged when it shouldn't")
	center_holder.remove_reagent(reagent, amount, phase = phase_from)
	switch(phase_into)
		if(GAS)
			create_mist(reagent, amount, get_turf(source))
		if(LIQUID)
			create_liquid(reagent, amount, get_turf(source))
			message_admins("creating liquid")
		if(SOLID)
			create_solid(reagent, amount, get_turf(source))
			message_admins("creating solid")
		if(IONISED)
			var/zap_flags = ZAP_MOB_DAMAGE | ZAP_OBJ_DAMAGE | ZAP_MOB_STUN
			tesla_zap(source, 7, amount*100, zap_flags)
		if(POWDER)
			stack_trace("Attemptung to transform INTO powder from [phase_from] in a physical phase. This shouldn't be happening!")
	process()

/datum/physical_phase/process()
	//SIGNAL_HANDLER
	if(center_holder.total_volume <= 0)
		end_all_physical_phases()
		return
	var/delta_cell = CEILING(center_holder.total_volume/cell_capacity, 1)
	if(delta_cell == current_cells)
		return
	if(delta_cell > current_cells)
		create_new_cell(delta_cell) //Only make 1 cell at a time to make it look like it's spreading!
		//stack_trace("Removal of gas is trying to create more cells!")
	else if(delta_cell < current_cells)
		remove_cell(delta_cell)
	var/interface_alpha =  50 + (((center_holder.total_volume % cell_capacity)/20) * 200)
	SEND_SIGNAL(src, COMSIG_PHASE_CHANGE_COLOR, mix_color_from_reagents(center_holder.reagent_list), interface_alpha)

/datum/physical_phase/proc/create_new_cell(num_cells)
	var/min_dist = 999
	var/obj/phase_object/target
	for(var/obj/phase_object/phasey in interface_cells)
		var/phasey_distance = get_dist(source, phasey)
		if(phasey_distance < min_dist)
			target = phasey
			min_dist = phasey_distance
	if(!target)
		stack_trace("No target physical phase found! Is the interfacial list empty? Should this be a deleted controller?")
	//we have a target
	var/created_new = FALSE
	for(var/turf/new_turf in target.local_turf.GetAtmosAdjacentTurfs())
		var/obj/phase_object/phasey_boi = locate() in new_turf //Don't spread smoke where there's already smoke!
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

/datum/physical_phase/proc/remove_cell(num_cells) //This isn't working!
	var/max_dist = 0
	var/obj/phase_object/target
	for(var/obj/phase_object/phasey in interface_cells)
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
	qdel(src)

/datum/physical_phase/proc/add_to_interface(obj/phase_object/phasey)
	if(phasey in interface_cells)
		return
	interface_cells += phasey
	phasey.interfacial = TRUE

/datum/physical_phase/proc/remove_from_interface(obj/phase_object/phasey)
	//debug - should work with this removed
	var/turf/t_loc = get_turf(phasey)
	var/adjacent_filled
	for(var/turf/T in t_loc.GetAtmosAdjacentTurfs())
		var/obj/phase_object/other_phasey = locate() in T //Don't spread smoke where there's already smoke!
		if(other_phasey)
			add_to_interface(other_phasey)
			continue
	if(!adjacent_filled)
		message_admins("I forget why this check is here")
	interface_cells -= phasey
	phasey.interfacial = FALSE
	if(current_cells <= 0)
		qdel(src)

//		~~~			GAS PHASES			~~~

/datum/physical_phase/gas_phase
	phase_object = /obj/phase_object/mist
	phase_type = GAS
	cell_capacity = 20

/datum/physical_phase/gas_phase/on_new_reagent(source, datum/reagent/reagent, amount, reagtemp, data, no_react)
	. = ..()
	RegisterSignal(reagent, COMSIG_REAGENT_DIFFUSE, .proc/override_reagent_diffusion)

///Diffusion creates mist - so we want to stop that!
/datum/physical_phase/gas_phase/proc/override_reagent_diffusion(datum/reagent, volume)
	center_holder.remove_reagent(reagent.type, volume/5)
	return COMSIG_REAGENT_BLOCK_DIFFUSE

/datum/physical_phase/gas_phase/on_del_reagent(source, datum/reagent/reagent)
	. = ..()
	UnregisterSignal(reagent, COMSIG_REAGENT_DIFFUSE)

/datum/physical_phase/gas_phase/proc/carbon_breathe(source, mob/living/carbon/carby, delta_time)
	SIGNAL_HANDLER
	center_holder.expose(carby, INGEST) //This should block transfer with a mask.
	center_holder.trans_to(carby, 2, methods = INGEST, ignore_stomach = TRUE)

//		~~~			LIQUID PHASES			~~~

/datum/physical_phase/liquid_phase
	phase_object = /obj/phase_object/liquid
	phase_type = LIQUID
	cell_capacity = 25


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
	var/sum_volume
	///The interfacial cells - all cells within the center are considered "stable" so we don't process their movement
	var/list/atom/mist/interface_mists = list()

/datum/gas_phase/New(datum/reagent/reagent, volume)
	. = ..()
	center_holder = new /datum/reagents(3000)
	center_holder.my_atom = src
	RegisterSignal(center_holder, COMSIG_REAGENTS_NEW_REAGENT, .proc/on_new_reagent)
	RegisterSignal(center_holder, COMSIG_REAGENTS_DEL_REAGENT, .proc/on_del_reagent)
	RegisterSignal(source, COMSIG_REAGENTS_DEL_REAGENT, .proc/on_del_reagent)
	center_holder.add_reagent(reagent.type, volume) //Does not remove volume from original holder

/datum/gas_phase/Destroy(force, ...)
	UnregisterSignal(src, COMSIG_REAGENTS_NEW_REAGENT)
	UnregisterSignal(src, COMSIG_REAGENTS_DEL_REAGENT)
	SEND_SIGNAL(src, COMSIG_PHASE_STATE_DELETE)
	for(var/datum/reagent/reagent as anything in center_holder.reagent_list)
		on_del_reagent(reagent) //Clean up signals
	QDEL_NULL(center_holder)
	..()

///Adds a reagent to the mist cloud
/datum/gas_phase/proc/add_phase_reagent(datum/reagent/reagent)
	center_holder.add_reagent(reagent.type, reagent.get_phase_volume(GAS))

/datum/gas_phase/proc/on_new_reagent(datum/reagent/reagent, amount, reagtemp, data, no_react)
	SIGNAL_HANDLER
	RegisterSignal(reagent, COMSIG_PHASE_CHANGE_FROM_GAS, .proc/on_phase_change_from_gas)
	RegisterSignal(reagent, COMSIG_PHASE_CHANGE_TO_GAS, .proc/on_phase_change_to_gas) //Might not be needed

/datum/gas_phase/proc/on_del_reagent(datum/reagent/reagent)
	SIGNAL_HANDLER
	UnregisterSignal(reagent, COMSIG_PHASE_CHANGE_FROM_GAS)
	UnregisterSignal(reagent, COMSIG_PHASE_CHANGE_TO_GAS)

/datum/gas_phase/proc/on_phase_change_to_gas(datum/reagent/reagent, change_volume)
	SIGNAL_HANDLER


/datum/gas_phase/proc/on_phase_change_from_gas(datum/reagent/reagent, change_volume)
	SIGNAL_HANDLER
	sum_volume -= change_volume
	if(sum_volume <= 0)
		end_all_mist()
	var/delta_cell = CEILING(sum_volume/MIST_STANDARD_CELL_CAPACITY, 1)
	if(delta_cell > current_cells)
		stack_trace("Removal of gas is trying to create more cells!")
	if(delta_cell == current_cells)
		return
	create_new_cell(delta_cell) //Only make 1 cell at a time to make it look like it's spreading!


/datum/gas_phase/proc/create_new_cell(num_cells)
	var/min_dist = 999
	var/atom/mist/target_mist
	for(var/atom/mist/misty in interfacial_cells)
		var/misty_distance = get_dist(source, mist)
		if(misty_distance < min_dist)
			target_mist = misty
			min_dist = misty_distance
	if(!target_mist)
		stack_trace("No target mist found! Is the interfacial list empty? Should this be a deleted controller?")
	//we have a target

/datum/gas_phase/proc/create_new_mist_cell(turf/turf)
	var/atom/mist/mist = new atom/mist(turf, center_holder)
	RegisterSignal(mist, COMSIG_PHASE_STATE_STABLE, ./proc/remove_from_interface)
	RegisterSignal(mist, COMSIG_PHASE_STATE_UNSTABLE, ./proc/add_to_interface)

/datum/gas_phase/proc/end_all_mist()
	qdel(src)

/datum/gas_phase/proc/add_to_interface(atom/mist)
	interface_mists += mist
	current_cells++

/datum/gas_phase/proc/remove_from_interface(atom/mist)
	//debug - should work with this removed
	var/turf/t_loc = get_turf(mist)
	var/adjacent_filled
	for(var/turf/T in t_loc.GetAtmosAdjacentTurfs())
		var/atom/mist/misty_boi = locate() in T //Don't spread smoke where there's already smoke!
		if(misty_boi)
			adjacent_filled++
			continue
	if(!adjacent_filled)

	interface_mists -= mist
	current_cells--


/*The "gas" phase of reagents - this is what all reagents that aren't of the gas subtype are converted into upon entering their gas phase
* If they are a datum/reagent/gas type then atmos handles them instead
* Otherwise a mist is made of a certain size - depending on volume. To prevent confusion with air/gas/linda comments will refer to this effect either as mist or gas_phase, with the former being preferred
* Unlike liquids - a single reagent tracks the mist's contents - so gas transferal isn't a thing
* Gas dissipates - reduces in volume at the edges of it's area
* This is not meant to be atmos 2.0 - our granularity is higher compared to atmos so we take steps to ensure we're a much lower cost
* This hooks up the the mist obj which does most of the math with signals - Welcome to signal city
*/

#define MIST_STANDARD_CELL_CAPACITY 50

/datum/gas_phase
	///This is the holder that holds the current reagents that are in the "air"
	var/datum/reagent/center_holder
	///How big our mist cloud is - i.e. the total number of cells we're on - affects diffuse rate
	var/current_cells
	///The sum of the volume in the mist - this is
	var/sum_volume
	///The interfacial cells - all cells within the center are considered "stable" so we don't process their movement

/datum/gas_phase/New(datum/reagent/reagent, volume)
	. = ..()
	center_holder = new /datum/reagents(3000)
	center_holder.my_atom = src
	RegisterSignal(center_holder, COMSIG_REAGENTS_NEW_REAGENT, .proc/on_new_reagent)
	RegisterSignal(center_holder, COMSIG_REAGENTS_DEL_REAGENT, .proc/on_del_reagent)
	center_holder.add_reagent(reagent.type, volume) //Does not remove volume from original holder

/datum/gas_phase/Destroy(force, ...)
	UnregisterSignal(src, COMSIG_REAGENTS_NEW_REAGENT)
	UnregisterSignal(src, COMSIG_REAGENTS_DEL_REAGENT)
	SEND_SIGNAL(src, COMSIG_PHASE_STATE_DELETE)
	QDEL_NULL(center_holder)
	..()

///Adds a reagent to the mist cloud
/datum/gas_phase/proc/add_phase_reagent(datum/reagent/reagent)
	center_holder.add_reagent(reagent.type, reagent.get_phase_volume(GAS))

/datum/gas_phase/proc/on_new_reagent(datum/reagent/reagent, amount, reagtemp, data, no_react)
	RegisterSignal(reagent, COMSIG_PHASE_CHANGE_FROM_GAS, .proc/on_phase_change_from_gas)
	RegisterSignal(reagent, COMSIG_PHASE_CHANGE_TO_GAS, .proc/on_phase_change_to_gas)

/datum/gas_phase/proc/on_del_reagent(datum/reagent/reagent)
	UnregisterSignal(reagent, COMSIG_PHASE_CHANGE_FROM_GAS)
	UnregisterSignal(reagent, COMSIG_PHASE_CHANGE_TO_GAS)

/datum/gas_phase/proc/on_phase_change_from_gas(datum/reagent/reagent, change_volume)
	sum_volume -= change_volume
	if(sum_volume <= 0)
		end_all_mist()
	var/delta_cell = CEILING(sum_volume/MIST_STANDARD_CELL_CAPACITY, 1)
	if(delta_cell > current_cells)
		stack_trace("Removal of gas is trying to create more cells!")
	if(delta_cell == current_cells)
		return
	create_new_cells(delta_cell)


/datum/gas_phase/proc/create_new_mist_cell(turf/turf)
	var/atom/mist/mist =  atom/mist(turf)
	mist.RegisterSignal(src, COMSIG_PHASE_STATE_DELETE, /atom/mist/proc/begone)
	RegisterSignal(mist, COMSIG_PHASE_STATE_STABLE, ./proc/remove_from_interface)
	RegisterSignal(mist, COMSIG_PHASE_STATE_UNSTABLE, ./proc/add_to_interface)


/datum/gas_phase/proc/remove_from_interface(atom/mist)

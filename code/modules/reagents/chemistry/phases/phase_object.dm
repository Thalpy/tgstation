/obj/phase_object
	name = "blank phase cell"
	desc = "This shouldn't be here, please let fermi know!"
	icon = 'icons/obj/chemical.dmi'
	icon_state = "clown flower"//So it's obviously an error
	alpha = 200
	///Local turf we're in
	var/turf/open/local_turf
	///The controller for this cloud
	var/datum/physical_phase/gas_phase/phase_controller
	///If this is an interfacial cell
	var/interfacial = FALSE
	///If this obj will costs reagents on del - i.e. if it's blown up we want to cost the holder some reagents
	var/cost_on_delete = TRUE
	///What type of phase we are
	var/phase
	///What temperature we're at
	var/temperature
	///What pressure we're at
	var/pressure
	///What our cell capacity is
	var/cell_capacity

//For solids - see solid phase object

/*
- I don't think these need to move, just move the center and delete entries to encourage movement - they're thick!
Todo:
- prevent this obj from being grabbed
*/

/obj/phase_object/New(turf/open/input_turf, datum/reagents/center_holder, datum/physical_phase/input_phase_controller)
	if(!isopenturf(input_turf))
		stack_trace("Input turf isn't open!")
	for(var/obj/phase_object/other_phase in input_turf.contents) //Optimisation possible here, deal with multiple loops over contents in 1 loop
		if(other_phase == src || other_phase.phase != phase)
			continue
		stack_trace("Attempting to move into occupied turf with a new physical phase! This shouldn't be happening!!")
		other_phase.phase_controller.merge_into(phase_controller.center_holder)
		begone() //Same as qdel
		return
	. = ..()
	local_turf = input_turf
	//reagents = center_holder // Do not do this - qdel will trigger the datum's destroy, killing the reagent controller's reagents with it (since it's a pointer)
	phase_controller = input_phase_controller
	RegisterSignal(local_turf, COMSIG_ATOM_ENTERED, .proc/flag_entree)
	RegisterSignal(local_turf, COMSIG_ATOM_EXIT, .proc/unflag_entree)
	RegisterSignal(local_turf, COMSIG_TURF_EXPOSE, .proc/update_cell_temperature)
	phase_controller.current_cells += src
	//Check to see if we're on the interface - i.e we're not surrounded.
	for(var/turf/nearby_turf in input_turf.GetAtmosAdjacentTurfs())
		var/obj/phase_object/phasey = locate() in nearby_turf //This seems bad
		if(phasey?.phase == phase) //If there's a mist there, keep looking
			continue
		phase_controller.add_to_interface(src)
		break
	//I might've meant to add something else here

/obj/phase_object/Destroy()
	UnregisterSignal(local_turf, COMSIG_ATOM_ENTERED)
	UnregisterSignal(local_turf, COMSIG_ATOM_EXIT)
	phase_controller.remove_from_interface(src)
	phase_controller.current_cells -= src
	if(cost_on_delete)
		phase_controller.center_holder.remove_all(phase_controller.cell_capacity)
	..()

/obj/phase_object/proc/add_reagent(datum/reagent/reagent, amount)
	phase_controller.center_holder.add_reagent(reagent.type, amount, reagtemp = reagent.holder.chem_temp, added_purity = reagent.purity, added_ph = reagent.ph)
	phase_controller.shift_center(x, y, z, amount)

/obj/phase_object/proc/remove_reagent(datum/reagent/reagent, amount)
	phase_controller.center_holder.remove_reagent(reagent.type, amount, phase = phase)
	phase_controller.shift_center(x, y, z, -amount)

/obj/phase_object/proc/flag_entree(atom/newLoc, atom/movable/moveable, atom/oldLoc)
	SIGNAL_HANDLER

/obj/phase_object/proc/unflag_entree(atom/oldLoc, atom/movable/moveable, atom/newLoc)
	SIGNAL_HANDLER

/obj/phase_object/proc/recalculate_color(datum/physical_phase/controller, new_color, interface_alpha)
	SIGNAL_HANDLER
	color = new_color
	if(interfacial)
		alpha = interface_alpha

/obj/phase_object/proc/update_cell_temperature(datum/source, datum/gas_mixture/air, exposed_temperature)
	SIGNAL_HANDLER
	temperature = exposed_temperature
	pressure = air.return_pressure()
	phase_controller.update_temp_pressure = TRUE

/obj/phase_object/proc/begone(source)
	SIGNAL_HANDLER
	if(!QDELETED(src))
		cost_on_delete = FALSE
		qdel(src)
	else
		stack_trace("attempted to delete phase cell when it was flagged to delete")

/obj/phase_object/mist
	name = "mist cloud"
	desc = "A cloud of gaseous reagents. Be careful of breathing this stuff in!"
	icon_state = "gas_phase"
	phase = GAS
	layer = ABOVE_NORMAL_TURF_LAYER
	cell_capacity = 20

/obj/phase_object/mist/New(turf/open/input_turf, datum/reagents/center_holder, datum/physical_phase/input_phase_controller)
	. = ..()
	for(var/mob/living/carbon/carby in input_turf.contents)
		phase_controller.RegisterSignal(carby, COMSIG_CARBON_BREATHE_TURF, /datum/physical_phase/gas_phase/proc/carbon_breathe)

/obj/phase_object/Destroy(force)
	for(var/mob/living/carbon/carby in local_turf.contents)
		phase_controller.UnregisterSignal(carby, COMSIG_CARBON_BREATHE_TURF)
	return ..()

/obj/phase_object/mist/flag_entree(atom/newLoc, atom/movable/moveable, atom/oldLoc)
	. = ..()
	var/mob/living/carbon/carby = moveable
	if(!iscarbon(carby))
		return
	if(phase_controller.signal_procs[carby] && phase_controller.signal_procs[carby][COMSIG_CARBON_BREATHE_TURF]) //If we've already flagged a signal - then don't reflag
		message_admins("Mob already flagged")
		return
	phase_controller.RegisterSignal(carby, COMSIG_CARBON_BREATHE_TURF, /datum/physical_phase/gas_phase/proc/carbon_breathe)

/obj/phase_object/mist/unflag_entree(atom/oldLoc, atom/movable/moveable, atom/newLoc)
	. = ..()
	var/mob/living/carbon/carby = moveable
	if(!iscarbon(carby))
		return
	var/turf/open/new_turf = get_turf(newLoc)
	for(var/obj/phase_object/other in new_turf.contents) // is if(mist in contents) faster?
		if(other.reagents == reagents)
			return //we're in the same cloud so keep checking their breath
	phase_controller.UnregisterSignal(carby, COMSIG_CARBON_BREATHE_TURF)

/obj/phase_object/liquid
	name = "Liquid"
	desc = "A pool of liquid reagents. Be careful of swimming in this stuff!"
	icon_state = "liquid_phase"
	alpha = 200
	phase = LIQUID
	layer = ABOVE_OPEN_TURF_LAYER

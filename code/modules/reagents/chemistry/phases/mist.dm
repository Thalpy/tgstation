/atom/mist
	name = "mist cloud"
	desc = "A cloud of gaseous reagents. Be careful of breathing this stuff in!"
	icon_state = "mist"
	icon = 'icons/obj/chemical.dmi'
	alpha = 150
	///Local turf we're in
	var/turf/open/local_turf
	///The controller for this cloud
	var/datum/gas_phase/phase_controller

/*
- I don't think these need to move, just move the center and delete entries to encourage movement - they're thick!
*/

/atom/mist/New(turf/open/input_turf, datum/reagents/center_holder, datum/gas_phase/input_phase_controller)
	if(!isopenturf(input_turf))
		stack_trace("Input turf isn't open!")
	for(var/atom/mist/other_mist in input_turf.contents) //Optimisation possible here, deal with multiple loops over contents in 1 loop
		message_admins("Attempting to move into occupied turf from a mist! This shouldn't be happening!!")
		other_mist.phase_controller.merge_into(phase_controller.center_holder)
		qdel(src)
		return
	. = ..()
	local_turf = input_turf
	reagents = center_holder
	phase_controller = input_phase_controller
	RegisterSignal(local_turf, COMSIG_ATOM_ENTERED, .proc/flag_entree)
	RegisterSignal(local_turf, COMSIG_ATOM_EXIT, .proc/unflag_entree)
	RegisterSignal(phase_controller, COMSIG_PHASE_STATE_DELETE, .proc/begone)
	RegisterSignal(phase_controller, COMSIG_PHASE_CHANGE_COLOR, .proc/recalculate_color)

	for(var/mob/living/carbon/carby in input_turf.contents)
		RegisterSignal(carby, COMSIG_CARBON_BREATHE_TURF, .proc/carbon_breathe)
	for(var/turf/nearby_turf in input_turf.GetAtmosAdjacentTurfs())
		var/atom/mist/misty = locate() in nearby_turf //Don't spread smoke where there's already smoke!
		if(!misty)
			continue
		phase_controller.add_to_interface(misty)
	/*
	mist.RegisterSignal(loc, COMSIG_TURF_EXPOSE, /atom/mist/proc/on_turf_change())
	SEND_SIGNAL(src, COMSIG_ATOM_ENTERED, AM, oldLoc)
	SEND_SIGNAL(AM, COMSIG_ATOM_ENTERING, src, oldLoc)*/

/atom/mist/Destroy()
	UnregisterSignal(local_turf, COMSIG_ATOM_ENTERED)
	UnregisterSignal(local_turf, COMSIG_ATOM_EXIT)
	UnregisterSignal(phase_controller, COMSIG_PHASE_CHANGE_COLOR)
	UnregisterSignal(phase_controller, COMSIG_PHASE_STATE_DELETE)
	for(var/mob/living/carbon/carby in local_turf.contents)
		UnregisterSignal(carby, COMSIG_CARBON_BREATHE_TURF)
	phase_controller.remove_from_interface(src)
	..()

/atom/mist/proc/carbon_breathe(mob/living/carbon/carby, delta_time)
	SIGNAL_HANDLER
	reagents.expose(carby, INGEST) //This should block transfer with a mask.

/atom/mist/proc/flag_entree(atom/movable/moveable, atom/oldLoc)
	SIGNAL_HANDLER
	if(!iscarbon(moveable))
		return
	var/mob/living/carbon/carby = moveable
	RegisterSignal(carby, COMSIG_CARBON_BREATHE_TURF, .proc/carbon_breathe)
	//reagents.expose(carby, INGEST) //This should block transfer with a mask.

/atom/mist/proc/unflag_entree(atom/movable/moveable, atom/newLoc)
	SIGNAL_HANDLER
	if(!iscarbon(moveable))
		return
	var/turf/open/new_turf = get_turf(newLoc)
	for(var/atom/mist/other_mist in new_turf.contents) // is if(mist in contents) faster?
		if(other_mist.reagents == reagents)
			return //we're in the same cloud so keep checking their breath
	var/mob/living/carbon/carby = moveable
	UnregisterSignal(carby, COMSIG_CARBON_BREATHE_TURF)

/atom/mist/proc/recalculate_color(new_color)
	SIGNAL_HANDLER
	color = new_color

/atom/mist/proc/begone()
	SIGNAL_HANDLER
	qdel(src)

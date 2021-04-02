//This handles the reagents datum phases - i.e. the chemicals themselves transitioning.

PROCESSING_SUBSYSTEM_DEF(phase)
	name = "Phase"
	init_order = INIT_ORDER_PHASE
	priority = FIRE_PRIORITY_REAGENTS
	wait = 1 SECONDS
	flags = SS_KEEP_TIMING
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	///What time was it when we last ticked
	var/previous_world_time = 0

/datum/controller/subsystem/processing/phase/Initialize()
	. = ..()
	//So our first step isn't insane
	previous_world_time = world.time
	return

/datum/controller/subsystem/processing/phase/fire(resumed = FALSE)
	if (!resumed)
		currentrun = processing.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/current_run = currentrun

	//Sync with SSReagents
	var/delta_realtime = (world.time - previous_world_time)/10 //normalise to s from ds
	previous_world_time = world.time

	var/datum/reagents/holder
	while(current_run.len) //PHASE
		var/datum/reagent/reagent = current_run[current_run.len]
		if(QDELETED(reagent))
			stack_trace("Found qdeleted reagent in [type]: [holder.my_atom] | [reagent], in the current_run list.")
			processing -= reagent
		if(!reagent.holder)
			stack_trace("A holderless reagent made it's way to the phase list when it shouldn't")
			STOP_PROCESSING(src, reagent)
		if(reagent.holder != holder)
			//if(QDELETED(reagent.holder))
			//	processing -= reagent
			//	continue
			//We do this first because we want to update after we've done all the reagents in the holder
			if(holder) //but this means we have a null holder on start
				holder.update_pressure()
				SEND_SIGNAL(holder, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES) //Forces physical phases (mists, liquids and solids) to update
			holder = reagent.holder

		//If holder is processing - then we don't need to
		if(!(reagent.holder.datum_flags & DF_ISPROCESSING))
			if(reagent.process(delta_realtime) == PROCESS_KILL) //we are realtime
				// fully stop so that a future START_PROCESSING will work
				STOP_PROCESSING(src, reagent)

		current_run.len--
		if (MC_TICK_CHECK)
			SEND_SIGNAL(holder, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES) //Forces physical phases (mists, liquids and solids) to update
			holder.update_pressure()
			return

	//Finally lets make sure we call the end procs when we're done everything
	if(holder)
		SEND_SIGNAL(holder, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES) //Forces physical phases (mists, liquids and solids) to update
		holder.update_pressure()

///datum/controller/subsystem/processing/phase/proc/find_phase_profiles(var/datum/reagent/reagent)


/*
	var/object_list = list()
		for(var/item in phase_states)
			var/datum/reagent_phase/phase_lookup = GLOB.reagent_phase_list[item]
			object_list[phase_lookup] = phase_states[item] ///OBJECT = percentage
		phase_states = object_list
*/
/*
/datum/controller/subsystem/processing/phase/proc/start_processing(datum/reagents/reagents, datum/reagent/reagent)
	if(reagent.datum_flags & DF_ISPROCESSING)
		return
	if(!processing[reagents])
		processing[reagents] = list()
	reagent.datum_flags |= DF_ISPROCESSING
	processing[reagents] += reagent

/datum/controller/subsystem/processing/phase/proc/stop_processing(datum/reagents/reagents, datum/reagent/reagent)
	reagent.datum_flags &= ~DF_ISPROCESSING
	processing[reagents] -= reagent
	if(!length(processing[reagents]))
		processing -= reagents
*/

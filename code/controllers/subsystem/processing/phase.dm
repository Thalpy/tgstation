PROCESSING_SUBSYSTEM_DEF(phase)
	name = "Phase"
	init_order = INIT_ORDER_PHASE
	priority = FIRE_PRIORITY_REAGENTS
	wait = 1 SECONDS
	flags = SS_KEEP_TIMING
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	///What time was it when we last ticked
	var/previous_world_time = 0
	///The list of datums we're phase processing
	var/list/datum/reagents/phase_processing = list()

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
			//We do this first because we want to update after we've done all the reagents in the holder
			if(holder) //but this means we have a null holder on start
				holder.update_pressure()
			holder = reagent.holder

		current_run.len--
		//If holder is processing - then we don't need to
		if(!(holder.datum_flags & DF_ISPROCESSING))
			if(reagent.process(delta_realtime) == PROCESS_KILL) //we are realtime
				// fully stop so that a future START_PROCESSING will work
				STOP_PROCESSING(src, reagent)
		if (MC_TICK_CHECK)
			holder.update_pressure()
			return


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

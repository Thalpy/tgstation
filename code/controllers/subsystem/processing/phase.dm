PROCESSING_SUBSYSTEM_DEF(phase)
	name = "Phase"
	init_order = INIT_ORDER_REAGENTS
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

	while(current_run.len) //REACTIONS
		var/datum/reagents/holder = current_run[current_run.len]
		current_run.len--
		//If holder is processing - then we don't need to
		if(holder.datum_flags & DF_ISPROCESSING)
			continue
		for(var/datum/reagent/reagent as anything in current_run[holder])
			if(QDELETED(reagent))
				stack_trace("Found qdeleted reagent in [type]: [holder.my_atom] | [reagent], in the current_run list.")
				processing -= reagent
			else if(reagent.process(delta_realtime) == PROCESS_KILL) //we are realtime
				// fully stop so that a future START_PROCESSING will work
				stop_processing(holder, reagent)
			if (MC_TICK_CHECK)
				return
		holder.update_pressure()

/datum/controller/subsystem/processing/phase/proc/start_processing(datum/reagents/reagents, datum/reagent/reagent)
	if(!processing[reagents])
		processing[reagents] = list()
	if(!(reagent.datum_flags & DF_ISPROCESSING))
		reagent.datum_flags |= DF_ISPROCESSING
		processing[reagents] += reagents

/datum/controller/subsystem/processing/phase/proc/stop_processing(datum/reagents/reagents, datum/reagent/reagent)
	reagent.datum_flags &= ~DF_ISPROCESSING
	processing[reagents] -= reagents
	if(!length(processing[reagents]))
		processing -= reagents

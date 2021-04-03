#define REM REAGENTS_EFFECT_MULTIPLIER

GLOBAL_LIST_INIT(name2reagent, build_name2reagent())

/proc/build_name2reagent()
	. = list()
	for (var/t in subtypesof(/datum/reagent))
		var/datum/reagent/R = t
		if (length(initial(R.name)))
			.[ckey(initial(R.name))] = t


//Various reagents
//Toxin & acid reagents
//Hydroponics stuff

/// A single reagent
/datum/reagent
	/// datums don't have names by default
	var/name = "Reagent"
	/// nor do they have descriptions
	var/description = ""
	///J/(K*mol)
	var/specific_heat = SPECIFIC_HEAT_DEFAULT
	/// used by taste messages
	var/taste_description = "metaphorical salt"
	///how this taste compares to others. Higher values means it is more noticable
	var/taste_mult = 1
	/// use for specialty drinks.
	var/glass_name = "glass of ...what?"
	/// desc applied to glasses with this reagent
	var/glass_desc = "You can't really tell what this is."
	/// Otherwise just sets the icon to a normal glass with the mixture of the reagents in the glass.
	var/glass_icon_state = null
	/// used for shot glasses, mostly for alcohol
	var/shot_glass_icon_state = null
	/// fallback icon if  the reagent has no glass or shot glass icon state. Used for restaurants.
	var/fallback_icon_state = null
	/// reagent holder this belongs to
	var/datum/reagents/holder = null
	/// special data associated with this like viruses etc
	var/list/data
	/// increments everytime on_mob_life is called
	var/current_cycle = 0
	///pretend this is moles
	var/volume = 0
	/// pH of the reagent
	var/ph = 7
	///Purity of the reagent - for use with internal reaction mechanics only. Use below (creation_purity) if you're writing purity effects into a reagent's use mechanics.
	var/purity = 1
	///the purity of the reagent on creation (i.e. when it's added to a mob and it's purity split it into 2 chems; the purity of the resultant chems are kept as 1, this tracks what the purity was before that)
	var/creation_purity = 1
	///The mass of the reagent - used to calculate the phase profile of non-custom reagents
	var/mass = null //leave this as null so we can catch any reagents that can't be autogenerated
	///Phase vars
	/// SOLID, POWDER, LIQUID, GAS - these are converted to object references on startup, but in general I wouldn't expect to interact with these directly.
	///IMPORTANT - the ORDER that these are in determine the priorty of the phases!!
	var/list/phase_states = PHASE_STATE_LIQUID_DETERMINISTIC
	///TODO: delete this var since above is replacing it
	var/reagent_state = UNDEFINED
	/// color it looks in containers etc
	var/color = "#000000" // rgb: 0, 0, 0
	///how fast the reagent is metabolized by the mob
	var/metabolization_rate = REAGENTS_METABOLISM
	/// above this overdoses happen
	var/overdose_threshold = 0
	/// You fucked up and this is now triggering its overdose effects, purge that shit quick.
	var/overdosed = FALSE
	///if false stops metab in liverless mobs
	var/self_consuming = FALSE
	///affects how far it travels when sprayed
	var/reagent_weight = 1
	///is it currently metabolizing
	var/metabolizing = FALSE
	/// is it bad for you? Currently only used for borghypo. C2s and Toxins have it TRUE by default.
	var/harmful = FALSE
	/// Are we from a material? We might wanna know that for special stuff. Like metalgen. Is replaced with a ref of the material on New()
	var/datum/material/material
	///A list of causes why this chem should skip being removed, if the length is 0 it will be removed from holder naturally, if this is >0 it will not be removed from the holder.
	var/list/reagent_removal_skip_list = list()
	///The set of exposure methods this penetrates skin with.
	var/penetrates_skin = VAPOR
	/// See fermi_readme.dm REAGENT_DEAD_PROCESS, REAGENT_DONOTSPLIT, REAGENT_INVISIBLE, REAGENT_SNEAKYNAME, REAGENT_SPLITRETAINVOL, REAGENT_CANSYNTH, REAGENT_IMPURE
	var/chemical_flags = NONE
	///impure chem values (see fermi_readme.dm for more details on impure/inverse/failed mechanics):
	/// What chemical path is made when metabolised as a function of purity
	var/impure_chem = /datum/reagent/impurity
	/// If the impurity is below 0.5, replace ALL of the chem with inverse_chem upon metabolising
	var/inverse_chem_val = 0.25
	/// What chem is metabolised when purity is below inverse_chem_val
	var/inverse_chem = /datum/reagent/inverse
	///what chem is made at the end of a reaction IF the purity is below the recipies purity_min at the END of a reaction only
	var/failed_chem = /datum/reagent/consumable/failed_reaction
	///Thermodynamic vars
	///Temperature at which the reagent catches fire

	//FERMI_TODO: x = (y-c)/m for minimum reagent pressure ignite temperature

	var/ignite_temperature = null
	///What GASSES are produced from burning - can be a gas OR reagent with asssociate volume
	var/burning_products = list(/datum/gas/carbon_dioxide, 5)
	///How hot this reagent burns when it's on fire - null means it can't burn
	var/burning_temperature = null
	///How much is consumed when it is burnt per second
	var/burning_volume = 0.5
	///Assoc list with key type of addiction this reagent feeds, and value amount of addiction points added per unit of reagent metabolzied (which means * REAGENTS_METABOLISM every life())
	var/list/addiction_types = null
	///The amount a robot will pay for a glass of this (20 units but can be higher if you pour more, be frugal!)
	var/glass_price


/datum/reagent/New()
	SHOULD_CALL_PARENT(TRUE)
	. = ..()
	if(!mass)
		mass = rand(20, 800)
	if(material)
		material = GET_MATERIAL_REF(material)
	//Lest we calculate everything at the start
	if(length(GLOB.reagent_phase_list)) //Convert to object reference
		var/object_list = list()
		for(var/item in phase_states)
			var/datum/reagent_phase/phase_lookup = GLOB.reagent_phase_list[item]
			object_list[phase_lookup] = phase_states[item] ///OBJECT = percentage
		if(phase_states)
			phase_states = object_list
	//else //At init a master reagent list is made - we don't want them to be processing their phases
		//phase_states = null
	if(glass_price)
		AddElement(/datum/element/venue_price, glass_price)


/datum/reagent/Destroy() // This should only be called by the holder, so it's already handled clearing its references
	STOP_PROCESSING(SSphase, src)
	holder = null
	phase_states = null //Do not destroy reference - it's a lookup table
	..()

///Incase a phase profile breaks, this will repair it
/datum/reagent/proc/relink_phase_profiles()
	//phase_states = PHASE_STATE_LIQUID_DETERMINISTIC
	var/object_list = list()
	for(var/item in phase_states)
		var/datum/reagent_phase/phase_lookup = GLOB.reagent_phase_list[item]
		object_list[phase_lookup] = phase_states[item] ///OBJECT = percentage
	phase_states = object_list

///A test called on this reagent from the unit testing methods
///Use this to set up tests specific to a reagent subtype
/datum/reagent/proc/unit_test()
	. = list()
	if(name == "Reagent")
		. += "Generic failure: [type] has no name, if this is not a true reagent please add it to the GLOB.fake_reagent_blacklist."
	if(!mass)
		. += "Generic failure: [type] is missing a mass."
	var/pass = FALSE
	for(var/datum/reagent_phase/phase in phase_states)
		pass += phase.determine_phase_percent(src, 300, 1)
	if(!pass)
		. += "Generic failure: [type] failed phase testing - no valid phase for 300K at 101kPa!"
	return .

/// Applies this reagent to an [/atom]
/datum/reagent/proc/expose_atom(atom/exposed_atom, reac_volume)
	SHOULD_CALL_PARENT(TRUE)

	. = 0
	. |= SEND_SIGNAL(src, COMSIG_REAGENT_EXPOSE_ATOM, exposed_atom, reac_volume)
	. |= SEND_SIGNAL(exposed_atom, COMSIG_ATOM_EXPOSE_REAGENT, src, reac_volume)

/// Applies this reagent to a [/mob/living]
/datum/reagent/proc/expose_mob(mob/living/exposed_mob, methods=TOUCH, reac_volume, show_message = TRUE, touch_protection = 0)
	SHOULD_CALL_PARENT(TRUE)

	. = SEND_SIGNAL(src, COMSIG_REAGENT_EXPOSE_MOB, exposed_mob, methods, reac_volume, show_message, touch_protection)
	if((methods & penetrates_skin) && exposed_mob.reagents) //smoke, foam, spray
		var/amount = round(reac_volume*clamp((1 - touch_protection), 0, 1), 0.1)
		if(amount >= 0.5)
			exposed_mob.reagents.add_reagent(type, amount, added_purity = purity)

/// Applies this reagent to an [/obj]
/datum/reagent/proc/expose_obj(obj/exposed_obj, reac_volume)
	SHOULD_CALL_PARENT(TRUE)

	return SEND_SIGNAL(src, COMSIG_REAGENT_EXPOSE_OBJ, exposed_obj, reac_volume)

/// Applies this reagent to a [/turf]
/datum/reagent/proc/expose_turf(turf/exposed_turf, reac_volume)
	SHOULD_CALL_PARENT(TRUE)

	return SEND_SIGNAL(src, COMSIG_REAGENT_EXPOSE_TURF, exposed_turf, reac_volume)

///Called whenever a reagent is on fire, or is in a holder that is on fire. (WIP)
/datum/reagent/proc/burn(datum/reagents/holder)
	return

/// Called from [/datum/reagents/proc/metabolize]
/datum/reagent/proc/on_mob_life(mob/living/carbon/M, delta_time, times_fired)
	current_cycle++
	if(length(reagent_removal_skip_list))
		return
	holder.remove_reagent(type, metabolization_rate * M.metabolism_efficiency * delta_time) //By default it slowly disappears.

/*
Used to run functions before a reagent is transfered. Returning TRUE will block the transfer attempt.
Primarily used in reagents/reaction_agents
*/
/datum/reagent/proc/intercept_reagents_transfer(datum/reagents/target)
	return FALSE

///Called after a reagent is transfered
/datum/reagent/proc/on_transfer(atom/A, methods=TOUCH, trans_volume)
	return

/// Called when this reagent is first added to a mob
/datum/reagent/proc/on_mob_add(mob/living/L, amount)
	overdose_threshold /= max(normalise_creation_purity(), 1) //Maybe??? Seems like it would help pure chems be even better but, if I normalised this to 1, then everything would take a 25% reduction
	return

/// Called when this reagent is removed while inside a mob
/datum/reagent/proc/on_mob_delete(mob/living/L)
	SEND_SIGNAL(L, COMSIG_CLEAR_MOOD_EVENT, "[type]_overdose")
	return

/// Called when this reagent first starts being metabolized by a liver
/datum/reagent/proc/on_mob_metabolize(mob/living/L)
	return

/// Called when this reagent stops being metabolized by a liver
/datum/reagent/proc/on_mob_end_metabolize(mob/living/L)
	return

/// Called when a reagent is inside of a mob when they are dead
/datum/reagent/proc/on_mob_dead(mob/living/carbon/C)
	if(!(chemical_flags & REAGENT_DEAD_PROCESS))
		return
	current_cycle++
	if(length(reagent_removal_skip_list))
		return
	holder.remove_reagent(type, metabolization_rate * C.metabolism_efficiency)

/// Called by [/datum/reagents/proc/conditional_update_move]
/datum/reagent/proc/on_move(mob/M)
	return

/// Called after add_reagents creates a new reagent.
/datum/reagent/proc/on_new(data)
	return

/// Called when two reagents of the same are mixing.
/datum/reagent/proc/on_merge(data, amount)
	return

/// Called by [/datum/reagents/proc/conditional_update]
/datum/reagent/proc/on_update(atom/A)
	return

/// Called when the reagent container is hit by an explosion
/datum/reagent/proc/on_ex_act(severity)
	return

/// Called if the reagent has passed the overdose threshold and is set to be triggering overdose effects
/datum/reagent/proc/overdose_process(mob/living/M, delta_time, times_fired)
	return

/// Called when an overdose starts
/datum/reagent/proc/overdose_start(mob/living/M)
	to_chat(M, "<span class='userdanger'>You feel like you took too much of [name]!</span>")
	SEND_SIGNAL(M, COMSIG_ADD_MOOD_EVENT, "[type]_overdose", /datum/mood_event/overdose, name)
	return

/**
 * New, standardized method for chemicals to affect hydroponics trays.
 * Defined on a per-chem level as opposed to by the tray.
 * Can affect plant's health, stats, or cause the plant to react in certain ways.
 */
/datum/reagent/proc/on_hydroponics_apply(obj/item/seeds/myseed, datum/reagents/chems, obj/machinery/hydroponics/mytray, mob/user)
	if(!mytray)
		return

/// Should return a associative list where keys are taste descriptions and values are strength ratios
/datum/reagent/proc/get_taste_description(mob/living/taster)
	return list("[taste_description]" = 1)

/**
 * Used when you want the default reagents purity to be equal to the normal effects
 * (i.e. if default purity is 0.75, and your reacted purity is 1, then it will return 1.33)
 *
 * Arguments
 * * normalise_num_to - what number/purity value you're normalising to. If blank it will default to the compile value of purity for this chem
 * * creation_purity - creation_purity override, if desired. This is the purity of the reagent that you're normalising from.
 */
/datum/reagent/proc/normalise_creation_purity(normalise_num_to, creation_purity)
	if(!normalise_num_to)
		normalise_num_to = initial(purity)
	if(!creation_purity)
		creation_purity = src.creation_purity
	return creation_purity / normalise_num_to

/proc/pretty_string_from_reagent_list(list/reagent_list)
	//Convert reagent list to a printable string for logging etc
	var/list/rs = list()
	for (var/datum/reagent/R in reagent_list)
		rs += "[R.name], [R.volume]"

	return rs.Join(" | ")

///////////////////Phase related procs////////////////////////////////

/*
 *Diffuses out the reagent into the air, the actual removal is handled by the reagent phase datum
 *
 * arguments
 * * Amount: how much was diffused
 */
/datum/reagent/proc/diffuse(amount)
	if(SEND_SIGNAL(src, COMSIG_REAGENT_DIFFUSE, amount) & COMSIG_REAGENT_BLOCK_DIFFUSE)
		return
	var/turf/source_turf = get_turf(holder.my_atom)
	if(!isopenturf(source_turf))
		return
	var/obj/phase_object/mist/misty = locate() in source_turf
	if(!misty)
		//If there's no mist on our target turf - we want to join to an existing mist if it exists.
		for(var/turf/nearby_turf in source_turf.GetAtmosAdjacentTurfs())
			var/obj/phase_object/mist/misty_lass = locate() in nearby_turf
			if(misty_lass)
				if(QDELETED(misty_lass.phase_controller))
					continue
				new /obj/phase_object/mist(source_turf, misty_lass.phase_controller.center_holder, misty_lass.phase_controller)
				misty_lass.phase_controller.center_holder.add_reagent(type, amount, reagtemp = holder.chem_temp, added_purity = purity, added_ph = ph)
				return
		//If we're truly alone, create a new one
		new /datum/physical_phase/gas_phase(src, amount, holder.my_atom, source_turf)
		holder.remove_reagent(type, amount, phase = GAS)
		return
	//Edge case - we don't want deleting things to be rejuvinated
	if(QDELETED(misty.phase_controller))
		return
	misty.phase_controller.center_holder.add_reagent(type, amount, reagtemp = holder.chem_temp, added_purity = purity, added_ph = ph)
	holder.remove_reagent(type, amount, phase = GAS)

///DO NOT CALL THIS DIRECTLY! Use check_reagent_phase() to start this from it's holder
///Processes the phases of each reagent in the holder
/datum/reagent/process(delta_time)
	var/needs_update = adjust_phase_targets(delta_time)
	needs_update += phase_tick(delta_time)
	if(!needs_update)
		return PROCESS_KILL

/*
 * Calculates the new target for the reagent's phase states.
 * First we go through our list of possible phases - the ordering is important as we stop calculating as soon as we've hit a sum ratio of 1
 * Then after we have our target volumes in target_list() we then go over the same list and adjust the % values for each of the phases
 * If we
 */
/datum/reagent/proc/adjust_phase_targets(delta_time)
	//Debug
	if(!holder)
		stack_trace("Attempted to update [type]'s phases, but it has no holder!")
		return FALSE
	check_phase_ratio("Failed ratios at the start!") //Remove me later
	var/sum_ratio //What is our total target to adjust ratios to?
	//var/list/target_list = list()
	var/positive_changes = 0 //how much SUM ratio we're changing - the target defines the rates
	var/list/positive_budget = list()
	//var/negative_changes = 0 //The NUMBER of ragents we're removing from
	var/list/negative_budget = list() //The total ratio of all the phases
	var/debug = "[type] [delta_time]\n"
	var/needs_update = FALSE
	var/unchanged = 0
	for(var/datum/reagent_phase/phase as anything in phase_states) //We prioritise the first phases in the list
		if(phase_states[phase] > 1)
			message_admins("Input phase [phase.phase] is giving funky input ratios [phase_states[phase]]")
		if(sum_ratio >= 1)
			//target_list[phase] = 0
			//We're at our limit - but we still need to track what we're removing from
			if(phase_states[phase] != 0)
				//negative_changes += 1
				negative_budget[phase] += phase_states[phase]
				debug += "Prephase: phase [phase.phase] has a ratio of [phase_states[phase]] with a target of 0\n"
				debug += "Prephase: phase [phase.phase] has a negative budget of [phase_states[phase]]\n"
			else
				unchanged++
			continue
		var/ratio = round(phase.determine_phase_percent(src, holder.chem_temp, holder.pressure), CHEMICAL_VOLUME_MINIMUM)
		debug += "Prephase: phase [phase.phase] has a ratio of [phase_states[phase]] with a target of [ratio]\n"
		if(ratio < 0 || ratio > 1)
			stack_trace("Ratio is giving a funky number: [ratio] for reagent: [type]")
		else if (phase_states[phase] == ratio)
			unchanged++
		//Limit our addition to be 1 across all states
		if(1 < sum_ratio + ratio )
			ratio = 1 - sum_ratio
			debug += "This ratio was adjusted to [ratio]\n"
		//Positive change
		if(ratio > phase_states[phase])
			var/difference = round(ratio - phase_states[phase], CHEMICAL_VOLUME_MINIMUM)
			//If our delta_realtime is huge - it can cause problems
			var/phase_specific_time = min(phase.transition_speed * delta_time, 1)
			//So we don't take too much
			var/potential_change = phase_specific_time
			if(difference > phase_specific_time)
				needs_update = TRUE
			else
				potential_change = difference
			if(potential_change == 0)//Rounding error catch
				sum_ratio += ratio
				continue
			if(phase_states[phase] + potential_change > 1)
				positive_changes += 1-phase_states[phase]
				positive_budget[phase] += 1-phase_states[phase]
			else//Otherwise take it all
				positive_changes += potential_change
				positive_budget[phase] += potential_change

			debug += "Prephase: phase [phase.phase] has a positive target of [potential_change]\n"
		//We can't know if we're taking too much here, so we solve that in the next loop
		//But we can know if we're taking away from our current - and we need to check we're not making more than possible
		else if(ratio < phase_states[phase])
			negative_budget[phase] += phase_states[phase]
			debug += "Prephase: phase [phase.phase] has a negative budget of [phase_states[phase]]\n"
		sum_ratio += ratio
	if(unchanged == length(phase_states))
		return FALSE
	if(!negative_budget.len && positive_budget.len)
		message_admins("Reagent [type] is attempting to create matter from nothing! (positive changes with nothing to take it from)")
		message_admins(debug)
		//check_phase_ratio(debug)
		return
	if(!negative_budget.len || !positive_budget.len) //No changes!
		return FALSE
	debug += "TOTAL: Adding a total vol of [positive_changes].\n"

	for(var/datum/reagent_phase/phase in negative_budget) //Negative
		var/change = positive_changes / negative_budget.len
		if(negative_budget[phase] < change)
			positive_changes -= change - negative_budget[phase]
			phase.transition_from(src, phase_states[phase] * volume)
			phase_states[phase] = 0
			debug += "[phase.phase] Removing [change - negative_budget[phase]] by setting it to 0 and removing [change - negative_budget[phase]] from positive changes [positive_changes]. Final ratio: [phase_states[phase]]\n"
		else
			phase.transition_from(src, change * volume)
			phase_states[phase] = phase_states[phase] - change
			debug += "[phase.phase] Removing [(positive_changes / negative_budget.len)] and setting it to [phase_states[phase]]\n"

	for(var/datum/reagent_phase/phase in positive_budget) //Positive
		if(positive_budget[phase] > positive_changes)
			phase.transition_to(src, positive_changes * volume)
			phase_states[phase] = phase_states[phase] + positive_changes
			debug += "[phase.phase] is overbudget, adding [positive_changes] instead of [positive_budget[phase]] and setting positive change to 0, final ratio: [phase_states[phase]]\n"
			positive_changes = 0
		else
			phase.transition_to(src, positive_budget[phase] * volume)
			phase_states[phase] = phase_states[phase] + positive_budget[phase]
			positive_changes -= positive_budget[phase]
			debug += "[phase.phase] adding [positive_budget[phase]] and setting positive budget to [positive_changes] with final ratio of [phase_states[phase]]\n"

	//Ensure we're 100%
	check_phase_ratio(debug)
	return needs_update

///Resolves the phase profile of a reagent immediately
/datum/reagent/proc/resolve_phase(temp, pressure)
	var/sum_ratio = 0
	//Debug section
	if(!phase_states)
		relink_phase_profiles()
		message_admins("[src] had no phase states assigned to it! How??")
	for(var/datum/reagent_phase/phase as anything in phase_states) //We prioritise the first phases in the list
		if(!istype(phase, /datum/))
			stack_trace("Phases are not set up correctly! Is this a reference value?")
			return FALSE
		if(sum_ratio >= 1)
			phase_states[phase] = 0
			continue
		var/ratio = phase.determine_phase_percent(src, temp, pressure)
		if(1 < sum_ratio + ratio)
			ratio = 1 - sum_ratio
		sum_ratio += ratio
		phase_states[phase] = round(ratio, CHEMICAL_QUANTISATION_LEVEL)
	check_phase_ratio(debug = "yes")
	STOP_PROCESSING(SSphase, src)

/datum/reagent/proc/full_phase_transition(phase_from, phase_into)
	if(!get_phase_ratio(phase_from))
		return FALSE
	set_phase_percent(phase_into, get_phase_ratio(phase_from), check_ratio = FALSE)
	set_phase_percent(phase_from, 0, check_ratio = FALSE)
	check_phase_ratio()

///Calls the tick proc on each of the phases - so that their extra effects work
/datum/reagent/proc/phase_tick(delta_time)
	var/needs_update = FALSE
	for(var/datum/reagent_phase/phase as anything in phase_states)
		if(phase_states[phase] == 0) //Don't process empty phases
			continue
		needs_update += phase.tick(src, delta_time)
	return needs_update

///Gets the phase datum from a state
/datum/reagent/proc/get_phase(state)
	for(var/datum/reagent_phase/phase_state in phase_states)
		if(state == phase_state.phase)
			return phase_state
	return FALSE

///Gets the phase related volume of a reagent
/datum/reagent/proc/get_phase_volume(state)
	for(var/datum/reagent_phase/phase_state in phase_states)
		if(state == phase_state.phase)
			return phase_states[phase_state] * volume
	return FALSE

///Gets the current ratio of the specified phase (between 0 and 1)
///Arguments: phase - the define state (i.e. GAS, LIQUID, SOLID)
/datum/reagent/proc/get_phase_ratio(state)
	for(var/datum/reagent_phase/phase_state in phase_states)
		if(state == phase_state.phase)
			return phase_states[phase_state]
	return 0

///Sets a specific phase to a certain ratio - call check_phase_ratio after using this.
/datum/reagent/proc/set_phase_percent(phase, amount, check_ratio = TRUE)
	for(var/datum/reagent_phase/phase_state in phase_states)
		if(phase == phase_state.phase)
			phase_states[phase_state] = amount
			if(check_ratio)
				check_phase_ratio()
			return TRUE
	return FALSE

///Checks to make sure that the ratio values for all the phases are
/datum/reagent/proc/check_phase_ratio(debug = FALSE)
	var/sum_ratio = 0
	for(var/phase_state in phase_states)
		sum_ratio += phase_states[phase_state]
	sum_ratio = round(sum_ratio, CHEMICAL_VOLUME_ROUNDING) //Pesky 0.0000001s
	if(sum_ratio <= 0)
		message_admins("reagent has a sum ratio of 0 which we want to avoid happening")
		return FALSE //If we're being deleted then our sum will be 0
	if(sum_ratio != 1) //This can happen from set_phase_percent()
		if(debug)
			message_admins("[type] didn't have correct ratios! This is not an error you can ignore! ratio sum: [sum_ratio]")
			message_admins(debug + "\nFinal ratio: [sum_ratio]")
		for(var/datum/reagent_phase/phase_state in phase_states)
			phase_states[phase_state] = phase_states[phase_state] / sum_ratio

///Checks to see if the current reagent is in flux,
///but doesn't check to see if the ratios are right - we shouldn't need to do this as processing should flag this correctly
///Mostly a check for unsealed(), it's much better to call the holder's check_reagent_phase()
///Consider removing as it might encourage poor coding practice
/datum/reagent/proc/check_phase_flux()
	if(phase_states == null) //Are we a reference value? If so don't process imaginary reagents
		return FALSE
	if(datum_flags == DF_ISPROCESSING)//We're already processing
		return FALSE
	//if(!(holder.flags & SEALED) && get_phase_ratio(GAS)) //gases diffuse out when unsealed FERMI_TODO
	//	return TRUE
	if(chemical_flags & REAGENT_PHASE_INSTANT)
		resolve_phase(holder.chem_temp, holder.pressure)
		return FALSE
	else if(adjust_phase_targets(1))
		return TRUE
	return FALSE

///Checks the current phases to see if the reaction speed/reaction purity is affected by phases
/datum/reagent/proc/consider_phase_modifiers(list/modifiers)
	for(var/datum/reagent_phase/phase as anything in phase_states)
		if(!phase_states[phase])
			continue
		modifiers["sum_speed"] += phase.reaction_speed_modifier * phase_states[phase]
		modifiers["sum_purity"] += phase.purity_modifier * phase_states[phase]
	return modifiers


//Debug stuff
/datum/reagent/proc/message_plasma_admins(message)
	if(type == /datum/reagent/stable_plasma)
		message_admins(message)

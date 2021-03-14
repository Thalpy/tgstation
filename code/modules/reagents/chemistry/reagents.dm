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

	//TODO: x = (y-c)/m for minimum reagent pressure ignite temperature

	var/ignite_temperature = null
	///What GASSES are produced from burning - can be a gas OR reagent with asssociate volume
	var/burning_products = list(/datum/gas/carbon_dioxide, 5)
	///How hot this reagent burns when it's on fire - null means it can't burn
	var/burning_temperature = null
	///How much is consumed when it is burnt per second
	var/burning_volume = 0.5
	///Assoc list with key type of addiction this reagent feeds, and value amount of addiction points added per unit of reagent metabolzied (which means * REAGENTS_METABOLISM every life())
	var/list/addiction_types = null

/datum/reagent/New()
	SHOULD_CALL_PARENT(TRUE)
	. = ..()

	if(material)
		material = GET_MATERIAL_REF(material)

/datum/reagent/Destroy() // This should only be called by the holder, so it's already handled clearing its references
	. = ..()
	holder = null
	phase_states = null //Do not destroy reference - it's a lookup table

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
			exposed_mob.reagents.add_reagent(type, amount)

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
 * Calculates the new target for the reagent's phase states.
 * First we go through our list of possible phases - the ordering is important as we stop calculating as soon as we've hit a sum ratio of 1
 * Then after we have our target volumes in target_list() we then go over the same list and adjust the % values for each of the phases
 * If we
 */
/datum/reagent/proc/adjust_phase_targets(delta_time)
	var/sum_ratio //What is our total target to adjust ratios to?
	var/list/target_list()
	for(var/datum/reagent_phase/phase in phase_states) //We prioritise the first phases in the list
		if(sum_ratio >= 1)
			target_list[phase] = 0
			continue
		var/ratio = phase.determine_phase_percent(src, holder.chem_temp, holder.pressure)
		if(ration < 0 || ratio > 1)
			stack_trace("Ratio is giving a funky number: [ratio] for reagent: [reagent]")
		if(1 < sum_ratio + ratio )
			ratio = 1 - sum_ratio
		target_list[phase] = ratio * reagent.volume
		sum_ratio += ratio
	//If we're not at our target yet - request an update on the next tick
	var/needs_update = FALSE
	for(var/datum/reagent_phase/phase in target_list) //target list is the target volume assoc list
		if(target_list[phase] == phase_states[phase])//No change
			continue
		if(target_list[phase] > phase_states[phase]) //Positive change
			var/amount = clamp(phase_states[phase] + (phase.transition_speed * delta_time), 0, target_list[phase])
			phase.transition_to(src, amount)
			phase_states[phase] += amount
		if(target_list[phase] < phase_states[phase]) //Negative change
			var/amount = clamp(phase_states[phase] - (phase.transition_speed * delta_time), target_list[phase], 0)
			phase.transition_from(src, amount)
			phase_states[phase] -= amount

		if(target_list[phase] != phase_states[phase])//We updated - but we're not at our target yet
			needs_update = TRUE
	//Ensure we're 100%
	check_phase_ratio()
	return needs_update



///Gets the current ratio of the specified phase (between 0 and 1)
/datum/reagent/proc/get_phase_percent(phase)
	for(var/datum/reagent_phase/phase_state in phase_states)
		if(phase == phase_state.phase)
			return phase_states[phase_state]
	return 0

///Sets a specific phase to a certain ratio - call check_phase_ratio after using this.
/datum/reagent/proc/get_phase_percent(phase, amount)
	for(var/datum/reagent_phase/phase_state in phase_states)
		if(phase == phase_state.phase)
			phase_states[phase_state] = amount
			return TRUE
	return FALSE

///Checks to make sure that the ratio values for all the phases are
/datum/reagent/proc/check_phase_ratio()
	sum_ratio = 0
	for(var/datum/reagent_phase/phase_state in phase_states)
		sum_ratio += phase_states[phase_state]
	if(sum_ratio != 1)
		debug_world("[reagent] didn't have correct ratios!")
		for(var/datum/reagent_phase/phase_state in phase_states)
			phase_states[phase_state] /= sum_ratio

///Checks the current phases to see if the reaction speed/reaction purity is affected by phases
/datum/reagent/proc/consider_phase_modifiers(var/datum/equilibrium/reaction)
	var/sum_speed = 0 //Sum of speed modifiers
	var/sum_purity = 0 //Sum of purity modifiers
	for(var/datum/reagent_phase/phase in phase_states)
		sum_speed += phase.reaction_speed_modifier * phase_states[phase]
		sum_purity += phase.purity_modifier * phase_states[phase]
	if(!sum_speed || !sum_purity)
		stack_trace("Something went wrong when trying to calculate phase modifiers from reagent phase")
		return
	sum_speed /= length(phase_states)
	sum_purity /= length(phase_states)
	reaction.speed_mod *= sum_speed
	reaction.h_ion_mod *= sum_purity

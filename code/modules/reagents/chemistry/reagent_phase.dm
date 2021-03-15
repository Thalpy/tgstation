/*
 * P = mT + c
 * Temperature is T (K)
 * P is pressure (atm)
 * Both of above are dervived from holder/reagents datum
 * Highly recommended that you edit these vars from the calulator linked in the readme. It's not as complicated as you think!
 * The critical point for reagents is gamified into range - this isn't exactly true to reality (since it's past a point, rather than a range) but this should make it more dynamic and less expensive
 * This is a lookup/reference var and shouldn't be edited
*/
/datum/reagent_phase
	///The name or DEFINE of the phase for use with GUI/general case uses (I.e. SOLID, POWDER, LIQUID, GAS)
	var/phase
	///The density of this phase
	var/density
	///How fast this phase can transition (u/s) (into and from) If there's bugs it's likely this
	var/transition_speed = 5
	///The speed modifier of this phase
	var/reaction_speed_modifier = 1
	///The purity modifier of this phase
	var/purity_modifier = 1

///called for each update that this phase has a volume presence
/datum/reagent_phase/proc/tick(delta_time)

///Calculates how much of this current phase we should be aiming to convert into
/datum/reagent_phase/proc/determine_phase_percent(datum/reagent/reagent, temperature, pressure)

///When this current phase has a certain volume removed from it
/datum/reagent_phase/proc/transition_from(datum/reagent/reagent, amount, target_phase)

///When this current phase has a certain volume added to it
/datum/reagent_phase/proc/transition_to(datum/reagent/reagent, amount, target_phase)

//Default phase gas
/datum/reagent_phase/gas
	phase = GAS
	density = 0.5
	priority = PHASE_PRIORITY_DEFAULT
	reaction_speed_modifier = 0.2

/datum/reagent_phase/gas/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	reaction_speed_modifier = clamp(pressure/100 * 0.2, 0.1, 0.8)
	return 1

/datum/reagent_phase/gas/tick(datum/reagent/reagent, delta_time)
	dissipate(reagent, reagent.mass * delta_time)

///liquid to gas
/datum/reagent_phase/gas/transition_from(datum/reagent/reagent, amount)
	reagent.holder.adjust_specific_reagent_ph(reagent.type, )

///If we're a gas and we're in an unsealed chamber
/datum/reagent_phase/gas/proc/dissipate(datum/reagent/reagent, amount)
	if(reagent.holder.flags & SEALED) // Don't dissipate if we're sealed
		return
	amount = max((reagent.volume * reagent.get_phase_percent(phase)) - amount, 0)//Don't remove more than we have
	if(!amount)
		return
	//Move below to remove_reagent()
	//reagent.set_phase_percent(phase, reagent.volume * reagent.get_phase_percent(phase)) - amount) / (reagent.volume - amount)
	reagent.holder.remove_reagent(reagent.type, amount, phase = phase)
	reagent.check_phase_ratio()

/datum/reagent_phase/linear
	///The m (gradient/slope) aka equation of a line (y = mx+c): pressure = m * temperature + c See the readme and use the calculator
	var/gradient
	///same as m, except it the c (constant) part of y = mx+c See the readme and use the calculator
	var/constant
	///The range around the phase line where transitions are deterministic based off linear decay (See readme)
	var/range

/datum/reagent_phase/linear/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	var/required_pressure = gradient * temperature + constant
	if(pressure < required_pressure - range)
		return 0
	return  clamp(((pressure - required_pressure) / range), 0, 1)

///Default liquid
/datum/reagent_phase/linear/liquid
	phase = LIQUID
	gradient = 1
	constant = 0.03
	range = 25
	density = 1
	priority = PHASE_PRIORITY_STANDARD

///Default solid
/datum/reagent_phase/linear/solid
	phase = SOLID
	gradient = 0.12
	constant = -2.4
	range = 50
	reaction_speed_modifier = 0.35
	density = 1.5
	priority = PHASE_PRIORITY_STANDARD

///solid to powder (powder cannot become solid without turning into a liquid/gas first)
/datum/reagent_phase/linear/solid/proc/grind(datum/reagent/reagent, amount)
	if(!reagent.has_phase(phase))
		return FALSE
	reagent.set_phase_percent(POWDER, get_phase_percent(phase))
	reagent.set_phase_percent(phase, 0)
	reagent.check_phase_ratio()

///Ground powder
/datum/reagent_phase/linear/solid/powder
	phase = SOLID
	reaction_speed_modifier = 0.9
	density = 1.1
	priority = PHASE_PRIORITY_DEFAULT

/datum/reagent_phase/linear/solid/powder/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	if(reagent.phase_states[src] == 0) //Save some calculations
		return 0
	. = ..()
	return min(., reagent.phase_states[src])//So we can only remain the same, or go lower

///Plasma - called IONISED because plasma is everywhere in the codebase
/datum/reagent_phase/plasma
	phase = IONISED
	reaction_speed_modifier = 2 //Good luck!
	purity_modifier = 1.1 //If you're mad enough to try using this to speed up reactions while it's actively reversing - wow!
	density = 0.2
	priority = PHASE_PRIORITY_HIGH
	///The chemical reaction that this reagent is MADE from - i.e. we're going backwards
	var/datum/chemical_reaction/reverse_reaction

/datum/reagent_phase/plasma/tick(datum/reagent/reagent, delta_time)
	if(!reverse_reaction)
		reverse_reaction = get_chemical_reaction(reagent.type)
	reagent.holder.reverse_reaction(reverse_reaction, 0.85, delta_time)
	holder.adjust_thermal_energy(100, 0, CHEMICAL_MAXIMUM_TEMPERATURE)

/////////////The mass calculated/autofill methods/////////////////

/datum/reagent_phase/linear/liquid/mass_effect
	//These are autogenerated/work off mass and ph instead
	gradient = null
	constant = null
	range = 10

/datum/reagent_phase/linear/liquid/mass_effect/proc/generate_gradient(datum/reagent/reagent)
	return (reagent.mass ** ((reagent.ph - 7) * 0.01)) * 0.0015

/datum/reagent_phase/linear/solid/mass_effect/proc/generate_constant(datum/reagent/reagent)
	constant = -(gradient * (-80 - (reagent.mass * 0.2)))

/datum/reagent_phase/linear/solid/mass_effect
	//These are autogenerated/work off mass and ph instead
	gradient = null
	constant = null

/datum/reagent_phase/linear/solid/mass_effect/proc/generate_gradient(datum/reagent/reagent)
	return (reagent.mass ** ((reagent.ph - 7) * 0.01)) * 0.002

/datum/reagent_phase/linear/solid/mass_effect/proc/generate_constant(datum/reagent/reagent)
	constant = -(gradient * (100 + (reagent.mass / 10)))

/datum/reagent_phase/linear/liquid/mass_effect/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	//These will be overwritten everytime this is called - but that should be fine (so we have less objects about)
	gradient = generate_gradient(reagent)
	constant = generate_constant(reagent)
	..()

//Powder doesn't need this - since it can only be created by grinding
/datum/reagent_phase/linear/solid/mass_effect/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	gradient = generate_gradient(reagent)
	constant = generate_constant(reagent)
	..()

///Low weight gas mixture used in pressure calculations
/datum/pseudo_gas
	///Associative gas list
	var/list/reagent_gasses = list()

/datum/pseudo_gas/proc/convert_to_reagent(type)
	switch(type)
		if(/datum/gas/hydrogen)
			return /datum/reagent/hydrogen

		if(/datum/gas/water_vapor)
			return /datum/reagent/water

		if(/datum/gas/oxygen)
			return /datum/reagent/oxygen

		if(/datum/gas/carbon_dioxide)
			return /datum/reagent/carbondioxide

		if(/datum/gas/nitrogen)
			return /datum/reagent/nitrogen

		if(/datum/gas/nitrous_oxide)
			return /datum/reagent/nitrous_oxide

		if(/datum/gas/helium)
			return /datum/reagent/helium

		if(/datum/gas/plasma)
			return /datum/reagent/toxin/plasma

		if(/datum/gas/bz)
			return /datum/reagent/toxin/mindbreaker

		if(/datum/gas/healium)
			return /datum/reagent/healium

		if(/datum/gas/stimulum)
			return /datum/reagent/stimulum

		if(/datum/gas/nitryl)
			return /datum/reagent/nitryl

		if(/datum/gas/freon)
			return /datum/reagent/freon

		if(/datum/gas/halon)
			return /datum/reagent/halon

		if(/datum/gas/hypernoblium)
			return /datum/reagent/hypernoblium

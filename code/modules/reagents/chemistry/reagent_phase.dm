#define REAGENT_GAS_DEFAULT_SPEED 0.4

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
	///How fast this phase can transition (ratio/s) (into and from) If there's bugs it's likely this
	var/transition_speed = 0.05
	///The speed modifier of this phase
	var/reaction_speed_modifier = 1
	///The purity modifier of this phase
	var/purity_modifier = 1
	///The UI color of this phase
	var/color

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
	reaction_speed_modifier = REAGENT_GAS_DEFAULT_SPEED
	color = "#5fcffc"

/datum/reagent_phase/gas/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	reaction_speed_modifier = clamp(pressure/100 * REAGENT_GAS_DEFAULT_SPEED, 0.2, 0.9)
	return 1

/datum/reagent_phase/gas/tick(datum/reagent/reagent, delta_time)
	dissipate(reagent, reagent.mass * delta_time)

///liquid to gas
/datum/reagent_phase/gas/transition_from(datum/reagent/reagent, amount, delta_time)
	reagent.holder.adjust_specific_reagent_ph(reagent.type, )

///If we're a gas and we're in an unsealed chamber
/datum/reagent_phase/gas/proc/dissipate(datum/reagent/reagent, amount, delta_time)
	if(reagent.holder.flags & SEALED) // Don't dissipate if we're sealed
		return
	amount = max((reagent.volume * reagent.get_phase_ratio(phase)) - amount, 0)//Don't remove more than we have
	if(!amount)
		return
	//Move below to remove_reagent() FERMI_TODO
	//reagent.set_phase_percent(phase, reagent.volume * reagent.get_phase_ratio(phase)) - amount) / (reagent.volume - amount)
	reagent.diffuse(amount, delta_time)
	reagent.holder.remove_reagent(reagent.type, amount, phase = phase)
	if(reagent)
		reagent.check_phase_ratio()

/datum/reagent_phase/linear
	///The m (gradient/slope) aka equation of a line (y = mx+c): pressure = m * temperature + c See the readme and use the calculator
	var/gradient
	///same as m, except it the c (constant) part of y = mx+c See the readme and use the calculator
	var/constant
	///The range around the phase line where transitions are deterministic based off linear decay (See readme)
	var/range

/datum/reagent_phase/linear/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	var/required_pressure = (gradient * temperature) + (constant - range)
	if(pressure < required_pressure)
		return 0
	var/saturation_pressure = (gradient * temperature) + (constant + range)
	var/ratio = (pressure - required_pressure) / (saturation_pressure - required_pressure)
	return  clamp(ratio, 0, 1)

///Default liquid
/datum/reagent_phase/linear/liquid
	phase = LIQUID
	gradient = 1
	constant = 0.03
	range = 25
	density = 1
	color = "#3dbe47"

///Default solid
/datum/reagent_phase/linear/solid
	phase = SOLID
	gradient = 0.12
	constant = -2.4
	range = 50
	reaction_speed_modifier = 0.55
	density = 1.5
	color = "#e4f582"

///solid to powder (powder cannot become solid without turning into a liquid/gas first)
/datum/reagent_phase/linear/solid/proc/grind(datum/reagent/reagent, amount)
	if(!reagent.get_phase_ratio(phase))
		return FALSE
	reagent.set_phase_percent(POWDER, reagent.get_phase_ratio(phase))
	reagent.set_phase_percent(phase, 0)
	reagent.check_phase_ratio()

///Ground powder
/datum/reagent_phase/linear/solid/powder
	phase = POWDER
	reaction_speed_modifier = 0.95
	density = 1.25
	color = "#e78c4f"

/datum/reagent_phase/linear/solid/powder/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	if(reagent.phase_states[src] == 0) //Save some calculations - we can never generate powder this way
		return 0
	//Make sure we're synced with our solid phase
	var/datum/reagent_phase/linear/solid = reagent.get_phase(SOLID)
	gradient = solid.gradient
	constant = solid.constant
	. = ..()
	return min(., reagent.phase_states[src])//So we can only remain the same, or go lower

///Plasma - called IONISED because plasma is everywhere in the codebase
/datum/reagent_phase/plasma
	phase = IONISED
	reaction_speed_modifier = 2 //Good luck!
	purity_modifier = 1.1 //If you're mad enough to try using this to speed up reactions while it's actively reversing - wow!
	density = 0.2
	///The chemical reaction that this reagent is MADE from - i.e. we're going backwards
	var/datum/chemical_reaction/reverse_reaction
	color = "#dd8bfd"

//FERMI_TODO
/datum/reagent_phase/plasma/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	return 0

/* FERMI_TODO
/datum/reagent_phase/plasma/tick(datum/reagent/reagent, delta_time)
	if(!reverse_reaction)
		reverse_reaction = get_chemical_reaction(reagent.type)
	reagent.holder.reverse_reaction(reverse_reaction, 0.85, delta_time)
	holder.adjust_thermal_energy(100, 0, CHEMICAL_MAXIMUM_TEMPERATURE)
*/

/*		~~~		The mass calculated/autofill methods		~~~ 		*/
//This is messy and bad but I can't figure out a better way of doing it!

/datum/reagent_phase/linear/liquid/mass_effect
	//These are autogenerated/work off mass and ph instead
	gradient = null
	constant = null
	range = 20

/datum/reagent_phase/linear/liquid/mass_effect/proc/generate_gradient(datum/reagent/reagent)
	return (reagent.mass ** ((reagent.ph - 7) * 0.01)) * 0.15

/datum/reagent_phase/linear/liquid/mass_effect/proc/generate_constant(datum/reagent/reagent)
	return -(gradient * (-80 - (reagent.mass * 0.2)))

/datum/reagent_phase/linear/solid/mass_effect
	//These are autogenerated/work off mass and ph instead
	gradient = null
	constant = null
	range = 30

/datum/reagent_phase/linear/solid/mass_effect/proc/generate_gradient(datum/reagent/reagent)
	return (reagent.mass ** ((reagent.ph - 7) * 0.01)) * 1

/datum/reagent_phase/linear/solid/mass_effect/proc/generate_constant(datum/reagent/reagent)
	return -(gradient * (100 + (reagent.mass * 0.1)))

/datum/reagent_phase/linear/liquid/mass_effect/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	//These will be overwritten everytime this is called - but that should be fine (so we have less objects about)
	gradient = generate_gradient(reagent)
	constant = generate_constant(reagent)
	return ..()

/datum/reagent_phase/linear/solid/mass_effect/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	gradient = generate_gradient(reagent)
	constant = generate_constant(reagent)
	return ..()

//These are to create gasses at room temp
/datum/reagent_phase/linear/liquid/mass_effect/gas/generate_gradient(datum/reagent/reagent)
	return (reagent.mass ** ((reagent.ph - 7) * 0.005)) * 0.2

/datum/reagent_phase/linear/liquid/mass_effect/gas/generate_constant(datum/reagent/reagent)
	return -(gradient * (-450 - (reagent.mass * 0.2)))


/datum/reagent_phase/linear/solid/mass_effect/gas/generate_gradient(datum/reagent/reagent)
	return (reagent.mass ** ((reagent.ph - 7) * 0.01)) * 1.5

/datum/reagent_phase/linear/solid/mass_effect/gas/generate_constant(datum/reagent/reagent)
	return -(gradient * (reagent.mass * 0.1))

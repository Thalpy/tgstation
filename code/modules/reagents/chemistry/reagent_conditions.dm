
#define PHASE_PRIORITY_DEFAULT 0 //the default phase that any % will be filled in by
#define PHASE_PRIORITY_STANDARD 1 //Stuff like solid and liquids - any phases above any others
//if you need more - then either define a higher order or just increase your number
/*
* A datapacket for setting reactions/reagents/conditions for reagents on creation OR for recipes
*/

/*
 * P = mT + c
 * Temperature is T (K)
 * P is pressure (atm)
 * Both of above are dervived from holder/reagents datum
 * Highly recommended that you edit these vars from the calulator linked in the readme. It's not as complicated as you think!
 * The critical point for reagents is gamified into range - this isn't exactly true to reality (since it's past a point, rather than a range) but this should make it more dynamic and less expensive
 * consider moving this to a lookup role and having volume percent as a component instead to reduce overhead
*/
/datum/reagent_phase
	///The name or DEFINE of the phase for use with GUI/general case uses (I.e. SOLID, POWDER, LIQUID, GAS)
	var/phase
	///The percentage of said phase (from 0 to 1)
	var/volume_percent
	///The m (gradient/slope) aka equation of a line (y = mx+c): pressure = m * temperature + c See the readme and use the calculator
	var/gradient
	///same as m, except it the c (constant) part of y = mx+c See the readme and use the calculator
	var/constant
	///The range around the phase line where transitions are deterministic based off linear decay (See readme)
	var/range
	///The density of this phase
	var/density
	///The priority of the phase (for multistacking lines), higher is better
	var/prioty
	///The reagent we're a phase of
	var/datum/reagent/reagent
	///The speed modifier of this phase
	var/reaction_speed_modifier = 1
	///The purity modifier of this phase
	var/purity_modifier = 1

/datum/reagent_phase/New(_reagent)
	. = ..()
	reagent = _reagent

/datum/reagent_phase/Destroy(force, ...)
	reagent = null //Do not qdel - we're just removing this phase as a possibility.
	..()

///called for each update
/datum/reagent_phase/proc/tick(delta_time)

///Calculates how much of this current phase we should be aiming to convert into
/datum/reagent_phase/proc/determine_phase_percent(temperature, pressure)
	var/required_pressure = gradient * temperature + constant
	if(pressure < required_pressure - range)
		return 0
	return  clamp(((pressure - required_pressure) / range), 0, 1)

///Solid to liquid
/datum/reagent_phase/proc/melt(amount)

///liquid to gas
/datum/reagent_phase/proc/vaporise(amount)
	reagent.holder.adjust_specific_reagent_ph(reagent.type, )

///gas to solid
/datum/reagent_phase/proc/deposition(amount)

///solid to gas
/datum/reagent_phase/proc/sublimation(amount)

///gas to liquid
/datum/reagent_phase/proc/condensation(amount)

///liquid to solid
/datum/reagent_phase/proc/freeze(amount)

//Default gas
/datum/reagent_phase/gas
	phase = GAS
	density = 0.5
	priority = PHASE_PRIORITY_DEFAULT

/datum/reagent_phase/gas/tick(delta_time)
	dissipate(reagent.mass * delta_time)

///If we're a gas and we're in an unsealed chamber
/datum/reagent_phase/gas/proc/dissipate(amount)
	if(reagent.holder.flags & SEALED) // Don't dissipate if we're sealed
		return
	amount = max((reagent.volume * volume_percent) - amount, 0)//Don't remove more than we have
	if(!amount)
		return
	volume_percent = (reagent.volume * volume_percent) - amount) / (reagent.volume - amount)
	reagent.holder.remove_reagent(reagent.type, amount)

///Default liquid
/datum/reagent_phase/liquid
	phase = LIQUID
	gradient = 0.001
	constant = 0.03
	range = 0.1
	density = 1
	priority = PHASE_PRIORITY_STANDARD

///Default solid
/datum/reagent_phase/solid
	phase = SOLID
	gradient = 0.012
	constant = -2.4
	range = 0.2
	reaction_speed_modifier = 0.25
	density = 1.5
	priority = PHASE_PRIORITY_STANDARD

///solid to powder (powder cannot become solid without turning into a liquid/gas first)
/datum/reagent_phase/solid/proc/grind(amount)
	reagent.adjust_phase(POWDER, volume_percent)
	volume_percent = 0

///Ground powder
/datum/reagent_phase/solid/powder
	phase = POWDER
	reaction_speed_modifier = 0.9
	density = 1.1
	priority = PHASE_PRIORITY_DEFAULT

///Plasma
/datum/reagent_phase/plasma
	phase = PLASMA
	gradient
	constant
	reaction_speed_modifier = 2 //Good luck!
	range = 0.1
	purity_modifier = 1.1 //If you're mad enough to try using this to speed up reactions while it's actively reversing - wow!
	density = 0.2
	///The chemical reaction that this reagent is MADE from - i.e. we're going backwards
	var/datum/chemical_reaction/reverse_reaction

/datum/reagent_phase/plasma/tick(delta_time)
	if(!reverse_reaction)
		reverse_reaction = get_chemical_reaction(reagent.type)
	reagent.holder.reverse_reaction(reverse_reaction, 0.85, delta_time)
	holder.adjust_thermal_energy(heat_energy, 0, CHEMICAL_MAXIMUM_TEMPERATURE)

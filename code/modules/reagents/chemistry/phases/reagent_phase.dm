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
	///The calculation type for determining the phase - default is linear
	var/datum/phase_calc/calculation_method = /datum/phase_calc/linear/mass_effect

/datum/reagent_phase/New()
	. = ..()
	if(calculation_method)
		calculation_method = new calculation_method(phase)

///called for each update that this phase has a volume presence
/datum/reagent_phase/proc/tick(datum/reagent/reagent, delta_time)

///When this current phase has a certain volume removed from it
/datum/reagent_phase/proc/transition_from(datum/reagent/reagent, amount, target_phase)

///When this current phase has a certain volume added to it
/datum/reagent_phase/proc/transition_to(datum/reagent/reagent, amount, target_phase)

///Calculates how much of this current phase we should be aiming to convert into
/datum/reagent_phase/proc/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	return calculation_method.determine_phase_percent(reagent, temperature, pressure)

///Used to calculate the GUI phase graph output of the phases x value
/datum/reagent_phase/proc/get_graph_coords(datum/reagent/reagent)
	var/list/profile = list()
	profile = calculation_method.get_graph_coords(reagent)
	profile["color"] = color
	return profile

//Default phase gas
/datum/reagent_phase/gas
	phase = GAS
	density = 0.5
	reaction_speed_modifier = REAGENT_GAS_DEFAULT_SPEED
	color = "#5fcffc"
	calculation_method = null //This is the default so we want to know if we're accidentally calculating

/datum/reagent_phase/gas/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	reaction_speed_modifier = clamp(pressure/100 * REAGENT_GAS_DEFAULT_SPEED, 0.2, 0.9)
	return 1

//FERMI_TODO - return full size
/datum/reagent_phase/gas/get_graph_coords(datum/reagent/reagent)
	return

/datum/reagent_phase/gas/tick(datum/reagent/reagent, delta_time)
	return dissipate(reagent, reagent.get_phase_volume(GAS) * STANDARD_REAGENT_DIFFUSE_RATE * delta_time, delta_time)

///liquid to gas
/datum/reagent_phase/gas/transition_from(datum/reagent/reagent, amount, delta_time)
	reagent.holder.adjust_specific_reagent_ph(reagent.type, )
	SEND_SIGNAL(src, COMSIG_PHASE_CHANGE_FROM_GAS, amount)

/datum/reagent_phase/gas/transition_to(datum/reagent/reagent, amount)
	SEND_SIGNAL(src, COMSIG_PHASE_CHANGE_TO_GAS, amount)

///If we're a gas and we're in an unsealed chamber
/datum/reagent_phase/gas/proc/dissipate(datum/reagent/reagent, amount)
	if(reagent.holder.flags & SEALED) // Don't dissipate if we're sealed
		return FALSE
	//amount = max(reagent.get_phase_volume(GAS) - amount, 0)//Don't remove more than we have - probably doesn't work, move this to remove_reagent
	amount = max(amount, STANDARD_REAGENT_DIFFUSE_RATE)
	//Move below to remove_reagent() FERMI_TODO
	//reagent.set_phase_percent(phase, reagent.volume * reagent.get_phase_ratio(phase)) - amount) / (reagent.volume - amount)
	reagent.diffuse(amount)
	if(reagent)
		reagent.check_phase_ratio()
	return TRUE


///Default liquid
/datum/reagent_phase/liquid
	phase = LIQUID
	density = 1
	color = "#3dbe47"
	calculation_method = /datum/phase_calc/linear/mass_effect/liquid

///Default solid
/datum/reagent_phase/solid
	phase = SOLID
	reaction_speed_modifier = 0.55
	density = 1.5
	color = "#e4f582"
	calculation_method = /datum/phase_calc/linear/mass_effect/solid

///solid to powder (powder cannot become solid without turning into a liquid/gas first)
/datum/reagent_phase/solid/proc/grind(datum/reagent/reagent, amount)
	if(!reagent.get_phase_ratio(phase))
		return FALSE
	reagent.set_phase_percent(POWDER, reagent.get_phase_ratio(phase))
	reagent.set_phase_percent(phase, 0)
	reagent.check_phase_ratio()

///Ground powder
/datum/reagent_phase/solid/powder
	phase = POWDER
	reaction_speed_modifier = 0.95
	density = 1.25
	color = "#e78c4f"
	calculation_method = null //uses solid - we want this to crash if it tries to calculate otherwise

/datum/reagent_phase/solid/powder/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	if(reagent.phase_states[src] == 0) //Save some calculations - we can never generate powder this way
		return 0
	//Make sure we're synced with our solid phase
	var/datum/reagent_phase/solid = reagent.get_phase(SOLID)
	. = solid.determine_phase_percent(reagent, temperature, pressure)
	//calculation_method.gradient = solid.calculation_method.gradient
	//calculation_method.constant = solid.calculation_method.constant
	return min(., reagent.phase_states[src])//So we can only remain the same, or go lower

///We don't want this to appear on our graph
/datum/reagent_phase/solid/powder/get_graph_coords()
	return null

///Plasma - called IONISED because plasma is everywhere in the codebase
/datum/reagent_phase/plasma
	phase = IONISED
	reaction_speed_modifier = 2 //Good luck!
	purity_modifier = 1.1 //If you're mad enough to try using this to speed up reactions while it's actively reversing - wow!
	density = 0.2
	///The chemical reaction that this reagent is MADE from - i.e. we're going backwards
	var/datum/chemical_reaction/reverse_reaction
	color = "#dd8bfd"
	calculation_method = null //Not in yet

//FERMI_TODO
/datum/reagent_phase/plasma/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	return 0

/datum/reagent_phase/plasma/get_graph_coords(datum/reagent/reagent)
	return

/* FERMI_TODO
/datum/reagent_phase/plasma/tick(datum/reagent/reagent, delta_time)
	if(!reverse_reaction)
		reverse_reaction = get_chemical_reaction(reagent.type)
	reagent.holder.reverse_reaction(reverse_reaction, 0.85, delta_time)
	holder.adjust_thermal_energy(100, 0, CHEMICAL_MAXIMUM_TEMPERATURE)
*/

/*		~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~		 /
		~~~~	    Phase calcs		 ~~~~
/		~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~		*/


/datum/phase_calc/proc/determine_phase_percent(datum/reagent/reagent, temperature, pressure)

/datum/phase_calc/proc/get_graph_coords(datum/reagent/reagent)

/*		~~~~		Linear			 ~~~~		*/

/datum/phase_calc/linear
	///The m (gradient/slope) aka equation of a line (y = mx+c): pressure = m * temperature + c See the readme and use the calculator
	var/gradient
	///same as m, except it the c (constant) part of y = mx+c See the readme and use the calculator
	var/constant
	///The range around the phase line where transitions are deterministic based off linear decay (See readme)
	var/range = 25

/datum/phase_calc/linear/New(_gradient, _constant)
	. = ..()
	gradient = _gradient
	constant = _constant

/datum/phase_calc/linear/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	//The min required pressure
	var/required_pressure
	if(!range) //if we have no range - then it's a true/false check
		required_pressure = (gradient * temperature) + constant
		if(pressure < required_pressure)
			return 0
		return 1
	//Otherwise we check our ranges
	required_pressure = (gradient * temperature) + (constant - range)
	if(pressure < required_pressure)
		return 0
	var/saturation_pressure = (gradient * temperature) + (constant + range)
	var/ratio = (pressure - required_pressure) / (saturation_pressure - required_pressure)
	return  clamp(ratio, 0, 1)

/datum/phase_calc/linear/get_graph_coords(datum/reagent/reagent)
	var/x1 = -(constant+range)/gradient
	var/y1 = 0
	if(x1 < 0)
		x1 = 0
		y1 = gradient + constant + range
	var/x2 = 1100
	var/y2 = (gradient * 1100) + constant + range
	if(y2 > 600)
		x2 = (600-(constant + range))/gradient
		y2 = 600
	return list("x1" = x1, "x2" = x2, "y1" = y1, "y2" = y2, "range" = range*2, "type" = "linear")

///A big if else check square
/datum/phase_calc/square
	///Bottom left coords - x is temp, y is pressure in whole values
	var/x1
	var/y1
	///Top right coords
	var/x2
	var/y2
	///The area around the box
	var/range = 15

/datum/phase_calc/square/get_graph_coords(datum/reagent/reagent)
	return list("x1" = x1, "x2" = x2, "y1" = y1, "y2" = y2, "range" = range, "type" = "square")

/datum/phase_calc/square/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	if(temperature > x1 && temperature < x2)
		if(pressure > y1 && pressure < y2)
			return 1

/*		~~~		The mass calculated/autofill method 		~~~ 		*/

/datum/phase_calc/linear/mass_effect
	//!!! Vars are autogenerated/work off mass and ph instead - overwriting the previous type !!!
	//The factors are fudge numbers I made up and have no realistic basis - check the mapping tool to make sense of them
	///The factor a for gradient
	var/g_factor_a
	///The factor b for gradient
	var/g_factor_b
	///The factor a for constant
	var/c_factor_a
	///The factor b for constant
	var/c_factor_b

/datum/phase_calc/linear/mass_effect/proc/generate_gradient(datum/reagent/reagent)
	return (reagent.mass ** ((reagent.ph - 7) * g_factor_a)) * g_factor_b

/datum/phase_calc/linear/mass_effect/proc/generate_constant(datum/reagent/reagent)
	return -(gradient * (c_factor_a - (reagent.mass * c_factor_b)))

/datum/phase_calc/linear/mass_effect/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	gradient = generate_gradient(reagent)
	constant = generate_constant(reagent)
	return ..()

/datum/phase_calc/linear/mass_effect/get_graph_coords(datum/reagent/reagent)
	gradient = generate_gradient(reagent)
	constant = generate_constant(reagent)
	return ..()

//These are the types of modifiers used for different profiles
/datum/phase_calc/linear/mass_effect/solid
	g_factor_a = 0.01
	g_factor_b = 1
	c_factor_a = 100
	c_factor_b = 0.1
	range = 30

/datum/phase_calc/linear/mass_effect/liquid
	g_factor_a = 0.01
	g_factor_b = 0.15
	c_factor_a = -80
	c_factor_b = 0.2
	range = 20




		/* - this is the liquid setting for a forced
		if(GAS)
			g_factor_a = 0.005
			g_factor_b = 0.2
			c_factor_a = -450
			c_factor_b = 0.2
		*/

/*
/datum/reagent_phase/solid/mass_effect
	//These are autogenerated/work off mass and ph instead
	gradient = null
	constant = null
	range = 30

/datum/reagent_phase/solid/mass_effect/proc/generate_gradient(datum/reagent/reagent)
	return (reagent.mass ** ((reagent.ph - 7) * 0.01)) * 1

/datum/reagent_phase/solid/mass_effect/proc/generate_constant(datum/reagent/reagent)
	return -(gradient * (100 + (reagent.mass * 0.1)))

/datum/phase_calc/linear/mass_effect/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	//These will be overwritten everytime this is called - but that should be fine (so we have less objects about)
	gradient = generate_gradient(reagent)
	constant = generate_constant(reagent)
	return ..()

/datum/phase_calc/linear/mass_effect/get_graph_coords(datum/reagent/reagent)
	gradient = generate_gradient(reagent)
	constant = generate_constant(reagent)
	return ..()

/datum/reagent_phase/solid/mass_effect/determine_phase_percent(datum/reagent/reagent, temperature, pressure)
	gradient = generate_gradient(reagent)
	constant = generate_constant(reagent)
	return ..()

/datum/reagent_phase/solid/mass_effect/get_graph_coords(datum/reagent/reagent)
	gradient = generate_gradient(reagent)
	constant = generate_constant(reagent)
	return ..()

//These are to create gasses at room temp
/datum/phase_calc/linear/mass_effect/gas/generate_gradient(datum/reagent/reagent)
	return (reagent.mass ** ((reagent.ph - 7) * 0.005)) * 0.2

/datum/phase_calc/linear/mass_effect/gas/generate_constant(datum/reagent/reagent)
	return -(gradient * (-450 - (reagent.mass * 0.2)))


/datum/reagent_phase/solid/mass_effect/gas/generate_gradient(datum/reagent/reagent)
	return (reagent.mass ** ((reagent.ph - 7) * 0.01)) * 1.5

/datum/reagent_phase/solid/mass_effect/gas/generate_constant(datum/reagent/reagent)
	return -(gradient * (reagent.mass * 0.1))
*/

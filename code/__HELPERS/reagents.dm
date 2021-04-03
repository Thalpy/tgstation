/proc/chem_recipes_do_conflict(datum/chemical_reaction/r1, datum/chemical_reaction/r2)
	//We have to check to see if either is competitive so can ignore it (competitive reagents are supposed to conflict)
	if((r1.reaction_flags & REACTION_COMPETITIVE) || (r2.reaction_flags & REACTION_COMPETITIVE))
		return FALSE

	//do the non-list tests first, because they are cheaper
	if(r1.required_container != r2.required_container)
		return FALSE
	if(r1.is_cold_recipe == r2.is_cold_recipe)
		if(r1.required_temp != r2.required_temp)
			//one reaction requires a more extreme temperature than the other, so there is no conflict
			return FALSE
	else
		var/datum/chemical_reaction/cold_one = r1.is_cold_recipe ? r1 : r2
		var/datum/chemical_reaction/warm_one = r1.is_cold_recipe ? r2 : r1
		if(cold_one.required_temp < warm_one.required_temp)
			//the range of temperatures does not overlap, so there is no conflict
			return FALSE

	//find the reactions with the shorter and longer required_reagents list
	var/datum/chemical_reaction/long_req
	var/datum/chemical_reaction/short_req
	if(r1.required_reagents.len > r2.required_reagents.len)
		long_req = r1
		short_req = r2
	else if(r1.required_reagents.len < r2.required_reagents.len)
		long_req = r2
		short_req = r1
	else
		//if they are the same length, sort instead by the length of the catalyst list
		//this is important if the required_reagents lists are the same
		if(r1.required_catalysts.len > r2.required_catalysts.len)
			long_req = r1
			short_req = r2
		else
			long_req = r2
			short_req = r1


	//check if the shorter reaction list is a subset of the longer one
	var/list/overlap = r1.required_reagents & r2.required_reagents
	if(overlap.len != short_req.required_reagents.len)
		//there is at least one reagent in the short list that is not in the long list, so there is no conflict
		return FALSE

	//check to see if the shorter reaction's catalyst list is also a subset of the longer reaction's catalyst list
	//if the longer reaction's catalyst list is a subset of the shorter ones, that is fine
	//if the reaction lists are the same, the short reaction will have the shorter required_catalysts list, so it will register as a conflict
	var/list/short_minus_long_catalysts = short_req.required_catalysts - long_req.required_catalysts
	if(short_minus_long_catalysts.len)
		//there is at least one unique catalyst for the short reaction, so there is no conflict
		return FALSE

	//if we got this far, the longer reaction will be impossible to create if the shorter one is earlier in GLOB.chemical_reactions_list, and will require the reagents to be added in a particular order otherwise
	return TRUE

/proc/get_chemical_reaction(id)
	if(!GLOB.chemical_reactions_list)
		return
	for(var/reagent in GLOB.chemical_reactions_list)
		for(var/R in GLOB.chemical_reactions_list[reagent])
			var/datum/reac = R
			if(reac.type == id)
				return R

/proc/remove_chemical_reaction(datum/chemical_reaction/R)
	if(!GLOB.chemical_reactions_list || !R)
		return
	for(var/rid in R.required_reagents)
		GLOB.chemical_reactions_list[rid] -= R

//see build_chemical_reactions_list in holder.dm for explanations
/proc/add_chemical_reaction(datum/chemical_reaction/R)
	if(!GLOB.chemical_reactions_list || !R.required_reagents || !R.required_reagents.len)
		return
	var/primary_reagent = R.required_reagents[1]
	if(!GLOB.chemical_reactions_list[primary_reagent])
		GLOB.chemical_reactions_list[primary_reagent] = list()
	GLOB.chemical_reactions_list[primary_reagent] += R

//Creates foam from the reagent. Metaltype is for metal foam, notification is what to show people in textbox
/datum/reagents/proc/create_foam(foamtype,foam_volume,metaltype = 0,notification = null)
	var/location = get_turf(my_atom)
	var/datum/effect_system/foam_spread/foam = new foamtype()
	foam.set_up(foam_volume, location, src, metaltype)
	foam.start()
	clear_reagents()
	if(!notification)
		return
	for(var/mob/M in viewers(5, location))
		to_chat(M, notification)

///Converts the pH into a tgui readable color - i.e. white and black text is readable over it. This is NOT the colourwheel for pHes however.
/proc/convert_ph_to_readable_color(pH)
	switch(pH)
		if(-INFINITY to 1)
			return "red"
		if(1 to 2)
			return "orange"
		if(2 to 3)
			return "average"
		if(3 to 4)
			return "yellow"
		if(4 to 5)
			return "olive"
		if(5 to 6)
			return "good"
		if(6 to 8)
			return "green"
		if(8 to 9.5)
			return "teal"
		if(9.5 to 11)
			return "blue"
		if(11 to 12.5)
			return "violet"
		if(12.5 to INFINITY)
			return "purple"

///Converts pH to universal indicator colours. This is the colorwheel for pHes
#define CONVERT_PH_TO_COLOR(pH, color) \
	switch(pH) {\
		if(14 to INFINITY)\
			{ color = "#462c83" }\
		if(13 to 14)\
			{ color = "#63459b" }\
		if(12 to 13)\
			{ color = "#5a51a2" }\
		if(11 to 12)\
			{ color = "#3853a4" }\
		if(10 to 11)\
			{ color = "#3f93cf" }\
		if(9 to 10)\
			{ color = "#0bb9b7" }\
		if(8 to 9)\
			{ color = "#23b36e" }\
		if(7 to 8)\
			{ color = "#3aa651" }\
		if(6 to 7)\
			{ color = "#4cb849" }\
		if(5 to 6)\
			{ color = "#b5d335" }\
		if(4 to 5)\
			{ color = "#f7ec1e" }\
		if(3 to 4)\
			{ color = "#fbc314" }\
		if(2 to 3)\
			{ color = "#f26724" }\
		if(1 to 2)\
			{ color = "#ef1d26" }\
		if(-INFINITY to 1)\
			{ color = "#c6040c" }\
		}

///Returns a list of chemical_reaction datums that have the input STRING as a product
/proc/get_reagent_type_from_product_string(string)
	var/input_reagent = replacetext(lowertext(string), " ", "") //95% of the time, the reagent id is a lowercase/no spaces version of the name
	if (isnull(input_reagent))
		return

	var/list/shortcuts = list("meth" = /datum/reagent/drug/methamphetamine)
	if(shortcuts[input_reagent])
		input_reagent = shortcuts[input_reagent]
	else
		input_reagent = find_reagent(input_reagent)
	return input_reagent

///Returns reagent datum from typepath
/proc/find_reagent(input)
	. = FALSE
	if(GLOB.chemical_reagents_list[input]) //prefer IDs!
		return input
	else
		return get_chem_id(input)

/proc/find_reagent_object_from_type(input)
	if(GLOB.chemical_reagents_list[input]) //prefer IDs!
		return GLOB.chemical_reagents_list[input]
	else
		return null

///Returns a random reagent object minus blacklisted reagents
/proc/get_random_reagent_id()
	var/static/list/random_reagents = list()
	if(!random_reagents.len)
		for(var/thing in subtypesof(/datum/reagent))
			var/datum/reagent/R = thing
			if(initial(R.chemical_flags) & REAGENT_CAN_BE_SYNTHESIZED)
				random_reagents += R
	var/picked_reagent = pick(random_reagents)
	return picked_reagent

///Returns reagent datum from reagent name string
/proc/get_chem_id(chem_name)
	for(var/X in GLOB.chemical_reagents_list)
		var/datum/reagent/R = GLOB.chemical_reagents_list[X]
		if(ckey(chem_name) == ckey(lowertext(R.name)))
			return X

///Takes a type in and returns a list of associated recipes
/proc/get_recipe_from_reagent_product(input_type)
	if(!input_type)
		return
	var/list/matching_reactions = GLOB.chemical_reactions_list_product_index[input_type]
	return matching_reactions

/proc/reagent_paths_list_to_text(list/reagents, addendum)
	var/list/temp = list()
	for(var/datum/reagent/R as anything in reagents)
		temp |= initial(R.name)
	if(addendum)
		temp += addendum
	return jointext(temp, ", ")

// 		~~		Physical phase related procs		~~

/**
 * Creates a new mist (gas phase physical state) from a reagent
 * If there is already a mist on the tile it'll merge with it
 * If there's a nearby mist, it'll join it's controller
 * If there's nothing nearby, it creates a new controller and mist
 *
 * arguments:
 * * reagent - the reagent that we're making the mist of
 * * amount - the volume of said reagent we're adding to
 * * source_turf - the location we're creating the mist in
 */
/proc/create_mist(datum/reagent/reagent, amount, turf/source_turf)
	var/obj/phase_object/mist/misty = locate() in source_turf
	if(!misty)
		//If there's no mist on our target turf - we want to join to an existing mist if it exists.
		for(var/turf/nearby_turf in source_turf.GetAtmosAdjacentTurfs())
			var/obj/phase_object/mist/misty_lass = locate() in nearby_turf
			if(misty_lass)
				if(QDELETED(misty_lass.phase_controller))
					continue
				new /obj/phase_object/mist(source_turf, misty_lass.phase_controller.center_holder, misty_lass.phase_controller)
				misty_lass.phase_controller.center_holder.add_reagent(reagent.type, amount, reagtemp = reagent.holder.chem_temp, added_purity = reagent.purity, added_ph = reagent.ph)
				return
		//If we're truly alone, create a new one
		new /datum/physical_phase/gas_phase(reagent, amount, reagent.holder.my_atom, source_turf)
		reagent.holder.remove_reagent(reagent.type, amount, phase = GAS)
		return
	//Edge case - we don't want deleting things to be rejuvinated
	if(QDELETED(misty.phase_controller))
		return
	misty.phase_controller.center_holder.add_reagent(reagent.type, amount, reagtemp = reagent.holder.chem_temp, added_purity = reagent.purity, added_ph = reagent.ph)
	reagent.holder.remove_reagent(reagent.type, amount, phase = GAS)

/**
 * Creates a new liquid (liquid phase physical state) from a reagent
 * If there is already a liquid on the tile it'll merge with it
 * If there's a nearby liquid, it'll join it's controller
 * If there's nothing nearby, it creates a new controller and liquid
 *
 * arguments:
 * * reagent - the reagent that we're making the liquid of
 * * amount - the volume of said reagent we're adding to
 * * source_turf - the location we're creating the liquid in
 */
/proc/create_liquid(datum/reagent/reagent, amount, turf/source_turf)
	var/obj/phase_object/liquid/moist = locate() in source_turf
	if(!moist)
		//If there's no liquid on our target turf - we want to join to an existing liquid if it exists.
		for(var/turf/nearby_turf in source_turf.GetAtmosAdjacentTurfs())
			var/obj/phase_object/liquid/moist_lass = locate() in nearby_turf
			if(moist_lass)
				if(QDELETED(moist_lass.phase_controller))
					continue
				new /obj/phase_object/liquid(source_turf, moist_lass.phase_controller.center_holder, moist_lass.phase_controller)
				moist_lass.phase_controller.center_holder.add_reagent(reagent.type, amount, reagtemp = reagent.holder.chem_temp, added_purity = reagent.purity, added_ph = reagent.ph)
				return
		//If we're truly alone, create a new one
		new /datum/physical_phase/gas_phase(reagent, amount, reagent.holder.my_atom, source_turf)
		reagent.holder.remove_reagent(reagent.type, amount, phase = LIQUID)
		return
	//Edge case - we don't want deleting things to be rejuvinated
	if(QDELETED(moist.phase_controller))
		return
	moist.phase_controller.center_holder.add_reagent(reagent.type, amount, reagtemp = reagent.holder.chem_temp, added_purity = reagent.purity, added_ph = reagent.ph)
	reagent.holder.remove_reagent(reagent.type, amount, phase = LIQUID)

/**
 * Creates a new crystal (solid phase physical state) from a reagent
 * If there is already a crystal on the tile it'll merge with it
 * If the crytal is full it'll create a new one
 * If there's no crystal it'll make a new one
 *
 * arguments:
 * * reagent - the reagent that we're making the crystal of
 * * amount - the volume of said reagent we're adding to
 * * source_turf - the location we're creating the crystal in
 */
/proc/create_solid(datum/reagent/reagent, amount, turf/source_turf)
	for(var/obj/item/stack/solid_phase_object/solid/crystal in source_turf)
		if(crystal.reagents.total_volume > SOLID_PHYSICAL_PHASE_CAPACITY)
			continue
		var/crystal_capacity = SOLID_PHYSICAL_PHASE_CAPACITY - crystal.reagents.total_volume
		var/trans_amount = min(amount, crystal_capacity)
		crystal.reagents.add_reagent(reagent.type, trans_amount, reagtemp = reagent.holder.chem_temp, added_purity = reagent.purity, added_ph = reagent.ph)
		reagent.holder.remove_reagent(reagent.type, amount, phase = SOLID)
		amount -= trans_amount
		if(amount <= 0)
			return
	///Should only occur if all crystals are full, or there are none.
	while(amount > 0)
		var/obj/item/stack/solid_phase_object/solid/reagent_stack = new /obj/item/stack/solid_phase_object/solid(source_turf, amount/5)
		reagent_stack.set_reagent(reagent, min(amount, 250))
		amount -= 250
		reagent.holder.remove_reagent(reagent.type, 250, phase = SOLID)

/**
 * Creates a new powder (powder phase physical state) from a reagent
 * If there is already a powder on the tile it'll merge with it
 * If the crytal is full it'll create a new one
 * If there's no powder it'll make a new one
 *
 * arguments:
 * * reagent - the reagent that we're making the powder of
 * * amount - the volume of said reagent we're adding to
 * * source_turf - the location we're creating the powder in
 */
/proc/create_powder(datum/reagent/reagent, amount, turf/source_turf)
	for(var/obj/item/stack/solid_phase_object/powder/powdery in source_turf)
		if(powdery.reagents.total_volume > SOLID_PHYSICAL_PHASE_CAPACITY)
			continue
		var/powdery_capacity = SOLID_PHYSICAL_PHASE_CAPACITY - powdery.reagents.total_volume
		var/trans_amount = min(amount, powdery_capacity)
		powdery.reagents.add_reagent(reagent.type, trans_amount, reagtemp = reagent.holder.chem_temp, added_purity = reagent.purity, added_ph = reagent.ph)
		reagent.holder.remove_reagent(reagent.type, amount, phase = POWDER)
		amount -= trans_amount
		if(amount <= 0)
			return
	///Should only occur if all crystals are full, or there are none.
	while(amount > 0)
		var/obj/item/stack/solid_phase_object/powder/reagent_stack = new /obj/item/stack/solid_phase_object/powder(source_turf, amount/5)
		reagent_stack.set_reagent(reagent, min(amount, 250))
		amount -= 250
		reagent.holder.remove_reagent(reagent.type, 250, phase = POWDER)


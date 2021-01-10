/obj/machinery/chem_recipe_debug
	name = "chemical reaction tester"
	density = TRUE
	icon = 'icons/obj/chemical.dmi'
	icon_state = "HPLC"
	use_power = IDLE_POWER_USE
	idle_power_usage = 40
	resistance_flags = FIRE_PROOF | ACID_PROOF | INDESTRUCTIBLE
	var/list/cached_reactions = list()
	var/index = 1
	var/processing = FALSE
	var/problem_string


/obj/machinery/chem_recipe_debug/Initialize()
	.=..()
	create_reagents(500)

/obj/machinery/chem_recipe_debug/attackby(obj/item/I, mob/user, params)
	.=..()
	if(processing)
		say("currently processing reaction [index]: [cached_reactions[index]] of [cached_reactions.len]")
		return
	say("Starting processing")
	setup_reactions()
	begin_processing()

/obj/machinery/chem_recipe_debug/AltClick(mob/living/user)
	. = ..()
	if(processing)
		say("currently processing reaction [index]: [cached_reactions[index]] of [cached_reactions.len]")
		return
	say("Starting processing")
	setup_reactions()
	begin_processing()

/obj/machinery/chem_recipe_debug/proc/setup_reactions()
	cached_reactions = list()
	for(var/V in GLOB.chemical_reactions_list)
		if(is_type_in_list(GLOB.chemical_reactions_list[V], cached_reactions))
			continue
		cached_reactions += GLOB.chemical_reactions_list[V]
	reagents.clear_reagents()
	index = 1
	processing = TRUE

/obj/machinery/chem_recipe_debug/process(delta_time)
	if(processing == FALSE)
		setup_reactions()
	if(reagents.isReacting == TRUE)
		return
	if(index >= cached_reactions.len)
		say("Completed testing, problem reactions are:")
		say("[problem_string]")
		processing = FALSE
		end_processing()
	if(reagents.reagent_list)
		say("Reaction completed for [cached_reactions[index]] final temperature = [reagents.chem_temp], pH = [reagents.pH].")
		var/datum/chemical_reaction/C = cached_reactions[index]
		for(var/R in C.results)
			var/datum/reagent/R2 =  reagents.get_reagent(R)
			if(!R2)
				say("<span class='warning'>Unable to find product [R] in holder after reaction! reagents found are:</span>")
				for(var/R3 in reagents.reagent_list)
					say("[R3]")
				problem_string += "<span class='warning'>Unable to find product [R] in holder after reaction! index:[index]</span>\n"
				continue
			say("Reaction has a product [R] [R2.volume]u purity of [R2.purity]")
			if(R2.purity < 0.9)
				problem_string += "Reaction has a product [R] [R2.volume]u <span class='boldwarning'>purity of [R2.purity]</span> index:[index]\n"
			else if (R2.purity < 1)
				problem_string += "Reaction has a product [R] [R2.volume]u <span class='warning'>purity of [R2.purity]</span> index:[index]\n"
			if(R2.volume < C.results[R])
				problem_string += "Reaction has a product [R] <span class='warning'>[R2.volume]u</span> purity of [R2.purity] index:[index]\n"
		reagents.clear_reagents()
		index++
	var/datum/chemical_reaction/C = cached_reactions[index]
	if(!C)
		say("Unable to find reaction on index: [index]")
	for(var/R in C.required_reagents)
		reagents.add_reagent(R, C.required_reagents[R]*20)
	reagents.chem_temp = C.optimal_temp
	say("Reacting <span class='nicegreen'>[cached_reactions[index]]</span> starting pH: [reagents.pH] index [index] of [cached_reactions.len]")
	if(C.reactionFlags & REACTION_INSTANT)
		say("This reaction is instant")


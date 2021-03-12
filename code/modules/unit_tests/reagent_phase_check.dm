///Checks ALL reagents in game to see if they have an assigned phase profile
/datum/unit_test/reagent_phase_check/Run()
	build_chemical_reactions_lists()
	build_chemical_reagent_list()
	for(var/reagent_path in GLOB.chemical_reagents_list)
		var/datum/reagent/reagent = GLOB.chemical_reagents_list[reagent_path]
		if(!reagent.mass)
			Fail("[reagent.type] is missing a mass.")

	calculate_phase_profiles()

///Checks ALL reagents in game to see if they have an assigned phase profile
/datum/unit_test/reagent_phase_check/Run()
	build_chemical_reactions_lists()
	build_chemical_reagent_list()
	build_reagent_phase_list()
	build_phase_profiles()
	for(var/reagent_path in GLOB.chemical_reagents_list)
		var/datum/reagent/reagent = GLOB.chemical_reagents_list[reagent_path]
		if(!reagent.mass)
			Fail("[reagent.type] is missing a mass.")
		var/pass = FALSE
		for(var/datum/reagent_phase/phase in reagent.phase_states)
			pass += phase.determine_phase_percent(src, 300, 1)
		if(!pass)
			Fail("[reagent.type] failed phase testing - no valid phase for 300K at 101kPa!")

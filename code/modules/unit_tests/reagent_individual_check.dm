///Checks ALL reagents in game to see if they have sensible numbers and inputs
/datum/unit_test/reagent_individual_check/Run()
	build_chemical_reactions_lists()
	build_chemical_reagent_list()
	build_reagent_phase_list()
	build_phase_profiles()
	for(var/reagent_path in GLOB.chemical_reagents_list)
		var/datum/reagent/reagent = GLOB.chemical_reagents_list[reagent_path]
		var/list/fail_message = reagent.unit_test()
		if(fail_message)
			fail_message.Join(" AND ")
			Fail(fail_message)

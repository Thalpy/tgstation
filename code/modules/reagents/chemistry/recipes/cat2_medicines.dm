
/*****BRUTE*****/
//oops no theme

/datum/chemical_reaction/medicine/helbital
	results = list(/datum/reagent/medicine/c2/helbital = 3)
	required_reagents = list(/datum/reagent/consumable/sugar = 1, /datum/reagent/fluorine = 1, /datum/reagent/carbon = 1)
	mix_message = "The mixture turns into a thick, yellow powder."
	//FermiChem vars:
	required_temp = 250
	optimal_temp = 1000
	overheat_temp = 550
	optimal_ph_min = 5
	optimal_ph_max = 9.5
	determin_ph_range = 4
	temp_exponent_factor = 1
	ph_exponent_factor = 4
	thermic_constant = 100
	H_ion_release = 4
	rate_up_lim = 55
	purity_min = 0.55
	reaction_flags = REACTION_PH_VOL_CONSTANT
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_HEALING | REACTION_TAG_BRUTE

/datum/chemical_reaction/medicine/helbital/overly_impure(datum/reagents/holder, datum/equilibrium/equilibrium)
	explode_fire_vortex(holder, equilibrium, 1, 1)
	holder.chem_temp += 2.5
	var/datum/reagent/helbital = holder.get_reagent(/datum/reagent/medicine/c2/helbital)
	if(!helbital)
		return
	if(helbital.purity <= 0.25)
		if(prob(25))
			new /obj/effect/hotspot(holder.my_atom.loc)
			holder.remove_reagent(/datum/reagent/medicine/c2/helbital, 2)
			holder.chem_temp += 5
			holder.my_atom.audible_message("<span class='notice'>[icon2html(holder.my_atom, viewers(DEFAULT_MESSAGE_RANGE, src))] The impurity of the reacting helbital is too great causing the [src] to let out a hearty burst of flame, evaporating part of the product!</span>")

/datum/chemical_reaction/medicine/helbital/overheated(datum/reagents/holder, datum/equilibrium/equilibrium)
	. = ..()//drains product
	explode_fire_vortex(holder, equilibrium, 2, 2, "overheat", TRUE)

/datum/chemical_reaction/medicine/helbital/reaction_finish(datum/reagents/holder, react_vol)
	. = ..()
	var/datum/reagent/helbital = holder.get_reagent(/datum/reagent/medicine/c2/helbital)
	if(!helbital)
		return
	if(helbital.purity <= 0.1) //So people don't ezmode this by keeping it at min
		explode_fire(holder, null, 3)
		clear_products(holder)

/datum/chemical_reaction/medicine/libital
	results = list(/datum/reagent/medicine/c2/libital = 3)
	required_reagents = list(/datum/reagent/phenol = 1, /datum/reagent/oxygen = 1, /datum/reagent/nitrogen = 1)
	required_temp = 225
	optimal_temp = 700
	overheat_temp = 840
	optimal_ph_min = 6
	optimal_ph_max = 10
	determin_ph_range = 4
	temp_exponent_factor = 1.75
	ph_exponent_factor = 1
	thermic_constant = 75
	H_ion_release = -6.5
	rate_up_lim = 40
	purity_min = 0.2
	reaction_flags = REACTION_PH_VOL_CONSTANT
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_HEALING | REACTION_TAG_BRUTE

/datum/chemical_reaction/medicine/probital
	results = list(/datum/reagent/medicine/c2/probital = 4)
	required_reagents = list(/datum/reagent/copper = 1, /datum/reagent/acetone = 2,  /datum/reagent/phosphorus = 1)
	required_temp = 225
	optimal_temp = 700
	overheat_temp = 750
	optimal_ph_min = 4.5
	optimal_ph_max = 12
	determin_ph_range = 2
	temp_exponent_factor = 0.75
	ph_exponent_factor = 4
	thermic_constant = 50
	H_ion_release = -2.5
	rate_up_lim = 30
	purity_min = 0.35//15% window
	reaction_flags = REACTION_CLEAR_INVERSE | REACTION_PH_VOL_CONSTANT
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_HEALING | REACTION_TAG_BRUTE

/*****BURN*****/
//These are all endothermic!

//This is a relatively simple demonstration have splitting negatives/having purity based negatives
//Since it requires silver - I don't want to make it too hard
/datum/chemical_reaction/medicine/lenturi
	results = list(/datum/reagent/medicine/c2/lenturi = 5)
	required_reagents = list(/datum/reagent/ammonia = 1, /datum/reagent/silver = 1, /datum/reagent/sulfur = 1, /datum/reagent/oxygen = 1, /datum/reagent/chlorine = 1)
	required_temp = 200
	optimal_temp = 300
	overheat_temp = 500
	optimal_ph_min = 6
	optimal_ph_max = 11
	determin_ph_range = 6
	temp_exponent_factor = 1
	ph_exponent_factor = 2
	thermic_constant = -175 //Though, it is a test in endothermicity
	H_ion_release = -2.5
	rate_up_lim = 30
	purity_min = 0.25
	reaction_flags = REACTION_PH_VOL_CONSTANT
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_HEALING | REACTION_TAG_BURN

/datum/chemical_reaction/medicine/aiuri
	results = list(/datum/reagent/medicine/c2/aiuri = 4)
	required_reagents = list(/datum/reagent/ammonia = 1, /datum/reagent/toxin/acid = 1, /datum/reagent/hydrogen = 2)
	required_temp = 50
	optimal_temp = 300
	overheat_temp = 350
	optimal_ph_min = 4.8
	optimal_ph_max = 9
	determin_ph_range = 3
	temp_exponent_factor = 5
	ph_exponent_factor = 2
	thermic_constant = -400
	H_ion_release = 3.2
	rate_up_lim = 35
	purity_min = 0.25
	reaction_flags = REACTION_PH_VOL_CONSTANT
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_HEALING | REACTION_TAG_BURN

/datum/chemical_reaction/medicine/aiuri/overheated(datum/reagents/holder, datum/equilibrium/equilibrium)
	. = ..()
	for(var/mob/living/living_mob as anything in orange(3, get_turf(holder.my_atom)))
		if(!isliving(living_mob))
			continue
		if(living_mob.flash_act(1, length = 5))
			living_mob.set_blurriness(10)
	holder.my_atom.audible_message("<span class='notice'>[icon2html(holder.my_atom, viewers(DEFAULT_MESSAGE_RANGE, src))] The [holder.my_atom] lets out a loud bang!</span>")
	playsound(holder.my_atom, 'sound/effects/explosion1.ogg', 50, 1)

/datum/chemical_reaction/medicine/hercuri
	results = list(/datum/reagent/medicine/c2/hercuri = 5)
	required_reagents = list(/datum/reagent/cryostylane = 3, /datum/reagent/bromine = 1, /datum/reagent/lye = 1)

	is_cold_recipe = TRUE
	required_temp = 47
	optimal_temp = 10
	overheat_temp = 5
	optimal_ph_min = 6
	optimal_ph_max = 10
	determin_ph_range = 1
	temp_exponent_factor = 3
	thermic_constant = -40
	H_ion_release = 3.7
	rate_up_lim = 50
	reaction_flags = REACTION_PH_VOL_CONSTANT
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_HEALING | REACTION_TAG_BURN

/datum/chemical_reaction/medicine/hercuri/overheated(datum/reagents/holder, datum/equilibrium/equilibrium)
	if(off_cooldown(holder, equilibrium, 2, "hercuri_freeze"))
		return
	playsound(holder.my_atom, 'sound/magic/ethereal_exit.ogg', 50, 1)
	holder.my_atom.visible_message("The reaction frosts over, releasing it's chilly contents!")
	var/radius = max((equilibrium.step_target_vol/50), 1)
	freeze_radius(holder, equilibrium, 200, radius, 50) //drying agent exists
	explode_shockwave(holder, equilibrium, sound_and_text = FALSE)

/*****OXY*****/
//These react faster with optional oxygen, and have blastback effects! (the oxygen makes their fail states deadlier)

/datum/chemical_reaction/medicine/convermol
	results = list(/datum/reagent/medicine/c2/convermol = 3)
	required_reagents = list(/datum/reagent/hydrogen = 1, /datum/reagent/fluorine = 1, /datum/reagent/fuel/oil = 1)
	required_temp = 370
	mix_message = "The mixture rapidly turns into a dense pink liquid."
	optimal_temp = 500
	overheat_temp = 720
	optimal_ph_min = 5
	optimal_ph_max = 10
	determin_ph_range = 2
	temp_exponent_factor = 0.75
	ph_exponent_factor = 1.25
	thermic_constant = 25
	H_ion_release = 4
	rate_up_lim = 50
	purity_min = 0.4
	reaction_flags = REACTION_PH_VOL_CONSTANT
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_HEALING | REACTION_TAG_OXY

/datum/chemical_reaction/medicine/convermol/reaction_step(datum/equilibrium/reaction, datum/reagents/holder, delta_t, delta_ph, step_reaction_vol)
	. = ..()
	var/datum/reagent/oxy = holder.has_reagent(/datum/reagent/oxygen)
	if(!oxy)
		reaction.delta_t = delta_t/10 //slow without oxygen
	else
		holder.remove_reagent(/datum/reagent/oxygen, 0.25)

/datum/chemical_reaction/medicine/convermol/overheated(datum/reagents/holder, datum/equilibrium/equilibrium, impure = FALSE)
	var/range = impure ? 4 : 3
	if(holder.has_reagent(/datum/reagent/oxygen))
		explode_shockwave(holder, equilibrium, range) //damage 5
	else
		explode_shockwave(holder, equilibrium, range, damage = 2)

/datum/chemical_reaction/medicine/convermol/overly_impure(datum/reagents/holder, datum/equilibrium/equilibrium)
	. = ..()
	overheated(holder, equilibrium, TRUE)
	clear_reactants(holder, 2)


/datum/chemical_reaction/medicine/tirimol
	results = list(/datum/reagent/medicine/c2/tirimol = 5)
	required_reagents = list(/datum/reagent/nitrogen = 3, /datum/reagent/acetone = 2)
	required_catalysts = list(/datum/reagent/toxin/acid = 1)
	mix_message = "The mixture sluggishly turns into a sleepy blue liquid."
	optimal_temp = 1
	optimal_temp = 900
	overheat_temp = 720
	optimal_ph_min = 5
	optimal_ph_max = 10
	determin_ph_range = 2
	temp_exponent_factor = 4
	ph_exponent_factor = 2
	thermic_constant = -20
	H_ion_release = 4
	rate_up_lim = 50
	purity_min = 0.4
	reaction_flags = REACTION_PH_VOL_CONSTANT
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_HEALING | REACTION_TAG_OXY

/datum/chemical_reaction/medicine/tirimol/reaction_step(datum/equilibrium/reaction, datum/reagents/holder, delta_t, delta_ph, step_reaction_vol)
	. = ..()
	var/datum/reagent/oxy = holder.has_reagent(/datum/reagent/oxygen)
	if(!oxy)
		holder.ph += 0.05//pH drifts faster
	else
		holder.remove_reagent(/datum/reagent/oxygen, 0.25)

//Sleepytime for chem
/datum/chemical_reaction/medicine/tirimol/overheated(datum/reagents/holder, datum/equilibrium/equilibrium, impure = FALSE)
	var/bonus = impure ? 2 : 1
	if(holder.has_reagent(/datum/reagent/oxygen))
		explode_attack_chem(holder, equilibrium, /datum/reagent/inverse/healing/tirimol, 7.5*bonus, 2, ignore_eyes = TRUE) //since we're smoke/air based
		clear_products(holder, 5)//since we attacked
		explode_invert_smoke(holder, equilibrium)
	else
		explode_invert_smoke(holder, equilibrium)

/datum/chemical_reaction/medicine/tirimol/overly_impure(datum/reagents/holder, datum/equilibrium/equilibrium)
	. = ..()
	overheated(holder, equilibrium, TRUE)
	clear_reactants(holder, 2)

/*****TOX*****/
//These all care about purity in their reactions

/datum/chemical_reaction/medicine/seiver //add alt that lowers temperature from reaction, make this one exothermic
	results = list(/datum/reagent/medicine/c2/seiver = 3)
	required_reagents = list(/datum/reagent/nitrogen = 1, /datum/reagent/potassium = 1, /datum/reagent/aluminium = 1)
	mix_message = "The mixture gives out a goopy slorp."
	is_cold_recipe = TRUE
	required_temp = 320
	optimal_temp = 50
	overheat_temp = 99999
	optimal_ph_min = 2
	optimal_ph_max = 5
	determin_ph_range = 6
	temp_exponent_factor = 2
	ph_exponent_factor = 0.5
	thermic_constant = -500
	H_ion_release = -5
	rate_up_lim = 60
	purity_min = 0.35
	reaction_flags = REACTION_PH_VOL_CONSTANT
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_HEALING | REACTION_TAG_TOXIN

/datum/chemical_reaction/medicine/seiver/overly_impure(datum/reagents/holder, datum/equilibrium/equilibrium)
	. = ..()
	if(off_cooldown(holder, equilibrium, 1, "seiver_rads"))
		return
	var/modifier = max((200 - holder.chem_temp)*0.1, 0) //0 - 20 based off temperature(colder is more)
	radiation_pulse(holder.my_atom, modifier, 0.5, can_contaminate=FALSE) //Please advise on this, I don't have a good handle on the numbers

/datum/chemical_reaction/medicine/multiver
	results = list(/datum/reagent/medicine/c2/multiver = 2)
	required_reagents = list(/datum/reagent/ash = 1, /datum/reagent/consumable/salt = 1)
	mix_message = "The mixture yields a fine black powder."
	required_temp = 380
	optimal_temp = 400
	overheat_temp = 410
	optimal_ph_min = 3
	optimal_ph_max = 7.5
	determin_ph_range = 4
	temp_exponent_factor = 0.5
	ph_exponent_factor = 1
	thermic_constant = 0
	H_ion_release = 0
	rate_up_lim = 25
	purity_min = 0.1 //Fire is our worry for now
	reaction_flags = REACTION_REAL_TIME_SPLIT | REACTION_PH_VOL_CONSTANT
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_HEALING | REACTION_TAG_PLANT | REACTION_TAG_TOXIN

//You get nothing! I'm serious about staying under the heating requirements!
/datum/chemical_reaction/medicine/multiver/overheated(datum/reagents/holder, datum/equilibrium/equilibrium)
	. = ..()
	var/datum/reagent/monover = holder.has_reagent(/datum/reagent/inverse/healing/monover)
	if(monover)
		holder.remove_reagent(/datum/reagent/inverse/healing/monover, monover.volume)
		holder.my_atom.audible_message("<span class='notice'>[icon2html(holder.my_atom, viewers(DEFAULT_MESSAGE_RANGE, src))] The Monover bursts into flames from the heat!</span>")
		explode_fire_square(holder, equilibrium, 1)
		holder.my_atom.fire_act(holder.chem_temp, monover.volume)//I'm kinda banking on this setting the thing on fire. If you see this, then it didn't!

/datum/chemical_reaction/medicine/multiver/reaction_step(datum/equilibrium/reaction, datum/reagents/holder, delta_t, delta_ph, step_reaction_vol)
	. = ..()
	if(delta_ph < 0.35)
		//normalise delta_ph
		var/norm_d_ph = 1-(delta_ph/0.35)
		holder.chem_temp += norm_d_ph*12 //0 - 48 per second)
	if(delta_ph < 0.1)
		holder.my_atom.visible_message("<span class='notice'>[icon2html(holder.my_atom, viewers(DEFAULT_MESSAGE_RANGE, src))] The Monover begins to glow!</span>")

/datum/chemical_reaction/medicine/syriniver
	results = list(/datum/reagent/medicine/c2/syriniver = 5)
	required_reagents = list(/datum/reagent/sulfur = 1, /datum/reagent/fluorine = 1, /datum/reagent/toxin = 1, /datum/reagent/nitrous_oxide = 2)
	required_temp = 250
	optimal_temp = 310
	overheat_temp = 99999
	optimal_ph_min = 5
	optimal_ph_max = 9
	determin_ph_range = 6
	temp_exponent_factor = 2
	ph_exponent_factor = 0.5
	thermic_constant = -20
	H_ion_release = -5
	rate_up_lim = 20 //affected by pH too
	purity_min = 0.3
	reaction_flags = REACTION_PH_VOL_CONSTANT
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_HEALING | REACTION_TAG_TOXIN

/datum/chemical_reaction/medicine/syriniver/reaction_step(datum/equilibrium/reaction, datum/reagents/holder, delta_t, delta_ph, step_reaction_vol)
	. = ..()
	reaction.delta_t = delta_t * delta_ph

/datum/chemical_reaction/medicine/penthrite
	results = list(/datum/reagent/medicine/c2/penthrite = 3)
	required_reagents = list(/datum/reagent/pentaerythritol = 1, /datum/reagent/acetone = 1,  /datum/reagent/toxin/acid/nitracid = 1 , /datum/reagent/wittel = 1)
	required_temp = 255
	optimal_temp = 350
	overheat_temp = 450
	optimal_ph_min = 2
	optimal_ph_max = 9
	determin_ph_range = 3
	temp_exponent_factor = 1
	ph_exponent_factor = 1
	thermic_constant = 150
	H_ion_release = -5
	rate_up_lim = 15
	purity_min = 0.55
	reaction_flags = REACTION_PH_VOL_CONSTANT
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_HEALING | REACTION_TAG_TOXIN

//overheat beats like a heart! (or is it overbeat?)
/datum/chemical_reaction/medicine/penthrite/overheated(datum/reagents/holder, datum/equilibrium/equilibrium)
	. = ..()
	if(off_cooldown(holder, equilibrium, 1, "lub"))
		explode_shockwave(holder, equilibrium, 3, 2)
		playsound(holder.my_atom, 'sound/health/slowbeat.ogg', 50, 1)
	if(off_cooldown(holder, equilibrium, 1, "dub", 0.5))
		explode_shockwave(holder, equilibrium, 3, 2, implosion = TRUE)
		playsound(holder.my_atom, 'sound/health/slowbeat.ogg', 50, 1)
	explode_fire_vortex(holder, equilibrium, 1, 1)

//enabling hardmode
/datum/chemical_reaction/medicine/penthrite/overly_impure(datum/reagents/holder, datum/equilibrium/equilibrium)
	holder.chem_temp += 15

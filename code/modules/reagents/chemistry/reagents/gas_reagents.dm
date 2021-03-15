/datum/reagent/gas
	description = "A gas that doesn't seem to do much of anything when consumed."
	reagent_state = GAS
	///The id of the gas that this reagent is associated with
	var/gas_id

///It is a requirement that you define a gas_id for this reagent subtype
/datum/reagent/gas/unit_test()
	. = ..()
	if(isnull(gas_id))
		. += "Gas subtype failure: [type] is missing a gas_id!")
	return .

/datum/reagent/gas/diffuse(amount, delta_time)
	. = ..()
	var/turf/open/exposed_turf = get_turf(holder)
	if(istype(exposed_turf))
		var/temp = holder.chem_temp
		exposed_turf.atmos_spawn_air("[gas_id]=[amount];TEMP=[temp]")

/datum/reagent/gas/expose_turf(turf/open/exposed_turf, reac_volume)
	if(istype(exposed_turf))
		var/temp = holder ? holder.chem_temp : T20C
		exposed_turf.atmos_spawn_air("[gas_id]=[reac_volume];TEMP=[temp]")
	return ..()

///Plasma and mindbreaker are toxins and are in toxin_reagents.dm
///Water is in other_reagents.dm because it's a liquid by default

/datum/reagent/oxygen
	name = "Oxygen"
	description = "A colorless, odorless gas. Grows on trees but is still pretty valuable."
	color = "#808080" // rgb: 128, 128, 128
	taste_mult = 0 // oderless and tasteless
	ph = 9.2//It's acutally a huge range and very dependant on the chemistry but ph is basically a made up var in it's implementation anyways
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	mass = 16
	gas_id = "o2"

/datum/reagent/carbondioxide
	name = "Carbon Dioxide"
	description = "A gas commonly produced by burning carbon fuels. You're constantly producing this in your lungs."
	color = "#B0B0B0" // rgb : 192, 192, 192
	taste_description = "something unknowable"
	ph = 6
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	mass = 44
	gas_id = "co2"

/datum/reagent/hydrogen //Consider editing to diatomic hydrogen
	name = "Hydrogen"
	description = "A colorless, odorless, nonmetallic, tasteless, highly combustible diatomic gas."
	color = "#808080" // rgb: 128, 128, 128
	taste_mult = 0
	ph = 0.1//Now I'm stuck in a trap of my own design. Maybe I should make -ve phes? (not 0 so I don't get div/0 errors)
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	mass = 1
	gas_id = "hydrogen"

/datum/reagent/nitrogen
	name = "Nitrogen"
	description = "A colorless, odorless, tasteless gas. A simple asphyxiant that can silently displace vital oxygen."
	color = "#808080" // rgb: 128, 128, 128
	taste_mult = 0
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	mass = 14
	gas_id = "n2"

/datum/reagent/nitrous_oxide
	name = "Nitrous Oxide"
	description = "A potent oxidizer used as fuel in rockets and as an anaesthetic during surgery."
	reagent_state = LIQUID
	metabolization_rate = 1.5 * REAGENTS_METABOLISM
	color = "#808080"
	taste_description = "sweetness"
	ph = 5.8
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	gas_id = "n2o"

/datum/reagent/nitrous_oxide/expose_mob(mob/living/exposed_mob, methods=TOUCH, reac_volume)
	. = ..()
	if(methods & VAPOR)
		exposed_mob.drowsyness += max(round(reac_volume, 1), 2)

/datum/reagent/nitrous_oxide/on_mob_life(mob/living/carbon/M, delta_time, times_fired)
	M.drowsyness += 2 * REM * delta_time
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		H.blood_volume = max(H.blood_volume - (10 * REM * delta_time), 0)
	if(DT_PROB(10, delta_time))
		M.losebreath += 2
		M.set_confusion(min(M.get_confusion() + 2, 5))
	..()

/datum/reagent/helium
	name = "Helium"
	description = "A non-toxic, inert, monatomic gas. A very noble gas indeed!"
	color = "#93fff6" // rgb: 72, 72, 72A
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	mass = 4
	gas_id = "helium"

/datum/reagent/stimulum
	name = "Stimulum"
	description = "An unstable experimental gas that greatly increases the energy of those that inhale it, while dealing increasing toxin damage over time."
	metabolization_rate = REAGENTS_METABOLISM * 0.5 // Because stimulum/nitryl/freon/hypernoblium are handled through gas breathing, metabolism must be lower for breathcode to keep up
	color = "E1A116"
	taste_description = "sourness"
	ph = 1.8
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	addiction_types = list(/datum/addiction/stimulants = 14)
	mass = 27
	gas_id = "stim"

/datum/reagent/stimulum/on_mob_metabolize(mob/living/L)
	..()
	ADD_TRAIT(L, TRAIT_STUNIMMUNE, type)
	ADD_TRAIT(L, TRAIT_SLEEPIMMUNE, type)

/datum/reagent/stimulum/on_mob_end_metabolize(mob/living/L)
	REMOVE_TRAIT(L, TRAIT_STUNIMMUNE, type)
	REMOVE_TRAIT(L, TRAIT_SLEEPIMMUNE, type)
	..()

/datum/reagent/stimulum/on_mob_life(mob/living/carbon/M, delta_time, times_fired)
	M.adjustStaminaLoss(-2 * REM * delta_time, 0)
	M.adjustToxLoss(0.1 * current_cycle * REM * delta_time, 0) // 1 toxin damage per cycle at cycle 10
	..()

/datum/reagent/nitryl
	name = "Nitryl"
	description = "A highly reactive gas that makes you feel faster."
	metabolization_rate = REAGENTS_METABOLISM * 0.5 // Because stimulum/nitryl/freon/hypernoblium are handled through gas breathing, metabolism must be lower for breathcode to keep up
	color = "90560B"
	taste_description = "burning"
	ph = 2
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	mass = 21
	gas_id = "no2"

/datum/reagent/nitryl/on_mob_metabolize(mob/living/L)
	..()
	L.add_movespeed_modifier(/datum/movespeed_modifier/reagent/nitryl)

/datum/reagent/nitryl/on_mob_end_metabolize(mob/living/L)
	L.remove_movespeed_modifier(/datum/movespeed_modifier/reagent/nitryl)
	..()

/datum/reagent/freon
	name = "Freon"
	description = "A powerful heat absorbent."
	metabolization_rate = REAGENTS_METABOLISM * 0.5 // Because stimulum/nitryl/freon/hypernoblium are handled through gas breathing, metabolism must be lower for breathcode to keep up
	color = "90560B"
	taste_description = "burning"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	mass = 11
	gas_id = "freon"

/datum/reagent/freon/on_mob_metabolize(mob/living/L)
	. = ..()
	L.add_movespeed_modifier(/datum/movespeed_modifier/reagent/freon)

/datum/reagent/freon/on_mob_end_metabolize(mob/living/L)
	L.remove_movespeed_modifier(/datum/movespeed_modifier/reagent/freon)
	return ..()

/datum/reagent/hypernoblium
	name = "Hyper-Noblium"
	description = "A suppressive gas that stops gas reactions on those who inhale it."
	metabolization_rate = REAGENTS_METABOLISM * 0.5 // Because stimulum/nitryl/freon/hyper-nob are handled through gas breathing, metabolism must be lower for breathcode to keep up
	color = "90560B"
	taste_description = "searingly cold"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	mass = 19
	gas_id = "nob"

/datum/reagent/hypernoblium/on_mob_metabolize(mob/living/L)
	. = ..()
	if(isplasmaman(L))
		ADD_TRAIT(L, TRAIT_NOFIRE, type)

/datum/reagent/hypernoblium/on_mob_end_metabolize(mob/living/L)
	if(isplasmaman(L))
		REMOVE_TRAIT(L, TRAIT_NOFIRE, type)
	return ..()

/datum/reagent/healium
	name = "Healium"
	description = "A powerful sleeping agent with healing properties"
	metabolization_rate = REAGENTS_METABOLISM * 0.5
	color = "90560B"
	taste_description = "rubbery"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	mass = 11
	gas_id = "healium"

/datum/reagent/healium/on_mob_metabolize(mob/living/L)
	. = ..()
	L.PermaSleeping()

/datum/reagent/healium/on_mob_end_metabolize(mob/living/L)
	L.SetSleeping(10)
	return ..()

/datum/reagent/healium/on_mob_life(mob/living/L, delta_time, times_fired)
	. = ..()
	L.adjustFireLoss(-2 * REM * delta_time, FALSE)
	L.adjustToxLoss(-5 * REM * delta_time, FALSE)
	L.adjustBruteLoss(-2 * REM * delta_time, FALSE)

/datum/reagent/halon
	name = "Halon"
	description = "A fire suppression gas that removes oxygen and cools down the area"
	metabolization_rate = REAGENTS_METABOLISM * 0.5
	color = "90560B"
	taste_description = "minty"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED
	mass = 26
	gas_id = "halon"

/datum/reagent/halon/on_mob_metabolize(mob/living/L)
	. = ..()
	L.add_movespeed_modifier(/datum/movespeed_modifier/reagent/halon)
	ADD_TRAIT(L, TRAIT_RESISTHEAT, type)

/datum/reagent/halon/on_mob_end_metabolize(mob/living/L)
	L.remove_movespeed_modifier(/datum/movespeed_modifier/reagent/halon)
	REMOVE_TRAIT(L, TRAIT_RESISTHEAT, type)
	return ..()

/datum/reagent/tritium
	description = "Precious tritium is the fuel that makes this project go."


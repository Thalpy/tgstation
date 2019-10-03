/datum/chemical_reaction/fermi
	mix_sound = 'sound/effects/bubbles.ogg'
	//FermiChem vars:
	var/OptimalTempMin 		= 0 // Lower area of bell curve for determining heat based rate reactions
	var/OptimalTempMax		= 1000 // Upper end for above
	var/ExplodeTemp			= 9999 //Temperature at which reaction explodes
	var/OptimalpHMin		= 1 // Lowest value of pH determining pH a 1 value for pH based rate reactions (Plateu phase)
	var/OptimalpHMax		= 14 // Higest value for above
	var/ReactpHLim			= 0 // How far out pH wil react, giving impurity place (Exponential phase)
	var/CatalystFact		= 0 // How much the catalyst affects the reaction (0 = no catalyst)
	var/CurveSharpT 		= 1.5 // How sharp the temperature exponential curve is (to the power of value)
	var/CurveSharppH 		= 3 // How sharp the pH exponential curve is (to the power of value)
	var/ThermicConstant		= 0 //Temperature change per 1u produced
	var/HIonRelease 		= 0 //pH change per 1u reaction
	var/RateUpLim 			= 10 //Optimal/max rate possible if all conditions are perfect
	var/FermiChem 			= TRUE//If the chemical uses the Fermichem reaction mechanics
	var/FermiExplode 		= FALSE //If the chemical explodes in a special way
	var/PurityMin			= 0.1 //The minimum purity something has to be above, otherwise it explodes.
	//use fermicalc.py to calculate how the curves look(i think)
//Called for every reaction step
/datum/chemical_reaction/fermi/proc/FermiCreate(holder)
	return

//Called when reaction STOP_PROCESSING
/datum/chemical_reaction/fermi/proc/FermiFinish(datum/reagents/holder)
	return

//Called when temperature is above a certain threshold, or if purity is too low.
/datum/chemical_reaction/fermi/proc/FermiExplode(datum/reagents, var/atom/my_atom, volume, temp, pH, Exploding = FALSE)
	if (Exploding == TRUE)
		return

	if(!pH)//Dunno how things got here without a pH, but just in case
		pH = 7
	var/ImpureTot = 0
	var/turf/T = get_turf(my_atom)

	if(temp>500)//if hot, start a fire
		switch(temp)
			if (500 to 750)
				for(var/turf/turf in range(1,T))
					new /obj/effect/hotspot(turf)

			if (751 to 1100)
				for(var/turf/turf in range(2,T))
					new /obj/effect/hotspot(turf)

			if (1101 to 1500) //If you're crafty
				for(var/turf/turf in range(3,T))
					new /obj/effect/hotspot(turf)

			if (1501 to 2500) //requested
				for(var/turf/turf in range(4,T))
					new /obj/effect/hotspot(turf)

			if (2501 to 5000)
				for(var/turf/turf in range(5,T))
					new /obj/effect/hotspot(turf)

			if (5001 to INFINITY)
				for(var/turf/turf in range(6,T))
					new /obj/effect/hotspot(turf)


	message_admins("Fermi explosion at [T], with a temperature of [temp], pH of [pH], Impurity tot of [ImpureTot].")
	log_game("Fermi explosion at [T], with a temperature of [temp], pH of [pH], Impurity tot of [ImpureTot].")
	var/datum/reagents/R = new/datum/reagents(3000)//Hey, just in case.
	var/datum/effect_system/smoke_spread/chem/s = new()
	R.my_atom = my_atom //Give the gas a fingerprint

	for (var/datum/reagent/reagent in my_atom.reagents.reagent_list) //make gas for reagents, has to be done this way, otherwise it never stops Exploding
		R.add_reagent(reagent.type, reagent.volume/3) //Seems fine? I think I fixed the infinite explosion bug.
			ImpureTot = (ImpureTot + (1-reagent.purity)) / 2
	if(pH < 4) //if acidic, make acid spray
		R.add_reagent("fermiAcid", (volume/3))
	if(R.reagent_list)
		s.set_up(R, (volume/5), my_atom)
		s.start()

	if (pH > 10) //if alkaline, small explosion.
		var/datum/effect_system/reagents_explosion/e = new()
		e.set_up(round((volume/30)*(pH-9)), T, 0, 0)
		e.start()

	if(!ImpureTot == 0) //If impure, v.small emp (0.6 or less)
		ImpureTot *= volume
		var/empVol = CLAMP (volume/10, 0, 15)
		empulse(T, empVol, ImpureTot/10, 1)

	my_atom.reagents.clear_reagents() //just in case
	return
/
//FOR INSTANT REACTIONS - DO NOT MULTIPLY LIMIT BY 10.
//There's a weird rounding error or something ugh.



/datum/chemical_reaction/fermi/acidic_buffer//done test
	name = "Acetic acid buffer"
	id = "acidic_buffer"
	results = list(/datum/reagent/fermi/acidic_buffer = 2) //acetic acid
	required_reagents = list("salglu_solution" = 0.2, "ethanol" = 0.6, "oxygen" = 0.6, "water" = 0.6)
	//FermiChem vars:
	OptimalTempMin 	= 250
	OptimalTempMax 	= 500
	ExplodeTemp 	= 9999 //check to see overflow doesn't happen!
	OptimalpHMin 	= 2
	OptimalpHMax 	= 6
	ReactpHLim 		= 0
	//CatalystFact 	= 0 //To do 1
	CurveSharpT 	= 4
	CurveSharppH 	= 0
	ThermicConstant = 0
	HIonRelease 	= -0.01
	RateUpLim 		= 20
	FermiChem 		= TRUE


/datum/chemical_reaction/fermi/acidic_buffer/FermiFinish(datum/reagents/holder, var/atom/my_atom) //might need this
	if(!locate(/datum/reagent/fermi/acidic_buffer) in my_atom.reagents.reagent_list)
		return
	var/datum/reagent/fermi/acidic_buffer/Fa = locate(/datum/reagent/fermi/acidic_buffer) in my_atom.reagents.reagent_list
	Fa.data = 0.1//setting it to 0 means byond thinks it's not there.

/datum/chemical_reaction/fermi/basic_buffer//done test
	name = "Ethyl Ethanoate buffer"
	id = "basic_buffer"
	results = list(/datum/reagent/fermi/basic_buffer = 1.5)
	required_reagents = list("acidic_buffer" = 0.5, "ethanol" = 0.5, "water" = 0.5)
	required_catalysts = list("sacid" = 1) //vagely acetic
	//FermiChem vars:x
	OptimalTempMin 	= 250
	OptimalTempMax 	= 500
	ExplodeTemp 	= 9999 //check to see overflow doesn't happen!
	OptimalpHMin 	= 5
	OptimalpHMax 	= 12
	ReactpHLim 		= 0
	//CatalystFact 	= 0 //To do 1
	CurveSharpT 	= 4
	CurveSharppH 	= 0
	ThermicConstant = 0
	HIonRelease 	= 0.01
	RateUpLim 		= 15
	FermiChem 		= TRUE


/datum/chemical_reaction/fermi/basic_buffer/FermiFinish(datum/reagents/holder, var/atom/my_atom) //might need this
	if(!locate(/datum/reagent/fermi/basic_buffer) in my_atom.reagents.reagent_list)
		return
	var/datum/reagent/fermi/basic_buffer/Fb = locate(/datum/reagent/fermi/basic_buffer) in my_atom.reagents.reagent_list
	Fb.data = 14


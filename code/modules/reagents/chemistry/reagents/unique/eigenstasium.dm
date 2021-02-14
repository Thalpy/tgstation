////////////////////////////////////////////////////////////////////////////////////////////////////
//										EIGENSTASIUM
///////////////////////////////////////////////////////////////////////////////////////////////////
//eigenstate Chem
//Teleports you to chemistry and back
//OD teleports you randomly around the Station
//Addiction send you on a wild ride and replaces you with an alternative reality version of yourself.
//During the process you get really hungry, then some of your items slowly start teleport around you,
//then alternative versions of yourself are brought in from a different universe and they yell at you.
//and finally you yourself get teleported to an alternative universe, and character your playing is replaced with said alternative

/datum/reagent/eigenstate
	name = "Eigenstasium"
	description = "A strange mixture formed from a controlled reaction of bluespace with plasma, that causes localised eigenstate fluxuations within the patient"
	taste_description = "wiggly cosmic dust."
	color = "#5020F4"
	overdose_threshold = 16
	addiction_threshold = 16
	metabolization_rate = 1 * REAGENTS_METABOLISM
	ph = 3.7
	impure_chem = /datum/reagent/impurity/eigenswap
	inverse_chem = null
	failed_chem = /datum/reagent/bluespace //crashes out 
	chemical_flags = REAGENT_DEAD_PROCESS //So if you die with it in your body, you still get teleported back to the location as a corpse
	data = list("location_created" = null)//So we retain the target location between reagent instances
	///The creation point assigned during the reaction
	var/turf/location_created
	///The return point indicator
	var/obj/effect/overlay/holo_pad_hologram/eigenstate
	///The point you're returning to after the reagent is removed
	var/turf/open/location_return = null
	///The addiction looper for addiction stage 3
	var/addictCyc3 = 0
	///Your clone from another reality
	var/mob/living/carbon/alt_clone = null

/datum/reagent/eigenstate/on_new(list/data)
	location_created = data["location_created"]

//Main functions
/datum/reagent/eigenstate/on_mob_life(mob/living/M) //Teleports to creation!
	if(current_cycle == 0)
		//make hologram at return point
		eigenstate = new (M.loc)
		eigenstate.appearance = M.appearance
		eigenstate.alpha = 170
		eigenstate.add_atom_colour("#77abff", FIXED_COLOUR_PRIORITY)
		eigenstate.mouse_opacity = MOUSE_OPACITY_TRANSPARENT//So you can't click on it.
		eigenstate.layer = FLY_LAYER//Above all the other objects/mobs. Or the vast majority of them.
		eigenstate.anchored = 1//So space wind cannot drag it.
		eigenstate.name = "[M]'s' eigenstate"//If someone decides to right click.
		eigenstate.set_light(2)	//hologram lighting

		location_return = get_turf(M)	//sets up return point
		to_chat(M, "<span class='userdanger'>You feel your wavefunction split!</span>")
		if(creation_purity > 0.9 && location_created) //Teleports you home if it's pure enough
			do_sparks(5,FALSE,M)
			do_teleport(M, location_created, 0, asoundin = 'sound/effects/phasein.ogg')
			do_sparks(5,FALSE,M)

	if(prob(20))
		do_sparks(5,FALSE,M)
	..()

/datum/reagent/eigenstate/on_mob_delete(mob/living/M) //returns back to original location
	do_sparks(5,FALSE,M)
	to_chat(M, "<span class='userdanger'>You feel your wavefunction collapse!</span>")
	if(!M.reagents.has_reagent(/datum/reagent/stabilizing_agent))
		do_teleport(M, location_return, 0, asoundin = 'sound/effects/phasein.ogg') //Teleports home
		do_sparks(5,FALSE,M)
	qdel(eigenstate)
	..()

/datum/reagent/eigenstate/overdose_start(mob/living/M) //Overdose, makes you teleport randomly
	. = ..()
	to_chat(M, "<span class='userdanger'>Oh god, you feel like your wavefunction is about to tear.</span>")
	M.Jitter(20)
	metabolization_rate += 0.5 //So you're not stuck forever teleporting.

/datum/reagent/eigenstate/overdose_process(mob/living/M) //Overdose, makes you teleport randomly, probably one of my favourite effects.
	do_sparks(5,FALSE,M)
	do_teleport(M, get_turf(M), 10, asoundin = 'sound/effects/phasein.ogg')
	do_sparks(5,FALSE,M)
	..()

//Addiction
/datum/reagent/eigenstate/addiction_act_stage1(mob/living/M) //Welcome to the wild ride.
	if(addiction_stage == 1)
		to_chat(M, "<span class='userdanger'>Your wavefunction feels like it's been ripped in half. You feel empty inside.</span>")
		M.Jitter(10)
	M.adjust_nutrition(-M.nutrition/15)
	..()

//Slowly teleports your items randomly
/datum/reagent/eigenstate/addiction_act_stage2(mob/living/M)
	if(addiction_stage == 11)
		to_chat(M, "<span class='userdanger'>You start to convlse violently as you feel your consciousness split and merge across realities as your possessions fly wildy off your body.</span>")
		M.Jitter(200)
		M.Stun(80)
	var/items = M.get_contents()
	if(!LAZYLEN(items))
		return ..()
	var/obj/item/item = pick(items)
	M.dropItemToGround(item, TRUE)
	do_sparks(5,FALSE,item)
	do_teleport(item, get_turf(item), 5, no_effects=TRUE);
	do_sparks(5,FALSE,item)
	..()

//Pulls multiple copies of the character from alternative realities while teleporting them around!
/datum/reagent/eigenstate/addiction_act_stage3(mob/living/M)
	//Clone function - spawns a clone then deletes it - simulates multiple copies of the player teleporting in
	switch(addictCyc3) //Loops 0 -> 1 -> 2 -> 1 -> 2 -> 1 ...ect.
		if(0)
			M.Jitter(100)
			to_chat(M, "<span class='userdanger'>Your eigenstate starts to rip apart, drawing in alternative reality versions of yourself!</span>")
		if(1)
			var/typepath = M.type
			alt_clone = new typepath(M.loc)
			var/mob/living/carbon/clone = alt_clone
			alt_clone.appearance = M.appearance
			clone.real_name = M.real_name
			M.visible_message("[M] collapses in from an alternative reality!")
			do_teleport(clone, get_turf(clone), 2, no_effects=TRUE) //teleports clone so it's hard to find the real one!
			do_sparks(5,FALSE,clone)
			clone.emote("spin")
			M.emote("spin")
			var/static/list/say_phrases = list(
				"Bugger me, whats all this then?",
				"Sacre bleu! Ou suis-je?!",
				"I knew powering the station using a singularity engine would lead to something like this...",
				"Wow, I can't believe in your universe Cencomm got rid of cloning.",
				"WHAT IS HAPPENING?!",
				"YOU'VE CREATED A TIME PARADOX!",
				"You trying to steal my job?",
				"So that's what I'd look like if I was ugly...",
				"So, two alternate universe twins walk into a bar...",
				"YOU'VE DOOMED THE TIMELINE!",
				"Ruffle a cat once in a while!",
				"Why haven't you gotten around to starting that band?!",
				"I bet we can finally take the clown now.",
				"LING DISGUISED AS ME!",
				"At long last! My evil twin!",
				"Keep going lets see if more of us show up.",
				"No! Dark spirits, do not torment me with these visions of my future self! It's horrible!",
				"Good. Now that the council is assembled the meeting can begin.",
				"Listen! I only have so much time before I'm ripped away. The secret behind the gas giants are...",
				"Das ist nicht deutschland. Das ist nicht akzeptabel!!!",
				"I've come from the future to warn you about eigenstasium! Oh no! I'm too late!",
				"You fool! You took too much eigenstasium! You've doomed us all!",
				"What...what's with these teleports? It's like one of my Japanese animes...!",
				"Ik stond op het punt om mehki op tafel te zetten, en nu, waar ben ik?",
				"Wake the fuck up spaceman we have a gas giant to burn",
				"This is one hell of a beepsky smash.",
				"Now neither of us will be virgins!")
			clone.say(pick(say_phrases))
		if(2)
			var/mob/living/carbon/clone = alt_clone
			do_sparks(5,FALSE,clone)
			qdel(clone) //Deletes CLONE, or was that you?
			M.visible_message("[M] is snapped across to a different alternative reality!")
			addictCyc3 = 0 //counter
			alt_clone = null
	addictCyc3++
	do_teleport(M, get_turf(M), 2, no_effects=TRUE) //Teleports player randomly
	do_sparks(5,FALSE,M)
	..()

/datum/reagent/eigenstate/addiction_act_stage4(mob/living/M) //Thanks for riding Fermichem's wild ride. Mild jitter and player buggery.
	if(alt_clone)//catch any stragilers
		var/mob/living/carbon/clone = alt_clone
		do_sparks(5,FALSE,clone)
		qdel(clone) 
		M.visible_message("[M] is snapped across to a different alternative reality!")
		alt_clone = null
	if(addiction_stage == 31)
		do_sparks(5,FALSE,M)
		do_teleport(M, get_turf(M), 2, no_effects=TRUE) //teleports clone so it's hard to find the real one!
		do_sparks(5,FALSE,M)
		M.Sleeping(100)
		M.Jitter(50)
		to_chat(M, "<span class='warning'>You feel your eigenstate settle, snapping an alternative version of yourself into reality.</span>")
		M.emote("me",1,"flashes into reality suddenly, gasping as they gaze around in a bewildered and highly confused fashion!",TRUE)
		log_game("FERMICHEM: [M] ckey: [M.key] has become an alternative universe version of themselves.")
		M.reagents.remove_all(1000)
		var/datum/component/mood/mood = M.GetComponent(/datum/component/mood)
		mood.remove_temp_moods() //New you, new moods. Little tempted to randomize traits but maybe not
		SEND_SIGNAL(M, COMSIG_ADD_MOOD_EVENT, "Eigentrip", /datum/mood_event/eigentrip, creation_purity)
		SSblackbox.record_feedback("tally", "chemical_reaction", 1, "Eigenstasium wild rides ridden")

	if(prob(20))
		do_sparks(5,FALSE,M)
	..()

///Lets you link lockers together
/datum/reagent/eigenstate/expose_turf(turf/exposed_turf, reac_volume)
	. = ..()
	if(creation_purity < 0.8)
		return
	var/obj/structure/closet/first
	var/obj/structure/closet/previous
	for(var/obj/structure/closet/closet in exposed_turf.contents)
		if(closet.eigen_target)
			closet.visible_message("[closet] fizzes, it's already linked to something else!")
			continue
		if(!previous)
			first = closet
			previous = closet
			continue
		closet.convert_to_eigenlocker(previous)
		previous = closet
	if(!first)
		return
	if(previous == first)
		return
	first.convert_to_eigenlocker(previous)
	first.visible_message("The lockers' eigenstates spilt and merge, linking each of their contents together.")

//eigenstate END

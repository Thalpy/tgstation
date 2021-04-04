#define REAGENT_VOL_TO_STACK_MULTIPLIER 5

/obj/item/stack/solid_phase_object
	name = "error"
	desc = "A solid mass of error" //Reagent name here
	icon_state = "reagent_phase_solid"
	//the reagent type this thing is
	var/reagent_type

/obj/item/stack/solid_phase_object/New(loc, volume, datum/reagent/reagent)
	create_reagents(SOLID_PHYSICAL_PHASE_CAPACITY) //5u per 1 stack
	name += " [reagent.name]"
	desc += " [reagent.name]"
	reagent_type = reagent.type
	color = reagent.color
	grind_results = list(reagent.type = REAGENT_VOL_TO_STACK_MULTIPLIER)
	reagents.add_reagent(reagent.type, amount*REAGENT_VOL_TO_STACK_MULTIPLIER, reagtemp = reagent.holder.chem_temp, added_purity = reagent.purity, added_ph = reagent.ph)
	//Have to do this before init - init checks stacks which requires a reagents datum to be set up
	. = ..()

/obj/item/stack/solid_phase_object/Initialize(mapload, new_amount, merge, list/mat_override, mat_amt)
	. = ..()
	RegisterSignal(reagents, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES, .proc/reagent_process)
	//Check physical states and setup temp signals, but otherwise doesn't need processing

/obj/item/stack/solid_phase_object/Destroy()
	UnregisterSignal(reagents, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES)
	QDEL_NULL(reagents)
	. = ..()

/obj/item/stack/solid_phase_object/use(used, transfer = FALSE, check = TRUE) // return 0 = borked; return 1 = had enough
	if(used * REAGENT_VOL_TO_STACK_MULTIPLIER > reagents.total_volume)
		to_chat(usr, "There's not enough reagent in the [src] to make a table!")
		return FALSE
	. = ..()
	reagents.remove_all(used*REAGENT_VOL_TO_STACK_MULTIPLIER)
	return TRUE

/obj/item/stack/solid_phase_object/proc/reagent_process()
	color = mix_color_from_reagents(reagents.reagent_list)
	if(reagents.total_volume <= 0)
		qdel(src)

//		~~~		solid		~~~

/obj/item/stack/solid_phase_object/solid
	name = "Solid"
	desc = "A solid mass of" //Reagent name here
	icon_state = "reagent_phase_solid"
	tableVariant = /obj/structure/table/reagents
	reagent_type = SOLID

/obj/item/stack/solid_phase_object/solid/can_merge(obj/item/stack/check)
	. = ..()
	if(!.) //if parent checks are false
		return FALSE
	var/obj/item/stack/solid_phase_object/check_phase = check
	if(check_phase.reagents.has_reagent(reagent_type))
		return TRUE
	return FALSE

/obj/item/stack/solid_phase_object/solid/merge(obj/item/stack/S, limit)
	var/transfer = ..()
	reagents.add_reagent(reagent_type, transfer*REAGENT_VOL_TO_STACK_MULTIPLIER)
	color = mix_color_from_reagents(reagents.reagent_list)

//		~~~		Powder		~~~

/obj/item/stack/solid_phase_object/powder
	name = "Powdered"
	desc = "A ground up mass of reagents" //Reagent name here
	icon_state = "reagent_phase_powder"
	reagent_type = POWDER

/obj/item/stack/solid_phase_object/powder/merge(obj/item/stack/incoming_stack, limit)
	var/transfer = ..()
	var/obj/item/stack/solid_phase_object/incoming_phase = incoming_stack
	incoming_phase.reagents.trans_to(reagents, transfer*REAGENT_VOL_TO_STACK_MULTIPLIER)
	color = mix_color_from_reagents(reagents.reagent_list)

//		~~~		Table		~~~

/obj/structure/table/reagents
	name = "Reagent Table"

/obj/structure/table/reagents/Destroy()
	QDEL_NULL(reagents)
	. = ..()

/obj/structure/table/reagents/post_create_table(obj/item/item)
	create_reagents(SOLID_PHYSICAL_PHASE_CAPACITY) //5u per 1 stack
	var/obj/item/stack/solid_phase_object/reagent_source = item
	color = mix_color_from_reagents(reagent_source.reagents.reagent_list)
	reagent_source.reagents.trans_to(reagents, reagent_source.reagents.total_volume)
	var/datum/reagent/reagent = reagent_source.reagents.reagent_list[1]
	name += "[reagent.name] Table"
	desc = "A table made out of [reagent.name]"


/obj/structure/table/reagents/AfterPutItemOnTable(obj/item/item, mob/living/user)
	. = ..()
	if(item.reagents)
		reagents.trans_to(item.reagents, 2)
	if(reagents.total_volume <= 0)
		qdel(src)
	alpha = 200 + (reagents.total_volume / 5)

#define REAGENT_VOL_TO_STACK_MULTIPLIER 5

/obj/item/stack/solid_phase_object
	name = "Solid"
	desc = "A solid mass of" //Reagent name here
	icon_state = "reagent_phase_solid"
	tableVariant = /obj/structure/table/reagents
	//the reagent type this thing is
	var/reagent_type

/obj/item/stack/solid_phase_object/Initialize(mapload, new_amount, merge, list/mat_override, mat_amt)
	. = ..()
	RegisterSignal(reagents, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES, .proc/process)

/obj/item/stack/solid_phase_object/Destroy()
	UnregisterSignal(reagents, COMSIG_REAGENTS_UPDATE_PHYSICAL_STATES)
	QDEL_NULL(reagents)
	. = ..()

/obj/item/stack/solid_phase_object/proc/set_reagent(datum/reagent/reagent, amount)
	name += " [reagent.name]"
	desc += " [reagent.name]"
	reagent_type = reagent.type
	color = reagent.color
	create_reagents(250) //5u per 1 stack
	grind_results = list(reagent.type = REAGENT_VOL_TO_STACK_MULTIPLIER)
	reagents.add_reagent(reagent.type, amount, added_purity = reagent.purity)

/obj/item/stack/solid_phase_object/use(used, transfer = FALSE, check = TRUE) // return 0 = borked; return 1 = had enough
	if(used * REAGENT_VOL_TO_STACK_MULTIPLIER > reagents.total_volume)
		stack_trace("Jank is happening for solid phase objects - it should be [REAGENT_VOL_TO_STACK_MULTIPLIER]u per 1 stack. Attempted to use [used*REAGENT_VOL_TO_STACK_MULTIPLIER]u of total volume [reagents.total_volume]")
		return FALSE
	. = ..()
	reagents.remove_all(used*REAGENT_VOL_TO_STACK_MULTIPLIER)
	return TRUE

/obj/item/stack/solid_phase_object/can_merge(obj/item/stack/check)
	if(!..()) //if parent checks are false
		return FALSE
	var/obj/item/stack/solid_phase_object/check_phase = check
	if(check_phase.reagents.has_reagent(reagent_type))
		return TRUE
	return FALSE

/obj/item/stack/solid_phase_object/merge(obj/item/stack/S, limit)
	var/transfer = ..()
	reagents.add_reagent(reagent_type, transfer*REAGENT_VOL_TO_STACK_MULTIPLIER)
	color = mix_color_from_reagents(reagents.reagent_list)

/obj/item/stack/solid_phase_object/process()
	color = mix_color_from_reagents(reagents.reagent_list)
	if(reagents.total_volume <= 0)
		qdel(src)

/obj/item/stack/solid_phase_object/powder
	name = "Powdered"
	desc = "A ground up mass of" //Reagent name here
	icon_state = "reagent_phase_powder"
	tableVariant = null

/obj/structure/table/reagents
	name = "Reagent Table"

/obj/structure/table/reagents/Destroy()
	QDEL_NULL(reagents)
	. = ..()

/obj/structure/table/reagents/post_create_table(obj/item/item)
	create_reagents(250) //5u per 1 stack
	var/obj/item/stack/solid_phase_object/reagent_source = item
	color = mix_color_from_reagents(reagent_source.reagent_list)
	reagent_source.trans_to(reagents, reagent_source.total_volume)
	var/datum/reagent/reagent = reagent_source.reagent_list[1]
	name += "[reagent.name] Table"
	desc = "A table made out of [reagent.name]"


/obj/structure/table/reagents/AfterPutItemOnTable(obj/item/item, mob/living/user)
	. = ..()
	if(item.reagents)
		reagents.trans_to(item.reagents, 2)
	if(reagents.total_volume <= 0)
		qdel(src)

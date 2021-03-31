///This is different to SSphase - it handles the objects and physical states represented in the game (i.e. the interactable obj)
///This draws from induvidual reagent phases however

PROCESSING_SUBSYSTEM_DEF(phase_states)
	name = "Phase_states"
	init_order = INIT_ORDER_PHASE_STATES
	priority = FIRE_PRIORITY_REAGENTS
	wait = 2 SECONDS
	flags = SS_NO_FIRE| SS_NO_INIT
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	///What time was it when we last ticked
	var/gas_states = list()


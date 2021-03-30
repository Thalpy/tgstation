///This is different to SSphase - it handles the objects and physical states represented in the game (i.e. the interactable obj)
///This draws from induvidual reagent phases however

PROCESSING_SUBSYSTEM_DEF(phase_states)
	name = "Reagents"
	init_order = INIT_ORDER_PHASE_STATES
	priority = FIRE_PRIORITY_REAGENTS
	wait = 0.25 SECONDS
	flags = SS_KEEP_TIMING
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	///What time was it when we last ticked
	var/previous_world_time = 0


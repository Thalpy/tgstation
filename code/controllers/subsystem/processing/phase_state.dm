///This is different to SSphase - it handles the objects and physical states represented in the game
///This draws from induvidual reagent phases however

PROCESSING_SUBSYSTEM_DEF(phase_states)
	name = "Reagents"
	init_order = INIT_ORDER_PHASE_STATES
	priority = FIRE_PRIORITY_REAGENTS
	wait = 0.25 SECONDS //You might think that rate_up_lim has to be set to half, but since everything is normalised around delta_time, it automatically adjusts it to be per second. Magic!
	flags = SS_KEEP_TIMING
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	///What time was it when we last ticked
	var/previous_world_time = 0

atom/mist
	name = "mist cloud"
	desc = "A cloud of gaseous reagents. Be careful of breathing this stuff in!"
	icon_state = "mist"
	icon = 'icons/obj/chemical.dmi'

atom/mist/New(loc, ...)
	. = ..()
	mist.RegisterSignal(loc, COMSIG_TURF_EXPOSE, /atom/mist/proc/on_turf_change())


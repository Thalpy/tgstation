#define SOLID 			1
#define LIQUID			2
#define GAS				3

#define INJECTABLE		(1<<0)	// Makes it possible to add reagents through droppers and syringes.
#define DRAWABLE		(1<<1)	// Makes it possible to remove reagents through syringes.

#define REFILLABLE		(1<<2)	// Makes it possible to add reagents through any reagent container.
#define DRAINABLE		(1<<3)	// Makes it possible to remove reagents through any reagent container.
#define DUNKABLE		(1<<4)	// Allows items to be dunked into this container for transfering reagents. Used in conjunction with the dunkable component.

#define TRANSPARENT		(1<<5)	// Used on containers which you want to be able to see the reagents off.
#define AMOUNT_VISIBLE	(1<<6)	// For non-transparent containers that still have the general amount of reagents in them visible.
#define NO_REACT		(1<<7)	// Applied to a reagent holder, the contents will not react with each other.
#define INSTANT_REACT   (1<<8)  // Applied to a reagent holder, all of the reactions in the reagents datum will be instant. Meant to be used for things like smoke effects where reactions aren't meant to occur

//weakness flags for reagent_holders
#define PH_WEAK 		(1<<9) //weak to pH <2 and >14
#define TEMP_WEAK 		(1<<10) //weak to temperatures over 500

// Is an open container for all intents and purposes.
#define OPENCONTAINER 	(REFILLABLE | DRAINABLE | TRANSPARENT)

// Reagent exposure methods.
/// Used for splashing.
#define TOUCH			(1<<0)
/// Used for ingesting the reagents. Food, drinks, inhaling smoke.
#define INGEST			(1<<1)
/// Used by foams, sprays, and blob attacks.
#define VAPOR			(1<<2)
/// Used by medical patches and gels.
#define PATCH			(1<<3)
/// Used for direct injection of reagents.
#define INJECT			(1<<4)

#define MIMEDRINK_SILENCE_DURATION 30  //ends up being 60 seconds given 1 tick every 2 seconds
///Health threshold for synthflesh and rezadone to unhusk someone
#define UNHUSK_DAMAGE_THRESHOLD 50
///Amount of synthflesh required to unhusk someone
#define SYNTHFLESH_UNHUSK_AMOUNT 100

//used by chem masters and pill presses
#define PILL_STYLE_COUNT 22 //Update this if you add more pill icons or you die
#define RANDOM_PILL_STYLE 22 //Dont change this one though

//used by chem master
#define CONDIMASTER_STYLE_AUTO "auto"
#define CONDIMASTER_STYLE_FALLBACK "_"

#define ALLERGIC_REMOVAL_SKIP "Allergy"

//Used in holder.dm/equlibrium.dm to set values and volume limits
#define CHEMICAL_QUANTISATION_LEVEL 0.0001 //stops floating point errors causing issues with checking reagent amounts
#define CHEMICAL_VOLUME_MINIMUM 0.001 //The smallest amount of volume allowed - prevents tiny numbers
#define CHEMICAL_NORMAL_PH 7.000

//reagent bitflags, used for altering how they works
#define REAGENT_DEAD_PROCESS		(1<<0)	//allows on_mob_dead() if present in a dead body
#define REAGENT_DONOTSPLIT			(1<<1)	//Do not split the chem at all during processing - ignores all purity effects
#define REAGENT_INVISIBLE			(1<<2)	//Doesn't appear on handheld health analyzers.
#define REAGENT_SNEAKYNAME          (1<<3)  //When inverted, the inverted chem uses the name of the original chem
#define REAGENT_SPLITRETAINVOL      (1<<4)  //Retains initial volume of chem when splitting for purity effects

//Chemical reaction flags, for determining reaction specialties
#define REACTION_CLEAR_IMPURE       (1<<0)  //Convert into impure/pure on reaction completion
#define REACTION_CLEAR_INVERSE      (1<<1)  //Convert into inverse on reaction completion when purity is low enough
#define REACTION_CLEAR_RETAIN		(1<<2)	//Clear converted chems retain their purities/inverted purities. Requires 1 or both of the above.
#define REACTION_INSTANT            (1<<3)  //Used to create instant reactions

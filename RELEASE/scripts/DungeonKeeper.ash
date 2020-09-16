script "Dungeon Keeper";
notify "gausie";

import <zlib.ash>;
import <canadv.ash>;

/**
 * GENERAL CLAN MANAGEMENT
 **/
string [int] get_whitelist()
{
	string CLAN_PATTERN = "option value=([0-9]+)>([^<]+)";

	string html = visit_url( "clan_signup.php" );
	string clan_list = html.excise( "Whitelist List", "You are currently whitelisted by" );

	string [int] wl;

	string [int, int] results = clan_list.group_string( CLAN_PATTERN );

	foreach i in results
	{
		int clan_id = results[ i ][ 1 ].to_int();
		wl[clan_id] = results[ i ][ 2 ];
	}

	return wl;
}

boolean [string] get_whitelist_names()
{
	boolean [string] wl_names;

	foreach id, name in get_whitelist()
	{
		wl_names[name] = true;
	}

	return wl_names;
}

boolean join_clan( int clan_id )
{
	if ( clan_id == get_clan_id() )
	{
		return true;
	}

	string html = visit_url( `showclan.php?recruiter=1&whichclan={clan_id}&pwd&whichclan={clan_id}&action=joinclan&apply=Apply+to+this+Clan&confirm=on` );

	return html.contains_text( "clanhalltop.gif" );
}

boolean join_clan( string clan_name )
{
	clan_name = clan_name.to_lower_case();

	if ( clan_name == get_clan_name().to_lower_case() )
	{
		return true;
	}

	foreach id, name in get_whitelist() if ( name == clan_name ) {
		return join_clan( id );
	}

	return false;
}

/**
 * Dungeon Stuff
 */

string DUNGEON_PATTERN = "<div id='([A-Za-z]+)'><center><b>[A-Za-z ]+:<!--[a-z]+:([0-9]+)--><\/b><p><table [^>]+><tr><td [^>]+>(.*?)<\/table><\/div>";
string META_PATTERN = "<center>([A-Za-z\.\(\) ]+)?<b>([0-9]+)<\/b>([A-Za-z\.\(\) ]+)\.<\/center>";
string BLOCK_PATTERN = "<b>([A-Za-z \.]+):?</b><blockquote>(.*?)</blockquote>";
string LOG_PATTERN = "([A-Za-z0-9 _]+) \\(#([0-9]+)\\) (.*?)(?: \\(([0-9]+) turns?\\))?(?:<\/b>)?<br>";

boolean [monster] DREAD_BOSSES = $monsters[Great Wolf of the Air, Falls-From-Sky, Mayor Ghost, Zombie Homeowners' Association, Count Drunkula, The Unkillable Skeleton];

int [location] DREAD_FORCELOC = {
	$location[Dreadsylvanian Woods]: 0,
	$location[Dreadsylvanian Village]: 3,
	$location[Dreadsylvanian Castle]: 6,
};

string [location, int] DREAD_NC_NAMES = {
	$location[Dreadsylvanian Woods]: { 1: "Cabin", 2: "Tallest Tree", 3: "Burrows" },
	$location[Dreadsylvanian Village]: { 1: "Village Square", 2: "Skid Row", 3: "Old Duke's Estate" },
	$location[Dreadsylvanian Castle]: { 1: "Great Hall", 2: "Tower", 3: "Dungeons" },
};

record DreadMonsterType {
	string singular;
	string plural;
	location loc;
};

DreadMonsterType [string] DREAD_MONSTER_TYPES = {
	"bugbears": new DreadMonsterType( "bugbear", "bugbears",$location[Dreadsylvanian Woods] ),
	"ghosts": new DreadMonsterType( "ghost", "ghosts", $location[Dreadsylvanian Village] ),
	"skeletons": new DreadMonsterType( "skeleton", "skeletons", $location[Dreadsylvanian Castle] ),
	"vampires": new DreadMonsterType( "vampire", "vampires", $location[Dreadsylvanian Castle] ),
	"werewolves": new DreadMonsterType( "werewolf", "werewolves", $location[Dreadsylvanian Woods] ),
	"zombies": new DreadMonsterType( "zombie", "zombies", $location[Dreadsylvanian Village] ),
};

int [location] DREAD_SHEETS_REQUIRED = {
	$location[Dreadsylvanian Woods]: 0,
	$location[Dreadsylvanian Village]: 1000,
	$location[Dreadsylvanian Castle]: 2000,
};

record DungeonActionType {
	location loc;
	string choices;
	string type;
	string detail;
	int max;
	string pattern;
};

record DungeonAction {
	int id;
	string user_name;
	int user_id;
	string loc;
	string info;
};

record DungeonActionResult {
	boolean success;
	int amount;
};

record DungeonActionRequirement {
	DungeonActionType action_type;
	DungeonActionType dread_unlock;
	boolean [item] required_items;
	boolean [class] required_class;
};

record DungeonLogs {
	DungeonAction [int] actions;
	int [string] meta;
};

DungeonActionType NULL_AT = new DungeonActionType();

DungeonActionType DREAD_BONE_FLOUR = new DungeonActionType($location[Dreadsylvanian Woods], "1,1,2", "item", "bone flour", -1, "made some bone flour");
DungeonActionType DREAD_AUDITORS_BADGE = new DungeonActionType($location[Dreadsylvanian Woods], "1,2,3", "item", "Dreadsylvania Auditor's Badge", 1, "got a Dreadsylvanian auditor's badge");
DungeonActionType DREAD_LOCK_IMPRESSION = new DungeonActionType($location[Dreadsylvanian Woods], "1,2,4", "item", "complicated lock impression", -1, "made an impression of a complicated lock");
DungeonActionType DREAD_UNLOCK_CABIN = new DungeonActionType($location[Dreadsylvanian Woods], "1,3", "unlocked", "", 1, "unlocked the attic of the cabin");
DungeonActionType DREAD_BANISH_WOODS_SPOOKY = new DungeonActionType($location[Dreadsylvanian Woods], "1,3,1", "", "spooky", 1, "made the forest less spooky");
DungeonActionType DREAD_INTRICATE_MUSIC_BOX = new DungeonActionType($location[Dreadsylvanian Woods], "1,3,1", "item", "intricate music box parts", 1, "made the forest less spooky");
DungeonActionType DREAD_BANISH_WEREWOLVES_WOODS = new DungeonActionType($location[Dreadsylvanian Woods], "1,3,2", "banish", "werewolves", 1, "drove some werewolves out of the forest");
DungeonActionType DREAD_BANISH_VAMPIRES_WOODS = new DungeonActionType($location[Dreadsylvanian Woods], "1,3,3", "banish", "vampires", 1, "drove some vampires out of the castle");
DungeonActionType DREAD_MOXIE_WOODS = new DungeonActionType($location[Dreadsylvanian Woods], "1,3,4", "stat", "moxie", -1, "flipped through a photo album");
DungeonActionType DREAD_KNOCK_KIWI = new DungeonActionType($location[Dreadsylvanian Woods], "2,1,1", "misc", "dread-kiwi", 1, "knocked some fruit loose");
DungeonActionType DREAD_WASTE_KIWI = new DungeonActionType($location[Dreadsylvanian Woods], "2,1,1", "", "", -1, "wasted some fruit");
DungeonActionType DREAD_BANISH_WOODS_SLEAZY = new DungeonActionType($location[Dreadsylvanian Woods], "2,1,2", "banish", "sleaze", 1, "made the forest less sleazy");
DungeonActionType DREAD_UNLOCK_WATCHTOWER = new DungeonActionType($location[Dreadsylvanian Woods], "2,2", "unlocked", "", 1, "unlocked the fire watchtower");
DungeonActionType DREAD_BANISH_GHOSTS_WOODS = new DungeonActionType($location[Dreadsylvanian Woods], "2,2,1", "banish", "ghosts", 1, "drove some ghosts out of the village");
DungeonActionType DREAD_WATCHTOWER_FREDDIES = new DungeonActionType($location[Dreadsylvanian Woods], "2,2,2", "item", "Freddy Kruegerand", 10, "rifled through a footlocker");
DungeonActionType DREAD_MUSCLE_WOODS = new DungeonActionType($location[Dreadsylvanian Woods], "2,2,3", "stat", "muscle", -1, "lifted some weights");
DungeonActionType DREAD_COOL_IRON_INGOT = new DungeonActionType($location[Dreadsylvanian Woods], "3,1,3", "item", "cool iron ingot", -1, "made a cool iron ingot");
DungeonActionType DREAD_UNLOCK_SCHOOLHOUSE = new DungeonActionType($location[Dreadsylvanian Village], "1,1", "unlocked", "", 1, "unlocked the schoolhouse");
DungeonActionType DREAD_BANISH_GHOSTS_VILLAGE = new DungeonActionType($location[Dreadsylvanian Village], "1,1,1", "banish", "ghosts", 1, "drove some ghosts out of the village");
DungeonActionType DREAD_GHOST_PENCIL = new DungeonActionType($location[Dreadsylvanian Village], "1,1,2", "item", "ghost pencil", 10, "collected a ghost pencil");
DungeonActionType DREAD_MYST_VILLAGE = new DungeonActionType($location[Dreadsylvanian Village], "1,1,3", "stat", "mysticality", -1, "read some naughty carvings");
DungeonActionType DREAD_COOLING_IRON_BREASTPLATE = new DungeonActionType($location[Dreadsylvanian Village], "1,2,3,1", "item", "cooling iron breastplate", -1, "made a cool iron breastplate");
DungeonActionType DREAD_COOLING_IRON_HELMET = new DungeonActionType($location[Dreadsylvanian Village], "1,2,3,2", "item", "cooling iron helmet", -1, "made a cool iron helmet");
DungeonActionType DREAD_COOLING_IRON_GREAVES = new DungeonActionType($location[Dreadsylvanian Village], "1,2,3,3", "item", "cooling iron greaves", -1, "made some cool iron greaves");
DungeonActionType DREAD_SHACK_FREDDIES = new DungeonActionType($location[Dreadsylvanian Village], "2,3,1", "item", "Freddy Kruegerand", 10, "looted the tinker's shack");
DungeonActionType DREAD_COMPLICATED_KEY = new DungeonActionType($location[Dreadsylvanian Village], "2,3,2", "item", "replica key", -1, "made a complicated key");
DungeonActionType DREAD_POLISHED_MOON_AMBER = new DungeonActionType($location[Dreadsylvanian Village], "2,3,3", "item", "polished moon-amber", -1, "polished some moon-amber");
DungeonActionType DREAD_CLOCKWORK_BIRD = new DungeonActionType($location[Dreadsylvanian Village], "2,3,4", "item", "unwound mechanical songbird", -1, "made a clockwork bird");
DungeonActionType DREAD_OLD_FUSE = new DungeonActionType($location[Dreadsylvanian Village], "2,3,5", "item", "old fuse", -1, "got some old fuse");
DungeonActionType DREAD_SHEPHERDS_PIE = new DungeonActionType($location[Dreadsylvanian Village], "3,2,2", "item", "Dreadsylvanian shepherd's pie", -1, "made a shepherd's pie");
DungeonActionType DREAD_UNLOCK_MASTER_SUITE = new DungeonActionType($location[Dreadsylvanian Village], "3,1", "unlocked", "", 1, "unlocked the master suite");
DungeonActionType DREAD_BANISH_WEREWOLVES_VILLAGE = new DungeonActionType($location[Dreadsylvanian Village], "3,3,1", "banish", "werewolves", 1, "drove some werewolves out of the forest");
DungeonActionType DREAD_EAU_DE_MORT = new DungeonActionType($location[Dreadsylvanian Village], "3,3,2", "item", "eau de mort", -1, "got a bottle of eau de mort");
DungeonActionType DREAD_GHOST_SHAWL = new DungeonActionType($location[Dreadsylvanian Village], "3,3,3", "item", "ghost shawl", -1, "made a ghost shawl");
DungeonActionType DREAD_UNLOCK_BALLROOM = new DungeonActionType($location[Dreadsylvanian Castle], "1,1", "unlocked", "", 1, "unlocked the ballroom");
DungeonActionType DREAD_BANISH_VAMPIRES_CASTLE = new DungeonActionType($location[Dreadsylvanian Castle], "1,1,1", "banish", "vampires", 1, "drove some vampires out of the castle");
DungeonActionType DREAD_MOXIE_CASTLE = new DungeonActionType($location[Dreadsylvanian Castle], "1,1,2", "stat", "moxie", -1, "twirled on the dance floor");
DungeonActionType DREAD_WEEDY_SKIRT = new DungeonActionType($location[Dreadsylvanian Castle], "1,1,2", "item", "weedy skirt", -1, "twirled on the dance floor");
DungeonActionType DREAD_WAX_BANANA = new DungeonActionType($location[Dreadsylvanian Castle], "1,3,3", "item", "wax banana", 1, "got a wax banana");
DungeonActionType DREAD_UNLOCK_LABORATORY = new DungeonActionType($location[Dreadsylvanian Castle], "2,1", "unlocked", "", 1, "unlocked the lab");
DungeonActionType DREAD_BANISH_BUGBEARS_CASTLE = new DungeonActionType($location[Dreadsylvanian Castle], "2,1,1", "banish", "bugbears", 1, "drove some bugbears out of the forest");
DungeonActionType DREAD_BANISH_ZOMBIES_CASTLE = new DungeonActionType($location[Dreadsylvanian Castle], "2,1,2", "banish", "zombies", 10, "drove some zombies out of the village");
DungeonActionType DREAD_FIX_MACHINE = new DungeonActionType($location[Dreadsylvanian Castle], "2,1,3", "misc", "dread-repair", 1, "fixed The Machine");
DungeonActionType DREAD_USE_MACHINE = new DungeonActionType($location[Dreadsylvanian Castle], "2,1,4", "misc", "dread-skill", 3, "used The Machine, assisted by");
DungeonActionType DREAD_BLOODY_KIWITINI = new DungeonActionType($location[Dreadsylvanian Castle], "2,1,5", "item", "bloody kiwitini", -1, "made a blood kiwitini");
DungeonActionType DREAD_BANISH_SKELETONS_CASTLE = new DungeonActionType($location[Dreadsylvanian Castle], "2,2,1", "banish", "skeletons", 1, "drove some skeletons out of the castle");
DungeonActionType DREAD_MYST_CASTLE = new DungeonActionType($location[Dreadsylvanian Castle], "2,2,2", "stat", "mysticality", -1, "read some ancient secrets");
DungeonActionType DREAD_NECKLACE_RECIPE = new DungeonActionType($location[Dreadsylvanian Castle], "2,2,3", "recipe", "moon-amber necklace", -1, "learned to make a moon-amber necklace");


DungeonActionType [97] ACTION_TYPES = {
	new DungeonActionType($location[none], "0", "combat", "none", -1, "defeated(?! by) +([A-Za-z0-9\-\. ]+?)( x ([0-9]+)|$)"),
	new DungeonActionType($location[none], "0", "defeat", "none", -1, "defeated by +([A-Za-z0-9\-\. ]+?)( x ([0-9]+)|$)"),
	new DungeonActionType($location[none], "0", "carriageman", "none", 2000, "got the carriageman ([0-9]+) sheet\\(s\\) drunker"),
	// Dreadsylvania
	new DungeonActionType($location[Dreadsylvanian Woods], "1,1,1", "item", "dread tarragon", -1, "acquired some dread tarragon"),
	DREAD_BONE_FLOUR,
	new DungeonActionType($location[Dreadsylvanian Woods], "1,1,3", "banish", "stench", 1, "made the forest less stinky"),
	new DungeonActionType($location[Dreadsylvanian Woods], "1,2,1", "item", "Freddy Kruegerand", 10, "recycled some newspapers"),
	new DungeonActionType($location[Dreadsylvanian Woods], "1,2,2", "effect", "Bored Stiff", -1, "read an old diary"),
	DREAD_AUDITORS_BADGE,
	DREAD_LOCK_IMPRESSION,
	DREAD_UNLOCK_CABIN,
	DREAD_BANISH_WOODS_SPOOKY,
	DREAD_INTRICATE_MUSIC_BOX,
	DREAD_BANISH_WEREWOLVES_WOODS,
	DREAD_BANISH_VAMPIRES_WOODS,
	DREAD_MOXIE_WOODS,
	DREAD_KNOCK_KIWI,
	DREAD_WASTE_KIWI,
	DREAD_BANISH_WOODS_SLEAZY,
	new DungeonActionType($location[Dreadsylvanian Woods], "2,1,3", "item", "moon-amber", 1, "acquired a chunk of moon-amber"),
	DREAD_UNLOCK_WATCHTOWER,
	DREAD_BANISH_GHOSTS_VILLAGE,
	DREAD_WATCHTOWER_FREDDIES,
	DREAD_MUSCLE_WOODS,
	new DungeonActionType($location[Dreadsylvanian Woods], "2,3,1", "item", "blood kiwi", 1, "got a blood kiwi"),
	new DungeonActionType($location[Dreadsylvanian Woods], "2,3,2", "item", "Dreadsylvanian seed pod", -1, "got a cool seed pod"),
	new DungeonActionType($location[Dreadsylvanian Woods], "3,1,1", "banish", "hot", 1, "made the forest less hot"),
	new DungeonActionType($location[Dreadsylvanian Woods], "3,1,2", "effect", "Dragged Through the Coals", -1, "got intimate with some hot coals"),
	DREAD_COOL_IRON_INGOT,
	new DungeonActionType($location[Dreadsylvanian Woods], "3,2,1", "banish", "cold", 1, "made the forest less cold"),
	new DungeonActionType($location[Dreadsylvanian Woods], "3,2,2", "stat", "mysticality", -1, "listened to the forest's heart"),
	new DungeonActionType($location[Dreadsylvanian Woods], "3,2,3", "effect", "Nature's Bounty", -1, "drank some nutritious forest goo"),
	new DungeonActionType($location[Dreadsylvanian Woods], "3,3,1", "banish", "bugbears", 1, "drove some bugbears out of the forest "),
	new DungeonActionType($location[Dreadsylvanian Woods], "3,3,2", "item", "Freddy Kruegerand", 10, "found and sold a rare baseball card"),
	DREAD_UNLOCK_SCHOOLHOUSE,
	DREAD_BANISH_GHOSTS_VILLAGE,
	DREAD_GHOST_PENCIL,
	DREAD_MYST_VILLAGE,
	new DungeonActionType($location[Dreadsylvanian Village], "1,2,1", "banish", "cold", 1, "made the village less cold"),
	new DungeonActionType($location[Dreadsylvanian Village], "1,2,2", "item", "Freddy Kruegerand", 10, "looted the blacksmith's till"),
	DREAD_COOLING_IRON_BREASTPLATE,
	DREAD_COOLING_IRON_HELMET,
	DREAD_COOLING_IRON_GREAVES,
	new DungeonActionType($location[Dreadsylvanian Village], "1,3,1", "banish", "spooky", 1, "made the village less spooky"),
	new DungeonActionType($location[Dreadsylvanian Village], "1,3,2", "misc", "dread-hungman", 1, "was hung by a clanmate"),
	new DungeonActionType($location[Dreadsylvanian Village], "1,3,4", "misc", "dread-hangman", 1, "hung a clanmate"),
	new DungeonActionType($location[Dreadsylvanian Village], "2,1,1", "banish", "stinky", 1, "made the village less stinky"),
	new DungeonActionType($location[Dreadsylvanian Village], "2,1,2", "effect", "Sewer-Drenched", -1, "swam in a sewer"),
	new DungeonActionType($location[Dreadsylvanian Village], "2,2,1", "banish", "skeletons", 1, "drove some skeletons out of the castle"),
	new DungeonActionType($location[Dreadsylvanian Village], "2,2,2", "banish", "sleaze", 1, "made the village less sleazy"),
	new DungeonActionType($location[Dreadsylvanian Village], "2,2,3", "stat", "muscle", -1, "moved some bricks around"),
	DREAD_SHACK_FREDDIES,
	DREAD_COMPLICATED_KEY,
	DREAD_POLISHED_MOON_AMBER,
	DREAD_CLOCKWORK_BIRD,
	DREAD_OLD_FUSE,
	new DungeonActionType($location[Dreadsylvanian Village], "3,1,1", "banish", "zombies", 1, "drove some zombies out of the village"),
	new DungeonActionType($location[Dreadsylvanian Village], "3,1,2", "item", "Freddy Kruegerand", 10, "robbed some graves"),
	new DungeonActionType($location[Dreadsylvanian Village], "3,1,3", "effect", "Fifty Ways to Bereave Your Lover", -1, "read some lurid epitaphs"),
	new DungeonActionType($location[Dreadsylvanian Village], "3,2,1", "banish", "hot", 1, "made the village less hot"),
	DREAD_SHEPHERDS_PIE,
	new DungeonActionType($location[Dreadsylvanian Village], "3,2,3", "stat", "moxie", -1, "raided some naughty cabinets"),
	DREAD_UNLOCK_MASTER_SUITE,
	DREAD_BANISH_WEREWOLVES_VILLAGE,
	DREAD_EAU_DE_MORT,
	DREAD_GHOST_SHAWL,
	DREAD_UNLOCK_BALLROOM,
	DREAD_BANISH_VAMPIRES_CASTLE,
	DREAD_MOXIE_CASTLE,
	DREAD_WEEDY_SKIRT,
	new DungeonActionType($location[Dreadsylvanian Castle], "1,2,1", "banish", "cold", 1, "made the castle less cold"),
	new DungeonActionType($location[Dreadsylvanian Castle], "1,2,2", "effect", "Staying Frosty", -1, "frolicked in a freezer"),
	new DungeonActionType($location[Dreadsylvanian Castle], "1,3,1", "item", "dreadful roast", 1, "got some roast beast"),
	new DungeonActionType($location[Dreadsylvanian Castle], "1,3,2", "banish", "stench", 1, "made the castle less stinky"),
	DREAD_WAX_BANANA,
	DREAD_UNLOCK_LABORATORY,
	DREAD_BANISH_BUGBEARS_CASTLE,
	DREAD_BANISH_ZOMBIES_CASTLE,
	DREAD_FIX_MACHINE,
	DREAD_USE_MACHINE,
	DREAD_BLOODY_KIWITINI,
	DREAD_BANISH_SKELETONS_CASTLE,
	DREAD_MYST_CASTLE,
	DREAD_NECKLACE_RECIPE,
	new DungeonActionType($location[Dreadsylvanian Castle], "2,3,1", "banish", "sleaze", 1, "made the castle less sleazy"),
	new DungeonActionType($location[Dreadsylvanian Castle], "2,3,2", "item", "Freddy Kruegerand", 10, "raided a dresser"),
	new DungeonActionType($location[Dreadsylvanian Castle], "2,3,3", "effect", "Magically Fingered", -1, "got magically fingered"),
	new DungeonActionType($location[Dreadsylvanian Castle], "3,1,1", "banish", "spooky", 1, "made the castle less spooky"),
	new DungeonActionType($location[Dreadsylvanian Castle], "3,1,2", "stat", "muscle", -1, "did a whole bunch of pushups"),
	new DungeonActionType($location[Dreadsylvanian Castle], "3,1,3", "mp", "10000", -1, "took a nap on a prison cot"),
	new DungeonActionType($location[Dreadsylvanian Castle], "3,2,1", "banish", "hot", 1, "made the castle less hot"),
	new DungeonActionType($location[Dreadsylvanian Castle], "3,2,2", "item", "Freddy Kruegerands", 10, "sifted through some ashes"),
	new DungeonActionType($location[Dreadsylvanian Castle], "3,2,3", "stat", "all", -1, "relaxed in a furnace"),
	new DungeonActionType($location[Dreadsylvanian Castle], "3,3,1", "item", "stinking agaricus", 1, "got some stinking agaric"),
	new DungeonActionType($location[Dreadsylvanian Castle], "3,3,2", "effect", "Spore-Wreathed", -1, "rolled around in some mushrooms"),
	new DungeonActionType($location[The Slime Tube], "0", "tickle", "", -1, "tickled a Slime uvula" ),
	new DungeonActionType($location[The Slime Tube], "0", "squeeze", "", 5, "squeezed a Slime gall bladder" ),
};

boolean [class] NULL_CLASSES;
boolean [item] NULL_ITEMS;

DungeonActionRequirement [42] ACTION_REQUIREMENTS = {
	new DungeonActionRequirement( DREAD_BONE_FLOUR, NULL_AT, $items[old dry bone], $classes[Seal Clubber, Turtle Tamer] ),
	new DungeonActionRequirement( DREAD_AUDITORS_BADGE, NULL_AT, $items[replica key], NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_LOCK_IMPRESSION, NULL_AT, $items[wax banana], NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_BANISH_WOODS_SPOOKY, DREAD_UNLOCK_CABIN, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_INTRICATE_MUSIC_BOX, DREAD_UNLOCK_CABIN, NULL_ITEMS, $classes[Accordion Thief] ),
	new DungeonActionRequirement( DREAD_BANISH_WEREWOLVES_WOODS, DREAD_UNLOCK_CABIN, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_BANISH_VAMPIRES_WOODS, DREAD_UNLOCK_CABIN, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_MOXIE_WOODS, DREAD_UNLOCK_CABIN, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_KNOCK_KIWI, NULL_AT, NULL_ITEMS, $classes[Seal Clubber, Turtle Tamer] ),
	new DungeonActionRequirement( DREAD_WASTE_KIWI, NULL_AT, NULL_ITEMS, $classes[Seal Clubber, Turtle Tamer] ),
	new DungeonActionRequirement( DREAD_BANISH_WOODS_SLEAZY, NULL_AT, NULL_ITEMS, $classes[Seal Clubber, Turtle Tamer] ),
	new DungeonActionRequirement( DREAD_BANISH_GHOSTS_WOODS, DREAD_UNLOCK_WATCHTOWER, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_WATCHTOWER_FREDDIES, DREAD_UNLOCK_WATCHTOWER, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_MUSCLE_WOODS, DREAD_UNLOCK_WATCHTOWER, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_COOL_IRON_INGOT, NULL_AT, $items[old ball and chain], NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_BANISH_GHOSTS_VILLAGE, DREAD_UNLOCK_SCHOOLHOUSE, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_GHOST_PENCIL, DREAD_UNLOCK_SCHOOLHOUSE, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_MYST_VILLAGE, DREAD_UNLOCK_SCHOOLHOUSE, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_COOLING_IRON_BREASTPLATE, NULL_AT, $items[hothammer, cool iron ingot, warm fur], NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_COOLING_IRON_HELMET, NULL_AT, $items[hothammer, cool iron ingot, warm fur], NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_COOLING_IRON_GREAVES, NULL_AT, $items[hothammer, cool iron ingot, warm fur], NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_SHACK_FREDDIES, NULL_AT, NULL_ITEMS, $classes[Disco Bandit, Accordion Thief] ),
	new DungeonActionRequirement( DREAD_COMPLICATED_KEY, NULL_AT, $items[intricate music box parts, complicated lock impression], $classes[Disco Bandit, Accordion Thief] ),
	new DungeonActionRequirement( DREAD_POLISHED_MOON_AMBER, NULL_AT, $items[moon-amber], $classes[Disco Bandit, Accordion Thief] ),
	// Requires 3 parts...
	new DungeonActionRequirement( DREAD_CLOCKWORK_BIRD, NULL_AT, $items[intricate music box parts, Dreadsylvanian clockwork key], $classes[Disco Bandit, Accordion Thief] ),
	new DungeonActionRequirement( DREAD_OLD_FUSE, NULL_AT, NULL_ITEMS, $classes[Disco Bandit, Accordion Thief] ),
	new DungeonActionRequirement( DREAD_SHEPHERDS_PIE, NULL_AT, $items[dread tarragon, bone flour, dreadful roast, stinking agaricus], $classes[Sauceror, Pastamancer] ),
	new DungeonActionRequirement( DREAD_BANISH_WEREWOLVES_VILLAGE, DREAD_UNLOCK_MASTER_SUITE, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_EAU_DE_MORT, DREAD_UNLOCK_MASTER_SUITE, NULL_ITEMS, NULL_CLASSES ),
	// Requires 10 ghost thread
	new DungeonActionRequirement( DREAD_GHOST_SHAWL, DREAD_UNLOCK_MASTER_SUITE, $items[ghost thread], NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_BANISH_VAMPIRES_CASTLE, DREAD_UNLOCK_BALLROOM, NULL_ITEMS, NULL_CLASSES),
	new DungeonActionRequirement( DREAD_MOXIE_CASTLE, DREAD_UNLOCK_BALLROOM, NULL_ITEMS, NULL_CLASSES),
	// Muddy skirt must be equipped
	new DungeonActionRequirement( DREAD_WEEDY_SKIRT, DREAD_UNLOCK_BALLROOM, $items[muddy skirt, Dreadsylvanian seed pod], NULL_CLASSES),
	new DungeonActionRequirement( DREAD_WAX_BANANA, NULL_AT, NULL_ITEMS, $classes[Sauceror, Pastamancer]),
	new DungeonActionRequirement( DREAD_BANISH_BUGBEARS_CASTLE, DREAD_UNLOCK_LABORATORY, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_BANISH_ZOMBIES_CASTLE, DREAD_UNLOCK_LABORATORY, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_FIX_MACHINE, DREAD_UNLOCK_LABORATORY, $items[skull capacitor], NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_USE_MACHINE, DREAD_UNLOCK_LABORATORY, NULL_ITEMS, NULL_CLASSES ),
	new DungeonActionRequirement( DREAD_BLOODY_KIWITINI, DREAD_UNLOCK_LABORATORY, $items[blood kiwi, eau de mort], $classes[Disco Bandit, Accordion Thief] ),
	new DungeonActionRequirement( DREAD_BANISH_SKELETONS_CASTLE, NULL_AT, NULL_ITEMS, $classes[Sauceror, Pastamancer]),
	new DungeonActionRequirement( DREAD_MYST_CASTLE, NULL_AT, NULL_ITEMS, $classes[Sauceror, Pastamancer]),
	new DungeonActionRequirement( DREAD_NECKLACE_RECIPE, NULL_AT, NULL_ITEMS, $classes[Sauceror, Pastamancer]),
};

boolean can_dungeoneer( location loc )
{
	// @TODO Check carriageman and area progress
	return loc.can_adv();
}

string to_string( DungeonActionType dat )
{
	if ( dat.loc == $location[none] )
	{
		return dat.type;
	}
	else
	{
		return `{dat.loc}:{dat.choices}`;
	}
}

string to_short_name( location loc )
{
	if ( loc.zone != "Dreadsylvania" )
	{
		return loc.to_string();
	}

	return loc.to_string().substring( 15 ).to_lower_case();
}

string get_nc_name( DungeonActionType dat )
{
	int first_choice = dat.choices.substring(0, 1).to_int();
	return DREAD_NC_NAMES[ dat.loc ][ first_choice ];
}

string to_readable( DungeonActionType dat )
{
	switch ( dat.type )
	{
		case "combat":
			return "Defeat a monster";
		case "defeat":
			return "Be defeated by a monster";
		case "carriageman":
			return "Feed the carriageman";
		case "banish":
			if ( DREAD_MONSTER_TYPES contains dat.detail )
			{
				return `Banish {dat.detail} monsters (via the {dat.get_nc_name()})`;
			}
			else
			{
				return `Banish {dat.detail} monsters from the {dat.pattern.split_string(" ")[2]}`;
			}
		case "effect":
			return `Get the effect {dat.detail}`;
		case "stat":
			return `Gain {dat.detail} stats (via the {dat.get_nc_name()})`;
		case "item":
			return `Retrieve {dat.detail} (via the {dat.get_nc_name()})`;
		case "unlocked":
			string [int] pattern_pieces = dat.pattern.split_string(" ");
			return `Unlock the {pattern_pieces[pattern_pieces.count() - 1]}`;
		case "mp":
			return "Restore MP";
		case "misc":
			switch ( dat.detail )
			{
				case "dread-hungman":
					return "Get hung by your clanmate";
				case "dread-hangman":
					return "Hang your clanmate";
				case "dread-kiwi":
					return "Knock a blood kiwi loose";
			}
		default:
			return dat.pattern;
	}

	return "";
}

boolean equals( DungeonActionType a, DungeonActionType b )
{
	return a.to_string() == b.to_string();
}

DungeonActionType get_type( DungeonAction action )
{
	if ( action.id > -1 )
	{
		return ACTION_TYPES[ action.id ];
	}
	else
	{
		return NULL_AT;
	}
}

location get_location( DungeonAction action )
{
	if ( $strings[The Woods, The Village, The Castle] contains action.loc )
	{
		return `Dreadsylvanian {action.loc.substring( 4 )}`.to_location();
	}

	return action.loc.to_location();
}

int get_carriageman_sheets()
{
	return visit_url( "clan_dreadsylvania.php?place=carriage" ).excise( "carriageman is currently ", " sheet" ).to_int();
}

float get_sheets( item it )
{
	if ( it == $item[snifter of thoroughly aged brandy])
	{
		return 3.0;
	}
	if ( it.adventures.index_of( "-" ) < 0 )
    {
        return it.adventures.to_float();
    }
    else
    {
        matcher m = "(-?[0-9]+)-(-?[0-9]+)".create_matcher( it.adventures );

		if ( !m.find() )
		{
			return 0;
		}

        return ( m.group( 1 ).to_int() + m.group( 2 ).to_int() ) / 2.0;
    }
}

item best_carriageman_booze()
{
	item [int] booze;

	foreach it in $items[] if ( it.inebriety > 0 && it.mall_price() > 0 )
	{
		booze[ count( booze ) ] = it;
	}

	sort booze by -( value.get_sheets() / value.mall_price() );

	return booze[ 0 ];
}

boolean feed_carriageman( int sheets_to_feed )
{
	// This loop only buys booze at the expected mall price, and rechecks the best booze once we pass that price
	int loops = 0;

	while ( sheets_to_feed > 0 )
	{
		item booze = best_carriageman_booze();
		float sheets = booze.get_sheets();

		int quantity = buy( ceil( sheets_to_feed / sheets ), booze, booze.mall_price() );

		string result = visit_url( `clan_dreadsylvania.php?place=carriage&action=feedbooze&whichbooze={booze.to_int()}&boozequantity={quantity}` );

		if (result.contains_text( "That'd be a waste" ) || result.contains_text( "already plenty drunk" ) )
		{
			return true;
		}

		sheets_to_feed -= sheets * quantity;

		loops++;

		if ( loops > 2000 )
		{
			return false;
		}
	}

	return true;
}

boolean feed_carriageman()
{
	return feed_carriageman( 2000 - get_carriageman_sheets() );
}

DungeonActionResult run( DungeonActionType dat )
{
	DungeonActionResult result = new DungeonActionResult();

	if ( !dat.loc.can_dungeoneer() )
	{
		return result;
	}

	if ( dat.type == "carriageman" )
	{
		result.success = feed_carriageman();
		return result;
	}

	if ( dat.choices != "0" )
	{
		string [int] choices = dat.choices.split_string( "," );

		if ( DREAD_FORCELOC contains dat.loc )
		{
			int offset = dread_forceloc[ dat.loc ];

			string html = "";

			foreach i, c in choices {
				int choice = c.to_int();

				if ( i == 0 )
				{
					html = visit_url( `clan_dreadsylvania.php?action=forceloc&loc={offset + choice}` );
				}
				else
				{
					html = run_choice( choice );
				}
			}

			switch ( dat.type )
			{
				case "item":
					int [item] booty = html.extract_items();
					item desired_item = dat.detail.to_item();
					result.amount = booty[desired_item];
					result.success = result.amount > 0;
					break;
				case "effect":
					effect desired_effect = dat.detail.to_effect();
					result.success = desired_effect.have_effect() > 0;
					break;
				default:
					result.success = true;
					break;
			}

			return result;
		}
	}

	print( "We don't know how to run this action" );
	return result;
}

boolean are_mutually_exclusive( DungeonActionType a, DungeonActionType b )
{
	return (
		( a.loc == b.loc ) &&
		( a.choices.length() >= 2 ) &&
		( b.choices.length() >= 2 ) &&
		( a.choices.substring( 0, 2 ) == b.choices.substring( 0, 2 ) )
	);
}

// Find mutually exclusive options
DungeonActionType [int] siblings( DungeonActionType dat )
{
	DungeonActionType [int] siblings;

	foreach i, at in ACTION_TYPES if ( are_mutually_exclusive( dat, at ) )
	{
		siblings[ count( siblings ) ] = at;
	}

	return siblings;
}

DungeonActionRequirement find_requirement( DungeonActionType action_type )
{
	foreach i, requirement in action_requirements if ( requirement.action_type.equals( action_type ) )
	{
		return requirement;
	}

	return new DungeonActionRequirement();
}


DungeonActionType identify_action( string log )
{
	foreach i, action in ACTION_TYPES if ( action.pattern.create_matcher( log ).find() )
	{
		return action;
	}

	return NULL_AT;
}

int get_id( DungeonActionType dat )
{
	foreach i, action in ACTION_TYPES if ( action.equals( dat ) )
	{
		return i;
	}

	return -1;
}

string parse_meta( string text )
{
	switch ( text) 
	{
		case " kisses earned in this dungeon so far": return "kisses";
		case "Your clan has defeated  monster(s) in the Castle": return "castle";
		case "Your clan has defeated  monster(s) in the Village": return "village";
		case "Your clan has defeated  monster(s) in the Forest": return "woods";
	}
	
	return "unknown";
}

DungeonAction parse_log( string log, string user_name, int user_id, string loc )
{
	DungeonActionType action_type = log.identify_action();

	DungeonAction action = new DungeonAction( action_type.get_id(), user_name, user_id, loc );

	if ( action.id == -1 )
	{
		print( `Couldn't parse: {log}`, 'red' );
		return action;
	}

	matcher m = action_type.pattern.create_matcher( log );

	switch ( action_type.type ) {
		case "combat":
		case "defeat":
			m.find();
			action.info = m.group( 1 ).to_monster().to_string();
			break;
		case "carriageman":
			m.find();
			action.info = m.group( 1 );
			break;
	}

	return action;
}

DungeonLogs parse_logs( string desired_dungeon, boolean just_meta )
{
	string html = visit_url( "clan_raidlogs.php" );

	DungeonAction [int] actions;
	int [string] metadata;

	matcher dungeon_matcher = DUNGEON_PATTERN.create_matcher( html );

	while ( dungeon_matcher.find() )
	{
		string dungeon_type = dungeon_matcher.group( 1 );
		int dungeon_id = dungeon_matcher.group( 2 ).to_int();
		string contents = dungeon_matcher.group( 3 );

		if ( desired_dungeon != "" && dungeon_type.to_lower_case() != desired_dungeon.to_lower_case() )
		{
			continue;
		}

		matcher meta_matcher = META_PATTERN.create_matcher( contents );

		while ( meta_matcher.find() )
		{
			int number = meta_matcher.group( 2 ).to_int();
			string text = meta_matcher.group( 1 ) + meta_matcher.group( 3 );
			string meta_type = text.parse_meta();
			metadata[ meta_type ] = number;
		}

		if ( just_meta ) break;

		matcher block_matcher = BLOCK_PATTERN.create_matcher( contents );

		while ( block_matcher.find() )
		{
			string loc = block_matcher.group( 1 );
			string logs = block_matcher.group( 2 );

			matcher log_matcher = LOG_PATTERN.create_matcher( logs );

			while ( log_matcher.find() )
			{
				string name = log_matcher.group( 1 );
				int user_id = log_matcher.group( 2 ).to_int();
				string log = log_matcher.group( 3 );
				int turns = max( 1, log_matcher.group( 4 ).to_int() );

				DungeonAction action = log.parse_log( name, user_id, loc );

				for (int i = 0; i < turns; i++)
				{
					actions[ count(actions) ] = action;
				}
			}
		}
	}

	return new DungeonLogs( actions, metadata );
}

DungeonLogs parse_logs( string desired_dungeon )
{
	return parse_logs( desired_dungeon, false );
}

DungeonLogs parse_logs()
{
	return parse_logs( "" );
}

DungeonActionType [int] possible_actions( DungeonAction [int] actions, string zone ) {
	DungeonActionType [int] todo;

	int [string] action_remaining;
	foreach i, action_type in ACTION_TYPES
	{
		action_remaining[ action_type.to_string() ] = action_type.max;
	}

	boolean [string] action_unlocked;

	int [location] progress;

	foreach i, action in actions
	{
		boolean me = action.user_id == my_id().to_int();

		DungeonActionType action_type = action.get_type();

		if ( action_type.type == "combat" )
		{
			progress[action.get_location()] += 1;
		}

		if ( me )
		{
			DungeonActionType [int] siblings = action_type.siblings();
			foreach i, sibling in siblings
			{
				string key = sibling.to_string();
				action_remaining[key] = 0;
			}
		}

		int amount = 1;

		if ( action_type.type == "carriageman" )
		{
			amount = action.info.to_int();
		}

		string key = action_type.to_string();
		int remaining = action_remaining[key];
		action_remaining[key] = ( me ) ? 0 : max( 0, remaining - amount );

		if ( action_type.type == "unlocked" )
		{
			action_unlocked[ key ] = true;
		}
	}

	foreach i, action_type in ACTION_TYPES
	{
		string type = action_type.to_string();

		string action_zone = action_type.loc.zone == "Clan Basement" ? "The Slime Tube" : action_type.loc.zone;

		if ( action_zone != zone )
		{
			// Not for this dungeon
			continue;
		}

		if ( zone == "Dreadsylvania" )
		{
			if ( progress[action_type.loc] > 999 || DREAD_SHEETS_REQUIRED[action_type.loc] > ( 2000 - action_remaining["carriageman"] ) )
			{
				// Skipping because area is cleared
				continue;
			}
		}

		if (action_remaining[type] == 0) {
			// Skipping due to limit
			continue;
		}

		if ( action_type.type == "" )
		{
			continue;
		}

		DungeonActionRequirement requirement = action_type.find_requirement();

		if ( requirement.action_type.type != "" )
		{
			if ( ( requirement.required_class.count() > 0 ) && !( requirement.required_class contains my_class() ) )
			{
				// Skipping due to wrong class
				continue;
			}

			if ( requirement.dread_unlock.type != "" && !action_unlocked[ requirement.dread_unlock.to_string() ] )
			{
				// Skipping due to not unlocked
				continue;
			}
		}

		todo[ count( todo ) ] = action_type;
	}

	return todo;
}

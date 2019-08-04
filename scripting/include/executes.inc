#if defined _executes_included
#endinput
#endif
#define _executes_included

enum Bombsite {
  BombsiteA = 0,
  BombsiteB = 1,
};

enum SpawnSite {
  SpawnSite_Any = 0,
  SpawnSite_A = 1,
  SpawnSite_B = 2,
};

enum SitePref {
  SitePref_None = 0,
  SitePref_A = 1,
  SitePref_B = 2,
  SitePref_Mid = 3,
};

enum StratType {
  StratType_Normal = 0,
  StratType_Pistol = 1,
  StratType_ForceBuy = 2,
};

// Most spawn flags only apply to gun rounds typically.
#define SPAWNFLAG_MOLOTOV (1 << 0)
#define SPAWNFLAG_MAG7 (1 << 1)     // CT only
#define SPAWNFLAG_ALURKER (1 << 2)  // T only
#define SPAWNFLAG_BLURKER (1 << 3)  // T only
#define SPAWNFLAG_FLASH (1 << 4)
#define SPAWNFLAG_SMOKE (1 << 5)

#define SITESTRING(%1) ((%1) == BombsiteA ? "A" : "B")
#define TEAMSTRING(%1) ((%1) == CS_TEAM_CT ? "CT" : "T")

/**
 * Maxmimum length of a nade string. Example: "hfs" is a hegrenade, flashbang, and smoke.
 */
#define NADE_STRING_LENGTH 8

/**
 * Maxmimum length of a weapon name. Example: "weapon_ak47"
 */
#define WEAPON_STRING_LENGTH 32

/**
 * Called right before players get put onto teams for the next round.
 * This is the best place to decide who goes onto what team if you want
 * to change the default behavior.
 *
 * @param rankingQueue a priority queue (see include/priorityqueue.inc)
 * @param waitingQueue a queue of the players waiting to join (see include/queue.inc)
 * @noreturn
 */
forward void Executes_OnPreRoundEnqueue(ArrayList rankingQueue, ArrayList waitingQueue);

/**
 * Called after active players have been placed into the priority scoring queue
 * for the next round. This is a convenient place to change their scores by
 * editing the ranking priority queue itself.
 * (rather than using the Executes_SetRoundPoints native)
 *
 * @param rankingQueue a priority queue (see include/priorityqueue.inc)
 * @noreturn
 */
forward void Executes_OnPostRoundEnqueue(ArrayList rankingQueue);

/**
 * Called when the team sizes are set for the round.
 *
 * @param tCount the number of terrorists that will play the round
 * @param ctcount the number of counter-terrorists that will play the round
 * @noreturn
 */
forward void Executes_OnTeamSizesSet(int& tCount, int& ctCount);

/**
 * Called when a team wins a round.
 *
 * @param winner the winning team (CS_TEAM_T or CS_TEAM_CT)
 * @param tPlayers an ArrayList of the players on the terrorist team
 * @param ctPlayers an ArrayList of the players on the counter-terrorist team
 * @noreturn
 */
forward void Executes_OnRoundWon(int winner, ArrayList tPlayers, ArrayList ctPlayers, int executeId,
                                 StratType stratType);

/**
 * Called after teams have been determined for the round.
 *
 * @param tPlayers an ArrayList of the players on the terrorist team
 * @param ctPlayers an ArrayList of the players on the counter-terrorist team
 * @param bombsite
 * @noreturn
 */
forward void Executes_OnTeamsSet(ArrayList tPlayers, ArrayList ctPlayers, Bombsite bombsite);

/**
 * Called when a client issues a command to bring up a "guns" menu.
 */
forward void Executes_OnGunsCommand(int client);

/**
 * TODO
 */
forward void Executes_GetPlayerSpecialPowers(int client, bool& higherAwpPriority);

/**
 * Returns if a player has joined the game, i.e., if they are on T/Ct or in the waiting queue.
 *
 * @param client a player
 * @return if the player has joined
 */
native bool Executes_IsJoined(int client);

/**
 * Returns if a player is in the waiting queue.
 *
 * @param client a player
 * @return if the player is in the waiting queue
 */
native bool Executes_IsInQueue(int client);

/**
 * Sends a retake formatted message to a client.
 *
 * @param client a player
 * @param format string message
 * @noreturn
 */
native void Executes_Message(int client, const char[] format, any ...);

/**
 * Sends a retake formatted message to all clients.
 *
 * @param format string message
 * @noreturn
 */
native void Executes_MessageToAll(const char[] format, any ...);

/**
 * Returns the number of terrorists for the current round.
 */
native int Executes_GetNumActiveTs();

/**
 * Returns the number of terrorists for the current round.
 */
native int Executes_GetNumActiveCTs();

/**
 * Returns the number of active players (t+ct) for the current round.
 */
native int Executes_GetNumActivePlayers();

/**
 * Returns the bombsite for the current scenario.
 */
native Bombsite Executes_GetCurrrentBombsite();

/**
 * Returns the round points for a client in the current round.
 */
native int Executes_GetRoundPoints(int client);

/**
 * Sets the round points for a client in the current round.
 */
native int Executes_SetRoundPoints(int client, int points);

/**
 * Changes the round points for a client in the current round.
 */
native void Executes_ChangeRoundPoints(int client, int dp);

/**
 * Sets player weapon/equipment information for the current round.
 */
native void Executes_SetPlayerInfo(int client, const char[] primary = "",
                                   const char[] secondary = "", const char[] nades = "",
                                   int health = 100, int armor = 0, bool helmet = false,
                                   bool kit = false);

/**
 * Gets player weapon/equipment information for the current round.
 */
native void Executes_GetPlayerInfo(int client, char primary[WEAPON_STRING_LENGTH],
                                   char secondary[WEAPON_STRING_LENGTH],
                                   char nades[NADE_STRING_LENGTH], int& health, int& armor,
                                   bool& helmet, bool& kit);

/**
 * Returns the total number of live rounds played on the current map.
 */
native int Executes_GetRoundsPlayed();

/**
 * Returns if edit mode is active.
 */
native bool Executes_InEditMode();

/**
 * Returns if the plugin is enabled.
 */
native bool Executes_Enabled();

/**
 * Returns the maximum number of players allowed into the game.
 */
native int Executes_GetMaxPlayers();

native bool Executes_InWarmup();

public SharedPlugin __pl_executes = {
    name = "executes", file = "executes.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_Executes_SetNTVOptional() {
  MarkNativeAsOptional("Executes_IsJoined");
  MarkNativeAsOptional("Executes_IsInQueue");
  MarkNativeAsOptional("Executes_Message");
  MarkNativeAsOptional("Executes_MessageToAll");
  MarkNativeAsOptional("Executes_GetNumActiveTs");
  MarkNativeAsOptional("Executes_GetNumActiveCTs");
  MarkNativeAsOptional("Executes_GetNumActivePlayers");
  MarkNativeAsOptional("Executes_GetCurrrentBombsite");
  MarkNativeAsOptional("Executes_GetRoundPoints");
  MarkNativeAsOptional("Executes_SetRoundPoints");
  MarkNativeAsOptional("Executes_ChangeRoundPoints");
  MarkNativeAsOptional("Executes_SetPlayerInfo");
  MarkNativeAsOptional("Executes_GetPlayerInfo");
  MarkNativeAsOptional("Executes_GetRoundsPlayed");
  MarkNativeAsOptional("Executes_InEditMode");
  MarkNativeAsOptional("Executes_Enabled");
  MarkNativeAsOptional("Executes_GetMaxPlayers");
  MarkNativeAsOptional("Executes_InWarmup");
}
#endif
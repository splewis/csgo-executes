#include <clientprefs>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <smlib>
#include <sourcemod>

#include "include/executes.inc"
#include "include/logdebug.inc"
#include "include/priorityqueue.inc"
#include "include/queue.inc"
#include "include/restorecvars.inc"

#include "../csgo-practice-mode/scripting/include/csutils.inc"

#undef REQUIRE_PLUGIN
#include "../csgo-practice-mode/scripting/include/practicemode.inc"
#include <pugsetup>

#pragma semicolon 1
#pragma newdecls required

/***********************
 *                     *
 *   Global variables  *
 *                     *
 ***********************/

/**
 * The general way players are put on teams is using a system of
 * "round points". Actions during a round earn points, and at the end of the round,
 * players are put into a priority queue using their rounds as the value.
 */
#define POINTS_KILL 50
#define POINTS_DMG 1
#define POINTS_BOMB 40
#define POINTS_LOSS 5000

bool g_Enabled = true;
Handle g_SavedCvars = INVALID_HANDLE;

/** Client variable arrays **/
int g_SpawnIndices[MAXPLAYERS + 1] = 0;
int g_RoundPoints[MAXPLAYERS + 1] = 0;
bool g_PluginTeamSwitch[MAXPLAYERS + 1] = false;
int g_Team[MAXPLAYERS + 1] = 0;
char g_LastItemPickup[MAXPLAYERS + 1][WEAPON_STRING_LENGTH];

/** Queue Handles **/
Handle g_hWaitingQueue = INVALID_HANDLE;
Handle g_hRankingQueue = INVALID_HANDLE;

/** ConVar handles **/
ConVar g_EnabledCvar;
ConVar g_hAutoTeamsCvar;
ConVar g_hCvarVersion;
ConVar g_hEditorEnabled;
ConVar g_hMinPlayers;
ConVar g_hMaxPlayers;
ConVar g_hRatioConstant;
ConVar g_hRoundsToScramble;
ConVar g_hRoundTime;
ConVar g_hRoundTimeVariationCvar;
ConVar g_AutoScrambleCvar;
ConVar g_DisableOtherBombSiteCvar;
ConVar g_ExtraFreezeTimeCvar;

/** Editing global variables **/
bool g_EditMode = false;
bool g_DirtySpawns = false;  // whether the spawns have been edited since loading from the file

/** Win-streak data **/
bool g_ScrambleSignal = false;
int g_WinStreak = 0;
int g_RoundCount = 0;

/** Stored info from the executes config file **/
#define MAX_SPAWNS 512
#define MAX_EXECUTES 64
#define ID_LENGTH 16
#define EXECUTE_NAME_LENGTH 64
#define SPAWN_NAME_LENGTH 64

// Spawn Data
// For the love of god we need structs...
int g_NumSpawns = 0;
char g_SpawnIDs[MAX_SPAWNS][ID_LENGTH];
char g_SpawnNames[MAX_SPAWNS][SPAWN_NAME_LENGTH];
bool g_SpawnDeleted[MAX_SPAWNS];
float g_SpawnPoints[MAX_SPAWNS][3];
float g_SpawnAngles[MAX_SPAWNS][3];
int g_SpawnTeams[MAX_SPAWNS];
int g_SpawnFlags[MAX_SPAWNS];

int g_SpawnGrenadeThrowTimes[MAX_SPAWNS];
GrenadeType g_SpawnGrenadeTypes[MAX_SPAWNS];
float g_SpawnNadePoints[MAX_SPAWNS][3];
float g_SpawnNadeVelocities[MAX_SPAWNS][3];
int g_SpawnSiteFriendly[MAX_SPAWNS][2];  // CT only
int g_SpawnAwpFriendly[MAX_SPAWNS];
int g_SpawnBombFriendly[MAX_SPAWNS];          // T only
int g_SpawnLikelihood[MAX_SPAWNS];            // CT only
ArrayList g_SpawnExclusionRules[MAX_SPAWNS];  // Spawns excluded if this spawn is chosen.

#define DEFAULT_THROWTIME 0
#define MIN_FRIENDLINESS 1
#define AVG_FRIENDLINESS 3
#define MAX_FRIENDLINESS 5

// Generic name buffer
char g_TempNameBuffer[128];
bool g_EditingExecutes = false;  // if true, editing a spawm

// Buffers for spawn editing
bool g_EditingASpawn = false;
int g_EditingSpawnIndex = -1;
int g_NextSpawnId = 0;

int g_EditingSpawnTeam = CS_TEAM_T;
GrenadeType g_EditingSpawnGrenadeType = GrenadeType_None;
float g_EditingSpawnNadePoint[3];
float g_EditingSpawnNadeVelocity[3];
int g_EditingSpawnSiteFriendly[2] = {MIN_FRIENDLINESS, MIN_FRIENDLINESS};
int g_EditingSpawnAwpFriendly = AVG_FRIENDLINESS;
int g_EditingSpawnBombFriendly = AVG_FRIENDLINESS;
int g_EditingSpawnLikelihood = AVG_FRIENDLINESS;
int g_EditingSpawnThrowTime;
int g_EditingSpawnFlags;

// Execute data
int g_SelectedExecute = 0;
StratType g_SelectedExecuteStrat;

int g_NumExecutes = 0;
char g_ExecuteIDs[MAX_EXECUTES][ID_LENGTH];
char g_ExecuteNames[MAX_EXECUTES][EXECUTE_NAME_LENGTH];
bool g_ExecuteDeleted[MAX_EXECUTES];
Bombsite g_ExecuteSites[MAX_EXECUTES];
ArrayList g_ExecuteTSpawnsOptional[MAX_EXECUTES];
ArrayList g_ExecuteTSpawnsRequired[MAX_EXECUTES];
int g_ExecuteLikelihood[MAXPLAYERS + 1];
char g_ExecuteForceBombId[MAX_EXECUTES][ID_LENGTH];
bool g_ExecuteStratTypes[MAX_EXECUTES][3];
bool g_ExecuteFake[MAX_EXECUTES];
float g_ExecuteExtraFreezeTime[MAX_EXECUTES];

// Buffers for execute ediitng
bool g_EditingAnExecute = false;
int g_EditingExecuteIndex = -1;

int g_NextExecuteId = 0;
Bombsite g_EditingExecuteSite = BombsiteA;
ArrayList g_EditingExecuteTRequired = null;
ArrayList g_EditingExecuteTOptional = null;
int g_EditingExecuteLikelihood = AVG_FRIENDLINESS;
char g_EditingExecuteForceBombId[ID_LENGTH];
bool g_EditingExecuteStratTypes[3];
bool g_EditingExecuteFake;

/** Data created for the current scenario **/
Bombsite g_Bombsite;
char g_PlayerPrimary[MAXPLAYERS + 1][WEAPON_STRING_LENGTH];
char g_PlayerSecondary[MAXPLAYERS + 1][WEAPON_STRING_LENGTH];
char g_PlayerNades[MAXPLAYERS + 1][NADE_STRING_LENGTH];
int g_PlayerHealth[MAXPLAYERS + 1];
int g_PlayerArmor[MAXPLAYERS + 1];
bool g_PlayerHelmet[MAXPLAYERS + 1];
bool g_PlayerKit[MAXPLAYERS + 1];

/** Per-round information about the player setup **/
int g_LastTeam[MAXPLAYERS + 1];
int g_RoundStartTime = 0;
int g_BombOwner = -1;
int g_CTAwper = -1;
int g_TAwper = -1;
int g_NumCT = 0;
int g_NumT = 0;
int g_ActivePlayers = 0;
bool g_RoundSpawnsDecided = false;  // spawns are lazily decided on the first player spawn event

Handle g_SilencedM4Cookie = INVALID_HANDLE;
bool g_SilencedM4[MAXPLAYERS + 1];

Handle g_AllowAWPCookie = INVALID_HANDLE;
bool g_AllowAWP[MAXPLAYERS + 1];

// CT
Handle g_CZCTSideCookie = INVALID_HANDLE;
bool g_CZCTSide[MAXPLAYERS + 1];

// T
Handle g_CZTSideCookie = INVALID_HANDLE;
bool g_CZTSide[MAXPLAYERS + 1];

SitePref g_SitePreference[MAXPLAYERS + 1];

int g_EndWarmupTime = 0;
int g_BombSiteAIndex;
int g_BombSiteBIndex;
bool g_ShowingEditorInformation = true;

/** Forwards **/
Handle g_hOnGunsCommand = INVALID_HANDLE;
Handle g_hOnPostRoundEnqueue = INVALID_HANDLE;
Handle g_hOnPreRoundEnqueue = INVALID_HANDLE;
Handle g_hOnTeamSizesSet = INVALID_HANDLE;
Handle g_hOnTeamsSet = INVALID_HANDLE;
Handle g_OnRoundWon = INVALID_HANDLE;
Handle g_OnGetSpecialPowers = INVALID_HANDLE;

#include "executes/editor.sp"
#include "executes/editor_commands.sp"
#include "executes/editor_menus.sp"
#include "executes/execute_setup.sp"
#include "executes/executes_config.sp"
#include "executes/find_sites.sp"
#include "executes/loadout_common.sp"
#include "executes/loadout_forcerounds.sp"
#include "executes/loadout_gunrounds.sp"
#include "executes/loadout_pistolrounds.sp"
#include "executes/natives.sp"
#include "executes/prefs_menu.sp"
#include "executes/util.sp"

// clang-format off
public Plugin myinfo = {
    name = "CS:GO Executes",
    author = "splewis",
    description = "Site execute/defense practice",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-executes"
};
// clang-format on

public void OnPluginStart() {
  InitDebugLog("sm_executes_debug", "exec-dbg");
  LoadTranslations("common.phrases");
  LoadTranslations("executes.phrases");

  /** ConVars **/
  g_EnabledCvar = CreateConVar("sm_executes_enabled", "1", "Whether the plugin is enabled");
  g_hAutoTeamsCvar = CreateConVar("sm_executes_auto_set_teams", "1",
                                  "Whether executes is allowed to automanage team balance");
  g_hEditorEnabled = CreateConVar("sm_executes_editor_enabled", "1",
                                  "Whether the editor can be launched by admins");
  g_hMinPlayers = CreateConVar("sm_executes_minplayers", "5",
                               "Minimum number of players needed to start playing", _, true, 1.0);
  g_hMaxPlayers =
      CreateConVar("sm_executes_maxplayers", "10",
                   "Maximum number of players allowed in the game at once.", _, true, 2.0);
  g_hRatioConstant =
      CreateConVar("sm_executes_ratio_constant", "0.475", "Ratio constant for team sizes.");
  g_hRoundsToScramble = CreateConVar("sm_executes_scramble_rounds", "5",
                                     "Consecutive CT wins to cause a team scramble.");
  g_hRoundTime = CreateConVar("sm_executes_round_time", "40", "Round time in seconds.");
  g_hRoundTimeVariationCvar = CreateConVar("sm_executes_round_time_variation_enabled", "1",
                                           "Whether round time variations are enabled");
  g_AutoScrambleCvar = CreateConVar("sm_executes_auto_scramble", "7",
                                    "If greater than 0, scrambles teams every this many rounds");
  g_ExtraFreezeTimeCvar = CreateConVar("sm_executes_default_extra_freeze_time", "1.3",
                                       "Default extra freezetime for terroristseach round");
  g_DisableOtherBombSiteCvar =
      CreateConVar("sm_executes_disable_other_site", "1",
                   "Whether the other bombsite for an execute is disabled each round");

  HookConVarChange(g_EnabledCvar, EnabledChanged);

  /** Create/Execute executes cvars **/
  AutoExecConfig(true, "executes", "sourcemod/executes");

  g_hCvarVersion = CreateConVar("sm_executes_version", PLUGIN_VERSION, "Current executes version",
                                FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
  g_hCvarVersion.SetString(PLUGIN_VERSION);

  /** Command hooks **/
  AddCommandListener(Command_JoinTeam, "jointeam");
  AddCommandListener(Command_Drop, "drop");

  /** Admin/editor commands **/
  RegAdminCmd("sm_scramble", Command_ScrambleTeams, ADMFLAG_CHANGEMAP,
              "Sets teams to scramble on the next round");
  RegAdminCmd("sm_scrambleteams", Command_ScrambleTeams, ADMFLAG_CHANGEMAP,
              "Sets teams to scramble on the next round");

  RegAdminCmd("sm_edit", Command_EditSpawns, ADMFLAG_CHANGEMAP,
              "Launches the executes spawn editor mode");
  RegAdminCmd("sm_setname", Command_Name, ADMFLAG_CHANGEMAP, "sets name buffer");
  RegAdminCmd("sm_goto", Command_GotoSpawn, ADMFLAG_CHANGEMAP, "Goes to a executes spawn");
  RegAdminCmd("sm_clearbuffers", Command_ClearBuffers, ADMFLAG_CHANGEMAP, "");
  RegAdminCmd("sm_nextspawn", Command_NextSpawn, ADMFLAG_CHANGEMAP, "");
  RegAdminCmd("sm_execute_distribution", Command_ExecuteDistribution, ADMFLAG_CHANGEMAP, "");

  /** Player commands **/
  RegConsoleCmd("sm_guns", Command_Guns);
  RegConsoleCmd("debuginfo", Command_DebugInfo);
  RegAdminCmd("executes_editorinfo", Command_EditorInfo, ADMFLAG_CHANGEMAP);

  /** Event hooks **/
  HookEvent("player_connect_full", Event_PlayerConnectFull);
  HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("player_hurt", Event_DamageDealt);
  HookEvent("player_death", Event_PlayerDeath);
  HookEvent("round_prestart", Event_RoundPreStart);
  HookEvent("round_poststart", Event_RoundPostStart);
  HookEvent("round_freeze_end", Event_RoundFreezeEnd);
  HookEvent("bomb_beginplant", Event_PlantStart);
  HookEvent("bomb_exploded", Event_Bomb);
  HookEvent("bomb_defused", Event_Bomb);
  HookEvent("round_end", Event_RoundEnd);
  HookEvent("item_pickup", Event_ItemPickup);

  g_hOnGunsCommand = CreateGlobalForward("Executes_OnGunsCommand", ET_Ignore, Param_Cell);
  g_hOnPostRoundEnqueue = CreateGlobalForward("Executes_OnPostRoundEnqueue", ET_Ignore, Param_Cell);
  g_hOnPreRoundEnqueue =
      CreateGlobalForward("Executes_OnPreRoundEnqueue", ET_Ignore, Param_Cell, Param_Cell);
  g_hOnTeamSizesSet =
      CreateGlobalForward("Executes_OnTeamSizesSet", ET_Ignore, Param_CellByRef, Param_CellByRef);
  g_hOnTeamsSet =
      CreateGlobalForward("Executes_OnTeamsSet", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
  g_OnRoundWon = CreateGlobalForward("Executes_OnRoundWon", ET_Ignore, Param_Cell, Param_Cell,
                                     Param_Cell, Param_Cell, Param_Cell);
  g_OnGetSpecialPowers = CreateGlobalForward("Executes_GetPlayerSpecialPowers", ET_Ignore,
                                             Param_Cell, Param_CellByRef);

  g_hWaitingQueue = Queue_Init();
  g_hRankingQueue = PQ_Init();

  g_EditingExecuteTRequired = new ArrayList(ID_LENGTH);
  g_EditingExecuteTOptional = new ArrayList(ID_LENGTH);
  for (int i = 0; i < MAX_EXECUTES; i++) {
    g_ExecuteTSpawnsOptional[i] = new ArrayList(ID_LENGTH);
    g_ExecuteTSpawnsRequired[i] = new ArrayList(ID_LENGTH);
  }

  for (int i = 0; i < MAX_SPAWNS; i++) {
    g_SpawnExclusionRules[i] = new ArrayList(ID_LENGTH);
  }

  g_AllowAWPCookie = RegClientCookie("executes_awpchoice", "", CookieAccess_Private);
  g_SilencedM4Cookie = RegClientCookie("executes_silencedm4", "", CookieAccess_Private);
  g_CZCTSideCookie = RegClientCookie("executes_cz_ct_side", "", CookieAccess_Private);
  g_CZTSideCookie = RegClientCookie("executes_cz_t_side", "", CookieAccess_Private);
}

public void OnPluginEnd() {
  if (g_SavedCvars != INVALID_HANDLE) {
    RestoreCvars(g_SavedCvars, true);
  }
}

public void OnMapStart() {
  PQ_Clear(g_hRankingQueue);
  PQ_Clear(g_hWaitingQueue);
  g_ScrambleSignal = false;
  g_WinStreak = 0;
  g_RoundCount = 0;
  g_RoundSpawnsDecided = false;

  ReadMapConfig();

  g_EditingSpawnThrowTime = DEFAULT_THROWTIME;
  g_EditMode = false;
  ClearEditBuffers();
  ServerCommand("sv_infinite_ammo 0");

  CreateTimer(1.0, Timer_ShowSpawns, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
  CreateTimer(0.1, Timer_ShowClosestSpawn, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

  if (!g_Enabled) {
    return;
  }

  ExecConfigs();

  // Restart warmup for players to connect.
  EnsurePausedWarmup();

  if (g_NumSpawns == 0 || g_NumExecutes == 0) {
    LogMessage("Starting edit mode since there isn't enough map data saved");
    StartEditMode();
  }
}

public void OnConfigsExecuted() {
  if (!g_EditMode && LibraryExists("practicemode")) {
    PM_ExitPracticeMode();
  }
}

public void OnMapEnd() {
  if (!g_Enabled) {
    return;
  }

  if (g_DirtySpawns) {
    WriteMapConfig();
  }
}

public int EnabledChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
  bool wasEnabled = !StrEqual(oldValue, "0");
  g_Enabled = !StrEqual(newValue, "0");

  if (wasEnabled && !g_Enabled) {
    if (g_SavedCvars != INVALID_HANDLE)
      RestoreCvars(g_SavedCvars, true);

  } else if (!wasEnabled && g_Enabled) {
    Queue_Clear(g_hWaitingQueue);
    ExecConfigs();
    for (int i = 1; i <= MaxClients; i++) {
      if (IsClientConnected(i) && !IsFakeClient(i)) {
        OnClientConnected(i);
        if (IsClientInGame(i) && IsOnTeam(i)) {
          SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
          Queue_Enqueue(g_hWaitingQueue, i);
          // FakeClientCommand(i, "jointeam 2");
        }
      }
    }
    CS_TerminateRound(0.1, CSRoundEnd_CTWin);
  }
}

public void ExecConfigs() {
  if (g_SavedCvars != INVALID_HANDLE) {
    CloseCvarStorage(g_SavedCvars);
  }
  g_SavedCvars = ExecuteAndSaveCvars("sourcemod/executes/executes_game.cfg");
}

public void OnClientConnected(int client) {
  ResetClientVariables(client);

  if (GetActivePlayerCount() < g_hMinPlayers.IntValue) {
    EnsurePausedWarmup();
  }
}

public void OnClientDisconnect(int client) {
  ResetClientVariables(client);
  CheckRoundDone();
}

/**
 * Helper functions that resets client variables when they join or leave.
 */
public void ResetClientVariables(int client) {
  if (client == g_BombOwner) {
    g_BombOwner = -1;
  }

  Queue_Drop(g_hWaitingQueue, client);
  g_Team[client] = CS_TEAM_SPECTATOR;
  g_PluginTeamSwitch[client] = false;
  g_RoundPoints[client] = -POINTS_LOSS;
  g_SilencedM4[client] = false;
  g_AllowAWP[client] = true;
  g_LastTeam[client] = CS_TEAM_T;
  g_SitePreference[client] = SitePref_None;
  g_LastItemPickup[client] = "";
}

public Action Command_ScrambleTeams(int client, int args) {
  if (g_Enabled) {
    g_ScrambleSignal = true;
    Executes_MessageToAll("%t", "AdminScrambleTeams", client);
  }
}

public Action Command_Guns(int client, int args) {
  if (g_Enabled) {
    Call_StartForward(g_hOnGunsCommand);
    Call_PushCell(client);
    Call_Finish();
    GivePreferencesMenu(client);
  }
  return Plugin_Handled;
}

public Action Command_DebugInfo(int client, int args) {
  ReplyToCommand(client, "Debug info:");
  ReplyToCommand(client, "  Execute: id:%s \"%s\"", g_ExecuteIDs[g_SelectedExecute],
                 g_ExecuteNames[g_SelectedExecute]);
  ReplyToCommand(client, "  Strat type: %d", g_SelectedExecuteStrat);

  int team = GetClientTeam(client);
  ReplyToCommand(client, "  %s Spawns:", TEAMSTRING(team));
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && g_Team[i] == team) {
      int spawn = g_SpawnIndices[i];
      ReplyToCommand(client, "    %L had spawn id:%s \"%s\"%s", i, g_SpawnIDs[spawn],
                     g_SpawnNames[spawn], (g_BombOwner ? " (BOMB)" : ""));
    }
  }

  return Plugin_Handled;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] args) {
  if (!g_Enabled) {
    return Plugin_Continue;
  }

  static char gunsChatCommands[][] = {"gun", "guns", ".gun", ".guns", "!gun", "gnus"};
  for (int i = 0; i < sizeof(gunsChatCommands); i++) {
    if (strcmp(args[0], gunsChatCommands[i], false) == 0) {
      Call_StartForward(g_hOnGunsCommand);
      Call_PushCell(client);
      Call_Finish();
      GivePreferencesMenu(client);
      break;
    }
  }

  return Plugin_Continue;
}

/***********************
 *                     *
 *    Command Hooks    *
 *                     *
 ***********************/

public Action Command_JoinTeam(int client, const char[] command, int argc) {
  if (!g_Enabled || g_hAutoTeamsCvar.IntValue == 0) {
    return Plugin_Continue;
  }

  if (!IsValidClient(client) || argc < 1) {
    return Plugin_Handled;
  }

  if (g_EditMode) {
    MovePlayerToEditMode(client);
    return Plugin_Handled;
  }

  char arg[4];
  GetCmdArg(1, arg, sizeof(arg));
  int team_to = StringToInt(arg);
  int team_from = GetClientTeam(client);

  // if same team, teamswitch controlled by the plugin
  // note if a player hits autoselect their team_from=team_to=CS_TEAM_NONE
  if ((team_from == team_to && team_from != CS_TEAM_NONE) || g_PluginTeamSwitch[client] ||
      IsFakeClient(client)) {
    return Plugin_Continue;
  } else {
    // ignore switches between T/CT team
    if ((team_from == CS_TEAM_CT && team_to == CS_TEAM_T) ||
        (team_from == CS_TEAM_T && team_to == CS_TEAM_CT)) {
      return Plugin_Handled;

    } else if (InWarmup()) {
      int count = GetActivePlayerCount();
      if (count + 1 > g_hMaxPlayers.IntValue) {
        // Enough players already joined
        return PlacePlayer(client);

      } else {
        // Add since we're in a warmup state and check if enough to start
        if (count + 1 >= g_hMinPlayers.IntValue) {
          EndWarmup();
        } else {
          int num = g_hMinPlayers.IntValue - count - 1;
          if (num > 0) {
            if (num == 1) {
              Executes_MessageToAll("Need %d more player before going live - invite your friends!",
                                    num);
            } else {
              Executes_MessageToAll("Need %d more players before going live - invite your friends!",
                                    num);
            }
          }
        }

        return Plugin_Continue;
      }

    } else if (team_to == CS_TEAM_SPECTATOR) {
      // voluntarily joining spectator will not put you in the queue
      SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
      Queue_Drop(g_hWaitingQueue, client);
      g_Team[client] = CS_TEAM_SPECTATOR;

      // check if a team is now empty
      CheckRoundDone();

      return Plugin_Handled;

    } else {
      return PlacePlayer(client);
    }
  }
}

/**
 * Generic logic for placing a player into the correct team when they join.
 */
public Action PlacePlayer(int client) {
  int tHumanCount = 0, ctHumanCount = 0, nPlayers = 0;
  GetTeamsClientCounts(tHumanCount, ctHumanCount);
  nPlayers = tHumanCount + ctHumanCount;

  if (InWarmup() && nPlayers < g_hMaxPlayers.IntValue) {
    return Plugin_Continue;
  }

  if (nPlayers < 2) {
    ChangeClientTeam(client, CS_TEAM_SPECTATOR);
    Queue_Enqueue(g_hWaitingQueue, client);
    CS_TerminateRound(0.0, CSRoundEnd_CTWin);
    return Plugin_Handled;
  }

  ChangeClientTeam(client, CS_TEAM_SPECTATOR);
  Queue_Enqueue(g_hWaitingQueue, client);
  Executes_Message(client, "%t", "JoinedQueueMessage");
  return Plugin_Handled;
}

public void StartWarmup() {
  EnsurePausedWarmup();
}

public void EndWarmup() {
  LogDebug("EndWarmup");
  if (GetTime() - g_EndWarmupTime < 10) {
    LogDebug("EndWarmup early return");
    return;
  }

  g_EndWarmupTime = GetTime();
  Executes_MessageToAll("Starting executes since %d players are connected!",
                        g_hMinPlayers.IntValue);
  ServerCommand("mp_death_drop_gun 1");
  ServerCommand("mp_warmup_pausetimer 0");
  ServerCommand("mp_warmuptime 10");
}

public Action Command_Drop(int client, const char[] command, int argc) {
  if (!g_Enabled) {
    return Plugin_Continue;
  }

  if (!IsPlayer(client)) {
    return Plugin_Continue;
  }

  char weapon[64];
  Client_GetActiveWeaponName(client, weapon, sizeof(weapon));
  int minTime = FindConVar("mp_freezetime").IntValue + 3;
  if (StrEqual(weapon, "weapon_c4") && GetTime() - g_RoundStartTime <= minTime) {
    return Plugin_Stop;
  }

  return Plugin_Continue;
}

/***********************
 *                     *
 *     Event Hooks     *
 *                     *
 ***********************/

/**
 * Called when a player joins a team, silences team join events
 */
public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
  if (!g_Enabled) {
    return Plugin_Continue;
  }

  SetEventBroadcast(event, true);
  return Plugin_Continue;
}

/**
 * Full connect event right when a player joins.
 * This sets the auto-pick time to a high value because mp_forcepicktime is broken and
 * if a player does not select a team but leaves their mouse over one, they are
 * put on that team and spawned, so we can't allow that.
 */
public Action Event_PlayerConnectFull(Event event, const char[] name, bool dontBroadcast) {
  if (!g_Enabled) {
    return;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));
  SetEntPropFloat(client, Prop_Send, "m_fForceTeam", 3600.0);
}

/**
 * Called when a player spawns.
 */
public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  if (!g_Enabled) {
    return;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!IsPlayer(client))
    return;

  if (!InWarmup() && !g_EditMode && IsOnTeam(client) && g_ActivePlayers >= g_hMinPlayers.IntValue) {
    if (!g_RoundSpawnsDecided) {
      g_RoundSpawnsDecided = true;
      g_SelectedExecute = SelectExecute(g_NumT, g_NumCT);
      if (g_SelectedExecute >= 0) {
        LogDebug("Selected execute id %s, \"%s\"", g_ExecuteIDs[g_SelectedExecute],
                 g_ExecuteNames[g_SelectedExecute]);
        g_Bombsite = g_ExecuteSites[g_SelectedExecute];
        SelectRoundSpawns();
        SelectRoundLoadouts();
      } else {
        Executes_MessageToAll("Failed to find a suitable execute for %d terrorists.", g_NumT);
      }
    }

    SetupPlayer(client);
  }

  if (g_EditMode) {
    GivePlayerItem(client, "weapon_ak47");
    GivePlayerItem(client, "weapon_hegrenade");
    GivePlayerItem(client, "weapon_flashbang");
    GivePlayerItem(client, "weapon_smokegrenade");
    GivePlayerItem(client, "weapon_molotov");
  }

  if (!g_EditMode && InWarmup()) {
    if (GetClientTeam(client) == CS_TEAM_T) {
      GivePlayerItem(client, "weapon_ak47");
    } else if (GetClientTeam(client) == CS_TEAM_CT) {
      if (g_SilencedM4[client])
        GivePlayerItem(client, "weapon_m4a1_silencer");
      else
        GivePlayerItem(client, "weapon_m4a1");
    }

    Client_SetArmor(client, 100);
    SetEntProp(client, Prop_Send, "m_bHasHelmet", true);
  }
}

/**
 * Called when a player dies - gives points to killer, and does database stuff with the kill.
 */
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
  if (!Executes_Live()) {
    return;
  }

  int victim = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));

  bool validAttacker = IsValidClient(attacker);
  bool validVictim = IsValidClient(victim);

  if (validAttacker && validVictim) {
    g_LastItemPickup[victim] = "";
    if (HelpfulAttack(attacker, victim)) {
      g_RoundPoints[attacker] += POINTS_KILL;
    } else {
      g_RoundPoints[attacker] -= POINTS_KILL;
    }
  }
}

/**
 * Called when a player deals damage to another player - ads round points if needed.
 */
public Action Event_DamageDealt(Event event, const char[] name, bool dontBroadcast) {
  if (!Executes_Live()) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int victim = GetClientOfUserId(event.GetInt("userid"));
  int damage = event.GetInt("dmg_PlayerHealth");

  bool validAttacker = IsValidClient(attacker);
  bool validVictim = IsValidClient(victim);

  if (validAttacker && validVictim && HelpfulAttack(attacker, victim)) {
    g_RoundPoints[attacker] += (damage * POINTS_DMG);
  }
  return Plugin_Continue;
}

public void OnFlashAssist(int flashThrower, int killer, int victim) {
  g_RoundPoints[flashThrower] += 50;
  LogDebug("Flash assist for %L, killer=%L, victim=%L", flashThrower, killer, victim);
  Executes_Message(flashThrower, "You got a flash assist for blinding %N", victim);
}

public Action Event_PlantStart(Event event, const char[] name, bool dontBroadcast) {
  if (!Executes_Live()) {
    return;
  }

  EnableDisableSite(BombsiteA, true);
  EnableDisableSite(BombsiteB, true);
}

/**
 * Called when the bomb explodes or is defused, gives ponts to the one that planted/defused it.
 */
public Action Event_Bomb(Event event, const char[] name, bool dontBroadcast) {
  if (!Executes_Live()) {
    return;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsValidClient(client)) {
    g_RoundPoints[client] += POINTS_BOMB;
  }
}

public Action Event_ItemPickup(Event event, const char[] name, bool dontBroadcast) {
  if (!Executes_Live()) {
    return;
  }
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsValidClient(client) && GetClientTeam(client) == CS_TEAM_CT) {
    GetEventString(event, "item", g_LastItemPickup[client], WEAPON_STRING_LENGTH);
  }
}

/**
 * Called before any other round start events. This is the best place to change teams
 * since it should happen before respawns.
 */
public Action Event_RoundPreStart(Event event, const char[] name, bool dontBroadcast) {
  g_RoundStartTime = GetTime();

  if (!Executes_Live()) {
    return;
  }

  g_RoundSpawnsDecided = false;
  RoundEndUpdates();
  UpdateTeams();

  if (g_ActivePlayers < g_hMinPlayers.IntValue) {
    StartWarmup();
    Executes_MessageToAll("Starting warmup period until %d players are connected.",
                          g_hMinPlayers.IntValue);
  }
}

public Action Event_RoundPostStart(Event event, const char[] name, bool dontBroadcast) {
  GetBombSitesIndexes();

  if (g_EditMode) {
    BreakBreakableEntities();
  }

  if (!Executes_Live() || g_ActivePlayers < g_hMinPlayers.IntValue) {
    return;
  }

  if (!g_EditMode) {
    int roundTime = g_hRoundTime.IntValue;
    if (g_hRoundTimeVariationCvar.IntValue != 0) {
      roundTime += GetRandomInt(-3, 7);
    }

    GameRules_SetProp("m_iRoundTime", roundTime, 4, 0, true);
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i)) {
        if (g_Team[i] == CS_TEAM_T) {
          Executes_Message(i, "Executing %s: {GREEN}%s", SITESTRING(g_Bombsite),
                           g_ExecuteNames[g_SelectedExecute]);

          // TODO: figure out the font
          // PrintHintText(i, "Executing %s: %s", SITESTRING(g_Bombsite),
          // g_ExecuteNames[g_SelectedExecute]);
        }
      }
    }
  }

  float freezeTime =
      FindConVar("mp_freezetime").FloatValue + g_ExecuteExtraFreezeTime[g_SelectedExecute];
  ThrowRoundNades(freezeTime);
  BreakBreakableEntities();
}

/**
 * Round freezetime end, resets the round points and unfreezes the players.
 */
public Action Event_RoundFreezeEnd(Event event, const char[] name, bool dontBroadcast) {
  if (!Executes_Live()) {
    return;
  }

  for (int i = 1; i <= MaxClients; i++) {
    g_RoundPoints[i] = 0;
  }

  SetTeamMoveType(CS_TEAM_T, MOVETYPE_NONE);

  float time = g_ExtraFreezeTimeCvar.FloatValue;
  if (time < 0.0) {
    time = 0.0;
  }
  CreateTimer(time, Timer_UnfreezeTs);
}

public Action Timer_UnfreezeTs(Handle timer) {
  SetTeamMoveType(CS_TEAM_T, MOVETYPE_WALK);
}

/**
 * Round end event, calls the appropriate winner (T/CT) unction and sets the scores.
 */
public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  if (!Executes_Live()) {
    return;
  }

  if (g_ActivePlayers >= 2) {
    g_RoundCount++;
    int winner = event.GetInt("winner");

    ArrayList ts = new ArrayList();
    ArrayList cts = new ArrayList();

    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i)) {
        if (GetClientTeam(i) == CS_TEAM_CT)
          cts.Push(i);
        else if (GetClientTeam(i) == CS_TEAM_T)
          ts.Push(i);
      }
    }

    Call_StartForward(g_OnRoundWon);
    Call_PushCell(winner);
    Call_PushCell(ts);
    Call_PushCell(cts);
    Call_PushCell(StringToInt(g_ExecuteIDs[g_SelectedExecute]));
    Call_PushCell(g_SelectedExecuteStrat);
    Call_Finish();

    delete ts;
    delete cts;

    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i) && GetClientTeam(i) != winner) {
        g_RoundPoints[i] -= POINTS_LOSS;
      }
    }

    if (winner == CS_TEAM_T) {
      TerroristsWon();
    } else if (winner == CS_TEAM_CT) {
      CounterTerroristsWon();
    }
  }
}

/***********************
 *                     *
 *    Execute logic    *
 *                     *
 ***********************/

/**
 * Called at the end of the round - puts all the players into a priority queue by
 * their score for placing them next round.
 */
public void RoundEndUpdates() {
  PQ_Clear(g_hRankingQueue);

  Call_StartForward(g_hOnPreRoundEnqueue);
  Call_PushCell(g_hRankingQueue);
  Call_PushCell(g_hWaitingQueue);
  Call_Finish();

  for (int client = 1; client <= MaxClients; client++) {
    if (IsPlayer(client) && IsOnTeam(client)) {
      PQ_Enqueue(g_hRankingQueue, client, g_RoundPoints[client]);
      g_LastTeam[client] = GetClientTeam(client);
    }
  }

  while (!Queue_IsEmpty(g_hWaitingQueue) && PQ_GetSize(g_hRankingQueue) < g_hMaxPlayers.IntValue) {
    int client = Queue_Dequeue(g_hWaitingQueue);
    if (IsPlayer(client)) {
      int pts = GetRandomInt(-POINTS_LOSS, -POINTS_LOSS + 50 * POINTS_DMG);
      PQ_Enqueue(g_hRankingQueue, client, pts);
    } else {
      break;
    }
  }

  Call_StartForward(g_hOnPostRoundEnqueue);
  Call_PushCell(g_hRankingQueue);
  Call_Finish();
}

/**
 * Places players onto the correct team.
 * This assumes the priority queue has already been built (e.g. by RoundEndUpdates).
 */
public void UpdateTeams() {
  g_ActivePlayers = PQ_GetSize(g_hRankingQueue);
  if (g_ActivePlayers > g_hMaxPlayers.IntValue) {
    g_ActivePlayers = g_hMaxPlayers.IntValue;
  }

  g_NumCT = RoundToNearest(g_hRatioConstant.FloatValue * float(g_ActivePlayers));
  if (g_NumCT < 1) {
    g_NumCT = 1;
  }

  g_NumT = g_ActivePlayers - g_NumCT;

  Call_StartForward(g_hOnTeamSizesSet);
  Call_PushCellRef(g_NumT);
  Call_PushCellRef(g_NumCT);
  Call_Finish();

  bool autoScramble = (g_AutoScrambleCvar.IntValue > 0) && (g_RoundCount > 0) &&
                      (g_RoundCount % g_AutoScrambleCvar.IntValue == 0);

  if (autoScramble) {
    g_ScrambleSignal = true;
    Executes_MessageToAll("Teams are automatically being scrambled (will be every %d rounds).",
                          g_AutoScrambleCvar.IntValue);
  }

  if (g_ScrambleSignal) {
    int n = GetArraySize(g_hRankingQueue);
    for (int i = 0; i < n; i++) {
      int value = GetRandomInt(1, 1000);
      SetArrayCell(g_hRankingQueue, i, value, 1);
    }
    g_ScrambleSignal = false;
    g_WinStreak = 0;
  }

  ArrayList ts = new ArrayList();
  ArrayList cts = new ArrayList();

  if (g_hAutoTeamsCvar.IntValue != 0) {
    for (int i = 0; i < g_NumCT; i++) {
      int client = PQ_Dequeue(g_hRankingQueue);
      if (IsValidClient(client)) {
        cts.Push(client);
      }
    }

    for (int i = 0; i < g_NumT; i++) {
      int client = PQ_Dequeue(g_hRankingQueue);
      if (IsValidClient(client)) {
        ts.Push(client);
      }
    }
  } else {
    // Use the already set teams
    for (int i = 1; i <= MaxClients; i++) {
      if (IsValidClient(i)) {
        if (GetClientTeam(i) == CS_TEAM_CT) {
          cts.Push(i);
        } else if (GetClientTeam(i) == CS_TEAM_T) {
          ts.Push(i);
        }
      }
    }
    g_NumCT = cts.Length;
    g_NumT = ts.Length;
    g_ActivePlayers = g_NumCT + g_NumT;
  }

  Call_StartForward(g_hOnTeamsSet);
  Call_PushCell(ts);
  Call_PushCell(cts);
  Call_PushCell(g_Bombsite);
  Call_Finish();

  for (int i = 0; i < ts.Length; i++) {
    int client = GetArrayCell(ts, i);
    if (IsValidClient(client)) {
      SwitchPlayerTeam(client, CS_TEAM_T);
      g_Team[client] = CS_TEAM_T;
      g_PlayerPrimary[client] = "weapon_ak47";
      g_PlayerSecondary[client] = "weapon_glock";
      g_PlayerNades[client] = "";
      g_PlayerKit[client] = false;
      g_PlayerHealth[client] = 100;
      g_PlayerArmor[client] = 100;
      g_PlayerHelmet[client] = true;
    }
  }

  for (int i = 0; i < cts.Length; i++) {
    int client = GetArrayCell(cts, i);
    if (IsValidClient(client)) {
      SwitchPlayerTeam(client, CS_TEAM_CT);
      g_Team[client] = CS_TEAM_CT;

      if (StrEqual(g_LastItemPickup[client], "ak47")) {
        g_PlayerPrimary[client] = "weapon_ak47";
      } else if (g_SilencedM4[client]) {
        g_PlayerPrimary[client] = "weapon_m4a1_silencer";
      } else {
        g_PlayerPrimary[client] = "weapon_m4a1";
      }

      g_PlayerSecondary[client] = "weapon_hkp2000";
      g_PlayerNades[client] = "";
      g_PlayerKit[client] = true;
      g_PlayerHealth[client] = 100;
      g_PlayerArmor[client] = 100;
      g_PlayerHelmet[client] = true;
    }
  }

  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && ts.FindValue(i) == -1 && cts.FindValue(i) == -1) {
      // Belongs on spectator.
      g_Team[i] = CS_TEAM_SPECTATOR;
    }
  }

  // if somebody didn't get put in, put them back into the waiting queue
  while (!PQ_IsEmpty(g_hRankingQueue)) {
    int client = PQ_Dequeue(g_hRankingQueue);
    if (IsPlayer(client)) {
      Queue_EnqueueFront(g_hWaitingQueue, client);
    }
  }

  int length = Queue_Length(g_hWaitingQueue);
  for (int i = 0; i < length; i++) {
    int client = GetArrayCell(g_hWaitingQueue, i);
    if (IsValidClient(client)) {
      Executes_Message(client, "%t", "WaitingQueueMessage", g_hMaxPlayers.IntValue);
    }
  }

  delete ts;
  delete cts;
}

static bool ScramblesEnabled() {
  return g_hRoundsToScramble.IntValue >= 1 && g_AutoScrambleCvar.IntValue <= 0;
}

public void CounterTerroristsWon() {
  int toScramble = g_hRoundsToScramble.IntValue;
  g_WinStreak++;

  if (g_WinStreak >= toScramble) {
    if (ScramblesEnabled()) {
      g_ScrambleSignal = true;
      Executes_MessageToAll("%t", "ScrambleMessage", g_WinStreak);
    }
    g_WinStreak = 0;
  } else if (g_WinStreak >= toScramble - 3 && ScramblesEnabled()) {
    Executes_MessageToAll("%t", "WinStreakAlmostToScramble", g_WinStreak, toScramble - g_WinStreak);
  } else if (g_WinStreak >= 3) {
    Executes_MessageToAll("%t", "WinStreak", g_WinStreak);
  }
}

public void TerroristsWon() {
  if (g_WinStreak >= 3) {
    Executes_MessageToAll("%t", "WinStreakOver", g_WinStreak);
  }

  g_WinStreak = 0;
}

void CheckRoundDone() {
  int tHumanCount = 0, ctHumanCount = 0;
  GetTeamsClientCounts(tHumanCount, ctHumanCount);
  if (tHumanCount == 0 || ctHumanCount == 0) {
    CS_TerminateRound(0.1, CSRoundEnd_TerroristWin);
  }
}

public bool Executes_Live() {
  return Executes_Enabled() && !InWarmup() && !Executes_InEditMode();
}

public void BreakBreakableEntities() {
  int ent = -1;
  while ((ent = FindEntityByClassname(ent, "func_breakable")) != -1) {
    AcceptEntityInput(ent, "Break");
  }
  while ((ent = FindEntityByClassname(ent, "func_breakable_surf")) != -1) {
    AcceptEntityInput(ent, "Break");
  }
}

// pugsetup (github.com/splewis/csgo-pug-setup) integrations
#if defined _pugsetup_included
public Action PugSetup_OnSetupMenuOpen(int client, Menu menu, bool displayOnly) {
  int leader = PugSetup_GetLeader(false);
  if (!IsPlayer(leader)) {
    PugSetup_SetLeader(client);
  }

  int style = ITEMDRAW_DEFAULT;
  if (!PugSetup_HasPermissions(client, Permission_Leader) || displayOnly) {
    style = ITEMDRAW_DISABLED;
  }

  if (g_Enabled) {
    AddMenuItem(menu, "disableexecutes", "Disable executes", style);
  } else {
    AddMenuItem(menu, "enableexecutes", "Enable executes", style);
  }

  return Plugin_Continue;
}

public void PugSetup_OnSetupMenuSelect(Menu menu, int client, const char[] selected_info,
                                int selected_position) {
  if (StrEqual(selected_info, "disableexecutes")) {
    SetConVarInt(g_EnabledCvar, 0);
    PugSetup_GiveSetupMenu(client, false, selected_position);
  } else if (StrEqual(selected_info, "enableexecutes")) {
    SetConVarInt(g_EnabledCvar, 1);
    PugSetup_GiveSetupMenu(client, false, selected_position);
  }
}
#endif

#tryinclude "manual_version.sp"
#if !defined PLUGIN_VERSION
#define PLUGIN_VERSION "1.0.0-dev"
#endif

#define INTEGER_STRING_LENGTH 20  // max number of digits a 64-bit integer can use up as a string
// this is for converting ints to strings when setting menu values/cookies

#include <cstrike>
#include <smlib>

char g_ColorNames[][] = {"{NORMAL}",     "{DARK_RED}",    "{PURPLE}",    "{GREEN}",
                         "{MOSS_GREEN}", "{LIGHT_GREEN}", "{LIGHT_RED}", "{GRAY}",
                         "{ORANGE}",     "{LIGHT_BLUE}",  "{DARK_BLUE}", "{PURPLE}"};
char g_ColorCodes[][] = {"\x01", "\x02", "\x03", "\x04", "\x05", "\x06",
                         "\x07", "\x08", "\x09", "\x0B", "\x0C", "\x0E"};

/**
 * Switches a player to a new team.
 */
stock void SwitchPlayerTeam(int client, int team) {
  if (GetClientTeam(client) == team)
    return;

  g_PluginTeamSwitch[client] = true;
  if (team > CS_TEAM_SPECTATOR) {
    CS_SwitchTeam(client, team);
    CS_UpdateClientModel(client);
  } else {
    ChangeClientTeam(client, team);
  }
  g_PluginTeamSwitch[client] = false;
}

/**
 * Returns if the 2 players should be fighting each other.
 * Returns false on friendly fire/suicides.
 */
stock bool HelpfulAttack(int attacker, int victim) {
  if (!IsValidClient(attacker) || !IsValidClient(victim)) {
    return false;
  }
  int ateam = GetClientTeam(attacker);  // Get attacker's team
  int vteam = GetClientTeam(victim);    // Get the victim's team
  return ateam != vteam && attacker != victim;
}

/**
 * Returns the Human counts of the T & CT Teams.
 * Use this function for optimization if you have to get the counts of both teams,
 */
stock void GetTeamsClientCounts(int &tHumanCount, int &ctHumanCount) {
  for (int client = 1; client <= MaxClients; client++) {
    if (IsClientConnected(client) && IsClientInGame(client)) {
      if (GetClientTeam(client) == CS_TEAM_T)
        tHumanCount++;

      else if (GetClientTeam(client) == CS_TEAM_CT)
        ctHumanCount++;
    }
  }
}

/**
 * Returns the number of players currently on an active team (T/CT).
 */
stock int GetActivePlayerCount() {
  int count = 0;
  for (int client = 1; client <= MaxClients; client++) {
    if (IsClientConnected(client) && IsClientInGame(client)) {
      if (GetClientTeam(client) == CS_TEAM_T)
        count++;
      else if (GetClientTeam(client) == CS_TEAM_CT)
        count++;
    }
  }
  return count;
}

/**
 * Returns if a player is on an active/player team.
 */
stock bool IsOnTeam(int client) {
  int team = GetClientTeam(client);
  return (team == CS_TEAM_CT) || (team == CS_TEAM_T);
}

stock bool IsConnected(int client) {
  return client > 0 && client <= MaxClients && IsClientConnected(client) && !IsFakeClient(client);
}

/**
 * Function to identify if a client is valid and in game.
 */
stock bool IsValidClient(int client) {
  if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
    return true;
  return false;
}

/**
 * Function to identify if a client is valid and in game.
 */
stock bool IsPlayer(int client) {
  return IsValidClient(client) && !IsFakeClient(client);
}

stock void AddMenuOption(Menu menu, const char[] info, const char[] display, any ...) {
  char formattedDisplay[128];
  VFormat(formattedDisplay, sizeof(formattedDisplay), display, 4);
  menu.AddItem(info, formattedDisplay);
}

stock void AddMenuOptionDisabled(Menu menu, const char[] info, const char[] display, any ...) {
  char formattedDisplay[128];
  VFormat(formattedDisplay, sizeof(formattedDisplay), display, 4);
  menu.AddItem(info, formattedDisplay, ITEMDRAW_DISABLED);
}

/**
 * Adds an integer to a menu as a string choice.
 */
stock void AddMenuInt(Menu menu, int value, const char[] display) {
  char buffer[INTEGER_STRING_LENGTH];
  IntToString(value, buffer, sizeof(buffer));
  menu.AddItem(buffer, display);
}

/**
 * Adds an integer to a menu as a string choice with the integer as the display.
 */
stock void AddMenuInt2(Menu menu, int value) {
  char buffer[INTEGER_STRING_LENGTH];
  IntToString(value, buffer, sizeof(buffer));
  menu.AddItem(buffer, buffer);
}

/**
 * Gets an integer to a menu from a string choice.
 */
stock int GetMenuInt(Menu menu, int param2) {
  char choice[INTEGER_STRING_LENGTH];
  menu.GetItem(param2, choice, sizeof(choice));
  return StringToInt(choice);
}

/**
 * Adds a boolean to a menu as a string choice.
 */
stock void AddMenuBool(Menu menu, bool value, const char[] display) {
  int convertedInt = value ? 1 : 0;
  AddMenuInt(menu, convertedInt, display);
}

/**
 * Gets a boolean to a menu from a string choice.
 */
stock bool GetMenuBool(Menu menu, int param2) {
  return GetMenuInt(menu, param2) != 0;
}

/**
 * Returns a random index from an array.
 */
stock int RandomIndex(ArrayList array) {
  int len = array.Length;
  if (len == 0)
    ThrowError("Can't get random index from empty array");
  return GetRandomInt(0, len - 1);
}

/**
 * Returns a random element from an array.
 */
stock int RandomElement(ArrayList array) {
  return array.Get(RandomIndex(array));
}

/**
 * Returns a randomly-created boolean.
 */
stock bool GetRandomBool() {
  return GetRandomInt(0, 1) == 0;
}

/**
 * Returns a handle to a cookie with the given name, creating it if it doesn't exist.
 */
stock Handle FindNamedCookie(const char[] cookieName) {
  Handle cookie = FindClientCookie(cookieName);
  if (cookie == null) {
    cookie = RegClientCookie(cookieName, "", CookieAccess_Protected);
  }
  return cookie;
}

/**
 * Sets the value of a client cookie given the cookie name.
 */
stock void SetCookieStringByName(int client, const char[] cookieName, const char[] value) {
  Handle cookie = FindNamedCookie(cookieName);
  SetClientCookie(client, cookie, value);
  delete cookie;
}

/**
 * Gets the value of a client cookie given the cookie name.
 */
stock void GetCookieStringByName(int client, const char[] cookieName, char[] buffer, int length) {
  Handle cookie = FindNamedCookie(cookieName);
  GetClientCookie(client, cookie, buffer, length);
  delete cookie;
}

/**
 * Sets a cookie to an integer value by converting it to a string.
 */
stock void SetCookieIntByName(int client, const char[] cookieName, int value) {
  char buffer[INTEGER_STRING_LENGTH];
  IntToString(value, buffer, sizeof(buffer));
  SetCookieStringByName(client, cookieName, buffer);
}

/**
 * Fetches the value of a cookie that is an integer.
 */
stock int GetCookieIntByName(int client, const char[] cookieName) {
  char buffer[INTEGER_STRING_LENGTH];
  GetCookieStringByName(client, cookieName, buffer, sizeof(buffer));
  return StringToInt(buffer);
}

/**
 * Sets a cookie to a boolean value.
 */
stock void SetCookieBoolByName(int client, const char[] cookieName, bool value) {
  int convertedInt = value ? 1 : 0;
  SetCookieIntByName(client, cookieName, convertedInt);
}

/**
 * Gets a cookie that represents a boolean.
 */
stock bool GetCookieBoolByName(int client, const char[] cookieName) {
  return GetCookieIntByName(client, cookieName) != 0;
}

/**
 * Sets a cookie to an integer value by converting it to a string.
 */
stock void SetCookieInt(int client, Handle cookie, int value) {
  char buffer[INTEGER_STRING_LENGTH];
  IntToString(value, buffer, sizeof(buffer));
  SetClientCookie(client, cookie, buffer);
}

/**
 * Fetches the value of a cookie that is an integer.
 */
stock int GetCookieInt(int client, Handle cookie, int defaultValue = 0) {
  char buffer[INTEGER_STRING_LENGTH];
  GetClientCookie(client, cookie, buffer, sizeof(buffer));
  if (StrEqual(buffer, "")) {
    return defaultValue;
  }

  return StringToInt(buffer);
}

/**
 * Sets a cookie to a boolean value.
 */
stock void SetCookieBool(int client, Handle cookie, bool value) {
  int convertedInt = value ? 1 : 0;
  SetCookieInt(client, cookie, convertedInt);
}

/**
 * Gets a cookie that represents a boolean.
 */
stock bool GetCookieBool(int client, Handle cookie, bool defaultValue = false) {
  return GetCookieInt(client, cookie, defaultValue) != 0;
}

stock bool Chance(float p) {
  float f = GetRandomFloat();
  return f < p;
}

/**
 * Fills a buffer with the current map name,
 * with any directory information removed.
 * Example: de_dust2 instead of workshop/125351616/de_dust2
 */
stock void GetCleanMapName(char[] buffer, int size) {
  char mapName[PLATFORM_MAX_PATH + 1];
  GetCurrentMap(mapName, sizeof(mapName));
  int last_slash = 0;
  int len = strlen(mapName);
  for (int i = 0; i < len; i++) {
    if (mapName[i] == '/')
      last_slash = i + 1;
  }
  strcopy(buffer, size, mapName[last_slash]);
}

/**
 * Applies colorized characters across a string to replace color tags.
 */
stock void Colorize(char[] msg, int size, bool strip = false) {
  for (int i = 0; i < sizeof(g_ColorNames); i++) {
    if (strip) {
      ReplaceString(msg, size, g_ColorNames[i], "\x01");
    } else {
      ReplaceString(msg, size, g_ColorNames[i], g_ColorCodes[i]);
    }
  }
}

stock bool InWarmup() {
  return GameRules_GetProp("m_bWarmupPeriod") != 0;
}

stock void EnsurePausedWarmup() {
  if (!InWarmup()) {
    StartPausedWarmup();
  }

  ServerCommand("mp_warmup_pausetimer 1");
  ServerCommand("mp_do_warmup_period 1");
  ServerCommand("mp_warmup_pausetimer 1");
  ServerCommand("mp_death_drop_gun 0");
}

stock void StartPausedWarmup() {
  ServerCommand("mp_warmup_start");
  ServerCommand("mp_warmuptime 120");  // this value must be greater than 6 or the warmup countdown
                                       // will always start
  ServerCommand("mp_warmup_pausetimer 1");
}

stock void StartTimedWarmup(int time) {
  ServerCommand("mp_do_warmup_period 1");
  ServerCommand("mp_warmup_pausetimer 0");
  ServerCommand("mp_warmuptime %d", time);
  ServerCommand("mp_warmup_start");
  ServerCommand("mp_warmup_start");  // don't ask.
}

stock void CopyList(ArrayList list1, ArrayList list2) {
  char buffer[ID_LENGTH];
  for (int i = 0; i < list1.Length; i++) {
    list1.GetString(i, buffer, sizeof(buffer));
    list2.PushString(buffer);
  }
}

stock int WipeFromList(ArrayList list, const char[] str) {
  int count = 0;
  for (int idx = list.FindString(str); idx >= 0; idx = list.FindString(str)) {
    count++;
    list.Erase(idx);
  }
  return count;
}

stock void AddRepeatedElement(ArrayList list, int element, int count = 1) {
  for (int i = 0; i < count; i++) {
    list.Push(element);
  }
}

stock void SetTeamMoveType(int team, MoveType moveType) {
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && GetClientTeam(i) == team)
      SetEntityMoveType(i, moveType);
  }
}

stock int CountArrayListOccurances(ArrayList list, int element) {
  int count = 0;
  for (int i = 0; i < list.Length; i++) {
    if (list.Get(i) == element)
      count++;
  }
  return count;
}

stock int GetOtherTeam(int team) {
  return (team == CS_TEAM_CT) ? CS_TEAM_T : CS_TEAM_CT;
}

stock Bombsite GetOtherSite(Bombsite site) {
  return (site == BombsiteA) ? BombsiteB : BombsiteA;
}

stock bool InFreezeTime() {
  return GameRules_GetProp("m_bFreezePeriod") != 0;
}

stock bool EnforceDirectoryExists(const char[] smPath) {
  char dir[PLATFORM_MAX_PATH + 1];
  BuildPath(Path_SM, dir, sizeof(dir), smPath);
  if (!DirExists(dir)) {
    if (!CreateDirectory(dir, 511)) {
      LogError("Failed to create directory %s", dir);
      return false;
    }
  }
  return true;
}
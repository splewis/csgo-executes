public int SelectExecute(int tCount, int ctCount) {
  ArrayList potentialExecutes = new ArrayList();

  // TODO: add some cvars for these.
  if (g_RoundCount <= 3) {
    g_SelectedExecuteStrat = StratType_Pistol;
    AddExecuteType(potentialExecutes, tCount, ctCount, StratType_Pistol);
  }

  if (g_RoundCount <= 5 && potentialExecutes.Length == 0) {
    g_SelectedExecuteStrat = StratType_ForceBuy;
    AddExecuteType(potentialExecutes, tCount, ctCount, StratType_ForceBuy);
  }

  if (potentialExecutes.Length == 0) {
    g_SelectedExecuteStrat = StratType_Normal;
    AddExecuteType(potentialExecutes, tCount, ctCount, StratType_Normal);
  }

  if (potentialExecutes.Length == 0) {
    delete potentialExecutes;
    LogError("Failed to find a suitable execute for %d T and %d CT players", tCount, ctCount);
    return -1;
  }

  int choice = RandomElement(potentialExecutes);
  delete potentialExecutes;
  return choice;
}

static void AddExecuteType(ArrayList potentialExecutes, int tCount, int ctCount, StratType type) {
  for (int executeIndex = 0; executeIndex < g_NumExecutes; executeIndex++) {
    if (g_ExecuteStratTypes[executeIndex][type]) {
      int count = ExecuteValid(tCount, ctCount, executeIndex);
      AddRepeatedElement(potentialExecutes, executeIndex, count);
    }
  }
}

public int ExecuteValid(int tCount, int ctCount, int execute) {
  if (g_ExecuteDeleted[execute]) {
    return 0;
  }

  // No fakes unless we have 4 T's and 4 CT's.
  if (g_ExecuteFake[execute] && tCount + ctCount <= 8) {
    return 0;
  }

  int minT = g_ExecuteTSpawnsRequired[execute].Length;
  int maxT = minT + g_ExecuteTSpawnsOptional[execute].Length;

  if (tCount >= minT && tCount <= maxT) {
    return g_ExecuteLikelihood[execute];
  }

  // TODO: On pistol rounds, favor exeutes with a low minT requirement

  return 0;
}

public void SelectRoundSpawns() {
  AssignTSpawns(g_NumT, g_NumCT, g_Bombsite);
  AssignCTSpawns(g_NumT, g_NumCT, g_Bombsite);

  // Disable other bombsite
  EnableDisableBombSites();
}

public void EnableDisableBombSites() {
  if (g_DisableOtherBombSiteCvar.IntValue == 0) {
    EnableDisableSite(BombsiteA, true);
    EnableDisableSite(BombsiteB, true);
  } else if (g_Bombsite == BombsiteA) {
    EnableDisableSite(BombsiteA, true);
    EnableDisableSite(BombsiteB, false);
  } else {
    EnableDisableSite(BombsiteA, false);
    EnableDisableSite(BombsiteB, true);
  }
}

public void EnableDisableSite(Bombsite site, bool enabled) {
  int index = (site == BombsiteA) ? g_BombSiteAIndex : g_BombSiteBIndex;
  if (IsValidEntity(index)) {
    AcceptEntityInput(index, enabled ? "Enable" : "Disable");
  }
}

public void SelectRoundLoadouts() {
  ArrayList tPlayers = new ArrayList();
  ArrayList ctPlayers = new ArrayList();
  for (int i = 1; i <= MAXPLAYERS; i++) {
    if (IsPlayer(i)) {
      if (g_Team[i] == CS_TEAM_CT)
        ctPlayers.Push(i);
      else if (g_Team[i] == CS_TEAM_T)
        tPlayers.Push(i);
    }
  }

  switch (g_SelectedExecuteStrat) {
    case StratType_Normal:
      GunRounds_Assign(tPlayers, ctPlayers, g_Bombsite);
    case StratType_Pistol:
      PistolRounds_Assign(tPlayers, ctPlayers, g_Bombsite);
    case StratType_ForceBuy:
      ForceRounds_Assign(tPlayers, ctPlayers, g_Bombsite);
  }

  delete tPlayers;
  delete ctPlayers;
}

public void AssignTSpawns(int tCount, int ctCount, Bombsite site) {
  ArrayList chosenSpawns = new ArrayList();
  ArrayList clients = new ArrayList();
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && g_Team[i] == CS_TEAM_T) {
      clients.Push(i);
    }
  }

  // Pick from required spawns first.
  ArrayList potentialSpawns = new ArrayList();
  AddPotentialSpawns(g_ExecuteTSpawnsRequired[g_SelectedExecute], potentialSpawns, site);
  while (chosenSpawns.Length < tCount && potentialSpawns.Length > 0) {
    int choiceIndex = RandomIndex(potentialSpawns);
    int spawn = potentialSpawns.Get(choiceIndex);
    potentialSpawns.Erase(choiceIndex);
    chosenSpawns.Push(spawn);
    LogDebug("Adding required spawn id %s to T spawns (index=%d)", g_SpawnIDs[spawn], spawn);
  }

  // Now pick from optional spawns.
  bool nolurkers = (tCount <= 4) || g_ExecuteFake[g_SelectedExecute];
  potentialSpawns.Clear();
  AddPotentialSpawns(g_ExecuteTSpawnsOptional[g_SelectedExecute], potentialSpawns, site, nolurkers);
  while (chosenSpawns.Length < tCount && potentialSpawns.Length > 0) {
    int choiceIndex = RandomIndex(potentialSpawns);
    int spawn = potentialSpawns.Get(choiceIndex);
    potentialSpawns.Erase(choiceIndex);
    chosenSpawns.Push(spawn);
    LogDebug("Adding optional spawn id %s to T spawns (index=%d)", g_SpawnIDs[spawn], spawn);
  }

  int forceBombSpawnIndex = SpawnIdToIndex(g_ExecuteForceBombId[g_SelectedExecute]);
  bool hasForceBomb = (chosenSpawns.FindValue(forceBombSpawnIndex) >= 0);
  AssignSpawnsToClients(chosenSpawns, clients);

  if (hasForceBomb) {
    // Assign the bomb carrier spawn to the forced spawn
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i) && g_Team[i] == CS_TEAM_T && g_SpawnIndices[i] == forceBombSpawnIndex) {
        g_BombOwner = i;
        LogDebug("Forced bomb to id \"%s\", index=%d, client=%L",
                 g_ExecuteForceBombId[g_SelectedExecute], forceBombSpawnIndex, i);
        break;
      }
    }

  } else {
    // Assign bomb carrier spawn (g_BombOwner)
    ArrayList potentialBombCarriers = new ArrayList();
    for (int client = 1; client <= MaxClients; client++) {
      int spawn = g_SpawnIndices[client];
      if (IsPlayer(client) && g_Team[client] == CS_TEAM_T && !IsLurkerSpawn(spawn, site) &&
          g_SpawnBombFriendly[spawn] >= 2) {
        AddRepeatedElement(potentialBombCarriers, client, 3 * (g_SpawnBombFriendly[spawn] + 2));
      }
    }

    // Fallback if no bomb carriers found.
    if (potentialBombCarriers.Length == 0) {
      char mapName[PLATFORM_MAX_PATH + 1];
      GetCleanMapName(mapName, sizeof(mapName));
      LogError("Falling back to a random T to be bomb carrier: map=%s, execute id=%s, tCount=%d",
               mapName, g_ExecuteIDs[g_SelectedExecute], tCount);
      for (int client = 1; client <= MaxClients; client++) {
        if (IsPlayer(client) && g_Team[client] == CS_TEAM_T) {
          potentialBombCarriers.Push(client);
        }
      }
    }

    if (potentialBombCarriers.Length > 0) {
      g_BombOwner = RandomElement(potentialBombCarriers);
      LogDebug("Randomly chosen %L to recieve the bomb", g_BombOwner);
    }

    delete potentialBombCarriers;
  }

  // Assign T awper
  g_TAwper = -1;
  ArrayList potentialAwpers = new ArrayList();
  if (Chance(AwperProbability(tCount))) {
    for (int client = 1; client <= MaxClients; client++) {
      int spawn = g_SpawnIndices[client];
      if (g_BombOwner != client && MinDistanceToOtherSpawns(chosenSpawns, spawn) <= 500.0 &&
          g_SpawnAwpFriendly[spawn] >= 3 && !IsLurkerSpawn(spawn, site) && IsPlayer(client) &&
          g_Team[client] == CS_TEAM_T && g_AllowAWP[client]) {
        int weight = g_SpawnAwpFriendly[spawn];
        if (ElevatedAwpProbability(client)) {
          weight = 7 * g_SpawnAwpFriendly[spawn];
        }
        if (StrEqual(g_LastItemPickup[client], "awp", false)) {
          weight *= 10;
        }
        AddRepeatedElement(potentialAwpers, client, weight);
      }
    }
    if (potentialAwpers.Length >= 1) {
      g_TAwper = RandomElement(potentialAwpers);
    }
  }

  delete potentialAwpers;
  delete potentialSpawns;
  delete chosenSpawns;
  delete clients;
}

static bool IsLurkerSpawn(int spawn, Bombsite site) {
  if (site == BombsiteA)
    return HasFlag(spawn, SPAWNFLAG_ALURKER);
  else
    return HasFlag(spawn, SPAWNFLAG_BLURKER);
}

static float MinDistanceToOtherSpawns(ArrayList chosenSpawns, int spawn) {
  float minDist = -1.0;
  for (int i = 0; i < chosenSpawns.Length; i++) {
    int otherSpawn = chosenSpawns.Get(i);
    if (spawn != otherSpawn) {
      float dist = GetVectorDistance(g_SpawnPoints[spawn], g_SpawnPoints[otherSpawn]);
      if (minDist < 0 || dist < minDist) {
        minDist = dist;
      }
    }
  }
  return minDist;
}

static float AwperProbability(int teamsize) {
  // TODO: this is out of date rip
  // 0 players -> -.25
  // 1 player  -> -.05
  // 2 players ->  .15
  // 3 players ->  .35
  // 4 players ->  .55
  // 5 players ->  .75
  // etc.
  return teamsize * 0.225 - 0.175;
}

public void AssignCTSpawns(int tCount, int ctCount, Bombsite site) {
  bool spawnsTaken[MAX_SPAWNS];

  // Algorithm description:
  // 1. Setup what we think of the "default" CT setup in terms of the site-friendliness values to
  // the site getting hit.
  //
  // 2. We use an accumlated array version of the default CT setup created. Marching through this
  // array, we save the current accumlated score (friendliness of all spawns selected). Using this
  // we can determine the diff with the expected accumulated score, and can determine if we
  // are behind, ahead, or equal with the expected score. This logic gets passed into the
  // form of a min/max search of selectable CT spawns. The key element here is that there is
  // random fuzzing by the "expected score" each iteration (excluding the first: site anchor).
  // This allows more variation, including setups that are "gambling" towards a single site.
  //
  // 3. Once spawns are chosen, they are assigned to clients, with hints from their CT
  // site preferences.

  // Step 1.
  int goalScores[5] = {5, 4, 3, 2, 1};
  char mapName[128];
  GetCleanMapName(mapName, sizeof(mapName));

  // This is kinda gross. Maybe it should be configurable?
  if (StrEqual(mapName, "de_cbble")) {
    if (site == BombsiteA) {
      goalScores = {5, 4, 3, 2, 1};
    } else {
      goalScores = {5, 5, 4, 2, 1};
    }
  }

  if (StrEqual(mapName, "de_mirage")) {
    if (site == BombsiteA) {
      goalScores = {5, 5, 4, 2, 1};
    } else {
      goalScores = {5, 4, 3, 2, 1};
    }
  }

  if (StrEqual(mapName, "de_cache")) {
    if (site == BombsiteA) {
      goalScores = {5, 4, 3, 2, 1};
    } else {
      goalScores = {5, 4, 3, 2, 1};
    }
  }

  if (StrEqual(mapName, "de_inferno")) {
    if (site == BombsiteA) {
      goalScores = {5, 5, 4, 2, 1};
    } else {
      goalScores = {5, 5, 3, 2, 1};
    }
  }

  if (StrEqual(mapName, "de_overpass")) {
    if (site == BombsiteA) {
      goalScores = {5, 4, 3, 2, 1};
    } else {
      goalScores = {5, 5, 3, 2, 1};
    }
  }

  if (StrEqual(mapName, "de_train")) {
    if (site == BombsiteA) {
      goalScores = {5, 5, 4, 2, 1};
    } else {
      goalScores = {5, 4, 3, 2, 1};
    }
  }

  if (StrEqual(mapName, "de_dust2")) {
    if (site == BombsiteA) {
      goalScores = {5, 4, 4, 2, 1};
    } else {
      goalScores = {5, 4, 3, 2, 1};
    }
  }

  if (StrEqual(mapName, "de_nuke")) {
    if (site == BombsiteA) {
      goalScores = {5, 4, 4, 2, 1};
    } else {
      goalScores = {4, 4, 3, 2, 1};
    }
  }

  // Step 2.
  int accumulatedArray[5];
  accumulatedArray[0] = goalScores[0];
  for (int i = 1; i < sizeof(goalScores); i++) {
    accumulatedArray[i] += accumulatedArray[i - 1] + goalScores[i];
  }

  ArrayList chosenSpawns = new ArrayList();
  ArrayList clients = new ArrayList();
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && g_Team[i] == CS_TEAM_CT) {
      clients.Push(i);
    }
  }

  int currentScore = 0;
  for (int i = 0; i < ctCount; i++) {
    int expectedScore = accumulatedArray[i];

    int min = goalScores[i];
    int max = goalScores[i];

    if (i >= 1) {
      float f = GetRandomFloat();
      if (f < 0.3) {
        expectedScore++;
      } else if (f < 0.6) {
        expectedScore--;
      }

      int diff = expectedScore - currentScore - goalScores[i];

      // TOOD want to remove this (if it will still work...)
      if (diff < -1)
        diff = -1;
      else if (diff > 1)
        diff = 1;

      if (diff < 0) {  // expected < current, need to improve
        max += diff;
        // max++;
      } else {
        min -= diff;
        // min--;
      }

      if (min > max) {
        int tmp = min;
        min = max;
        max = tmp;
      }
    }

    int spawn = FindCTSpawn(min, max, site, spawnsTaken);
    if (spawn != -1) {
      currentScore += g_SpawnSiteFriendly[spawn][site];
      chosenSpawns.Push(spawn);
    }
  }

  // Fill in any extra spawns if needed.
  while (chosenSpawns.Length < ctCount) {
    int spawn = FindCTSpawn(0, 5, site, spawnsTaken);
    if (spawn != -1) {
      chosenSpawns.Push(spawn);
    }
  }

  AssignSpawnsToClients_CTSiteAwareness(chosenSpawns, clients);

  g_CTAwper = -1;
  ArrayList potentialAwpers = new ArrayList();
  if (Chance(AwperProbability(ctCount))) {
    // Find an awp friendly spawn
    for (int client = 1; client <= MaxClients; client++) {
      int spawn = g_SpawnIndices[client];
      if (IsPlayer(client) && g_SpawnAwpFriendly[spawn] >= 3 && g_Team[client] == CS_TEAM_CT &&
          g_AllowAWP[client]) {
        int weight = 2 * g_SpawnAwpFriendly[spawn];
        AddRepeatedElement(potentialAwpers, client, weight);

        if (ElevatedAwpProbability(client)) {
          AddRepeatedElement(potentialAwpers, client, 10 * weight);
        }

        if (StrEqual(g_LastItemPickup[client], "awp", false)) {
          weight *= 10;
        }
      }
    }
    if (potentialAwpers.Length >= 1) {
      g_CTAwper = RandomElement(potentialAwpers);
    }
  }

  delete potentialAwpers;
  delete chosenSpawns;
  delete clients;
}

// Alternate version of AssignSpawnsToClients that takes into account CT player preferences
static void AssignSpawnsToClients_CTSiteAwareness(ArrayList spawns, ArrayList clients) {
  while (spawns.Length >= 1 && clients.Length >= 1) {
    int clientIndex = RandomClientIndex_CTSiteAwareness(clients);
    int client = clients.Get(clientIndex);

    int spawnIndex = RandomSpawnIndex_CTSiteAwareness(spawns, client);
    int spawn = spawns.Get(spawnIndex);
    g_SpawnIndices[client] = spawn;

    spawns.Erase(spawnIndex);
    clients.Erase(clientIndex);
  }
}

// Prefers clients with a preference set
static int RandomClientIndex_CTSiteAwareness(ArrayList clients) {
  ArrayList indices_with_prefs = new ArrayList();
  for (int i = 0; i < clients.Length; i++) {
    int client = clients.Get(i);
    if (g_SitePreference[client] != SitePref_None) {
      indices_with_prefs.Push(i);
    }
  }

  if (indices_with_prefs.Length != 0) {
    int ret = RandomElement(indices_with_prefs);
    delete indices_with_prefs;
    return ret;
  }

  delete indices_with_prefs;
  return GetRandomInt(0, clients.Length - 1);
}

static SitePref GetSpawnPref(int spawnIndex) {
  int a = g_SpawnSiteFriendly[spawnIndex][BombsiteA];
  int b = g_SpawnSiteFriendly[spawnIndex][BombsiteB];
  if (a >= 4) {
    return SitePref_A;
  }
  if (b >= 4) {
    return SitePref_B;
  }
  if ((a <= 4 && b <= 4) && (a == 3 || a == 2) && (b == 3 || b == 2)) {
    return SitePref_Mid;
  }
  return SitePref_None;
}

// Prefers spawns set where the spawnPref will match the clients
static int RandomSpawnIndex_CTSiteAwareness(ArrayList spawns, int client) {
  ArrayList matching_spawn_indices = new ArrayList();
  for (int i = 0; i < spawns.Length; i++) {
    int spawnIndex = spawns.Get(i);
    if (GetSpawnPref(spawnIndex) == g_SitePreference[client]) {
      matching_spawn_indices.Push(i);
    }
  }

  if (matching_spawn_indices.Length != 0) {
    int ret = RandomElement(matching_spawn_indices);
    delete matching_spawn_indices;
    return ret;
  }
  delete matching_spawn_indices;

  // Otherwise fall back to full randomness
  return GetRandomInt(0, spawns.Length - 1);
}

static void AssignSpawnsToClients(ArrayList spawns, ArrayList clients) {
  while (spawns.Length >= 1 && clients.Length >= 1) {
    int spawnIndex = RandomIndex(spawns);
    int clientIndex = RandomIndex(clients);
    int spawn = spawns.Get(spawnIndex);
    int client = clients.Get(clientIndex);
    g_SpawnIndices[client] = spawn;
    spawns.Erase(spawnIndex);
    clients.Erase(clientIndex);
  }
}

static int FindCTSpawn(int minFriendly, int maxFriendly, Bombsite site,
                       bool spawnsTaken[MAX_SPAWNS]) {
  LogDebug("FindCTSpawn, min=%d, max=%d, site=%d", minFriendly, maxFriendly, site);
  ArrayList potential = new ArrayList();
  for (int i = 0; i < g_NumSpawns; i++) {
    if (!g_SpawnDeleted[i] && g_SpawnTeams[i] == CS_TEAM_CT && !spawnsTaken[i]) {
      // Probabilistically skip some close spawns on pistol / force rounds
      if (g_SpawnAwpFriendly[i] == 1) {
        if (g_SelectedExecuteStrat == StratType_Pistol && Chance(0.7)) {
          continue;
        }
        if (g_SelectedExecuteStrat == StratType_ForceBuy && Chance(0.3)) {
          continue;
        }
      }

      // Check if any already-select spawns force exclude this one.
      if (IsSpawnExcluded(i, spawnsTaken)) {
        continue;
      }

      if (g_SpawnSiteFriendly[i][site] >= minFriendly &&
          g_SpawnSiteFriendly[i][site] <= maxFriendly) {
        AddRepeatedElement(potential, i, g_SpawnLikelihood[i]);
      }
    }
  }

  if (potential.Length == 0) {
    delete potential;
    if (minFriendly < MIN_FRIENDLINESS && maxFriendly > MAX_FRIENDLINESS) {
      return -1;
    } else {
      // Try a wider rannge of spawn friendliness ratings.
      return FindCTSpawn(minFriendly - 1, maxFriendly + 1, site, spawnsTaken);
    }
  } else {
    int index = RandomIndex(potential);
    int choice = potential.Get(index);
    spawnsTaken[choice] = true;
    delete potential;
    return choice;
  }
}

static bool IsSpawnExcluded(int spawn, bool spawnsTaken[MAX_SPAWNS]) {
  for (int i = 0; i < g_NumSpawns; i++) {
    if (i != spawn && spawnsTaken[i]) {
      for (int j = 0; j < g_SpawnExclusionRules[i].Length; j++) {
        int excludedSpawn = g_SpawnExclusionRules[i].Get(j);
        if (excludedSpawn == spawn) {
          return true;
        }
      }
    }
  }
  return false;
}

static int AddPotentialSpawns(ArrayList input, ArrayList output, Bombsite site,
                              bool nolurkers = false) {
  int count = 0;
  for (int i = 0; i < input.Length; i++) {
    char id[ID_LENGTH];
    input.GetString(i, id, sizeof(id));
    int spawn = SpawnIdToIndex(id);
    if (IsValidSpawn(spawn)) {
      if (nolurkers && IsLurkerSpawn(spawn, site)) {
        continue;
      }

      count++;
      output.Push(spawn);

      // Only allow 1 lurker max.
      if (IsLurkerSpawn(spawn, site)) {
        nolurkers = true;
      }
    }
  }

  return count;
}

public void MoveToSpawn(int client, int spawn) {
  TeleportEntity(client, g_SpawnPoints[spawn], g_SpawnAngles[spawn], NULL_VECTOR);
}

/**
 * Sets up a player for the round, giving weapons, teleporting, etc.
 */
public void SetupPlayer(int client) {
  int spawnIndex = g_SpawnIndices[client];
  if (spawnIndex < 0) {
    LogError("Tried to setup player without a spawn selected: %L, spawnIndex=%d", client,
             spawnIndex);
    return;
  }

  SwitchPlayerTeam(client, g_Team[client]);
  MoveToSpawn(client, spawnIndex);
  GiveWeapons(client);
}

public void GiveWeapons(int client) {
  if (!IsValidClient(client)) {
    return;
  }

  Client_RemoveAllWeapons(client, "");
  if (g_Team[client] == CS_TEAM_T) {
    GivePlayerItem(client, "weapon_knife_t");
  } else {
    GivePlayerItem(client, "weapon_knife");
  }

  if (g_Team[client] == CS_TEAM_CT && StrEqual(g_PlayerPrimary[client], "weapon_ak47")) {
    SetEntProp(client, Prop_Data, "m_iTeamNum", CS_TEAM_T);
    GivePlayerItem(client, g_PlayerPrimary[client]);
    SetEntProp(client, Prop_Data, "m_iTeamNum", CS_TEAM_CT);

  } else {
    GivePlayerItem(client, g_PlayerPrimary[client]);
  }

  GivePlayerItem(client, g_PlayerSecondary[client]);
  Client_SetArmor(client, g_PlayerArmor[client]);
  SetEntityHealth(client, g_PlayerHealth[client]);

  SetEntProp(client, Prop_Send, "m_bHasHelmet", g_PlayerHelmet[client]);

  if (g_Team[client] == CS_TEAM_CT) {
    SetEntProp(client, Prop_Send, "m_bHasDefuser", g_PlayerKit[client]);
  }

  int len = strlen(g_PlayerNades[client]);
  for (int i = 0; i < len; i++) {
    char c = g_PlayerNades[client][i];

    if (g_Team[client] == CS_TEAM_T && c == 'i') {
      c = 'm';
    }

    if (g_Team[client] == CS_TEAM_CT && c == 'm') {
      c = 'i';
    }

    char weapon[32];
    switch (c) {
      case 'h':
        weapon = "weapon_hegrenade";
      case 'f':
        weapon = "weapon_flashbang";
      case 'm':
        weapon = "weapon_molotov";
      case 'i':
        weapon = "weapon_incgrenade";
      case 's':
        weapon = "weapon_smokegrenade";
      case 'd':
        weapon = "weapon_decoy";
    }
    GivePlayerItem(client, weapon);
  }

  if (g_BombOwner == client) {
    GivePlayerItem(client, "weapon_c4");
  }

  g_LastItemPickup[client] = "";
}

stock void ThrowRoundNades(float timeUntilFreezeEnd = 5.0) {
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && g_Team[i] == CS_TEAM_T) {
      int spawn = g_SpawnIndices[i];
      SetupThrowNade(timeUntilFreezeEnd, i, spawn);
    }
  }
}

stock void ThrowEditingNades(float timeUntilFreezeEnd, int client, bool optional) {
  ThrowNades(timeUntilFreezeEnd, client, g_EditingExecuteTRequired);
  if (optional)
    ThrowNades(timeUntilFreezeEnd, client, g_EditingExecuteTOptional);
}

static void ThrowNades(float timeUntilFreezeEnd, int client, ArrayList spawns) {
  char id[ID_LENGTH];
  for (int i = 0; i < spawns.Length; i++) {
    spawns.GetString(i, id, sizeof(id));
    int spawn = SpawnIdToIndex(id);
    SetupThrowNade(timeUntilFreezeEnd, client, spawn);
  }
}

public void SetupThrowNade(float timeUntilFreezeEnd, int client, int spawn) {
  if (IsGrenade(g_SpawnGrenadeTypes[spawn]) && IsPlayer(client)) {
    float jitter = GetRandomFloat(-0.5, 0.5);
    if (g_EditMode) {
      jitter = 0.0;
    }

    float time = timeUntilFreezeEnd + float(g_SpawnGrenadeThrowTimes[spawn]) + jitter;
    if (time < 0.0) {
      time = 0.1;
    }

    if (time <= timeUntilFreezeEnd) {
      time = timeUntilFreezeEnd + 0.01;
    }

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientSerial(client));
    pack.WriteCell(spawn);
    CreateTimer(time, Timer_ThrowNade, pack);
  }
}

public Action Timer_ThrowNade(Handle timer, DataPack data) {
  data.Reset();
  int serial = data.ReadCell();
  int spawn = data.ReadCell();
  delete data;

  int client = GetClientFromSerial(serial);
  if (IsPlayer(client) && IsValidSpawn(spawn) && IsGrenade(g_SpawnGrenadeTypes[spawn])) {
    CSU_ThrowGrenade(client, g_SpawnGrenadeTypes[spawn], g_SpawnNadePoints[spawn],
                     g_SpawnNadeVelocities[spawn]);
  }
}

public int GetMinFreezetime(int execute) {
  int freezetime = 1;

  int requiredTime = GetMinFreezetimeFromSpawns(g_ExecuteTSpawnsRequired[execute]);
  if (requiredTime > freezetime) {
    freezetime = requiredTime;
  }

  int optionalTime = GetMinFreezetimeFromSpawns(g_ExecuteTSpawnsOptional[execute]);
  if (optionalTime > freezetime) {
    freezetime = optionalTime;
  }

  return freezetime;
}

public int GetEditMinFreezetime() {
  int freezetime = 1;

  int requiredTime = GetMinFreezetimeFromSpawns(g_EditingExecuteTRequired);
  if (requiredTime > freezetime) {
    freezetime = requiredTime;
  }

  int optionalTime = GetMinFreezetimeFromSpawns(g_EditingExecuteTOptional);
  if (optionalTime > freezetime) {
    freezetime = optionalTime;
  }

  return freezetime;
}

public int GetMinFreezetimeFromSpawns(ArrayList spawns) {
  int freezetime = 1;
  char spawnId[ID_LENGTH];

  for (int i = 0; i < spawns.Length; i++) {
    spawns.GetString(i, spawnId, sizeof(spawnId));
    int spawn = SpawnIdToIndex(spawnId);
    if (IsValidSpawn(spawn)) {
      int spawnTime = g_SpawnGrenadeThrowTimes[spawn];
      if (spawnTime < 0 && -spawnTime > freezetime) {
        freezetime = -spawnTime;
      }
    }
  }

  return freezetime;
}

stock bool HasFlag(int spawn, int flag) {
  return (g_SpawnFlags[spawn] & flag) != 0;
}

public bool ElevatedAwpProbability(int client) {
  bool ret = false;
  Call_StartForward(g_OnGetSpecialPowers);
  Call_PushCell(client);
  Call_PushCellRef(ret);
  Call_Finish();
  return ret;
}

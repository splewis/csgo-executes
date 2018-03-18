/**
 * Reads the scenario keyvalues config file and sets up the global scenario and player arrays.
 */
public void ReadMapConfig() {
  g_DirtySpawns = false;
  char configFile[PLATFORM_MAX_PATH];
  GetConfigFileName(configFile, sizeof(configFile));

  g_NumSpawns = 0;
  g_NextSpawnId = 0;
  g_NextExecuteId = 0;
  g_NumExecutes = 0;

  if (!FileExists(configFile)) {
    LogMessage("The executes config file (%s) does not exist", configFile);
    return;
  }

  KeyValues kv = new KeyValues("Executes");
  if (!kv.ImportFromFile(configFile)) {
    LogMessage("The executes config file was empty");
    delete kv;
    return;
  }

  if (kv.JumpToKey("Spawns")) {
    if (kv.GotoFirstSubKey(false)) {
      ReadSpawns(kv);
      kv.GoBack();
    }
    kv.GoBack();
  }

  for (int i = 0; i < MAX_EXECUTES; i++) {
    g_ExecuteTSpawnsRequired[i].Clear();
    g_ExecuteTSpawnsOptional[i].Clear();
  }

  if (kv.JumpToKey("Executes")) {
    if (kv.GotoFirstSubKey(false)) {
      ReadExecutes(kv);
      kv.GoBack();
    }
    kv.GoBack();
  }
}

/**
 * Writes the stored scenario structures back to the config file.
 */
public void WriteMapConfig() {
  KeyValues kv = new KeyValues("Executes");

  if (kv.JumpToKey("Spawns", true)) {
    WriteSpawns(kv);
    kv.GoBack();
  }

  if (kv.JumpToKey("Executes", true)) {
    WriteExecutes(kv);
    kv.GoBack();
  }

  char configFile[PLATFORM_MAX_PATH];
  GetConfigFileName(configFile, sizeof(configFile));
  DeleteFile(configFile);

  if (FileExists(configFile)) {
    if (!DeleteFile(configFile)) {
      LogError("Couldn't delete previous config %s", configFile);
    }
  }

  kv.Rewind();
  EnforceDirectoryExists("configs/executes");
  if (!kv.ExportToFile(configFile)) {
    LogError("Failed to write map config to %s", configFile);
  }
  delete kv;

  g_DirtySpawns = false;
}

static void ReadSpawns(KeyValues spawnsKv) {
  int spawn = 0;

  do {
    spawnsKv.GetSectionName(g_SpawnIDs[spawn], ID_LENGTH);
    spawnsKv.GetString("name", g_SpawnNames[spawn], SPAWN_NAME_LENGTH);
    spawnsKv.GetVector("origin", g_SpawnPoints[spawn], NULL_VECTOR);
    spawnsKv.GetVector("angle", g_SpawnAngles[spawn], NULL_VECTOR);
    spawnsKv.GetVector("grenadeOrigin", g_SpawnNadePoints[spawn], NULL_VECTOR);
    spawnsKv.GetVector("grenadeVelocity", g_SpawnNadeVelocities[spawn], NULL_VECTOR);

    g_SpawnGrenadeThrowTimes[spawn] = spawnsKv.GetNum("grenadeThrowTime", DEFAULT_THROWTIME);
    g_SpawnFlags[spawn] = spawnsKv.GetNum("flags", 0);

    g_SpawnSiteFriendly[spawn][BombsiteA] = ReadFriendliness(spawnsKv, "A_friendly");
    g_SpawnSiteFriendly[spawn][BombsiteB] = ReadFriendliness(spawnsKv, "B_friendly");
    g_SpawnAwpFriendly[spawn] = ReadFriendliness(spawnsKv, "awp_friendly");
    g_SpawnBombFriendly[spawn] = ReadFriendliness(spawnsKv, "bomb_friendly");
    g_SpawnLikelihood[spawn] = ReadFriendliness(spawnsKv, "likelihood");

    char buffer[32];
    spawnsKv.GetString("grenadeType", buffer, sizeof(buffer));
    if (StrEqual(buffer, "smoke")) {
      g_SpawnGrenadeTypes[spawn] = GrenadeType_Smoke;
    } else if (StrEqual(buffer, "flash")) {
      g_SpawnGrenadeTypes[spawn] = GrenadeType_Flash;
    } else if (StrEqual(buffer, "molotov")) {
      g_SpawnGrenadeTypes[spawn] = GrenadeType_Molotov;
    } else {
      g_SpawnGrenadeTypes[spawn] = GrenadeType_None;
    }

    spawnsKv.GetString("team", buffer, sizeof(buffer), "T");
    g_SpawnTeams[spawn] = (StrEqual(buffer, "CT", false)) ? CS_TEAM_CT : CS_TEAM_T;

    g_SpawnDeleted[spawn] = false;

    char excludedList[1024];
    spawnsKv.GetString("excluded", excludedList, sizeof(excludedList));
    AddSpawnExclusionsToList(excludedList, g_SpawnExclusionRules[spawn]);

    spawn++;
    g_NumSpawns = spawn;
    if (spawn == MAX_SPAWNS) {
      LogError("Hit the max number of spawns");
      break;
    }

  } while (spawnsKv.GotoNextKey());

  g_NextSpawnId = StringToInt(g_SpawnIDs[g_NumSpawns - 1]) + 1;
}

static void WriteSpawns(KeyValues spawnsKv) {
  for (int spawn = 0; spawn < g_NumSpawns; spawn++) {
    if (spawn == MAX_SPAWNS) {
      LogError("Hit the max number (%d) of spawns", MAX_SPAWNS);
      break;
    }

    if (g_SpawnDeleted[spawn])
      continue;

    spawnsKv.JumpToKey(g_SpawnIDs[spawn], true);

    spawnsKv.SetString("name", g_SpawnNames[spawn]);
    spawnsKv.SetVector("origin", g_SpawnPoints[spawn]);
    spawnsKv.SetVector("angle", g_SpawnAngles[spawn]);
    spawnsKv.SetString("team", TEAMSTRING(g_SpawnTeams[spawn]));
    spawnsKv.SetNum("flags", g_SpawnFlags[spawn]);
    spawnsKv.SetNum("awp_friendly", g_SpawnAwpFriendly[spawn]);

    if (g_SpawnTeams[spawn] == CS_TEAM_CT) {
      spawnsKv.SetNum("A_friendly", g_SpawnSiteFriendly[spawn][BombsiteA]);
      spawnsKv.SetNum("B_friendly", g_SpawnSiteFriendly[spawn][BombsiteB]);
      spawnsKv.SetNum("likelihood", g_SpawnLikelihood[spawn]);
    } else {
      spawnsKv.SetNum("bomb_friendly", g_SpawnBombFriendly[spawn]);

      char buffer[32] = "none";
      if (g_SpawnGrenadeTypes[spawn] == GrenadeType_Smoke) {
        buffer = "smoke";
      } else if (g_SpawnGrenadeTypes[spawn] == GrenadeType_Flash) {
        buffer = "flash";
      } else if (g_SpawnGrenadeTypes[spawn] == GrenadeType_Molotov) {
        buffer = "molotov";
      }

      spawnsKv.SetString("grenadeType", buffer);
      if (!StrEqual(buffer, "none")) {
        spawnsKv.SetVector("grenadeOrigin", g_SpawnNadePoints[spawn]);
        spawnsKv.SetVector("grenadeVelocity", g_SpawnNadeVelocities[spawn]);
        spawnsKv.SetNum("grenadeThrowTime", g_SpawnGrenadeThrowTimes[spawn]);
      }
    }

    char excludedList[1024];
    CollapseSpawnExclusionsToString(g_SpawnExclusionRules[spawn], excludedList,
                                    sizeof(excludedList));
    spawnsKv.SetString("excluded", excludedList);

    spawnsKv.GoBack();
  }
}

static void ReadExecutes(KeyValues executesKv) {
  int execute = 0;

  do {
    executesKv.GetSectionName(g_ExecuteIDs[execute], ID_LENGTH);
    executesKv.GetString("name", g_ExecuteNames[execute], EXECUTE_NAME_LENGTH);

    char buffer[32];
    executesKv.GetString("site", buffer, sizeof(buffer), "A");
    g_ExecuteSites[execute] = (StrEqual(buffer, "A", false)) ? BombsiteA : BombsiteB;
    g_ExecuteLikelihood[execute] = ReadFriendliness(executesKv, "likelihood");
    executesKv.GetString("forcebomb_id", g_ExecuteForceBombId[execute], ID_LENGTH, "");

    g_ExecuteStratTypes[execute][StratType_Normal] = (executesKv.GetNum("strat_normal", 1) != 0);
    g_ExecuteStratTypes[execute][StratType_Pistol] = (executesKv.GetNum("strat_pistol", 0) != 0);
    g_ExecuteStratTypes[execute][StratType_ForceBuy] = (executesKv.GetNum("strat_force", 0) != 0);
    g_ExecuteFake[execute] = (executesKv.GetNum("fake") != 0);
    g_ExecuteExtraFreezeTime[execute] =
        executesKv.GetFloat("extra_freeze_time", g_ExtraFreezeTimeCvar.FloatValue);

    g_ExecuteDeleted[execute] = false;

    ReadExecuteSpawnsHelper("t_players", executesKv, g_ExecuteTSpawnsRequired[execute],
                            g_ExecuteTSpawnsOptional[execute]);

    execute++;
    g_NumExecutes = execute;
    if (execute == MAX_SPAWNS) {
      LogError("Hit the max number of executes");
      break;
    }

  } while (executesKv.GotoNextKey());

  g_NextExecuteId = StringToInt(g_ExecuteIDs[g_NumExecutes - 1]) + 1;
}

static void ReadExecuteSpawnsHelper(const char[] section, KeyValues kv, ArrayList required,
                                    ArrayList optional) {
  required.Clear();
  optional.Clear();

  if (kv.JumpToKey(section)) {
    if (kv.GotoFirstSubKey(false)) {
      char id[ID_LENGTH];
      char buffer[32];
      do {
        kv.GetSectionName(id, sizeof(id));
        kv.GetString(NULL_STRING, buffer, sizeof(buffer));
        int spawnIndex = SpawnIdToIndex(id);
        if (IsValidSpawn(spawnIndex)) {
          if (StrEqual(buffer, "required", false)) {
            required.PushString(id);
          } else if (StrEqual(buffer, "optional", false)) {
            optional.PushString(id);
          }
        } else {
          LogError("Spawn id %s does not exist, but used in an execute!", id);
        }
      } while (kv.GotoNextKey(false));
      kv.GoBack();
    }
    kv.GoBack();
  }
}

static void WriteExecutes(KeyValues executesKv) {
  for (int execute = 0; execute < g_NumExecutes; execute++) {
    if (execute == MAX_EXECUTES) {
      LogError("Hit the max number (%d) of executes", MAX_EXECUTES);
      break;
    }

    if (g_ExecuteDeleted[execute])
      continue;

    executesKv.JumpToKey(g_ExecuteIDs[execute], true);
    executesKv.SetString("name", g_ExecuteNames[execute]);
    executesKv.SetString("site", SITESTRING(g_ExecuteSites[execute]));
    executesKv.SetNum("likelihood", g_ExecuteLikelihood[execute]);
    executesKv.SetString("forcebomb_id", g_ExecuteForceBombId[execute]);
    executesKv.SetNum("strat_normal", g_ExecuteStratTypes[execute][StratType_Normal]);
    executesKv.SetNum("strat_pistol", g_ExecuteStratTypes[execute][StratType_Pistol]);
    executesKv.SetNum("strat_force", g_ExecuteStratTypes[execute][StratType_ForceBuy]);
    executesKv.SetNum("fake", g_ExecuteFake[execute]);

    float delta = g_ExecuteExtraFreezeTime[execute] - g_ExtraFreezeTimeCvar.FloatValue;
    if (delta < 0.01 && -delta < 0.01)
      executesKv.SetFloat("extra_freeze_time", g_ExecuteExtraFreezeTime[execute]);

    WriteExecuteSpawnsHelper("t_players", executesKv, g_ExecuteTSpawnsRequired[execute],
                             g_ExecuteTSpawnsOptional[execute]);

    executesKv.GoBack();
  }
}

static void WriteExecuteSpawnsHelper(const char[] section, KeyValues kv, ArrayList required,
                                     ArrayList optional) {
  char id[ID_LENGTH];
  if (kv.JumpToKey(section, true)) {
    for (int i = 0; i < required.Length; i++) {
      required.GetString(i, id, sizeof(id));
      kv.SetString(id, "required");
    }
    for (int i = 0; i < optional.Length; i++) {
      optional.GetString(i, id, sizeof(id));
      kv.SetString(id, "optional");
    }
    kv.GoBack();
  }
}

public int SpawnIdToIndex(const char[] id) {
  for (int i = 0; i < g_NumSpawns; i++) {
    if (StrEqual(id, g_SpawnIDs[i])) {
      if (g_SpawnDeleted[i])
        return -1;

      return i;
    }
  }
  return -1;
}

public int ExecuteIdToIndex(const char[] id) {
  for (int i = 0; i < g_NumExecutes; i++) {
    if (StrEqual(id, g_ExecuteIDs[i])) {
      if (g_ExecuteDeleted[i])
        return -1;

      return i;
    }
  }
  return -1;
}

public bool IsValidSpawn(int index) {
  return index >= 0 && index < g_NumSpawns && !g_SpawnDeleted[index];
}

public bool IsValidExecute(int index) {
  return index >= 0 && index < g_NumExecutes && !g_ExecuteDeleted[index];
}

static void GetConfigFileName(char[] buffer, int size) {
  // Get the map, with any workshop stuff before removed
  char mapName[128];
  GetCleanMapName(mapName, sizeof(mapName));
  BuildPath(Path_SM, buffer, size, "configs/executes/%s.cfg", mapName);
}

stock int ReadFriendliness(KeyValues kv, const char[] name, int defaultValue = AVG_FRIENDLINESS) {
  int value = kv.GetNum(name, defaultValue);
  if (value < MIN_FRIENDLINESS)
    return MIN_FRIENDLINESS;
  else if (value > MAX_FRIENDLINESS)
    return MAX_FRIENDLINESS;
  else
    return value;
}

public int AddSpawnExclusionsToList(const char[] inputString, ArrayList list) {
  const int maxSpawns = 10;
  char parts[maxSpawns][ID_LENGTH];
  int foundSpawns = ExplodeString(inputString, ";", parts, maxSpawns, ID_LENGTH);
  for (int i = 0; i < foundSpawns; i++) {
    if (!StrEqual(parts[i], "")) {
      list.Push(SpawnIdToIndex(parts[i]));
    }
  }
  return foundSpawns;
}

public void CollapseSpawnExclusionsToString(ArrayList list, char[] output, int len) {
  for (int i = 0; i < list.Length; i++) {
    StrCat(output, len, g_SpawnIDs[list.Get(i)]);
    StrCat(output, len, ";");
  }
}

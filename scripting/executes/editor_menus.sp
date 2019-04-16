// TODO: add CT spawn "exclusions" to the editor

enum SpawnStatus {
  Spawn_Required = 0,
  Spawn_Optional = 1,
  Spawn_NotUsed = 2,
}

stock void
GiveEditorMenu(int client, int menuPosition = -1) {
  Menu menu = new Menu(EditorMenuHandler);
  menu.ExitButton = true;
  menu.SetTitle("Executes editor");
  AddMenuOption(menu, "end_edit", "Exit edit mode");
  AddMenuOption(menu, "add_spawn", "Add a spawn");
  AddMenuOption(menu, "edit_spawn", "Edit a spawn");
  AddMenuOption(menu, "add_execute", "Add an execute");
  AddMenuOption(menu, "edit_execute", "Edit an execute");
  AddMenuOption(menu, "edit_nearest_spawn", "Edit nearest spawn");
  AddMenuOption(menu, "delete_nearest_spawn", "Delete nearest spawn");
  AddMenuOption(menu, "save_map_data", "Save map data");
  AddMenuOption(menu, "reload_map_data", "Reload map data (discard current changes)");
  AddMenuOption(menu, "clear_edit_buffers", "Clear edit buffers");

  if (menuPosition == -1) {
    menu.Display(client, MENU_TIME_FOREVER);
  } else {
    menu.DisplayAt(client, menuPosition, MENU_TIME_FOREVER);
  }
}

public int EditorMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char choice[64];
    menu.GetItem(param2, choice, sizeof(choice));
    int menuPosition = GetMenuSelectionPosition();

    if (StrEqual(choice, "end_edit")) {
      Executes_MessageToAll("Exiting edit mode.");
      ExitEditMode();

    } else if (StrEqual(choice, "add_spawn")) {
      g_EditingASpawn = false;
      GiveNewSpawnMenu(client);

    } else if (StrEqual(choice, "add_execute")) {
      g_EditingAnExecute = false;
      GiveNewExecuteMenu(client);

    } else if (StrEqual(choice, "edit_spawn")) {
      GiveEditSpawnChoiceMenu(client);

    } else if (StrEqual(choice, "edit_nearest_spawn")) {
      int spawn = FindClosestSpawn(client);
      EditSpawn(client, spawn);

    } else if (StrEqual(choice, "delete_nearest_spawn")) {
      DeleteClosestSpawn(client);
      GiveEditorMenu(client, menuPosition);

    } else if (StrEqual(choice, "edit_execute")) {
      // ClearExecuteBuffers
      GiveExecuteEditMenu(client);

    } else if (StrEqual(choice, "save_map_data")) {
      SaveMapData();
      GiveEditorMenu(client, menuPosition);

    } else if (StrEqual(choice, "reload_map_data")) {
      ReloadMapData();
      GiveEditorMenu(client, menuPosition);

    } else if (StrEqual(choice, "clear_edit_buffers")) {
      ClearEditBuffers();
      GiveEditorMenu(client, menuPosition);

    } else {
      LogError("unknown menu info string = %s", choice);
    }
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

stock void GiveNewSpawnMenu(int client, int pos = -1) {
  g_EditingExecutes = false;
  Menu menu = new Menu(GiveNewSpawnMenuHandler);
  menu.SetTitle("Add a spawn");

  if (StrEqual(g_TempNameBuffer, ""))
    AddMenuOptionDisabled(menu, "finish", "Finish spawn (use !setname to name first)");
  else
    AddMenuOption(menu, "finish", "Finish spawn (%s)", g_TempNameBuffer);

  AddMenuOption(menu, "team", "Team: %s", TEAMSTRING(g_EditingSpawnTeam));
  if (g_EditingSpawnTeam == CS_TEAM_CT) {
    AddMenuOption(menu, "a_friendly", "A site friendliness: %d",
                  g_EditingSpawnSiteFriendly[BombsiteA]);
    AddMenuOption(menu, "b_friendly", "B site friendliness: %d",
                  g_EditingSpawnSiteFriendly[BombsiteB]);
    AddMenuOption(menu, "awp_friendly", "AWP friendliness: %d", g_EditingSpawnAwpFriendly);
    AddMenuOption(menu, "likelihood", "Likelihood value: %d", g_EditingSpawnLikelihood);
  } else {
    AddMenuOption(menu, "bomb_friendly", "Bomb carrier friendliness: %d",
                  g_EditingSpawnBombFriendly);
    AddMenuOption(menu, "awp_friendly", "AWP friendliness: %d", g_EditingSpawnAwpFriendly);

    char type[32];
    GrenadeTypeName(g_EditingSpawnGrenadeType, type, sizeof(type));
    AddMenuOptionDisabled(menu, "x", "Grenade: %s", type);

    char throwTime[32];
    ThrowTimeString(g_EditingSpawnThrowTime, throwTime, sizeof(throwTime));
    if (IsGrenade(g_EditingSpawnGrenadeType)) {
      AddMenuOption(menu, "grenade_throw_time", "Throw Grenade: %s", throwTime);
    } else {
      AddMenuOptionDisabled(menu, "grenade_throw_time", "Throw Grenade: %s", throwTime);
    }
  }

  AddMenuOption(menu, "flags", "Edit flags");

  menu.ExitButton = true;
  menu.ExitBackButton = true;

  if (pos == -1) {
    menu.Display(client, MENU_TIME_FOREVER);
  } else {
    menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
  }
}

public int GiveNewSpawnMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int pos = GetMenuSelectionPosition();
    int client = param1;
    char choice[64];
    menu.GetItem(param2, choice, sizeof(choice));
    if (StrEqual(choice, "finish")) {
      AddSpawn(client);
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "team")) {
      g_EditingSpawnTeam = GetOtherTeam(g_EditingSpawnTeam);
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "name")) {
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "a_friendly")) {
      IncSiteFriendly(BombsiteA);
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "b_friendly")) {
      IncSiteFriendly(BombsiteB);
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "awp_friendly")) {
      IncAwpFriendly();
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "bomb_friendly")) {
      IncBombFriendly();
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "likelihood")) {
      IncSpawnLikelihood();
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "grenade_throw_time")) {
      IncThrowTime();
      GiveNewSpawnMenu(client, pos);

    } else if (StrEqual(choice, "flags")) {
      GiveEditFlagsMenu(client);

    } else {
      LogError("unknown menu info string = %s", choice);
    }
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveEditorMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

public void IncSiteFriendly(Bombsite site) {
  g_EditingSpawnSiteFriendly[site]++;
  if (g_EditingSpawnSiteFriendly[site] > MAX_FRIENDLINESS) {
    g_EditingSpawnSiteFriendly[site] = MIN_FRIENDLINESS;
  }
}

public void IncAwpFriendly() {
  g_EditingSpawnAwpFriendly++;
  if (g_EditingSpawnAwpFriendly > MAX_FRIENDLINESS) {
    g_EditingSpawnAwpFriendly = MIN_FRIENDLINESS;
  }
}

public void IncBombFriendly() {
  g_EditingSpawnBombFriendly++;
  if (g_EditingSpawnBombFriendly > MAX_FRIENDLINESS) {
    g_EditingSpawnBombFriendly = MIN_FRIENDLINESS;
  }
}

public void IncSpawnLikelihood() {
  g_EditingSpawnLikelihood++;
  if (g_EditingSpawnLikelihood > MAX_FRIENDLINESS) {
    g_EditingSpawnLikelihood = MIN_FRIENDLINESS;
  }
}

public void IncExecuteLikelihood() {
  g_EditingExecuteLikelihood++;
  if (g_EditingExecuteLikelihood > MAX_FRIENDLINESS) {
    g_EditingExecuteLikelihood = MIN_FRIENDLINESS;
  }
}

public void ThrowTimeString(int time, char[] buf, int len) {
  if (time == 0) {
    Format(buf, len, "at freezetime end");
  } else if (time > 0) {
    Format(buf, len, "%d AFTER freezetime end", time);
  } else {
    Format(buf, len, "%d BEFORE freezetime end", -time);
  }
}

public void IncThrowTime() {
  g_EditingSpawnThrowTime++;
  if (g_EditingSpawnThrowTime > 5) {
    g_EditingSpawnThrowTime = -3;
  }
}

stock void GiveNewExecuteMenu(int client, int pos = -1) {
  g_EditingExecutes = true;
  Menu menu = new Menu(GiveNewExecuteMenuHandler);
  if (g_EditingAnExecute)
    menu.SetTitle("Edit an execute");
  else
    menu.SetTitle("Add an execute");

  if (StrEqual(g_TempNameBuffer, ""))
    AddMenuOptionDisabled(menu, "finish", "Finish execute (use !setname to name it first)");
  else
    AddMenuOption(menu, "finish", "finish execute (%s)", g_TempNameBuffer);

  AddMenuOption(menu, "site", "Site: %s", SITESTRING(g_EditingExecuteSite));
  AddMenuOption(menu, "t_spawns", "Edit T spawns");

  AddMenuOption(menu, "play_required_nades", "Play required nades");
  AddMenuOption(menu, "play_all_nades", "Play all nades");
  AddMenuOption(menu, "likelihood", "Likelihood value: %d", g_EditingExecuteLikelihood);

  AddMenuOption(menu, "strat_normal", "Gun round strat: %d",
                g_EditingExecuteStratTypes[StratType_Normal]);
  AddMenuOption(menu, "strat_pistol", "Pistol round strat: %d",
                g_EditingExecuteStratTypes[StratType_Pistol]);
  AddMenuOption(menu, "strat_force", "Force round strat: %d",
                g_EditingExecuteStratTypes[StratType_ForceBuy]);
  AddMenuOption(menu, "fake", "Is a fake: %s", g_EditingExecuteFake ? "yes" : "no");

  if (IsValidSpawn(SpawnIdToIndex(g_EditingExecuteForceBombId))) {
    AddMenuOption(menu, "forcebomb_id", "Forced bomb spawn: %s",
                  g_SpawnNames[SpawnIdToIndex(g_EditingExecuteForceBombId)]);
  } else {
    AddMenuOption(menu, "forcebomb_id", "Forced bomb spawn: none");
  }

  if (g_EditingAnExecute)
    AddMenuOption(menu, "delete", "Delete this execute");

  menu.ExitButton = true;
  menu.ExitBackButton = true;

  if (pos == -1) {
    menu.Display(client, MENU_TIME_FOREVER);
  } else {
    menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
  }
}

public int GiveNewExecuteMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int pos = GetMenuSelectionPosition();
    int freezetime = GetEditMinFreezetime();

    int client = param1;
    char choice[64];
    menu.GetItem(param2, choice, sizeof(choice));
    if (StrEqual(choice, "finish")) {
      AddExecute(client);
      GiveEditorMenu(client);

    } else if (StrEqual(choice, "delete")) {
      g_ExecuteDeleted[g_EditingExecuteIndex] = true;
      GiveEditorMenu(client);

    } else if (StrEqual(choice, "site")) {
      g_EditingExecuteSite = GetOtherSite(g_EditingExecuteSite);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "name")) {
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "t_spawns")) {
      GiveExecuteSpawnsMenu(client);

    } else if (StrEqual(choice, "play_required_nades")) {
      ThrowEditingNades(float(freezetime), client, false);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "play_all_nades")) {
      ThrowEditingNades(float(freezetime), client, true);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "likelihood")) {
      IncExecuteLikelihood();
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "strat_normal")) {
      FlipStratType(StratType_Normal);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "strat_pistol")) {
      FlipStratType(StratType_Pistol);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "strat_force")) {
      FlipStratType(StratType_ForceBuy);
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "fake")) {
      g_EditingExecuteFake = !g_EditingExecuteFake;
      GiveNewExecuteMenu(client, pos);

    } else if (StrEqual(choice, "forcebomb_id")) {
      GiveForceBombSpawneMenu(client);

    } else {
      LogError("unknown menu info string = %s", choice);
    }
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveEditorMenu(client);
    g_EditingAnExecute = false;
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

static void FlipStratType(StratType type) {
  g_EditingExecuteStratTypes[type] = !g_EditingExecuteStratTypes[type];
}

public void GiveForceBombSpawneMenu(int client) {
  Menu menu = new Menu(GiveForceBombSpawneMenuHandler);
  menu.SetTitle("Select spawn to force bomb to");

  for (int i = 0; i < g_EditingExecuteTRequired.Length; i++) {
    char id[ID_LENGTH];
    g_EditingExecuteTRequired.GetString(i, id, sizeof(id));
    int idx = SpawnIdToIndex(id);
    if (IsValidSpawn(idx))
      AddMenuOption(menu, id, g_SpawnNames[idx]);
  }

  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int GiveForceBombSpawneMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    menu.GetItem(param2, g_EditingExecuteForceBombId, ID_LENGTH);
    GiveNewExecuteMenu(client);

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveNewExecuteMenu(client);

  } else if (action == MenuAction_End) {
    delete menu;
  }
}

static ArrayList GetSpawnList(bool required, int execute = -1) {
  // Use temp buffers lists
  if (execute == -1) {
    return required ? g_EditingExecuteTRequired : g_EditingExecuteTOptional;
  }

  return required ? g_ExecuteTSpawnsRequired[execute] : g_ExecuteTSpawnsOptional[execute];
}

stock void GiveExecuteSpawnsMenu(int client, int menuPosition = -1) {
  Menu menu = new Menu(GiveExecuteSpawnsMenuHandler);
  menu.SetTitle("Select spawns");
  int count = 0;

  for (int i = 0; i < g_NumSpawns; i++) {
    if (g_SpawnDeleted[i] || g_SpawnTeams[i] != CS_TEAM_T) {
      continue;
    }

    count++;

    char grenadeType[32];
    GrenadeTypeName(g_SpawnGrenadeTypes[i], grenadeType, sizeof(grenadeType));

    int useId = 0;
    char usedStr[32] = "not used";
    if (GetSpawnList(true).FindString(g_SpawnIDs[i]) >= 0) {
      useId = 1;
      usedStr = "required";
    } else if (GetSpawnList(false).FindString(g_SpawnIDs[i]) >= 0) {
      useId = 2;
      usedStr = "optional";
    }

    char infoStr[ID_LENGTH + 16];
    Format(infoStr, sizeof(infoStr), "%d %s", useId, g_SpawnIDs[i]);

    AddMenuOption(menu, infoStr, "%s: %s (id:%s, grenade:%s)", usedStr, g_SpawnNames[i],
                  g_SpawnIDs[i], grenadeType);
  }

  menu.ExitButton = true;
  menu.ExitBackButton = true;

  if (count == 0) {
    delete menu;
    Executes_Message(client, "No spawns avaliable, add more.");
    GiveNewSpawnMenu(client);
  } else {
    if (menuPosition == -1) {
      menu.Display(client, MENU_TIME_FOREVER);
    } else {
      menu.DisplayAt(client, menuPosition, MENU_TIME_FOREVER);
    }
  }
}

public int GiveExecuteSpawnsMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char info[32];
    menu.GetItem(param2, info, sizeof(info));

    char useString[2];
    strcopy(useString, sizeof(useString), info);
    int useId = StringToInt(useString);

    char id[ID_LENGTH];
    strcopy(id, sizeof(id), info[2]);
    int index = SpawnIdToIndex(id);

    if (useId == 0) {
      // not in use, make required
      SetSpawnStatus(id, Spawn_Required, GetSpawnList(true), GetSpawnList(false));
      Executes_MessageToAll("Added spawn \"%s\" to execute.", g_SpawnNames[index]);

    } else if (useId == 1) {
      // required, make optional
      SetSpawnStatus(id, Spawn_Optional, GetSpawnList(true), GetSpawnList(false));
      Executes_MessageToAll("Made spawn \"%s\" optional in execute.", g_SpawnNames[index]);

    } else {
      // optional, make not in use
      SetSpawnStatus(id, Spawn_NotUsed, GetSpawnList(true), GetSpawnList(false));
      Executes_MessageToAll("Removed spawn \"%s\" from execute.", g_SpawnNames[index]);
    }

    int menuPosition = GetMenuSelectionPosition();
    GiveExecuteSpawnsMenu(client, menuPosition);

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveNewExecuteMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

stock void GiveExecuteEditMenu(int client, int menuPosition = -1) {
  Menu menu = new Menu(GiveExecuteMenuHandler);
  menu.SetTitle("Select an execute to edit");
  menu.ExitButton = true;
  menu.ExitBackButton = true;

  int count = 0;

  for (int i = 0; i < g_NumExecutes; i++) {
    if (g_ExecuteDeleted[i]) {
      continue;
    }

    AddMenuOption(menu, g_ExecuteIDs[i], "%s (id:%s)", g_ExecuteNames[i], g_ExecuteIDs[i]);
    count++;
  }

  if (count == 0) {
    delete menu;
  } else {
    if (menuPosition == -1) {
      menu.Display(client, MENU_TIME_FOREVER);
    } else {
      menu.DisplayAt(client, menuPosition, MENU_TIME_FOREVER);
    }
  }
}

public int GiveExecuteMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char id[ID_LENGTH];
    menu.GetItem(param2, id, sizeof(id));
    int execute = ExecuteIdToIndex(id);

    g_TempNameBuffer = g_ExecuteNames[execute];
    g_EditingAnExecute = true;
    g_EditingExecuteIndex = execute;
    g_EditingExecuteSite = g_ExecuteSites[execute];
    g_EditingExecuteLikelihood = g_ExecuteLikelihood[execute];

    g_EditingExecuteTRequired.Clear();
    g_EditingExecuteTOptional.Clear();
    CopyList(g_ExecuteTSpawnsRequired[execute], g_EditingExecuteTRequired);
    CopyList(g_ExecuteTSpawnsOptional[execute], g_EditingExecuteTOptional);
    strcopy(g_EditingExecuteForceBombId, ID_LENGTH, g_ExecuteForceBombId[execute]);
    g_EditingExecuteStratTypes = g_ExecuteStratTypes[execute];

    GiveNewExecuteMenu(client);

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    g_EditingAnExecute = false;
    int client = param1;
    GiveNewExecuteMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

stock void GiveEditSpawnChoiceMenu(int client, int menuPosition = -1) {
  Menu menu = new Menu(GiveEditSpawnChoiceMenuHandler);
  menu.SetTitle("Select a spawn to edit");
  menu.ExitButton = true;
  menu.ExitBackButton = true;

  int count = 0;

  for (int i = 0; i < g_NumSpawns; i++) {
    if (g_SpawnDeleted[i]) {
      continue;
    }

    if (g_SpawnTeams[i] == CS_TEAM_CT) {
      AddMenuOption(menu, g_SpawnIDs[i], "%s (CT, id:%s)", g_SpawnNames[i], g_SpawnIDs[i]);
    } else {
      AddMenuOption(menu, g_SpawnIDs[i], "%s (T, id:%s)", g_SpawnNames[i], g_SpawnIDs[i]);
    }

    count++;
  }

  if (count == 0) {
    delete menu;
  } else {
    if (menuPosition == -1) {
      menu.Display(client, MENU_TIME_FOREVER);
    } else {
      menu.DisplayAt(client, menuPosition, MENU_TIME_FOREVER);
    }
  }
}

public int GiveEditSpawnChoiceMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char id[ID_LENGTH];
    menu.GetItem(param2, id, sizeof(id));
    int spawn = SpawnIdToIndex(id);
    EditSpawn(client, spawn);

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveEditorMenu(client);
    g_EditingASpawn = false;

  } else if (action == MenuAction_End) {
    delete menu;
  }
}

public void EditSpawn(int client, int spawn) {
  MoveToSpawnInEditor(client, spawn);
  g_TempNameBuffer = g_SpawnNames[spawn];
  g_EditingSpawnTeam = g_SpawnTeams[spawn];
  g_EditingSpawnGrenadeType = g_SpawnGrenadeTypes[spawn];
  g_EditingSpawnNadePoint = g_SpawnNadePoints[spawn];
  g_EditingSpawnNadeVelocity = g_SpawnNadeVelocities[spawn];
  g_EditingSpawnSiteFriendly = g_SpawnSiteFriendly[spawn];
  g_EditingSpawnAwpFriendly = g_SpawnAwpFriendly[spawn];
  g_EditingSpawnBombFriendly = g_SpawnBombFriendly[spawn];
  g_EditingSpawnLikelihood = g_SpawnLikelihood[spawn];
  g_EditingSpawnThrowTime = g_SpawnGrenadeThrowTimes[spawn];
  g_EditingSpawnFlags = g_SpawnFlags[spawn];

  g_EditingASpawn = true;
  g_EditingSpawnIndex = spawn;
  GiveNewSpawnMenu(client);
}

public void GiveEditFlagsMenu(int client) {
  Menu menu = new Menu(EditFlagsHandler);
  menu.SetTitle("Select a flag to toggle");
  menu.ExitButton = true;
  menu.ExitBackButton = true;

  AddFlag(menu, SPAWNFLAG_MOLOTOV, "molotov");
  AddFlag(menu, SPAWNFLAG_FLASH, "flash");
  AddFlag(menu, SPAWNFLAG_SMOKE, "smoke");

  AddFlag(menu, SPAWNFLAG_MAG7, "mag7", CS_TEAM_CT);
  AddFlag(menu, SPAWNFLAG_ALURKER, "A lurker", CS_TEAM_T);
  AddFlag(menu, SPAWNFLAG_BLURKER, "B lurker", CS_TEAM_T);

  menu.Display(client, MENU_TIME_FOREVER);
}

static void AddFlag(Menu menu, int flag, const char[] title, int team = -1) {
  char tmp[16] = "enabled";
  if (g_EditingSpawnFlags & flag == 0) {
    tmp = "disabled";
  }
  char display[64];
  Format(display, sizeof(display), "%s: %s", title, tmp);

  if (team == -1 || g_EditingSpawnTeam == team) {
    AddMenuInt(menu, flag, display);
  }
}

public int EditFlagsHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    int flagMask = GetMenuInt(menu, param2);

    if (g_EditingSpawnFlags & flagMask == 0) {
      // Enabled the flag
      g_EditingSpawnFlags |= flagMask;
    } else {
      // Disable the flag
      g_EditingSpawnFlags &= ~flagMask;
    }

    GiveEditFlagsMenu(client);

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveNewSpawnMenu(client);

  } else if (action == MenuAction_End) {
    delete menu;
  }
}

void SetSpawnStatus(const char[] id, SpawnStatus status, ArrayList req, ArrayList opt) {
  if (status == Spawn_NotUsed) {
    WipeFromList(req, id);
    WipeFromList(opt, id);
  } else if (status == Spawn_Required) {
    WipeFromList(opt, id);
    if (req.FindString(id) < 0) {
      req.PushString(id);
    }
  } else {
    // optional
    WipeFromList(req, id);
    if (opt.FindString(id) < 0) {
      opt.PushString(id);
    }
  }
}
